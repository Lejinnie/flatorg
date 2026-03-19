/// Represents the current state of a household task.
///
/// Used as a state machine: transitions are enforced by [Task] methods
/// and the week reset algorithm.
enum TaskState {
  /// Task assigned but not yet completed. Displayed as yellow in UI.
  pending,

  /// Task was completed before its deadline. Displayed as green in UI.
  completed,

  /// Deadline passed without completion; person is in grace period.
  /// Displayed as red in UI.
  notDone,

  /// Assigned person was removed by admin mid-week. No assignee.
  vacant;

  /// Firestore string representation of this state.
  String toFirestore() {
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

  /// Parses a Firestore string into a [TaskState].
  ///
  /// Returns [TaskState.pending] if the value is null or unrecognized.
  static TaskState fromFirestore(String? value) {
    switch (value) {
      case 'pending':
        return TaskState.pending;
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
