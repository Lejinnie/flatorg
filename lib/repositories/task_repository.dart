import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/strings.dart';
import '../models/task.dart';

/// Repository for Task documents under flats/{flatId}/tasks.
/// All Firestore access for tasks goes through this class (Repository pattern).
/// UI layers observe streams; Cloud Functions handle write-heavy operations.
class TaskRepository {
  final FirebaseFirestore _db;

  TaskRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  /// Returns the Firestore collection reference for tasks in a flat.
  CollectionReference<Map<String, dynamic>> _tasksCollection(String flatId) =>
      _db
          .collection(collectionFlats)
          .doc(flatId)
          .collection(collectionTasks);

  /// Returns a real-time stream of all tasks for a flat, sorted by ring_index.
  /// The UI uses this via StreamBuilder to reactively rebuild on changes.
  Stream<List<Task>> watchTasks(String flatId) =>
      _tasksCollection(flatId)
          .orderBy(fieldTaskRingIndex)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map(Task.fromFirestore)
                .toList(),
          );

  /// Returns a real-time stream of a single task.
  Stream<Task?> watchTask(String flatId, String taskId) =>
      _tasksCollection(flatId).doc(taskId).snapshots().map((doc) {
        if (!doc.exists) {
          return null;
        }
        return Task.fromFirestore(doc);
      });

  /// Fetches all tasks once (non-streaming).
  Future<List<Task>> fetchTasks(String flatId) async {
    final snapshot = await _tasksCollection(flatId)
        .orderBy(fieldTaskRingIndex)
        .get();
    return snapshot.docs
        .map(Task.fromFirestore)
        .toList();
  }

  /// Fetches a single task once.
  Future<Task?> fetchTask(String flatId, String taskId) async {
    final doc = await _tasksCollection(flatId).doc(taskId).get();
    if (!doc.exists) {
      return null;
    }
    return Task.fromFirestore(doc);
  }

  /// Creates a task document (used during initial flat setup).
  Future<void> createTask(String flatId, Task task) async {
    await _tasksCollection(flatId).doc(task.id).set(task.toFirestore());
  }

  /// Updates specific fields on a task document.
  Future<void> updateTask(
    String flatId,
    String taskId,
    Map<String, dynamic> updates,
  ) async {
    await _tasksCollection(flatId).doc(taskId).update(updates);
  }

  /// Updates the task's due date/time (admin only).
  Future<void> updateDueDateTime(
    String flatId,
    String taskId,
    DateTime newDueDateTime,
  ) async {
    await updateTask(flatId, taskId, {
      fieldTaskDueDateTime: Timestamp.fromDate(newDueDateTime),
    });
  }

  /// Swaps the assignees of two tasks atomically using a single Firestore batch.
  ///
  /// After the call, [taskAId] will be assigned to [assigneeForA] and
  /// [taskBId] will be assigned to [assigneeForB].
  ///
  /// Both task IDs and both assignee strings must be non-empty. The two task
  /// IDs must be distinct — swapping a task with itself is a programmer error.
  Future<void> swapTaskAssignees(
    String flatId,
    String taskAId,
    String assigneeForA,
    String taskBId,
    String assigneeForB,
  ) async {
    assert(
      flatId.isNotEmpty &&
          taskAId.isNotEmpty &&
          taskBId.isNotEmpty,
      'swapTaskAssignees: flatId, taskAId, and taskBId must not be empty. '
      'Got flatId="$flatId" taskAId="$taskAId" taskBId="$taskBId"',
    );
    assert(
      taskAId != taskBId,
      'swapTaskAssignees: taskAId and taskBId must differ — '
      'cannot swap a task with itself (id="$taskAId").',
    );

    final batch = _db.batch()
      ..update(
        _tasksCollection(flatId).doc(taskAId),
        {fieldTaskAssignedTo: assigneeForA},
      )
      ..update(
        _tasksCollection(flatId).doc(taskBId),
        {fieldTaskAssignedTo: assigneeForB},
      );
    await batch.commit();
  }

  /// Assigns [newAssigneeUid] to [taskId], automatically swapping assignees
  /// with any task that already holds [newAssigneeUid] so that no person ends
  /// up on two tasks simultaneously.
  ///
  /// Fetches a **fresh** task list from Firestore rather than trusting a
  /// potentially-stale in-memory snapshot, which prevents the class of bug
  /// where a StreamBuilder snapshot lags behind writes that happened earlier
  /// in the same async call stack.
  ///
  /// Assigning an empty [newAssigneeUid] clears the slot (makes it vacant)
  /// without any conflict check.
  Future<void> assignTask(
    String flatId,
    String taskId,
    String newAssigneeUid,
  ) async {
    assert(flatId.isNotEmpty, 'assignTask: flatId must not be empty.');
    assert(taskId.isNotEmpty, 'assignTask: taskId must not be empty.');

    if (newAssigneeUid.isEmpty) {
      await updateTask(flatId, taskId, {fieldTaskAssignedTo: ''});
      return;
    }

    // Fetch fresh data so conflict detection cannot be fooled by a stale snapshot.
    final allTasks = await fetchTasks(flatId);

    final currentTask = allTasks.where((t) => t.id == taskId).firstOrNull;
    assert(
      currentTask != null,
      'assignTask: task "$taskId" not found in flat "$flatId". '
      'This is a programmer error — the task must exist before assigning.',
    );
    if (currentTask == null) {
      return;
    }

    // If new assignee already holds a different task, swap both atomically so
    // no person is ever on two tasks at the same time.
    final conflictTask = allTasks
        .where((t) => t.id != taskId && t.assignedTo == newAssigneeUid)
        .firstOrNull;

    if (conflictTask != null) {
      await swapTaskAssignees(
        flatId,
        taskId,           newAssigneeUid,
        conflictTask.id,  currentTask.assignedTo,
      );
    } else {
      await updateTask(flatId, taskId, {fieldTaskAssignedTo: newAssigneeUid});
    }
  }

  /// Updates the task's name and description (admin only).
  Future<void> updateTaskDetails(
    String flatId,
    String taskId, {
    String? name,
    List<String>? description,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) {
      updates[fieldTaskName] = name;
    }
    if (description != null) {
      updates[fieldTaskDescription] = description;
    }
    if (updates.isNotEmpty) {
      await updateTask(flatId, taskId, updates);
    }
  }
}
