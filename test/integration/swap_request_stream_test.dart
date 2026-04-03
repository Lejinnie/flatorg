// BDD integration tests for SwapRequestRepository.watchPendingRequestsForUser.
//
// Uses fake_cloud_firestore (in-memory Firestore) so no real Firebase project
// is needed. Tests verify that the stream filtering logic correctly removes
// requests when the underlying task assignments change.
//
// Naming convention: "Given <precondition>, when <action>, then <outcome>"

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flatorg/constants/strings.dart';
import 'package:flatorg/models/issue.dart';
import 'package:flatorg/repositories/swap_request_repository.dart';
import 'package:flutter_test/flutter_test.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

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
  String assignedTo,
) async {
  await db
      .collection(collectionFlats)
      .doc(_kFlatId)
      .collection(collectionTasks)
      .doc(taskId)
      .set({
    fieldTaskAssignedTo: assignedTo,
    fieldTaskName: taskId,
    fieldTaskRingIndex: 0,
    fieldTaskState: 'pending',
    fieldTaskWeeksNotCleaned: 0,
  });
}

/// Seeds a member document with full swap tokens.
Future<void> _seedMember(FakeFirebaseFirestore db, String uid) async {
  await db
      .collection(collectionFlats)
      .doc(_kFlatId)
      .collection(collectionMembers)
      .doc(uid)
      .set({fieldPersonSwapTokens: 3});
}

/// Seeds a pending swap request document.
Future<void> _seedRequest(
  FakeFirebaseFirestore db,
  String requestId, {
  required String requesterUid,
  required String targetTaskId,
  required String requesterTaskId,
}) async {
  await db
      .collection(collectionFlats)
      .doc(_kFlatId)
      .collection(collectionSwapRequests)
      .doc(requestId)
      .set({
    fieldSwapRequesterUid:   requesterUid,
    fieldSwapTargetTaskId:   targetTaskId,
    fieldSwapRequesterTaskId: requesterTaskId,
    fieldSwapStatus:         'pending',
    fieldSwapCreatedAt:      Timestamp.fromDate(DateTime(2099)),
  });
}

/// Reads the next non-empty emission from a stream (skips empty lists that
/// may fire before Firestore has written all seed data).
Future<List<SwapRequest>> _nextNonEmpty(
  Stream<List<SwapRequest>> stream,
) async {
  await for (final list in stream) {
    if (list.isNotEmpty) {
      return list;
    }
  }
  return [];
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('Situation 6 — stream filtering after task reassignment', () {
    late FakeFirebaseFirestore db;
    late SwapRequestRepository repo;

    setUp(() {
      db   = FakeFirebaseFirestore();
      repo = SwapRequestRepository(db: db);
    });

    test(
      'Given Alice holds Task Toilet and Bob has a pending request for it, '
      "when Alice declines Bob's request, "
      "then Bob's request disappears from Alice's stream",
      () async {
        await _seedTask(db, _kTaskToilet,  _kAliceUid);
        await _seedTask(db, _kTaskKitchen, _kBobUid);
        await _seedRequest(
          db,
          'req-bob',
          requesterUid:    _kBobUid,
          targetTaskId:    _kTaskToilet,
          requesterTaskId: _kTaskKitchen,
        );

        final stream = repo.watchPendingRequestsForUser(_kFlatId, _kAliceUid);

        // Confirm the request appears in Alice's stream before declining.
        final before = await _nextNonEmpty(stream);
        expect(before.map((r) => r.id), contains('req-bob'));

        // Alice declines.
        await repo.respondToSwapRequest(
          _kFlatId,
          before.first,
          SwapRequestStatus.declined,
        );

        // Next emission must be empty — declined request drops from pending filter.
        final after = await stream.first;
        expect(after, isEmpty);
      },
    );

    test(
      'Given Alice holds Task Toilet, Bob and Carla both have pending requests '
      'for Task Toilet, '
      "when Alice accepts Bob's request (Task Toilet reassigned to Bob), "
      "then Carla's request also disappears from Alice's stream "
      'because Task Toilet is no longer assigned to Alice',
      () async {
        await _seedTask(db, _kTaskToilet,  _kAliceUid);
        await _seedTask(db, _kTaskKitchen, _kBobUid);
        await _seedTask(db, _kTaskShower,  _kCarlaUid);
        await _seedMember(db, _kBobUid);

        await _seedRequest(
          db,
          'req-bob',
          requesterUid:    _kBobUid,
          targetTaskId:    _kTaskToilet,
          requesterTaskId: _kTaskKitchen,
        );
        await _seedRequest(
          db,
          'req-carla',
          requesterUid:    _kCarlaUid,
          targetTaskId:    _kTaskToilet,
          requesterTaskId: _kTaskShower,
        );

        final stream = repo.watchPendingRequestsForUser(_kFlatId, _kAliceUid);

        // Both requests visible to Alice initially.
        final before = await _nextNonEmpty(stream);
        expect(before.map((r) => r.id), containsAll(['req-bob', 'req-carla']));

        // Alice accepts Bob's request.
        final bobReq = before.firstWhere((r) => r.id == 'req-bob');
        await repo.respondToSwapRequest(
          _kFlatId,
          bobReq,
          SwapRequestStatus.accepted,
        );

        // Task Toilet is now Bob's — neither request should appear for Alice.
        final after = await stream.first;
        expect(after, isEmpty,
          reason: "After Bob's accept, Task Toilet's assignee changed to Bob. "
              "Carla's request targeted Task Toilet, so it must also "
              "disappear from Alice's stream.",
        );
      },
    );
  });
}
