// BDD integration tests for PersonRepository.transferAdmin().
//
// Uses fake_cloud_firestore (in-memory Firestore) so no real Firebase project
// is needed. Tests verify that transferAdmin writes all three documents
// atomically and that unrelated members are untouched.
//
// Naming convention: "Given <precondition>, when <action>, then <outcome>"

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flatorg/constants/strings.dart';
import 'package:flatorg/repositories/person_repository.dart';
import 'package:flutter_test/flutter_test.dart';

// ── Fixtures ──────────────────────────────────────────────────────────────────

const _kFlatId    = 'flat-1';
const _kAdminUid  = 'alice-uid';
const _kMemberUid = 'bob-uid';
const _kOtherUid  = 'carla-uid';

/// Seeds a member document with the given role.
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
    fieldPersonUid:   uid,
    fieldPersonName:  uid,
    fieldPersonEmail: '$uid@flat.test',
    fieldPersonRole:  role,
    fieldPersonOnVacation: false,
    fieldPersonSwapTokens: 3,
  });
}

/// Seeds the flat document with the given admin UID.
Future<void> _seedFlat(FakeFirebaseFirestore db, String adminUid) async {
  await db.collection(collectionFlats).doc(_kFlatId).set({
    fieldFlatName:     'Test Flat',
    fieldFlatAdminUid: adminUid,
    fieldFlatInviteCode: 'ABC123',
  });
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('Situation 7 — transferAdmin', () {
    late FakeFirebaseFirestore db;
    late PersonRepository repo;

    setUp(() async {
      db   = FakeFirebaseFirestore();
      repo = PersonRepository(db: db);
      await _seedFlat(db, _kAdminUid);
      await _seedMember(db, _kAdminUid, 'admin');
      await _seedMember(db, _kMemberUid, 'member');
      await _seedMember(db, _kOtherUid, 'member');
    });

    test(
      'Given Alice is admin and Bob is a member, '
      'when transferAdmin is called, '
      "then the flat's admin_uid is updated to Bob's UID",
      () async {
        await repo.transferAdmin(_kFlatId, _kAdminUid, _kMemberUid);

        final flatDoc = await db.collection(collectionFlats).doc(_kFlatId).get();
        expect(
          flatDoc.data()![fieldFlatAdminUid],
          _kMemberUid,
          reason: "flat's admin_uid must point to the new admin.",
        );
      },
    );

    test(
      'Given Alice is admin, '
      'when transferAdmin is called, '
      "then Alice's role becomes 'member'",
      () async {
        await repo.transferAdmin(_kFlatId, _kAdminUid, _kMemberUid);

        final aliceDoc = await db
            .collection(collectionFlats)
            .doc(_kFlatId)
            .collection(collectionMembers)
            .doc(_kAdminUid)
            .get();
        expect(
          aliceDoc.data()![fieldPersonRole],
          'member',
          reason: 'Outgoing admin must be downgraded to member.',
        );
      },
    );

    test(
      'Given Bob is a member, '
      'when transferAdmin is called, '
      "then Bob's role becomes 'admin'",
      () async {
        await repo.transferAdmin(_kFlatId, _kAdminUid, _kMemberUid);

        final bobDoc = await db
            .collection(collectionFlats)
            .doc(_kFlatId)
            .collection(collectionMembers)
            .doc(_kMemberUid)
            .get();
        expect(
          bobDoc.data()![fieldPersonRole],
          'admin',
          reason: 'Incoming admin must be promoted.',
        );
      },
    );

    test(
      'Given Alice is admin and Bob and Carla are members, '
      'when transferAdmin(Alice → Bob) is called, '
      "then Carla's role is unchanged",
      () async {
        await repo.transferAdmin(_kFlatId, _kAdminUid, _kMemberUid);

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

    test(
      'Given Alice is admin and Bob is a member, '
      'when transferAdmin is called, '
      'then all three writes are consistent: flat points to Bob, '
      'Alice is member, Bob is admin',
      () async {
        await repo.transferAdmin(_kFlatId, _kAdminUid, _kMemberUid);

        final flatDoc = await db.collection(collectionFlats).doc(_kFlatId).get();
        final aliceDoc = await db
            .collection(collectionFlats)
            .doc(_kFlatId)
            .collection(collectionMembers)
            .doc(_kAdminUid)
            .get();
        final bobDoc = await db
            .collection(collectionFlats)
            .doc(_kFlatId)
            .collection(collectionMembers)
            .doc(_kMemberUid)
            .get();

        expect(flatDoc.data()![fieldFlatAdminUid], _kMemberUid);
        expect(aliceDoc.data()![fieldPersonRole],  'member');
        expect(bobDoc.data()![fieldPersonRole],    'admin');
      },
    );
  });
}
