// BDD integration tests for SwapRequestRepository.respondToSwapRequest.
//
// Uses FakeFirebaseFirestore — no real network calls.
//
// Key spec rules (CLAUDE.md):
//   - Vacation swap  → costs 1 token (isVacationSwap == true on the request)
//   - Mutual swap    → costs 0 tokens (isVacationSwap == false)
//   - Accept         → swaps assigned_to on both task documents
//   - Decline        → only updates request status; no task or token changes
//
// Scenarios are named:
//   "Given <precondition>, when <action>, then <outcome>"

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flatorg/constants/strings.dart';
import 'package:flatorg/models/issue.dart';
import 'package:flatorg/repositories/swap_request_repository.dart';
import 'package:flutter_test/flutter_test.dart';

// ── Fixtures ──────────────────────────────────────────────────────────────────

const _kFlatId       = 'flat-1';
const _kRequesterUid = 'alice-uid';
const _kTargetUid    = 'bob-uid';
const _kRequesterTaskId = 'task-requester';
const _kTargetTaskId    = 'task-target';
const _kRequestId       = 'request-1';

/// Seeds both task documents and the requester's member document into [db].
Future<void> _seedScenario(
  FakeFirebaseFirestore db, {
  int requesterTokens = 3,
}) async {
  final flat = db.collection(collectionFlats).doc(_kFlatId);

  // Requester's task
  await flat.collection(collectionTasks).doc(_kRequesterTaskId).set({
    fieldTaskAssignedTo: _kRequesterUid,
  });

  // Target's task
  await flat.collection(collectionTasks).doc(_kTargetTaskId).set({
    fieldTaskAssignedTo: _kTargetUid,
  });

  // Requester's member document
  await flat.collection(collectionMembers).doc(_kRequesterUid).set({
    fieldPersonSwapTokens: requesterTokens,
  });
}

SwapRequest _makeRequest({required bool isVacationSwap}) => SwapRequest(
  id: _kRequestId,
  requesterUid: _kRequesterUid,
  requesterTaskId: _kRequesterTaskId,
  targetTaskId: _kTargetTaskId,
  status: SwapRequestStatus.pending,
  createdAt: Timestamp.now(),
  isVacationSwap: isVacationSwap,
);

// ── Accept: task swap ─────────────────────────────────────────────────────────

void main() {
group('respondToSwapRequest — accept', () {
  test(
    'Given a pending swap request, '
    'when accepted, '
    'then assigned_to on the requester task becomes the target uid',
    () async {
      final db   = FakeFirebaseFirestore();
      final repo = SwapRequestRepository(db: db);
      await _seedScenario(db);
      final request = _makeRequest(isVacationSwap: false);
      await repo.createSwapRequest(_kFlatId, request);

      await repo.respondToSwapRequest(_kFlatId, request, SwapRequestStatus.accepted);

      final requesterTask = await db
          .collection(collectionFlats).doc(_kFlatId)
          .collection(collectionTasks).doc(_kRequesterTaskId)
          .get();
      expect(requesterTask.data()![fieldTaskAssignedTo], _kTargetUid);
    },
  );

  test(
    'Given a pending swap request, '
    'when accepted, '
    'then assigned_to on the target task becomes the requester uid',
    () async {
      final db   = FakeFirebaseFirestore();
      final repo = SwapRequestRepository(db: db);
      await _seedScenario(db);
      final request = _makeRequest(isVacationSwap: false);
      await repo.createSwapRequest(_kFlatId, request);

      await repo.respondToSwapRequest(_kFlatId, request, SwapRequestStatus.accepted);

      final targetTask = await db
          .collection(collectionFlats).doc(_kFlatId)
          .collection(collectionTasks).doc(_kTargetTaskId)
          .get();
      expect(targetTask.data()![fieldTaskAssignedTo], _kRequesterUid);
    },
  );

  test(
    'Given a pending swap request, '
    'when accepted, '
    'then the request status is updated to accepted',
    () async {
      final db   = FakeFirebaseFirestore();
      final repo = SwapRequestRepository(db: db);
      await _seedScenario(db);
      final request = _makeRequest(isVacationSwap: false);
      await repo.createSwapRequest(_kFlatId, request);

      await repo.respondToSwapRequest(_kFlatId, request, SwapRequestStatus.accepted);

      final doc = await db
          .collection(collectionFlats).doc(_kFlatId)
          .collection(collectionSwapRequests).doc(_kRequestId)
          .get();
      expect(doc.data()![fieldSwapStatus], 'accepted');
    },
  );
});

// ── Accept: token deduction (vacation swap) ───────────────────────────────────

group('respondToSwapRequest — vacation swap token cost', () {
  test(
    'Given a vacation swap request (isVacationSwap = true) '
    'and the requester has 3 tokens, '
    'when accepted, '
    'then the requester has 2 tokens remaining',
    () async {
      final db   = FakeFirebaseFirestore();
      final repo = SwapRequestRepository(db: db);
      await _seedScenario(db, requesterTokens: 3);
      final request = _makeRequest(isVacationSwap: true);
      await repo.createSwapRequest(_kFlatId, request);

      await repo.respondToSwapRequest(_kFlatId, request, SwapRequestStatus.accepted);

      final member = await db
          .collection(collectionFlats).doc(_kFlatId)
          .collection(collectionMembers).doc(_kRequesterUid)
          .get();
      expect(member.data()![fieldPersonSwapTokens], 2);
    },
  );

  test(
    'Given a vacation swap request and the requester has 1 token remaining, '
    'when accepted, '
    'then the requester has 0 tokens (last token consumed)',
    () async {
      final db   = FakeFirebaseFirestore();
      final repo = SwapRequestRepository(db: db);
      await _seedScenario(db, requesterTokens: 1);
      final request = _makeRequest(isVacationSwap: true);
      await repo.createSwapRequest(_kFlatId, request);

      await repo.respondToSwapRequest(_kFlatId, request, SwapRequestStatus.accepted);

      final member = await db
          .collection(collectionFlats).doc(_kFlatId)
          .collection(collectionMembers).doc(_kRequesterUid)
          .get();
      expect(member.data()![fieldPersonSwapTokens], 0);
    },
  );
});

// ── Accept: no token deduction (mutual non-vacation swap) ─────────────────────

group('respondToSwapRequest — mutual swap, no token cost', () {
  test(
    'Given a mutual swap request (isVacationSwap = false) '
    'and the requester has 3 tokens, '
    'when accepted, '
    'then the requester still has 3 tokens (no token consumed)',
    () async {
      final db   = FakeFirebaseFirestore();
      final repo = SwapRequestRepository(db: db);
      await _seedScenario(db, requesterTokens: 3);
      final request = _makeRequest(isVacationSwap: false);
      await repo.createSwapRequest(_kFlatId, request);

      await repo.respondToSwapRequest(_kFlatId, request, SwapRequestStatus.accepted);

      final member = await db
          .collection(collectionFlats).doc(_kFlatId)
          .collection(collectionMembers).doc(_kRequesterUid)
          .get();
      expect(member.data()![fieldPersonSwapTokens], 3);
    },
  );

  test(
    'Given a mutual swap request and the requester has 0 tokens, '
    'when accepted, '
    'then the requester still has 0 tokens (mutual swaps are always free)',
    () async {
      final db   = FakeFirebaseFirestore();
      final repo = SwapRequestRepository(db: db);
      await _seedScenario(db, requesterTokens: 0);
      final request = _makeRequest(isVacationSwap: false);
      await repo.createSwapRequest(_kFlatId, request);

      await repo.respondToSwapRequest(_kFlatId, request, SwapRequestStatus.accepted);

      final member = await db
          .collection(collectionFlats).doc(_kFlatId)
          .collection(collectionMembers).doc(_kRequesterUid)
          .get();
      expect(member.data()![fieldPersonSwapTokens], 0);
    },
  );
});

// ── Decline ───────────────────────────────────────────────────────────────────

group('respondToSwapRequest — decline', () {
  test(
    'Given a pending swap request, '
    'when declined, '
    'then the request status is updated to declined',
    () async {
      final db   = FakeFirebaseFirestore();
      final repo = SwapRequestRepository(db: db);
      await _seedScenario(db);
      final request = _makeRequest(isVacationSwap: true);
      await repo.createSwapRequest(_kFlatId, request);

      await repo.respondToSwapRequest(_kFlatId, request, SwapRequestStatus.declined);

      final doc = await db
          .collection(collectionFlats).doc(_kFlatId)
          .collection(collectionSwapRequests).doc(_kRequestId)
          .get();
      expect(doc.data()![fieldSwapStatus], 'declined');
    },
  );

  test(
    'Given a pending vacation swap request and the requester has 3 tokens, '
    'when declined, '
    'then no tokens are deducted',
    () async {
      final db   = FakeFirebaseFirestore();
      final repo = SwapRequestRepository(db: db);
      await _seedScenario(db, requesterTokens: 3);
      final request = _makeRequest(isVacationSwap: true);
      await repo.createSwapRequest(_kFlatId, request);

      await repo.respondToSwapRequest(_kFlatId, request, SwapRequestStatus.declined);

      final member = await db
          .collection(collectionFlats).doc(_kFlatId)
          .collection(collectionMembers).doc(_kRequesterUid)
          .get();
      expect(member.data()![fieldPersonSwapTokens], 3);
    },
  );

  test(
    'Given a pending swap request, '
    'when declined, '
    'then the task assignments are not changed',
    () async {
      final db   = FakeFirebaseFirestore();
      final repo = SwapRequestRepository(db: db);
      await _seedScenario(db);
      final request = _makeRequest(isVacationSwap: false);
      await repo.createSwapRequest(_kFlatId, request);

      await repo.respondToSwapRequest(_kFlatId, request, SwapRequestStatus.declined);

      final requesterTask = await db
          .collection(collectionFlats).doc(_kFlatId)
          .collection(collectionTasks).doc(_kRequesterTaskId)
          .get();
      final targetTask = await db
          .collection(collectionFlats).doc(_kFlatId)
          .collection(collectionTasks).doc(_kTargetTaskId)
          .get();

      expect(requesterTask.data()![fieldTaskAssignedTo], _kRequesterUid);
      expect(targetTask.data()![fieldTaskAssignedTo], _kTargetUid);
    },
  );
});

// ── isVacationSwap persisted in Firestore ─────────────────────────────────────

group('SwapRequest.isVacationSwap persistence', () {
  test(
    'Given a vacation swap request, '
    'when created, '
    'then isVacationSwap is stored as true in Firestore',
    () async {
      final db   = FakeFirebaseFirestore();
      final repo = SwapRequestRepository(db: db);
      await _seedScenario(db);
      final request = _makeRequest(isVacationSwap: true);

      await repo.createSwapRequest(_kFlatId, request);

      final doc = await db
          .collection(collectionFlats).doc(_kFlatId)
          .collection(collectionSwapRequests).doc(_kRequestId)
          .get();
      expect(doc.data()![fieldSwapIsVacationSwap], isTrue);
    },
  );

  test(
    'Given a mutual swap request, '
    'when created, '
    'then isVacationSwap is stored as false in Firestore',
    () async {
      final db   = FakeFirebaseFirestore();
      final repo = SwapRequestRepository(db: db);
      await _seedScenario(db);
      final request = _makeRequest(isVacationSwap: false);

      await repo.createSwapRequest(_kFlatId, request);

      final doc = await db
          .collection(collectionFlats).doc(_kFlatId)
          .collection(collectionSwapRequests).doc(_kRequestId)
          .get();
      expect(doc.data()![fieldSwapIsVacationSwap], isFalse);
    },
  );
});

} // end main
