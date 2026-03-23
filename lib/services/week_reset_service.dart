import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flatorg/constants/setting_constants.dart';
import 'package:flatorg/constants/string_constants.dart';
import 'package:flatorg/models/enums/task_state.dart';
import 'package:flatorg/models/person.dart';
import 'package:flatorg/models/task.dart';
import 'package:flatorg/services/week_reset_algorithm.dart';

/// Firestore adapter for the weekly task reassignment algorithm.
///
/// Reads task and person data from Firestore, delegates to
/// [WeekResetAlgorithm] for the pure assignment logic, and writes
/// results back as an atomic transaction.
class WeekResetService {
  final FirebaseFirestore _firestore;
  final WeekResetAlgorithm _algorithm;

  WeekResetService({
    FirebaseFirestore? firestore,
    WeekResetAlgorithm? algorithm,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _algorithm = algorithm ?? WeekResetAlgorithm();

  /// Runs the full weekly reset for a flat.
  ///
  /// Reads all tasks and persons from Firestore, runs the assignment
  /// algorithm, and writes the new assignments atomically.
  /// TODO: Perhaps do this isomorphic? But this only runs once a week... What to do if it fails?
  ///
  /// [flatId] — the Firestore document ID of the flat to reset.
  Future<void> weekReset(String flatId) async {
    // Get the flat from database.
    final flatRef =
        _firestore.collection(StringConstants.collectionFlats).doc(flatId);

    // Read collections outside the transaction (transaction.get only
    // accepts DocumentReference, not CollectionReference).
    // here we get the tasks and people inside the db.
    final taskSnaps =
        await flatRef.collection(StringConstants.collectionTasks).get();
    final personSnaps =
        await flatRef.collection(StringConstants.collectionPersons).get();

    // here we transform the ... to a list?
    final taskDocIds = taskSnaps.docs.map((d) => d.id).toList();
    final personDocIds = personSnaps.docs.map((d) => d.id).toList();

    await _firestore.runTransaction((transaction) async {
      // Re-read every document inside the transaction for consistency
      // Wait is this for atomicity?
      final flatSnap = await transaction.get(flatRef);
      final flatData = flatSnap.data() ?? {};
      final vacationThreshold =
          flatData[StringConstants.fieldVacationThresholdWeeks] as int? ??
              SettingConstants.defaultVacationThresholdWeeks;

      final tasks = <String, Task>{};
      final taskRefs = <String, DocumentReference>{};
      for (final docId in taskDocIds) {
        final ref =
            flatRef.collection(StringConstants.collectionTasks).doc(docId);
        final snap = await transaction.get(ref);
        if (snap.exists) {
          tasks[docId] = Task.fromFirestore(snap.data() ?? {});
          taskRefs[docId] = ref;
        }
      }

      final persons = <String, Person>{};
      final personRefs = <String, DocumentReference>{};
      for (final docId in personDocIds) {
        final ref =
            flatRef.collection(StringConstants.collectionPersons).doc(docId);
        final snap = await transaction.get(ref);
        if (snap.exists) {
          persons[docId] = Person.fromFirestore(snap.data() ?? {});
          personRefs[docId] = ref;
        }
      }

      // Run the pure algorithm
      final newAssignments = _algorithm.compute(
        tasks: tasks,
        persons: persons,
        vacationThreshold: vacationThreshold,
      );

      // Write all updates in the transaction
      _writeUpdates(
        transaction,
        tasks,
        taskRefs,
        newAssignments,
      );
    });
  }

  /// Writes all updated task documents in the transaction.
  void _writeUpdates(
    Transaction transaction,
    Map<String, Task> tasks,
    Map<String, DocumentReference> taskRefs,
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
        StringConstants.fieldAssignedTo: newUid,
        StringConstants.fieldOriginalAssignedTo: '',
        StringConstants.fieldState: TaskState.pending.toFirestore(),
        StringConstants.fieldWeeksNotCleaned: task.weeksNotCleaned,
      });
    }
  }
}
