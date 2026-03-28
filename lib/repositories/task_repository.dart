import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task.dart';
import '../constants/strings.dart';

/// Repository for Task documents under flats/{flatId}/tasks.
/// All Firestore access for tasks goes through this class (Repository pattern).
/// UI layers observe streams; Cloud Functions handle write-heavy operations.
class TaskRepository {
  final FirebaseFirestore _db;

  TaskRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  /// Returns the Firestore collection reference for tasks in a flat.
  CollectionReference<Map<String, dynamic>> _tasksCollection(String flatId) {
    return _db
        .collection(collectionFlats)
        .doc(flatId)
        .collection(collectionTasks);
  }

  /// Returns a real-time stream of all tasks for a flat, sorted by ring_index.
  /// The UI uses this via StreamBuilder to reactively rebuild on changes.
  Stream<List<Task>> watchTasks(String flatId) {
    return _tasksCollection(flatId)
        .orderBy(fieldTaskRingIndex)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Task.fromFirestore(doc))
              .toList(),
        );
  }

  /// Returns a real-time stream of a single task.
  Stream<Task?> watchTask(String flatId, String taskId) {
    return _tasksCollection(flatId).doc(taskId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Task.fromFirestore(doc);
    });
  }

  /// Fetches all tasks once (non-streaming).
  Future<List<Task>> fetchTasks(String flatId) async {
    final snapshot = await _tasksCollection(flatId)
        .orderBy(fieldTaskRingIndex)
        .get();
    return snapshot.docs
        .map((doc) => Task.fromFirestore(doc))
        .toList();
  }

  /// Fetches a single task once.
  Future<Task?> fetchTask(String flatId, String taskId) async {
    final doc = await _tasksCollection(flatId).doc(taskId).get();
    if (!doc.exists) return null;
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

  /// Updates the task's name and description (admin only).
  Future<void> updateTaskDetails(
    String flatId,
    String taskId, {
    String? name,
    List<String>? description,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates[fieldTaskName] = name;
    if (description != null) updates[fieldTaskDescription] = description;
    if (updates.isNotEmpty) {
      await updateTask(flatId, taskId, updates);
    }
  }
}
