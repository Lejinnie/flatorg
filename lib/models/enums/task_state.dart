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
  vacant,
}
