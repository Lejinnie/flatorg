// BDD integration tests for the "Leave Flat" flow.
//
// Covers three scenarios a user may face when leaving their flat:
//   1. Regular member leaves — their document is removed; nothing else changes.
//   2. Admin leaves with other members present — must transfer admin first, then
//      remove themselves; flat's admin_uid is updated accordingly.
//   3. Admin is the last member — the entire flat document is deleted.
//
// In all cases the Firebase Auth account is NOT deleted (the user keeps their
// login credentials so they can create or join another flat afterwards).  Auth
// deletion is handled by the Firebase SDK and is out of scope for Firestore
// integration tests.
//
// Uses FakeFirebaseFirestore (in-memory) — no real Firebase project needed.
// Naming convention: "Given <precondition>, when <action>, then <outcome>"

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flatorg/constants/strings.dart';
import 'package:flatorg/repositories/flat_repository.dart';
import 'package:flatorg/repositories/person_repository.dart';
import 'package:flutter_test/flutter_test.dart';

// ── Fixtures ──────────────────────────────────────────────────────────────────

const _kFlatId    = 'flat-1';
const _kAdminUid  = 'alice-uid';
const _kMemberUid = 'bob-uid';
const _kOtherUid  = 'carla-uid';

Future<void> _seedFlat(FakeFirebaseFirestore db, String adminUid) async {
  await db.collection(collectionFlats).doc(_kFlatId).set({
    fieldFlatName:        'Test Flat',
    fieldFlatAdminUid:    adminUid,
    fieldFlatInviteCode:  'ABC123',
  });
}

Future<void> _seedMember(
  FakeFirebaseFirestore db,
  String uid,
  String role,
) async {
  await db
      .collection(collectionFlats)
      .doc(_kFlatId)
      .collection(collectionMembers)
      .doc(uid)
      .set({
    fieldPersonUid:          uid,
    fieldPersonName:         uid,
    fieldPersonEmail:        '$uid@flat.test',
    fieldPersonRole:         role,
    fieldPersonOnVacation:   false,
    fieldPersonSwapTokens:   3,
  });
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // ── Scenario 1: Regular member leaves ─────────────────────────────────────
  group('Situation: Regular member leaves flat', () {
    late FakeFirebaseFirestore db;
    late PersonRepository personRepo;

    setUp(() async {
      db         = FakeFirebaseFirestore();
      personRepo = PersonRepository(db: db);
      await _seedFlat(db, _kAdminUid);
      await _seedMember(db, _kAdminUid, 'admin');
      await _seedMember(db, _kMemberUid, 'member');
      await _seedMember(db, _kOtherUid, 'member');
    });

    test(
      'Given Bob is a regular member, '
      "when removeMember is called with Bob's UID, "
      "then Bob's member document no longer exists in Firestore",
      () async {
        await personRepo.removeMember(_kFlatId, _kMemberUid);

        final bobDoc = await db
            .collection(collectionFlats)
            .doc(_kFlatId)
            .collection(collectionMembers)
            .doc(_kMemberUid)
            .get();
        expect(
          bobDoc.exists,
          isFalse,
          reason: "Bob's member document must be deleted after leaving.",
        );
      },
    );

    test(
      'Given Bob is a regular member, '
      "when removeMember is called with Bob's UID, "
      'then the flat document is unchanged',
      () async {
        await personRepo.removeMember(_kFlatId, _kMemberUid);

        final flatDoc =
            await db.collection(collectionFlats).doc(_kFlatId).get();
        expect(
          flatDoc.exists,
          isTrue,
          reason: 'Flat document must not be deleted when a regular member leaves.',
        );
        expect(
          flatDoc.data()![fieldFlatAdminUid],
          _kAdminUid,
          reason: 'Admin UID must remain unchanged.',
        );
      },
    );

    test(
      'Given Bob is a regular member and Carla is also a member, '
      "when removeMember is called with Bob's UID, "
      "then Carla's member document is unchanged",
      () async {
        await personRepo.removeMember(_kFlatId, _kMemberUid);

        final carlaDoc = await db
            .collection(collectionFlats)
            .doc(_kFlatId)
            .collection(collectionMembers)
            .doc(_kOtherUid)
            .get();
        expect(
          carlaDoc.exists,
          isTrue,
          reason: 'Other members must not be affected by Bob leaving.',
        );
        expect(
          carlaDoc.data()![fieldPersonRole],
          'member',
          reason: "Carla's role must remain 'member'.",
        );
      },
    );
  });

  // ── Scenario 2: Admin leaves with other members present ────────────────────
  group('Situation: Admin leaves flat with other members present', () {
    late FakeFirebaseFirestore db;
    late PersonRepository personRepo;

    setUp(() async {
      db         = FakeFirebaseFirestore();
      personRepo = PersonRepository(db: db);
      await _seedFlat(db, _kAdminUid);
      await _seedMember(db, _kAdminUid, 'admin');
      await _seedMember(db, _kMemberUid, 'member');
      await _seedMember(db, _kOtherUid, 'member');
    });

    test(
      'Given Alice is admin and Bob is a member, '
      'when transferAdmin(Alice → Bob) then removeMember(Alice) is called, '
      "then Alice's member document no longer exists",
      () async {
        await personRepo.transferAdmin(_kFlatId, _kAdminUid, _kMemberUid);
        await personRepo.removeMember(_kFlatId, _kAdminUid);

        final aliceDoc = await db
            .collection(collectionFlats)
            .doc(_kFlatId)
            .collection(collectionMembers)
            .doc(_kAdminUid)
            .get();
        expect(
          aliceDoc.exists,
          isFalse,
          reason: "Alice's member document must be deleted after leaving.",
        );
      },
    );

    test(
      'Given Alice is admin and Bob is a member, '
      'when transferAdmin(Alice → Bob) then removeMember(Alice) is called, '
      "then the flat's admin_uid points to Bob",
      () async {
        await personRepo.transferAdmin(_kFlatId, _kAdminUid, _kMemberUid);
        await personRepo.removeMember(_kFlatId, _kAdminUid);

        final flatDoc =
            await db.collection(collectionFlats).doc(_kFlatId).get();
        expect(
          flatDoc.data()![fieldFlatAdminUid],
          _kMemberUid,
          reason: 'Flat admin_uid must point to the new admin after transfer.',
        );
      },
    );

    test(
      'Given Alice is admin and Bob is a member, '
      'when transferAdmin(Alice → Bob) then removeMember(Alice) is called, '
      "then Bob's role is 'admin'",
      () async {
        await personRepo.transferAdmin(_kFlatId, _kAdminUid, _kMemberUid);
        await personRepo.removeMember(_kFlatId, _kAdminUid);

        final bobDoc = await db
            .collection(collectionFlats)
            .doc(_kFlatId)
            .collection(collectionMembers)
            .doc(_kMemberUid)
            .get();
        expect(
          bobDoc.data()![fieldPersonRole],
          'admin',
          reason: 'Bob must be promoted to admin after the transfer.',
        );
      },
    );

    test(
      'Given Alice is admin, Bob and Carla are members, '
      'when transferAdmin(Alice → Bob) then removeMember(Alice) is called, '
      "then Carla's role is unchanged",
      () async {
        await personRepo.transferAdmin(_kFlatId, _kAdminUid, _kMemberUid);
        await personRepo.removeMember(_kFlatId, _kAdminUid);

        final carlaDoc = await db
            .collection(collectionFlats)
            .doc(_kFlatId)
            .collection(collectionMembers)
            .doc(_kOtherUid)
            .get();
        expect(
          carlaDoc.data()![fieldPersonRole],
          'member',
          reason: 'Unrelated members must not have their role changed.',
        );
      },
    );
  });

  // ── Scenario 3: Admin is the last member ───────────────────────────────────
  group('Situation: Admin is the last member and leaves', () {
    late FakeFirebaseFirestore db;
    late FlatRepository flatRepo;

    setUp(() async {
      db       = FakeFirebaseFirestore();
      flatRepo = FlatRepository(db: db);
      await _seedFlat(db, _kAdminUid);
      await _seedMember(db, _kAdminUid, 'admin');
    });

    test(
      'Given Alice is admin and the only member, '
      'when deleteFlat is called, '
      'then the flat document no longer exists in Firestore',
      () async {
        await flatRepo.deleteFlat(_kFlatId);

        final flatDoc =
            await db.collection(collectionFlats).doc(_kFlatId).get();
        expect(
          flatDoc.exists,
          isFalse,
          reason: 'Flat document must be deleted when the last member leaves.',
        );
      },
    );

    test(
      'Given Alice is admin and the only member, '
      'when deleteFlat is called, '
      "then Alice's Firebase Auth account is unaffected "
      '(Auth is outside Firestore scope — verify no Firestore user record exists)',
      () async {
        await flatRepo.deleteFlat(_kFlatId);

        // Auth account deletion is handled by Firebase Auth SDK, not Firestore.
        // This test confirms Firestore has no residual user-scoped data under the flat.
        final membersSnapshot = await db
            .collection(collectionFlats)
            .doc(_kFlatId)
            .collection(collectionMembers)
            .get();
        expect(
          membersSnapshot.docs,
          isEmpty,
          reason: 'No member documents should remain after the flat is deleted.',
        );
      },
    );
  });
}
