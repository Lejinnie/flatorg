import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flatorg/constants/strings.dart';
import 'package:flatorg/models/enums/task_state.dart';
import 'package:flatorg/models/person.dart';
import 'package:flatorg/models/task.dart';

/// Service responsible for the weekly task reassignment algorithm.
///
/// This runs as a Cloud Function, triggered X hours (admin-configurable
/// grace period) after the latest due date of any task in the current week.
/// Must execute as an atomic Firestore transaction.
class WeekResetService {
  final FirebaseFirestore _firestore;

  WeekResetService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Runs the full weekly reset algorithm for a flat.
  ///
  /// Steps executed in order:
  /// 1. Blue short vacation → assigned from L1 upward, slots protected
  /// 2. Green L3 → move down to L2
  /// 3. Green L2 → move down to L1
  /// 4. Red L3 → stay at L3
  /// 5. Red L2 → move up to L3
  /// 6. Red L1 → move up to L2
  /// 7. Green L1 → fill remaining slots
  /// 8. Blue long vacation → fill remaining slots, unprotected
  ///
  /// Before assignment, increments [Task.weeksNotCleaned] on every task
  /// whose assignee is on vacation or whose state is vacant.
  ///
  /// Within each step, people are processed in sequential task-ring order
  /// (Toilet → Kitchen → ... → Shopping).
  ///
  /// [flatId] — the Firestore document ID of the flat to reset.
  Future<void> weekReset(String flatId) async {
    final flatRef = _firestore
        .collection(Strings.collectionFlats)
        .doc(flatId);

    await _firestore.runTransaction((transaction) async {
      // Read flat settings
      final flatSnap = await transaction.get(flatRef);
      final flatData = flatSnap.data() ?? {};
      final vacationThreshold = flatData[Strings.fieldVacationThresholdWeeks]
              as int? ??
          Strings.defaultVacationThresholdWeeks;

      // Read all tasks and persons
      final taskSnaps =
          await transaction.get(flatRef.collection(Strings.collectionTasks));
      final personSnaps =
          await transaction.get(flatRef.collection(Strings.collectionPersons));

      final tasks = <String, Task>{};
      final taskRefs = <String, DocumentReference>{};
      for (final doc in taskSnaps.docs) {
        tasks[doc.id] = Task.fromFirestore(doc.data());
        taskRefs[doc.id] = doc.reference;
      }

      final persons = <String, Person>{};
      final personRefs = <String, DocumentReference>{};
      for (final doc in personSnaps.docs) {
        persons[doc.id] = Person.fromFirestore(doc.data());
        personRefs[doc.id] = doc.reference;
      }

      // Build lookup: person UID → (taskDocId, task) for effective assignment
      final personTaskMap = _buildPersonTaskMap(tasks);

      // Increment weeksNotCleaned for vacation/vacant tasks
      _incrementWeeksNotCleaned(tasks, persons);

      // Classify people into algorithm buckets
      final buckets = _classifyPeople(
        tasks,
        persons,
        personTaskMap,
        vacationThreshold,
      );

      // Track which task doc IDs are assigned (by task ring index order)
      final assignedTaskIds = <String>{};
      // New assignments: person UID → task doc ID
      final newAssignments = <String, String>{};

      // Sort tasks by ring index for consistent ordering
      final tasksByRing = _tasksSortedByRing(tasks);

      // Step 1: Blue short vacation — L1 upward, protected slots
      _assignBlueShortVacation(
        buckets.blueShortVacation,
        tasksByRing,
        personTaskMap,
        assignedTaskIds,
        newAssignments,
      );

      // Step 2: Green L3 → move to L2
      _assignGreenDown(
        buckets.greenL3,
        Strings.difficultyLevelMedium,
        tasksByRing,
        personTaskMap,
        assignedTaskIds,
        newAssignments,
      );

      // Step 3: Green L2 → move to L1
      _assignGreenDown(
        buckets.greenL2,
        Strings.difficultyLevelEasy,
        tasksByRing,
        personTaskMap,
        assignedTaskIds,
        newAssignments,
      );

      // Step 4: Red L3 → stay at L3
      _assignRedSameLevel(
        buckets.redL3,
        Strings.difficultyLevelHard,
        tasksByRing,
        personTaskMap,
        assignedTaskIds,
        newAssignments,
      );

      // Step 5: Red L2 → move up to L3
      _assignRedUp(
        buckets.redL2,
        Strings.difficultyLevelHard,
        Strings.difficultyLevelMedium,
        tasksByRing,
        personTaskMap,
        assignedTaskIds,
        newAssignments,
      );

      // Step 6: Red L1 → move up to L2
      _assignRedUp(
        buckets.redL1,
        Strings.difficultyLevelMedium,
        Strings.difficultyLevelEasy,
        tasksByRing,
        personTaskMap,
        assignedTaskIds,
        newAssignments,
      );

      // Step 7: Green L1 → fill remaining
      _assignToRemaining(
        buckets.greenL1,
        tasksByRing,
        assignedTaskIds,
        newAssignments,
      );

      // Step 8: Blue long vacation → fill remaining
      _assignToRemaining(
        buckets.blueLongVacation,
        tasksByRing,
        assignedTaskIds,
        newAssignments,
      );

      // Write all updates in the transaction
      _writeUpdates(
        transaction,
        tasks,
        taskRefs,
        persons,
        personRefs,
        newAssignments,
      );
    });
  }

  // ---------------------------------------------------------------------------
  // Person → task lookup
  // ---------------------------------------------------------------------------

  /// Builds a map from person UID to (task doc ID, Task) using
  /// [Task.effectiveAssignedTo] to resolve swaps.
  Map<String, _PersonTaskEntry> _buildPersonTaskMap(Map<String, Task> tasks) {
    final map = <String, _PersonTaskEntry>{};
    for (final entry in tasks.entries) {
      final uid = entry.value.effectiveAssignedTo;
      if (uid.isNotEmpty) {
        map[uid] = _PersonTaskEntry(entry.key, entry.value);
      }
    }
    return map;
  }

  // ---------------------------------------------------------------------------
  // Pre-assignment: increment weeksNotCleaned
  // ---------------------------------------------------------------------------

  void _incrementWeeksNotCleaned(
    Map<String, Task> tasks,
    Map<String, Person> persons,
  ) {
    for (final task in tasks.values) {
      if (task.state == TaskState.vacant) {
        task.weeksNotCleaned++;
        continue;
      }
      final assignee = persons.values
          .where((p) => p.uid == task.effectiveAssignedTo)
          .firstOrNull;
      if (assignee != null && assignee.onVacation) {
        task.weeksNotCleaned++;
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Classification
  // ---------------------------------------------------------------------------

  /// Classifies each person into one of the 8 algorithm buckets.
  ///
  /// Each bucket is sorted by task-ring index for deterministic processing.
  _Buckets _classifyPeople(
    Map<String, Task> tasks,
    Map<String, Person> persons,
    Map<String, _PersonTaskEntry> personTaskMap,
    int vacationThreshold,
  ) {
    final buckets = _Buckets();

    for (final person in persons.values) {
      final entry = personTaskMap[person.uid];
      if (entry == null) continue;

      final task = entry.task;
      final level = task.difficultyLevel;

      if (person.onVacation) {
        if (task.weeksNotCleaned <= vacationThreshold) {
          buckets.blueShortVacation.add(_PersonWithRing(person, task));
        } else {
          buckets.blueLongVacation.add(_PersonWithRing(person, task));
        }
        continue;
      }

      final isGreen = task.state == TaskState.completed;

      if (isGreen) {
        switch (level) {
          case Strings.difficultyLevelHard:
            buckets.greenL3.add(_PersonWithRing(person, task));
          case Strings.difficultyLevelMedium:
            buckets.greenL2.add(_PersonWithRing(person, task));
          default:
            buckets.greenL1.add(_PersonWithRing(person, task));
        }
      } else {
        switch (level) {
          case Strings.difficultyLevelHard:
            buckets.redL3.add(_PersonWithRing(person, task));
          case Strings.difficultyLevelMedium:
            buckets.redL2.add(_PersonWithRing(person, task));
          default:
            buckets.redL1.add(_PersonWithRing(person, task));
        }
      }
    }

    // Sort each bucket by task-ring index
    for (final bucket in buckets.all) {
      bucket.sort((a, b) => a.task.taskRingIndex.compareTo(b.task.taskRingIndex));
    }

    return buckets;
  }

  // ---------------------------------------------------------------------------
  // Task sorting helpers
  // ---------------------------------------------------------------------------

  /// Returns task entries sorted by task-ring index.
  List<MapEntry<String, Task>> _tasksSortedByRing(Map<String, Task> tasks) {
    final sorted = tasks.entries.toList()
      ..sort((a, b) =>
          a.value.taskRingIndex.compareTo(b.value.taskRingIndex));
    return sorted;
  }

  // ---------------------------------------------------------------------------
  // Assignment steps
  // ---------------------------------------------------------------------------

  /// Step 1: Assign blue short-vacation people starting from L1 upward.
  ///
  /// Among vacation people, those with harder original tasks get the harder
  /// available slots. Slots are protected — Green people skip over them.
  void _assignBlueShortVacation(
    List<_PersonWithRing> people,
    List<MapEntry<String, Task>> tasksByRing,
    Map<String, _PersonTaskEntry> personTaskMap,
    Set<String> assignedTaskIds,
    Map<String, String> newAssignments,
  ) {
    // Sort by difficulty descending so harder-original people pick first
    final sorted = List<_PersonWithRing>.from(people)
      ..sort((a, b) =>
          b.task.difficultyLevel.compareTo(a.task.difficultyLevel));

    // Collect available slots by level: L1 first, then L2, then L3
    final availableSlots = <MapEntry<String, Task>>[];
    for (final level in [
      Strings.difficultyLevelEasy,
      Strings.difficultyLevelMedium,
      Strings.difficultyLevelHard,
    ]) {
      for (final entry in tasksByRing) {
        if (entry.value.difficultyLevel == level &&
            !assignedTaskIds.contains(entry.key)) {
          availableSlots.add(entry);
        }
      }
    }

    // Assign harder-original people to harder available slots
    // (availableSlots is ordered L1→L2→L3, sorted people is L3→L2→L1)
    // Reverse available so harder slots are assigned first to harder people
    final reversedSlots = availableSlots.reversed.toList();
    for (var i = 0; i < sorted.length && i < reversedSlots.length; i++) {
      final slot = reversedSlots[i];
      newAssignments[sorted[i].person.uid] = slot.key;
      assignedTaskIds.add(slot.key);
    }
  }

  /// Steps 2 & 3: Green people move down one difficulty level.
  ///
  /// Scans forward from the person's current task-ring position for the
  /// next unassigned task at [targetLevel]. If none found, stays at current.
  void _assignGreenDown(
    List<_PersonWithRing> people,
    int targetLevel,
    List<MapEntry<String, Task>> tasksByRing,
    Map<String, _PersonTaskEntry> personTaskMap,
    Set<String> assignedTaskIds,
    Map<String, String> newAssignments,
  ) {
    for (final pw in people) {
      final currentRingIdx = pw.task.taskRingIndex;
      final assigned = _scanForwardForLevel(
        currentRingIdx,
        targetLevel,
        tasksByRing,
        assignedTaskIds,
      );
      if (assigned != null) {
        newAssignments[pw.person.uid] = assigned;
        assignedTaskIds.add(assigned);
      } else {
        // No target-level slot free — stay at current level
        _assignSameOrAnyAtLevel(
          pw,
          pw.task.difficultyLevel,
          tasksByRing,
          personTaskMap,
          assignedTaskIds,
          newAssignments,
        );
      }
    }
  }

  /// Step 4: Red people stay at the same difficulty level.
  ///
  /// Tries their same task first; if taken, takes another at the same level.
  void _assignRedSameLevel(
    List<_PersonWithRing> people,
    int level,
    List<MapEntry<String, Task>> tasksByRing,
    Map<String, _PersonTaskEntry> personTaskMap,
    Set<String> assignedTaskIds,
    Map<String, String> newAssignments,
  ) {
    for (final pw in people) {
      _assignSameOrAnyAtLevel(
        pw,
        level,
        tasksByRing,
        personTaskMap,
        assignedTaskIds,
        newAssignments,
      );
    }
  }

  /// Steps 5 & 6: Red people move up one difficulty level.
  ///
  /// Tries to assign to [targetLevel]. If all full, stays at [fallbackLevel].
  void _assignRedUp(
    List<_PersonWithRing> people,
    int targetLevel,
    int fallbackLevel,
    List<MapEntry<String, Task>> tasksByRing,
    Map<String, _PersonTaskEntry> personTaskMap,
    Set<String> assignedTaskIds,
    Map<String, String> newAssignments,
  ) {
    for (final pw in people) {
      final assigned = _firstAvailableAtLevel(
        targetLevel,
        tasksByRing,
        assignedTaskIds,
      );
      if (assigned != null) {
        newAssignments[pw.person.uid] = assigned;
        assignedTaskIds.add(assigned);
      } else {
        // All target-level slots full — stay at current level
        _assignSameOrAnyAtLevel(
          pw,
          fallbackLevel,
          tasksByRing,
          personTaskMap,
          assignedTaskIds,
          newAssignments,
        );
      }
    }
  }

  /// Steps 7 & 8: Fill whatever slots remain.
  void _assignToRemaining(
    List<_PersonWithRing> people,
    List<MapEntry<String, Task>> tasksByRing,
    Set<String> assignedTaskIds,
    Map<String, String> newAssignments,
  ) {
    for (final pw in people) {
      if (newAssignments.containsKey(pw.person.uid)) continue;
      for (final entry in tasksByRing) {
        if (!assignedTaskIds.contains(entry.key)) {
          newAssignments[pw.person.uid] = entry.key;
          assignedTaskIds.add(entry.key);
          break;
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Scanning helpers
  // ---------------------------------------------------------------------------

  /// Scans forward from [startRingIdx] in the task ring for the next
  /// unassigned task at [targetLevel]. Returns the task doc ID or null.
  String? _scanForwardForLevel(
    int startRingIdx,
    int targetLevel,
    List<MapEntry<String, Task>> tasksByRing,
    Set<String> assignedTaskIds,
  ) {
    final ringSize = Strings.taskRingOrder.length;
    for (var offset = 1; offset <= ringSize; offset++) {
      final ringIdx = (startRingIdx + offset) % ringSize;
      for (final entry in tasksByRing) {
        if (entry.value.taskRingIndex == ringIdx &&
            entry.value.difficultyLevel == targetLevel &&
            !assignedTaskIds.contains(entry.key)) {
          return entry.key;
        }
      }
    }
    return null;
  }

  /// Returns the first unassigned task doc ID at [level], in ring order.
  String? _firstAvailableAtLevel(
    int level,
    List<MapEntry<String, Task>> tasksByRing,
    Set<String> assignedTaskIds,
  ) {
    for (final entry in tasksByRing) {
      if (entry.value.difficultyLevel == level &&
          !assignedTaskIds.contains(entry.key)) {
        return entry.key;
      }
    }
    return null;
  }

  /// Tries to assign [pw] to their same task; if taken, any unassigned task
  /// at [level].
  void _assignSameOrAnyAtLevel(
    _PersonWithRing pw,
    int level,
    List<MapEntry<String, Task>> tasksByRing,
    Map<String, _PersonTaskEntry> personTaskMap,
    Set<String> assignedTaskIds,
    Map<String, String> newAssignments,
  ) {
    final currentTaskEntry = personTaskMap[pw.person.uid];
    // Try same task first
    if (currentTaskEntry != null &&
        !assignedTaskIds.contains(currentTaskEntry.taskDocId)) {
      newAssignments[pw.person.uid] = currentTaskEntry.taskDocId;
      assignedTaskIds.add(currentTaskEntry.taskDocId);
      return;
    }
    // Otherwise any unassigned at this level
    final assigned = _firstAvailableAtLevel(level, tasksByRing, assignedTaskIds);
    if (assigned != null) {
      newAssignments[pw.person.uid] = assigned;
      assignedTaskIds.add(assigned);
    }
  }

  // ---------------------------------------------------------------------------
  // Transaction writes
  // ---------------------------------------------------------------------------

  /// Writes all updated task and person documents in the transaction.
  void _writeUpdates(
    Transaction transaction,
    Map<String, Task> tasks,
    Map<String, DocumentReference> taskRefs,
    Map<String, Person> persons,
    Map<String, DocumentReference> personRefs,
    Map<String, String> newAssignments,
  ) {
    // Build reverse map: task doc ID → person UID
    final taskToPersonUid = <String, String>{};
    for (final entry in newAssignments.entries) {
      taskToPersonUid[entry.value] = entry.key;
    }

    // Update each task
    for (final entry in tasks.entries) {
      final taskDocId = entry.key;
      final task = entry.value;
      final newUid = taskToPersonUid[taskDocId] ?? '';

      transaction.update(taskRefs[taskDocId]!, {
        Strings.fieldAssignedTo: newUid,
        Strings.fieldOriginalAssignedTo: '',
        Strings.fieldState: TaskState.pending.toFirestore(),
        Strings.fieldWeeksNotCleaned: task.weeksNotCleaned,
      });
    }

    // Clear vacation on persons who were assigned (they re-enter the rotation)
    // Vacation status persists — only completedTask() clears it.
  }
}

// ---------------------------------------------------------------------------
// Internal data classes
// ---------------------------------------------------------------------------

/// Associates a person UID with their effective task doc ID and Task object.
class _PersonTaskEntry {
  final String taskDocId;
  final Task task;

  _PersonTaskEntry(this.taskDocId, this.task);
}

/// A person paired with their current task, for ring-order sorting.
class _PersonWithRing {
  final Person person;
  final Task task;

  _PersonWithRing(this.person, this.task);
}

/// Holds the 8 algorithm buckets for person classification.
class _Buckets {
  final List<_PersonWithRing> blueShortVacation = [];
  final List<_PersonWithRing> greenL3 = [];
  final List<_PersonWithRing> greenL2 = [];
  final List<_PersonWithRing> redL3 = [];
  final List<_PersonWithRing> redL2 = [];
  final List<_PersonWithRing> redL1 = [];
  final List<_PersonWithRing> greenL1 = [];
  final List<_PersonWithRing> blueLongVacation = [];

  /// All buckets as a list, for bulk operations like sorting.
  List<List<_PersonWithRing>> get all => [
        blueShortVacation,
        greenL3,
        greenL2,
        redL3,
        redL2,
        redL1,
        greenL1,
        blueLongVacation,
      ];
}
