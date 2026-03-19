import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flatorg/constants/strings.dart';
import 'package:flatorg/models/enums/task_state.dart';
import 'package:flatorg/models/person.dart';

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

  /// Firebase Auth UID of the currently assigned person, or empty if vacant.
  String assignedTo;

  /// Firebase Auth UID of the person assigned before any swap occurred.
  /// Used by [WeekResetService.resetForNewWeek] to determine green/red status.
  /// Never updated while the assignee is on vacation.
  String originalAssignedTo;

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
    this.assignedTo = '',
    this.originalAssignedTo = '',
    this.state = TaskState.pending,
    this.weeksNotCleaned = 0,
  });

  /// The difficulty level of this task (1 = easy, 2 = medium, 3 = hard).
  ///
  /// Derived from the task name using the canonical difficulty groupings:
  /// - L3 (hard): Toilet, Shower, Bathroom
  /// - L2 (medium): Floor (A), Floor (B), Kitchen
  /// - L1 (easy): Recycling, Washing Rags, Shopping
  int get difficultyLevel =>
      Strings.taskDifficultyMap[name] ?? Strings.difficultyLevelEasy;

  /// The zero-based index of this task in the task ring order.
  ///
  /// Returns -1 if the task name is not in the canonical ring.
  int get taskRingIndex => Strings.taskRingOrder.indexOf(name);

  // ---------------------------------------------------------------------------
  // State transition methods
  // ---------------------------------------------------------------------------

  /// Transitions the task from [TaskState.pending] to [TaskState.notDone].
  ///
  /// Triggered by a Cloud Function when this task's own deadline passes.
  /// The UI updates the task color from yellow to red.
  ///
  /// Throws [StateError] if [state] is not [TaskState.pending].
  void enterGracePeriod() {
    if (state != TaskState.pending) {
      throw StateError(
        'Cannot enter grace period from state $state; expected pending.',
      );
    }
    state = TaskState.notDone;
  }

  /// Marks this task as completed and resets vacation-related counters.
  ///
  /// Called when the assigned person marks their task as done before the
  /// deadline. This method:
  /// 1. Sets [state] to [TaskState.completed].
  /// 2. Resets [weeksNotCleaned] to 0.
  /// 3. Clears [onVacation] on the assigned [person].
  /// 4. Updates [originalAssignedTo] to this task's assignee (only if the
  ///    [person] is not on vacation).
  ///
  /// Throws [StateError] if [state] is not [TaskState.pending].
  void completedTask(Person person) {
    if (state != TaskState.pending) {
      throw StateError(
        'Cannot complete task from state $state; expected pending.',
      );
    }
    state = TaskState.completed;
    weeksNotCleaned = 0;
    person.onVacation = false;
    if (!person.onVacation) {
      originalAssignedTo = assignedTo;
    }
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
  /// [requester] — the person initiating the swap.
  ///
  /// Throws [StateError] if [requester] has no swap tokens remaining.
  void requestChangeTask(String targetPersonUid, Person requester) {
    if (requester.swapTokensRemaining <= 0) {
      throw StateError('No swap tokens remaining.');
    }
    // Swap request creation is handled by the service/repository layer
    // which writes to Firestore and triggers push notifications.
    throw UnimplementedError(
      'Swap request creation requires Firestore write — '
      'implement in service layer.',
    );
  }

  // ---------------------------------------------------------------------------
  // Firestore serialization
  // ---------------------------------------------------------------------------

  /// Creates a [Task] instance from a Firestore document snapshot.
  ///
  /// [data] — the `Map<String, dynamic>` from `DocumentSnapshot.data()`.
  /// Expects fields matching [Strings] field name constants.
  factory Task.fromFirestore(Map<String, dynamic> data) {
    final rawDueDate = data[Strings.fieldDueDateTime];
    DateTime dueDateTime;
    if (rawDueDate is Timestamp) {
      dueDateTime = rawDueDate.toDate();
    } else if (rawDueDate is DateTime) {
      dueDateTime = rawDueDate;
    } else {
      dueDateTime = DateTime.now();
    }

    return Task(
      name: data[Strings.fieldName] as String? ?? '',
      description: List<String>.from(
        data[Strings.fieldDescription] as List? ?? [],
      ),
      dueDateTime: dueDateTime,
      assignedTo: data[Strings.fieldAssignedTo] as String? ?? '',
      originalAssignedTo: data[Strings.fieldOriginalAssignedTo] as String? ?? '',
      state: TaskState.fromFirestore(data[Strings.fieldState] as String?),
      weeksNotCleaned: data[Strings.fieldWeeksNotCleaned] as int? ?? 0,
    );
  }

  /// Serializes this [Task] to a `Map<String, dynamic>` for Firestore writes.
  Map<String, dynamic> toFirestore() {
    return {
      Strings.fieldName: name,
      Strings.fieldDescription: description,
      Strings.fieldDueDateTime: Timestamp.fromDate(dueDateTime),
      Strings.fieldAssignedTo: assignedTo,
      Strings.fieldOriginalAssignedTo: originalAssignedTo,
      Strings.fieldState: state.toFirestore(),
      Strings.fieldWeeksNotCleaned: weeksNotCleaned,
    };
  }
}
