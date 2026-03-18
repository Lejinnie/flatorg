import 'package:flatorg/constants/strings.dart';
import 'package:flatorg/models/enums/task_state.dart';

/// A household task that acts as a state machine stored in Firestore.
///
/// Each task has a difficulty level (L1 easy, L2 medium, L3 hard) and
/// cycles through states: [TaskState.pending] → [TaskState.completed]
/// or [TaskState.notDone], then back to [TaskState.pending] on weekly reset.
///
/// State transitions:
/// - **Pending → Completed**: person marks task done before deadline.
/// - **Pending → Not Done**: deadline passes without completion.
/// - **Not Done → Pending**: [WeekResetService.resetForNewWeek] fires.
/// - **Completed → Pending**: [WeekResetService.resetForNewWeek] fires.
/// - **Vacant**: admin removed the assigned person mid-week.
class Task {
  /// Display name of the task (e.g. "Toilet", "Kitchen").
  final String name;

  /// Ordered list of subtask descriptions the assignee should complete.
  final List<String> description;

  /// When this task is due. Configurable per task by admin.
  final DateTime dueDateTime;

  /// Firebase Auth UID of the currently assigned person, or null if vacant.
  String? assignedTo;

  /// Firebase Auth UID of the person assigned before any swap occurred.
  /// Used by [WeekResetService.resetForNewWeek] to determine green/red status.
  /// Never updated while the assignee is on vacation.
  String? originalAssignedTo;

  /// Current state of the task in its lifecycle.
  TaskState state;

  /// Number of consecutive weeks this task went uncleaned (assignee on
  /// vacation or task vacant). Resets to 0 when completed normally.
  /// Determines short (≤ threshold) vs. long (> threshold) vacation treatment.
  int weeksNotCleaned;

  Task({
    required this.name,
    required this.description,
    required this.dueDateTime,
    this.assignedTo,
    this.originalAssignedTo,
    this.state = TaskState.pending,
    this.weeksNotCleaned = 0,
  });

  /// The difficulty level of this task (1 = easy, 2 = medium, 3 = hard).
  ///
  /// Derived from the task name using the canonical difficulty groupings:
  /// - L3 (hard): Toilet, Shower, Bathroom
  /// - L2 (medium): Floor (A), Floor (B), Kitchen
  /// - L1 (easy): Recycling, Washing Rags, Shopping
  int get difficultyLevel {
    // TODO: implement
    return 0;
  }

  // ---------------------------------------------------------------------------
  // State transition methods
  // ---------------------------------------------------------------------------

  /// Transitions the task from [TaskState.pending] to [TaskState.notDone].
  ///
  /// Triggered by a Cloud Function when this task's own deadline passes.
  /// The UI updates the task color from yellow to red.
  ///
  /// Precondition: [state] must be [TaskState.pending].
  /// Postcondition: [state] is [TaskState.notDone].
  void enterGracePeriod() {
    // TODO: implement
  }

  /// Marks this task as completed and resets vacation-related counters.
  ///
  /// Called when the assigned person marks their task as done before the
  /// deadline. This method:
  /// 1. Sets [state] to [TaskState.completed].
  /// 2. Resets [weeksNotCleaned] to 0.
  /// 3. Clears [onVacation] on the assigned person.
  /// 4. Updates [originalAssignedTo] to this task's assignee (only if the
  ///    person is not on vacation).
  ///
  /// Precondition: [state] must be [TaskState.pending].
  /// Postcondition: [state] is [TaskState.completed], [weeksNotCleaned] is 0.
  void completedTask() {
    // TODO: implement
  }

  /// Fires a swap request event to the target person.
  ///
  /// The target person receives a push notification (Android) and sees
  /// a pending request in their in-app notification panel.
  ///
  /// On accept: [assignedTo] is swapped between both tasks (original
  /// assignments remain unchanged). Costs one swap token from the requester.
  ///
  /// On decline: request is cancelled and shown as declined in the
  /// requester's notification tile.
  ///
  /// [targetPersonUid] — the Firebase Auth UID of the person to swap with.
  ///
  /// Precondition: requester must have at least 1 swap token remaining.
  void requestChangeTask(String targetPersonUid) {
    // TODO: implement
  }

  // ---------------------------------------------------------------------------
  // Firestore serialization
  // ---------------------------------------------------------------------------

  /// Creates a [Task] instance from a Firestore document snapshot.
  ///
  /// [data] — the `Map<String, dynamic>` from `DocumentSnapshot.data()`.
  /// Expects fields matching [Strings] field name constants.
  factory Task.fromFirestore(Map<String, dynamic> data) {
    // TODO: implement deserialization
    return Task(
      name: data[Strings.fieldName] as String? ?? '',
      description: List<String>.from(
        data[Strings.fieldDescription] as List? ?? [],
      ),
      dueDateTime: DateTime.now(),
      assignedTo: data[Strings.fieldAssignedTo] as String?,
      originalAssignedTo: data[Strings.fieldOriginalAssignedTo] as String?,
      weeksNotCleaned: data[Strings.fieldWeeksNotCleaned] as int? ?? 0,
    );
  }

  /// Serializes this [Task] to a `Map<String, dynamic>` for Firestore writes.
  Map<String, dynamic> toFirestore() {
    // TODO: implement serialization
    return {};
  }
}
