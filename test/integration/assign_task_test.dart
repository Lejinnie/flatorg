// BDD integration tests for TaskRepository.assignTask().
//
// assignTask() is the single authoritative entry-point for changing a task's
// assignee.  It fetches fresh data from Firestore before acting, so it can
// never be fooled by a stale in-memory snapshot (unlike the previous inline
// conflict detection in _TaskEditTile._save() which read widget.tasks).
//
// These tests prove the invariant: after assignTask() completes, no two tasks
// share the same non-empty assignee UID.
//
// Naming: "Given <precondition>, when <action>, then <outcome>"

import 'package:cloud_firestore/cloud_firestore.dart';
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

final _kFutureDue = Timestamp.fromDate(DateTime(2099, 12, 31));

Future<void> _seedTask(
  FakeFirebaseFirestore db,
  String taskId,
  String name,
  String assignedTo, {
  int ringIndex = 0,
}) async {
  await db
      .collection(collectionFlats)
      .doc(_kFlatId)
      .collection(collectionTasks)
      .doc(taskId)
      .set({
    fieldTaskAssignedTo:         assignedTo,
    fieldTaskName:               name,
    fieldTaskRingIndex:          ringIndex,
    fieldTaskState:              'pending',
    fieldTaskWeeksNotCleaned:    0,
    fieldTaskDueDateTime:        _kFutureDue,
    fieldTaskDescription:        <String>[],
    fieldTaskOriginalAssignedTo: '',
  });
}

Future<String> _readAssignee(FakeFirebaseFirestore db, String taskId) async {
  final doc = await db
      .collection(collectionFlats)
      .doc(_kFlatId)
      .collection(collectionTasks)
      .doc(taskId)
      .get();
  return doc.data()![fieldTaskAssignedTo] as String;
}

/// Verifies the invariant: no two tasks share the same non-empty assignee.
Future<void> _assertNoDuplicateAssignees(FakeFirebaseFirestore db) async {
  final snap = await db
      .collection(collectionFlats)
      .doc(_kFlatId)
      .collection(collectionTasks)
      .get();
  final assignees = snap.docs
      .map((d) => d.data()[fieldTaskAssignedTo] as String)
      .where((uid) => uid.isNotEmpty)
      .toList();
  final unique = assignees.toSet();
  expect(
    assignees.length,
    unique.length,
    reason: 'Invariant violated: duplicate assignee UIDs found — '
        '${assignees.where((uid) => assignees.where((u) => u == uid).length > 1).toSet()}',
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('Situation 13 — assignTask() prevents duplicate assignment', () {
    late FakeFirebaseFirestore db;
    late TaskRepository repo;

    setUp(() {
      db   = FakeFirebaseFirestore();
      repo = TaskRepository(db: db);
    });

    testWidgets(
      'Given Alice has Toilet and Bob has Kitchen, '
      'when assignTask(Kitchen → Alice), '
      'then Alice has Kitchen and Bob has Toilet (swap, no duplicate)',
      (_) async {
        await _seedTask(db, _kTaskToilet,  'Toilet',  _kAliceUid);
        await _seedTask(db, _kTaskKitchen, 'Kitchen', _kBobUid,   ringIndex: 1);

        await repo.assignTask(_kFlatId, _kTaskKitchen, _kAliceUid);

        expect(await _readAssignee(db, _kTaskKitchen), _kAliceUid,
            reason: 'Alice must be on Kitchen after the call.');
        expect(await _readAssignee(db, _kTaskToilet), _kBobUid,
            reason: 'Bob must have been moved to Toilet (Alice vacated it).');
        await _assertNoDuplicateAssignees(db);
      },
    );

    testWidgets(
      'Given Alice has Toilet, '
      'when assignTask(Toilet → Alice) (same person, no change), '
      'then Alice still has Toilet and no other task is affected',
      (_) async {
        await _seedTask(db, _kTaskToilet,  'Toilet',  _kAliceUid);
        await _seedTask(db, _kTaskKitchen, 'Kitchen', _kBobUid,   ringIndex: 1);

        await repo.assignTask(_kFlatId, _kTaskToilet, _kAliceUid);

        expect(await _readAssignee(db, _kTaskToilet),  _kAliceUid);
        expect(await _readAssignee(db, _kTaskKitchen), _kBobUid);
        await _assertNoDuplicateAssignees(db);
      },
    );

    testWidgets(
      'Given Alice has Toilet and Kitchen is vacant, '
      'when assignTask(Kitchen → Alice), '
      'then Alice has Kitchen and Toilet becomes vacant (no duplicate)',
      (_) async {
        await _seedTask(db, _kTaskToilet,  'Toilet',  _kAliceUid);
        await _seedTask(db, _kTaskKitchen, 'Kitchen', '',          ringIndex: 1);

        await repo.assignTask(_kFlatId, _kTaskKitchen, _kAliceUid);

        expect(await _readAssignee(db, _kTaskKitchen), _kAliceUid,
            reason: 'Alice must be on Kitchen.');
        expect(await _readAssignee(db, _kTaskToilet), '',
            reason: 'Toilet must now be vacant — Alice was moved off it.');
        await _assertNoDuplicateAssignees(db);
      },
    );

    testWidgets(
      'Given Toilet is vacant, '
      'when assignTask(Toilet → Alice), '
      'then Alice has Toilet (simple update, no swap needed)',
      (_) async {
        await _seedTask(db, _kTaskToilet,  'Toilet',  '');
        await _seedTask(db, _kTaskKitchen, 'Kitchen', _kBobUid,  ringIndex: 1);

        await repo.assignTask(_kFlatId, _kTaskToilet, _kAliceUid);

        expect(await _readAssignee(db, _kTaskToilet),  _kAliceUid);
        expect(await _readAssignee(db, _kTaskKitchen), _kBobUid,
            reason: 'Bob must be unaffected — Alice had no prior task to displace.');
        await _assertNoDuplicateAssignees(db);
      },
    );

    testWidgets(
      'Given Alice has Toilet and Bob has Kitchen, '
      'when assignTask(Toilet → empty string), '
      'then Toilet becomes vacant and Bob is unaffected',
      (_) async {
        await _seedTask(db, _kTaskToilet,  'Toilet',  _kAliceUid);
        await _seedTask(db, _kTaskKitchen, 'Kitchen', _kBobUid,   ringIndex: 1);

        await repo.assignTask(_kFlatId, _kTaskToilet, '');

        expect(await _readAssignee(db, _kTaskToilet),  '',
            reason: 'Toilet must be vacant after clearing the assignee.');
        expect(await _readAssignee(db, _kTaskKitchen), _kBobUid,
            reason: 'Kitchen must be unaffected.');
        await _assertNoDuplicateAssignees(db);
      },
    );

    testWidgets(
      'Given Alice has Toilet, Bob has Kitchen, Carla has Shower, '
      'when assignTask(Shower → Alice), '
      'then Alice has Shower, Carla has Toilet, Bob is unaffected (no duplicate)',
      (_) async {
        await _seedTask(db, _kTaskToilet,  'Toilet',  _kAliceUid);
        await _seedTask(db, _kTaskKitchen, 'Kitchen', _kBobUid,   ringIndex: 1);
        await _seedTask(db, _kTaskShower,  'Shower',  _kCarlaUid, ringIndex: 2);

        await repo.assignTask(_kFlatId, _kTaskShower, _kAliceUid);

        expect(await _readAssignee(db, _kTaskShower),  _kAliceUid);
        expect(await _readAssignee(db, _kTaskToilet),  _kCarlaUid,
            reason: 'Carla displaced Alice on Toilet.');
        expect(await _readAssignee(db, _kTaskKitchen), _kBobUid,
            reason: 'Bob is unaffected.');
        await _assertNoDuplicateAssignees(db);
      },
    );
  });
}
