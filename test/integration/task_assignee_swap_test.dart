// BDD integration tests for TaskRepository.swapTaskAssignees().
//
// Uses fake_cloud_firestore (in-memory Firestore) so no real Firebase project
// is needed. Tests verify the atomic assignee-swap behaviour that prevents
// a person from being assigned to two tasks simultaneously.
//
// Naming convention: "Given <precondition>, when <action>, then <outcome>"

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flatorg/constants/strings.dart';
import 'package:flatorg/repositories/task_repository.dart';
import 'package:flutter_test/flutter_test.dart';

// ── Fixtures ──────────────────────────────────────────────────────────────────

const _kFlatId   = 'flat-1';
const _kAliceUid = 'alice-uid';
const _kBobUid   = 'bob-uid';
const _kCarlaUid = 'carla-uid';

const _kTaskToilet  = 'task-toilet';
const _kTaskKitchen = 'task-kitchen';
const _kTaskShower  = 'task-shower';

/// Seeds a task document with a given assignee.
Future<void> _seedTask(
  FakeFirebaseFirestore db,
  String taskId,
  String name,
  String assignedTo,
) async {
  await db
      .collection(collectionFlats)
      .doc(_kFlatId)
      .collection(collectionTasks)
      .doc(taskId)
      .set({
    fieldTaskAssignedTo:    assignedTo,
    fieldTaskName:          name,
    fieldTaskRingIndex:     0,
    fieldTaskState:         'pending',
    fieldTaskWeeksNotCleaned: 0,
  });
}

/// Reads the assignedTo field of a task document.
Future<String> _readAssignee(FakeFirebaseFirestore db, String taskId) async {
  final doc = await db
      .collection(collectionFlats)
      .doc(_kFlatId)
      .collection(collectionTasks)
      .doc(taskId)
      .get();
  return doc.data()![fieldTaskAssignedTo] as String;
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('Situation 8 — swapTaskAssignees', () {
    late FakeFirebaseFirestore db;
    late TaskRepository repo;

    setUp(() {
      db   = FakeFirebaseFirestore();
      repo = TaskRepository(db: db);
    });

    test(
      'Given Task Toilet is assigned to Bob and Task Kitchen to Alice, '
      'when swapTaskAssignees(Toilet→Alice, Kitchen→Bob) is called, '
      'then Task Toilet has Alice and Task Kitchen has Bob',
      () async {
        await _seedTask(db, _kTaskToilet,  'Toilet',  _kBobUid);
        await _seedTask(db, _kTaskKitchen, 'Kitchen', _kAliceUid);

        await repo.swapTaskAssignees(
          _kFlatId,
          _kTaskToilet,  _kAliceUid,
          _kTaskKitchen, _kBobUid,
        );

        expect(await _readAssignee(db, _kTaskToilet),  _kAliceUid,
          reason: 'Task Toilet must now be assigned to Alice.');
        expect(await _readAssignee(db, _kTaskKitchen), _kBobUid,
          reason: 'Task Kitchen must now be assigned to Bob.');
      },
    );

    test(
      'Given Task Toilet is assigned to Bob, Task Kitchen to Alice, '
      'and Task Shower to Carla, '
      'when swapTaskAssignees(Toilet, Kitchen) is called, '
      'then Task Shower is unaffected',
      () async {
        await _seedTask(db, _kTaskToilet,  'Toilet',  _kBobUid);
        await _seedTask(db, _kTaskKitchen, 'Kitchen', _kAliceUid);
        await _seedTask(db, _kTaskShower,  'Shower',  _kCarlaUid);

        await repo.swapTaskAssignees(
          _kFlatId,
          _kTaskToilet,  _kAliceUid,
          _kTaskKitchen, _kBobUid,
        );

        expect(await _readAssignee(db, _kTaskShower), _kCarlaUid,
          reason: 'Unrelated tasks must not be modified by the swap.');
      },
    );

    test(
      'Given Task Toilet is assigned to Bob and Task Kitchen is vacant (empty), '
      'when swapTaskAssignees(Toilet→Alice, Kitchen→Bob) is called, '
      'then Task Toilet has Alice and Task Kitchen has Bob',
      () async {
        await _seedTask(db, _kTaskToilet,  'Toilet',  _kBobUid);
        await _seedTask(db, _kTaskKitchen, 'Kitchen', '');

        await repo.swapTaskAssignees(
          _kFlatId,
          _kTaskToilet,  _kAliceUid,
          _kTaskKitchen, _kBobUid,
        );

        expect(await _readAssignee(db, _kTaskToilet),  _kAliceUid);
        expect(await _readAssignee(db, _kTaskKitchen), _kBobUid);
      },
    );
  });
}
