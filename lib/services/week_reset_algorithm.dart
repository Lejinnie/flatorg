import 'package:flatorg/constants/strings.dart';
import 'package:flatorg/models/enums/task_state.dart';
import 'package:flatorg/models/person.dart';
import 'package:flatorg/models/task.dart';

/// Pure algorithm for weekly task reassignment — no Firebase dependency.
///
/// Implements all 8 steps of the assignment algorithm:
/// 1. Blue short vacation → assigned from L1 upward, slots protected
/// 2. Green L3 → move down to L2
/// 3. Green L2 → move down to L1
/// 4. Red L3 → stay at L3
/// 5. Red L2 → move up to L3
/// 6. Red L1 → move up to L2
/// 7. Green L1 → fill remaining slots
/// 8. Blue long vacation → fill remaining slots, unprotected
class WeekResetAlgorithm {
  /// Runs the full assignment algorithm on in-memory data.
  ///
  /// Returns a map of person UID → task doc ID representing the new
  /// assignments for the coming week. Also mutates [tasks] in place
  /// to increment [Task.weeksNotCleaned] where applicable.
  ///
  /// [tasks] — map of task doc ID → Task (current state).
  /// [persons] — map of person doc ID → Person (current state).
  /// [vacationThreshold] — weeks threshold for short vs. long vacation.
  Map<String, String> compute({
    required Map<String, Task> tasks,
    required Map<String, Person> persons,
    required int vacationThreshold,
  }) {
    final personTaskMap = buildPersonTaskMap(tasks);

    incrementWeeksNotCleaned(tasks, persons);

    final buckets = classifyPeople(
      tasks,
      persons,
      personTaskMap,
      vacationThreshold,
    );

    final assignedTaskIds = <String>{};
    final newAssignments = <String, String>{};
    final tasksByRing = tasksSortedByRing(tasks);

    // Step 1: Blue short vacation — L1 upward, protected slots
    assignBlueShortVacation(
      buckets.blueShortVacation,
      tasksByRing,
      personTaskMap,
      assignedTaskIds,
      newAssignments,
    );

    // Step 2: Green L3 → move to L2
    assignGreenDown(
      buckets.greenL3,
      Strings.difficultyLevelMedium,
      tasksByRing,
      personTaskMap,
      assignedTaskIds,
      newAssignments,
    );

    // Step 3: Green L2 → move to L1
    assignGreenDown(
      buckets.greenL2,
      Strings.difficultyLevelEasy,
      tasksByRing,
      personTaskMap,
      assignedTaskIds,
      newAssignments,
    );

    // Step 4: Red L3 → stay at L3
    assignRedSameLevel(
      buckets.redL3,
      Strings.difficultyLevelHard,
      tasksByRing,
      personTaskMap,
      assignedTaskIds,
      newAssignments,
    );

    // Step 5: Red L2 → move up to L3
    assignRedUp(
      buckets.redL2,
      Strings.difficultyLevelHard,
      Strings.difficultyLevelMedium,
      tasksByRing,
      personTaskMap,
      assignedTaskIds,
      newAssignments,
    );

    // Step 6: Red L1 → move up to L2
    assignRedUp(
      buckets.redL1,
      Strings.difficultyLevelMedium,
      Strings.difficultyLevelEasy,
      tasksByRing,
      personTaskMap,
      assignedTaskIds,
      newAssignments,
    );

    // Step 7: Green L1 → fill remaining
    assignToRemaining(
      buckets.greenL1,
      tasksByRing,
      assignedTaskIds,
      newAssignments,
    );

    // Step 8: Blue long vacation → fill remaining
    assignToRemaining(
      buckets.blueLongVacation,
      tasksByRing,
      assignedTaskIds,
      newAssignments,
    );

    return newAssignments;
  }

  // ---------------------------------------------------------------------------
  // Person → task lookup
  // ---------------------------------------------------------------------------

  /// Builds a map from person UID to (task doc ID, Task) using
  /// [Task.effectiveAssignedTo] to resolve swaps.
  Map<String, PersonTaskEntry> buildPersonTaskMap(Map<String, Task> tasks) {
    final map = <String, PersonTaskEntry>{};
    for (final entry in tasks.entries) {
      final uid = entry.value.effectiveAssignedTo;
      if (uid.isNotEmpty) {
        map[uid] = PersonTaskEntry(entry.key, entry.value);
      }
    }
    return map;
  }

  // ---------------------------------------------------------------------------
  // Pre-assignment: increment weeksNotCleaned
  // ---------------------------------------------------------------------------

  /// Increments [Task.weeksNotCleaned] on tasks whose assignee is on vacation
  /// or whose state is [TaskState.vacant].
  void incrementWeeksNotCleaned(
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
  Buckets classifyPeople(
    Map<String, Task> tasks,
    Map<String, Person> persons,
    Map<String, PersonTaskEntry> personTaskMap,
    int vacationThreshold,
  ) {
    final buckets = Buckets();

    for (final person in persons.values) {
      final entry = personTaskMap[person.uid];
      if (entry == null) continue;

      final task = entry.task;
      final level = task.difficultyLevel;

      if (person.onVacation) {
        if (task.weeksNotCleaned <= vacationThreshold) {
          buckets.blueShortVacation.add(PersonWithRing(person, task));
        } else {
          buckets.blueLongVacation.add(PersonWithRing(person, task));
        }
        continue;
      }

      final isGreen = task.state == TaskState.completed;

      if (isGreen) {
        switch (level) {
          case Strings.difficultyLevelHard:
            buckets.greenL3.add(PersonWithRing(person, task));
          case Strings.difficultyLevelMedium:
            buckets.greenL2.add(PersonWithRing(person, task));
          default:
            buckets.greenL1.add(PersonWithRing(person, task));
        }
      } else {
        switch (level) {
          case Strings.difficultyLevelHard:
            buckets.redL3.add(PersonWithRing(person, task));
          case Strings.difficultyLevelMedium:
            buckets.redL2.add(PersonWithRing(person, task));
          default:
            buckets.redL1.add(PersonWithRing(person, task));
        }
      }
    }

    for (final bucket in buckets.all) {
      bucket.sort(
          (a, b) => a.task.taskRingIndex.compareTo(b.task.taskRingIndex));
    }

    return buckets;
  }

  // ---------------------------------------------------------------------------
  // Task sorting helpers
  // ---------------------------------------------------------------------------

  /// Returns task entries sorted by task-ring index.
  List<MapEntry<String, Task>> tasksSortedByRing(Map<String, Task> tasks) {
    final sorted = tasks.entries.toList()
      ..sort(
          (a, b) => a.value.taskRingIndex.compareTo(b.value.taskRingIndex));
    return sorted;
  }

  // ---------------------------------------------------------------------------
  // Assignment steps
  // ---------------------------------------------------------------------------

  /// Step 1: Assign blue short-vacation people starting from L1 upward.
  ///
  /// Among vacation people, those with harder original tasks get the harder
  /// available slots. Slots are protected — Green people skip over them.
  void assignBlueShortVacation(
    List<PersonWithRing> people,
    List<MapEntry<String, Task>> tasksByRing,
    Map<String, PersonTaskEntry> personTaskMap,
    Set<String> assignedTaskIds,
    Map<String, String> newAssignments,
  ) {
    final sorted = List<PersonWithRing>.from(people)
      ..sort(
          (a, b) => b.task.difficultyLevel.compareTo(a.task.difficultyLevel));

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
  void assignGreenDown(
    List<PersonWithRing> people,
    int targetLevel,
    List<MapEntry<String, Task>> tasksByRing,
    Map<String, PersonTaskEntry> personTaskMap,
    Set<String> assignedTaskIds,
    Map<String, String> newAssignments,
  ) {
    for (final pw in people) {
      final currentRingIdx = pw.task.taskRingIndex;
      final assigned = scanForwardForLevel(
        currentRingIdx,
        targetLevel,
        tasksByRing,
        assignedTaskIds,
      );
      if (assigned != null) {
        newAssignments[pw.person.uid] = assigned;
        assignedTaskIds.add(assigned);
      } else {
        assignSameOrAnyAtLevel(
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
  void assignRedSameLevel(
    List<PersonWithRing> people,
    int level,
    List<MapEntry<String, Task>> tasksByRing,
    Map<String, PersonTaskEntry> personTaskMap,
    Set<String> assignedTaskIds,
    Map<String, String> newAssignments,
  ) {
    for (final pw in people) {
      assignSameOrAnyAtLevel(
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
  void assignRedUp(
    List<PersonWithRing> people,
    int targetLevel,
    int fallbackLevel,
    List<MapEntry<String, Task>> tasksByRing,
    Map<String, PersonTaskEntry> personTaskMap,
    Set<String> assignedTaskIds,
    Map<String, String> newAssignments,
  ) {
    for (final pw in people) {
      final assigned = firstAvailableAtLevel(
        targetLevel,
        tasksByRing,
        assignedTaskIds,
      );
      if (assigned != null) {
        newAssignments[pw.person.uid] = assigned;
        assignedTaskIds.add(assigned);
      } else {
        assignSameOrAnyAtLevel(
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
  void assignToRemaining(
    List<PersonWithRing> people,
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
  String? scanForwardForLevel(
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
  String? firstAvailableAtLevel(
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
  void assignSameOrAnyAtLevel(
    PersonWithRing pw,
    int level,
    List<MapEntry<String, Task>> tasksByRing,
    Map<String, PersonTaskEntry> personTaskMap,
    Set<String> assignedTaskIds,
    Map<String, String> newAssignments,
  ) {
    final currentTaskEntry = personTaskMap[pw.person.uid];
    if (currentTaskEntry != null &&
        !assignedTaskIds.contains(currentTaskEntry.taskDocId)) {
      newAssignments[pw.person.uid] = currentTaskEntry.taskDocId;
      assignedTaskIds.add(currentTaskEntry.taskDocId);
      return;
    }
    final assigned =
        firstAvailableAtLevel(level, tasksByRing, assignedTaskIds);
    if (assigned != null) {
      newAssignments[pw.person.uid] = assigned;
      assignedTaskIds.add(assigned);
    }
  }
}

// ---------------------------------------------------------------------------
// Data classes (public for testability)
// ---------------------------------------------------------------------------

/// Associates a person UID with their effective task doc ID and Task object.
class PersonTaskEntry {
  final String taskDocId;
  final Task task;

  PersonTaskEntry(this.taskDocId, this.task);
}

/// A person paired with their current task, for ring-order sorting.
class PersonWithRing {
  final Person person;
  final Task task;

  PersonWithRing(this.person, this.task);
}

/// Holds the 8 algorithm buckets for person classification.
class Buckets {
  final List<PersonWithRing> blueShortVacation = [];
  final List<PersonWithRing> greenL3 = [];
  final List<PersonWithRing> greenL2 = [];
  final List<PersonWithRing> redL3 = [];
  final List<PersonWithRing> redL2 = [];
  final List<PersonWithRing> redL1 = [];
  final List<PersonWithRing> greenL1 = [];
  final List<PersonWithRing> blueLongVacation = [];

  /// All buckets as a list, for bulk operations like sorting.
  List<List<PersonWithRing>> get all => [
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
