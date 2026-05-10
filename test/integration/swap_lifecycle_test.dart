// BDD integration tests for the full swap-request lifecycle.
//
// Covers behaviour added on top of the existing accept/decline tests in
// swap_request_respond_test.dart:
//   1. Outgoing-request stream surfaces only the user's pending requests
//   2. Withdraw deletes the swap request document
//   3. Withdraw causes the target's incoming-request stream to drop the request
//   4. NotificationRepository.writeNotification persists the swap-outcome doc
//   5. declineAllOtherPendingForTarget auto-rejects competing requests on accept
//
// Uses FakeFirebaseFirestore — no real network calls.
//
// Naming convention: "Given <precondition>, when <action>, then <outcome>"

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flatorg/constants/strings.dart';
import 'package:flatorg/models/issue.dart';
import 'package:flatorg/repositories/notification_repository.dart';
import 'package:flatorg/repositories/swap_request_repository.dart';
import 'package:flutter_test/flutter_test.dart';

// ── Fixtures ──────────────────────────────────────────────────────────────────

const _kFlatId    = 'flat-1';
const _kAliceUid  = 'alice-uid';   // requester A
const _kBobUid    = 'bob-uid';     // target B
const _kCarlaUid  = 'carla-uid';   // second requester C (used for auto-reject)
const _kAliceTaskId = 'task-alice';
const _kBobTaskId   = 'task-bob';
const _kCarlaTaskId = 'task-carla';
const _kRequestAB   = 'req-alice-bob';
const _kRequestCB   = 'req-carla-bob';

/// Seeds three task documents and the requester's member document so accept
/// flows have a non-zero token balance.
Future<void> _seedScenario(FakeFirebaseFirestore db) async {
  final flat = db.collection(collectionFlats).doc(_kFlatId);

  await flat.collection(collectionTasks).doc(_kAliceTaskId).set({
    fieldTaskAssignedTo: _kAliceUid,
  });
  await flat.collection(collectionTasks).doc(_kBobTaskId).set({
    fieldTaskAssignedTo: _kBobUid,
  });
  await flat.collection(collectionTasks).doc(_kCarlaTaskId).set({
    fieldTaskAssignedTo: _kCarlaUid,
  });

  // Member docs (only requester tokens are referenced by respondToSwapRequest).
  await flat.collection(collectionMembers).doc(_kAliceUid).set({
    fieldPersonSwapTokens: 3,
  });
  await flat.collection(collectionMembers).doc(_kCarlaUid).set({
    fieldPersonSwapTokens: 3,
  });
}

SwapRequest _request({
  required String id,
  required String requesterUid,
  required String requesterTaskId,
  required String targetTaskId,
  bool isVacationSwap = false,
}) =>
    SwapRequest(
      id:              id,
      requesterUid:    requesterUid,
      requesterTaskId: requesterTaskId,
      targetTaskId:    targetTaskId,
      status:          SwapRequestStatus.pending,
      createdAt:       Timestamp.fromDate(DateTime(2099)),
      isVacationSwap:  isVacationSwap,
    );

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // ── Scenario 1: outgoing-request stream ────────────────────────────────────
  group('Situation: Outgoing request stream', () {
    late FakeFirebaseFirestore db;
    late SwapRequestRepository repo;

    setUp(() async {
      db   = FakeFirebaseFirestore();
      repo = SwapRequestRepository(db: db);
      await _seedScenario(db);
    });

    test(
      'Given Alice has no pending swap requests, '
      'when watchOutgoingPendingRequests is called for Alice, '
      'then the first emission is an empty list',
      () async {
        final emission = await repo
            .watchOutgoingPendingRequests(_kFlatId, _kAliceUid)
            .first;
        expect(emission, isEmpty);
      },
    );

    test(
      'Given Alice creates a pending swap request targeting Bob, '
      'when watchOutgoingPendingRequests is called for Alice, '
      'then the stream emits a list containing the request',
      () async {
        await repo.createSwapRequest(
          _kFlatId,
          _request(
            id:              _kRequestAB,
            requesterUid:    _kAliceUid,
            requesterTaskId: _kAliceTaskId,
            targetTaskId:    _kBobTaskId,
          ),
        );

        final emission = await repo
            .watchOutgoingPendingRequests(_kFlatId, _kAliceUid)
            .first;
        expect(emission.length, 1);
        expect(emission.first.id, _kRequestAB);
      },
    );

    test(
      'Given Alice has a pending request that is later declined by Bob, '
      'when watchOutgoingPendingRequests is observed, '
      'then the request stops appearing in the stream',
      () async {
        final req = _request(
          id:              _kRequestAB,
          requesterUid:    _kAliceUid,
          requesterTaskId: _kAliceTaskId,
          targetTaskId:    _kBobTaskId,
        );
        await repo.createSwapRequest(_kFlatId, req);

        await repo.respondToSwapRequest(
          _kFlatId,
          req,
          SwapRequestStatus.declined,
        );

        final emission = await repo
            .watchOutgoingPendingRequests(_kFlatId, _kAliceUid)
            .first;
        expect(emission, isEmpty,
            reason: 'declined requests must not appear in the pending-only stream.');
      },
    );

    test(
      'Given Carla has a pending request and Alice has none, '
      'when watchOutgoingPendingRequests is called for Alice, '
      "then Carla's request is NOT included",
      () async {
        await repo.createSwapRequest(
          _kFlatId,
          _request(
            id:              _kRequestCB,
            requesterUid:    _kCarlaUid,
            requesterTaskId: _kCarlaTaskId,
            targetTaskId:    _kBobTaskId,
          ),
        );

        final emission = await repo
            .watchOutgoingPendingRequests(_kFlatId, _kAliceUid)
            .first;
        expect(emission, isEmpty,
            reason: 'requesterUid filter must scope the stream to the caller.');
      },
    );
  });

  // ── Scenario 2: Withdraw ────────────────────────────────────────────────────
  group('Situation: Withdraw a pending swap request', () {
    late FakeFirebaseFirestore db;
    late SwapRequestRepository repo;

    setUp(() async {
      db   = FakeFirebaseFirestore();
      repo = SwapRequestRepository(db: db);
      await _seedScenario(db);
      await repo.createSwapRequest(
        _kFlatId,
        _request(
          id:              _kRequestAB,
          requesterUid:    _kAliceUid,
          requesterTaskId: _kAliceTaskId,
          targetTaskId:    _kBobTaskId,
        ),
      );
    });

    test(
      'Given Alice has a pending swap request, '
      'when withdrawSwapRequest is called, '
      'then the swap request document no longer exists in Firestore',
      () async {
        await repo.withdrawSwapRequest(_kFlatId, _kRequestAB);

        final doc = await db
            .collection(collectionFlats)
            .doc(_kFlatId)
            .collection(collectionSwapRequests)
            .doc(_kRequestAB)
            .get();
        expect(doc.exists, isFalse,
            reason: 'withdraw must delete the swap request document so the '
                "target's incoming-tile stream drops it automatically.");
      },
    );

    test(
      'Given Alice has a pending swap request, '
      'when withdrawSwapRequest is called, '
      'then watchOutgoingPendingRequests for Alice no longer emits the request',
      () async {
        await repo.withdrawSwapRequest(_kFlatId, _kRequestAB);

        final emission = await repo
            .watchOutgoingPendingRequests(_kFlatId, _kAliceUid)
            .first;
        expect(emission, isEmpty);
      },
    );

    test(
      "Given Alice has a pending request targeting Bob's task, "
      'when withdrawSwapRequest is called, '
      'then watchPendingRequestsForUser for Bob no longer emits the request',
      () async {
        await repo.withdrawSwapRequest(_kFlatId, _kRequestAB);

        final emission = await repo
            .watchPendingRequestsForUser(_kFlatId, _kBobUid)
            .first;
        expect(emission, isEmpty);
      },
    );
  });

  // ── Scenario 3: Outcome notifications written by the client ────────────────
  group('Situation: Swap-outcome notifications written by the client', () {
    late FakeFirebaseFirestore db;
    late NotificationRepository notifRepo;

    setUp(() {
      db        = FakeFirebaseFirestore();
      notifRepo = NotificationRepository(db: db);
    });

    test(
      "Given Bob declines Alice's swap request, "
      'when the client writes a swap_rejected notification to Alice, '
      'then the notification document exists with the correct type, title, and body',
      () async {
        await notifRepo.writeNotification(
          _kFlatId,
          _kAliceUid,
          type:  notifTypeSwapRejected,
          title: notifTitleSwapRejected,
          body:  notifBodySwapRejectedTemplate.replaceFirst('{name}', 'Bob'),
        );

        final snap = await db
            .collection(collectionFlats)
            .doc(_kFlatId)
            .collection(collectionMembers)
            .doc(_kAliceUid)
            .collection(collectionNotifications)
            .get();
        expect(snap.docs.length, 1);
        final data = snap.docs.first.data();
        expect(data[fieldNotifType],  notifTypeSwapRejected);
        expect(data[fieldNotifTitle], notifTitleSwapRejected);
        expect(data[fieldNotifBody],  contains('Bob'));
        expect(data[fieldNotifBody],  contains('rejected'));
      },
    );

    test(
      "Given Bob accepts Alice's swap request, "
      'when the client writes a swap_accepted notification to Alice, '
      'then the notification document exists with the swap_accepted type',
      () async {
        await notifRepo.writeNotification(
          _kFlatId,
          _kAliceUid,
          type:  notifTypeSwapAccepted,
          title: notifTitleSwapAccepted,
          body:  notifBodySwapAcceptedTemplate.replaceFirst('{name}', 'Bob'),
        );

        final snap = await db
            .collection(collectionFlats)
            .doc(_kFlatId)
            .collection(collectionMembers)
            .doc(_kAliceUid)
            .collection(collectionNotifications)
            .get();
        expect(snap.docs.length, 1);
        expect(snap.docs.first.data()[fieldNotifType], notifTypeSwapAccepted);
      },
    );

    test(
      'Given Alice withdraws her request, '
      'when the client writes a swap_withdrawn notification to Bob, '
      'then the notification document exists with the swap_withdrawn type',
      () async {
        await notifRepo.writeNotification(
          _kFlatId,
          _kBobUid,
          type:  notifTypeSwapWithdrawn,
          title: notifTitleSwapWithdrawn,
          body:  notifBodySwapWithdrawnTemplate.replaceFirst('{name}', 'Alice'),
        );

        final snap = await db
            .collection(collectionFlats)
            .doc(_kFlatId)
            .collection(collectionMembers)
            .doc(_kBobUid)
            .collection(collectionNotifications)
            .get();
        expect(snap.docs.length, 1);
        final data = snap.docs.first.data();
        expect(data[fieldNotifType], notifTypeSwapWithdrawn);
        expect(data[fieldNotifBody], contains('Alice'));
        expect(data[fieldNotifBody], contains('withdrew'));
      },
    );
  });

  // ── Scenario 4: Auto-reject competing requests on accept ───────────────────
  group('Situation: Auto-reject competing requests when one is accepted', () {
    late FakeFirebaseFirestore db;
    late SwapRequestRepository repo;

    setUp(() async {
      db   = FakeFirebaseFirestore();
      repo = SwapRequestRepository(db: db);
      await _seedScenario(db);
      // Both Alice and Carla send a swap request targeting Bob's task.
      await repo.createSwapRequest(
        _kFlatId,
        _request(
          id:              _kRequestAB,
          requesterUid:    _kAliceUid,
          requesterTaskId: _kAliceTaskId,
          targetTaskId:    _kBobTaskId,
        ),
      );
      await repo.createSwapRequest(
        _kFlatId,
        _request(
          id:              _kRequestCB,
          requesterUid:    _kCarlaUid,
          requesterTaskId: _kCarlaTaskId,
          targetTaskId:    _kBobTaskId,
        ),
      );
    });

    test(
      "Given Alice and Carla both have pending requests targeting Bob's task, "
      "when declineAllOtherPendingForTarget is called with Alice's request as accepted, "
      "then Carla's request status is updated to declined",
      () async {
        await repo.declineAllOtherPendingForTarget(
          _kFlatId,
          _kBobTaskId,
          _kRequestAB,
        );

        final doc = await db
            .collection(collectionFlats)
            .doc(_kFlatId)
            .collection(collectionSwapRequests)
            .doc(_kRequestCB)
            .get();
        expect(doc.data()![fieldSwapStatus], 'declined');
      },
    );

    test(
      "Given Alice and Carla both have pending requests targeting Bob's task, "
      "when declineAllOtherPendingForTarget is called with Alice's request as accepted, "
      "then Alice's request is unchanged (still pending)",
      () async {
        await repo.declineAllOtherPendingForTarget(
          _kFlatId,
          _kBobTaskId,
          _kRequestAB,
        );

        final doc = await db
            .collection(collectionFlats)
            .doc(_kFlatId)
            .collection(collectionSwapRequests)
            .doc(_kRequestAB)
            .get();
        expect(doc.data()![fieldSwapStatus], 'pending',
            reason: 'declineAllOtherPendingForTarget must not touch the '
                'accepted request itself.');
      },
    );

    test(
      "Given Alice and Carla both have pending requests targeting Bob's task, "
      "when declineAllOtherPendingForTarget is called with Alice's request as accepted, "
      "then the returned list contains Carla's requesterUid",
      () async {
        final rejected = await repo.declineAllOtherPendingForTarget(
          _kFlatId,
          _kBobTaskId,
          _kRequestAB,
        );

        expect(rejected, [_kCarlaUid]);
      },
    );

    test(
      "Given only Alice has a pending request targeting Bob's task, "
      'when declineAllOtherPendingForTarget is called for that request, '
      'then the returned list is empty (nothing else to decline)',
      () async {
        // Remove Carla's request first so Alice's is the only pending one.
        await db
            .collection(collectionFlats)
            .doc(_kFlatId)
            .collection(collectionSwapRequests)
            .doc(_kRequestCB)
            .delete();

        final rejected = await repo.declineAllOtherPendingForTarget(
          _kFlatId,
          _kBobTaskId,
          _kRequestAB,
        );
        expect(rejected, isEmpty);
      },
    );

    test(
      'Given a pending request from Alice targeting Bob and another pending '
      'request from Alice targeting Carla, '
      "when declineAllOtherPendingForTarget is called for Alice's Bob-request, "
      'then the Carla-targeting request is NOT touched (different target task)',
      () async {
        // Carla's request to Bob is irrelevant here — replace it with
        // another request from Alice, this time targeting Carla's task.
        await db
            .collection(collectionFlats)
            .doc(_kFlatId)
            .collection(collectionSwapRequests)
            .doc(_kRequestCB)
            .delete();
        const aliceCarlaRequestId = 'req-alice-carla';
        await repo.createSwapRequest(
          _kFlatId,
          _request(
            id:              aliceCarlaRequestId,
            requesterUid:    _kAliceUid,
            requesterTaskId: _kAliceTaskId,
            targetTaskId:    _kCarlaTaskId,
          ),
        );

        await repo.declineAllOtherPendingForTarget(
          _kFlatId,
          _kBobTaskId,
          _kRequestAB,
        );

        final doc = await db
            .collection(collectionFlats)
            .doc(_kFlatId)
            .collection(collectionSwapRequests)
            .doc(aliceCarlaRequestId)
            .get();
        expect(doc.data()![fieldSwapStatus], 'pending',
            reason: 'requests targeting a different task must not be auto-declined.');
      },
    );
  });
}
