import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/strings.dart';

/// Difficulty level of a task in the rotation ring.
enum TaskLevel {
  l1, // easy: Recycling, Washing Rags, Shopping
  l2, // medium: Kitchen, Floor(A), Floor(B)
  l3, // hard: Toilet, Shower, Bathroom
}

/// String representation stored in Firestore for [TaskLevel].
extension TaskLevelJson on TaskLevel {
  String toJson() {
    switch (this) {
      case TaskLevel.l1:
        return 'L1';
      case TaskLevel.l2:
        return 'L2';
      case TaskLevel.l3:
        return 'L3';
    }
  }

  static TaskLevel fromJson(String value) {
    switch (value) {
      case 'L2':
        return TaskLevel.l2;
      case 'L3':
        return TaskLevel.l3;
      default:
        return TaskLevel.l1;
    }
  }
}

/// Lifecycle state of a task within a single week.
enum TaskState {
  /// Set by week_reset(). Task not yet done — shown in yellow.
  pending,

  /// Assignee marked done before deadline — shown in green.
  completed,

  /// Deadline passed without completion (grace period) — shown in red.
  notDone,

  /// Assignee was removed mid-week by admin. Treated like vacation.
  vacant,
}

/// String representation stored in Firestore for [TaskState].
extension TaskStateJson on TaskState {
  String toJson() {
    switch (this) {
      case TaskState.pending:
        return 'pending';
      case TaskState.completed:
        return 'completed';
      case TaskState.notDone:
        return 'not_done';
      case TaskState.vacant:
        return 'vacant';
    }
  }

  static TaskState fromJson(String value) {
    switch (value) {
      case 'completed':
        return TaskState.completed;
      case 'not_done':
        return TaskState.notDone;
      case 'vacant':
        return TaskState.vacant;
      default:
        return TaskState.pending;
    }
  }
}

/// A single household task stored as a Firestore document.
/// Acts as a state machine; transitions are driven by Cloud Function events.
class Task {
  /// Firestore document ID.
  final String id;

  /// Display name (e.g. 'Toilet', 'Kitchen').
  final String name;

  /// Ordered list of subtask instructions shown to the assignee.
  final List<String> description;

  /// When the task must be completed.
  final Timestamp dueDateTime;

  /// UID of the currently assigned person. Empty string when vacant.
  final String assignedTo;

  /// UID of the pre-swap assignee. Empty string when no swap is active.
  /// week_reset() reads [effectiveAssignedTo] to determine green/red status.
  final String originalAssignedTo;

  /// Current lifecycle state.
  final TaskState state;

  /// Increments each week while the assignee is on vacation or task is vacant.
  /// Resets to 0 when completed normally.
  final int weeksNotCleaned;

  /// Position in the canonical task ring (0–8).
  final int ringIndex;

  const Task({
    required this.id,
    required this.name,
    required this.description,
    required this.dueDateTime,
    required this.assignedTo,
    required this.originalAssignedTo,
    required this.state,
    required this.weeksNotCleaned,
    required this.ringIndex,
  });

  /// Returns the effective assignee UID, respecting active swap overrides.
  /// week_reset() must use this — never [assignedTo] directly.
  String get effectiveAssignedTo =>
      originalAssignedTo.isNotEmpty ? originalAssignedTo : assignedTo;

  /// Creates a Task from a Firestore document snapshot.
  factory Task.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Task(
      id: doc.id,
      name: (data[fieldTaskName] as String?) ?? '',
      description: List<String>.from(data[fieldTaskDescription] as List? ?? []),
      dueDateTime: data[fieldTaskDueDateTime] as Timestamp,
      assignedTo: (data[fieldTaskAssignedTo] as String?) ?? '',
      originalAssignedTo: (data[fieldTaskOriginalAssignedTo] as String?) ?? '',
      state: TaskStateJson.fromJson((data[fieldTaskState] as String?) ?? 'pending'),
      weeksNotCleaned: (data[fieldTaskWeeksNotCleaned] as int?) ?? 0,
      ringIndex: (data[fieldTaskRingIndex] as int?) ?? -1,
    );
  }

  /// Converts this task to a Firestore-compatible map (excludes [id]).
  Map<String, dynamic> toFirestore() {
    return {
      fieldTaskName: name,
      fieldTaskDescription: description,
      fieldTaskDueDateTime: dueDateTime,
      fieldTaskAssignedTo: assignedTo,
      fieldTaskOriginalAssignedTo: originalAssignedTo,
      fieldTaskState: state.toJson(),
      fieldTaskWeeksNotCleaned: weeksNotCleaned,
      fieldTaskRingIndex: ringIndex,
    };
  }

  /// Returns a copy of this task with the specified fields replaced.
  Task copyWith({
    String? id,
    String? name,
    List<String>? description,
    Timestamp? dueDateTime,
    String? assignedTo,
    String? originalAssignedTo,
    TaskState? state,
    int? weeksNotCleaned,
    int? ringIndex,
  }) {
    return Task(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      dueDateTime: dueDateTime ?? this.dueDateTime,
      assignedTo: assignedTo ?? this.assignedTo,
      originalAssignedTo: originalAssignedTo ?? this.originalAssignedTo,
      state: state ?? this.state,
      weeksNotCleaned: weeksNotCleaned ?? this.weeksNotCleaned,
      ringIndex: ringIndex ?? this.ringIndex,
    );
  }
}
