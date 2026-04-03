import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/strings.dart';
import '../models/person.dart';

/// Repository for Person documents under flats/{flatId}/members.
/// All Firestore access for members goes through this class (Repository pattern).
class PersonRepository {
  final FirebaseFirestore _db;

  PersonRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _membersCollection(String flatId) =>
      _db
          .collection(collectionFlats)
          .doc(flatId)
          .collection(collectionMembers);

  /// Returns a real-time stream of all members in a flat.
  Stream<List<Person>> watchMembers(String flatId) =>
      _membersCollection(flatId).snapshots().map(
            (snapshot) => snapshot.docs
                .map(Person.fromFirestore)
                .toList(),
          );

  /// Returns a real-time stream of a single member.
  Stream<Person?> watchMember(String flatId, String uid) =>
      _membersCollection(flatId).doc(uid).snapshots().map((doc) {
        if (!doc.exists) {
          return null;
        }
        return Person.fromFirestore(doc);
      });

  /// Fetches a single member once.
  Future<Person?> fetchMember(String flatId, String uid) async {
    final doc = await _membersCollection(flatId).doc(uid).get();
    if (!doc.exists) {
      return null;
    }
    return Person.fromFirestore(doc);
  }

  /// Creates a member document (used during signup / flat join flow).
  Future<void> createMember(String flatId, Person person) async {
    await _membersCollection(flatId).doc(person.uid).set(person.toFirestore());
  }

  /// Updates specific fields on a member document.
  Future<void> updateMember(
    String flatId,
    String uid,
    Map<String, dynamic> updates,
  ) async {
    await _membersCollection(flatId).doc(uid).update(updates);
  }

  /// Toggles the on_vacation flag for a member.
  Future<void> setVacation(String flatId, String uid, {required bool onVacation}) async {
    await updateMember(flatId, uid, {fieldPersonOnVacation: onVacation});
  }

  /// Removes a member from the flat (admin only).
  /// The Cloud Function also sets the corresponding task to Vacant.
  Future<void> removeMember(String flatId, String uid) async {
    await _membersCollection(flatId).doc(uid).delete();
  }

  /// Stores the FCM device token for push notification delivery.
  Future<void> saveFcmToken(String flatId, String uid, String token) async {
    await updateMember(flatId, uid, {fieldPersonFcmToken: token});
  }

  /// Transfers admin rights from [currentAdminUid] to [newAdminUid] atomically.
  ///
  /// Writes three documents in a single batch:
  ///   1. flat's [fieldFlatAdminUid] → [newAdminUid]
  ///   2. old admin's [fieldPersonRole] → 'member'
  ///   3. new admin's [fieldPersonRole] → 'admin'
  ///
  /// [currentAdminUid] and [newAdminUid] must be non-empty, distinct UIDs of
  /// existing members; callers are responsible for validating this up front.
  Future<void> transferAdmin(
    String flatId,
    String currentAdminUid,
    String newAdminUid,
  ) async {
    assert(
      flatId.isNotEmpty && currentAdminUid.isNotEmpty && newAdminUid.isNotEmpty,
      'transferAdmin: flatId, currentAdminUid, and newAdminUid must not be empty. '
      'Got flatId="$flatId" currentAdminUid="$currentAdminUid" newAdminUid="$newAdminUid"',
    );
    assert(
      currentAdminUid != newAdminUid,
      'transferAdmin: currentAdminUid and newAdminUid must differ — '
      'cannot transfer admin rights to yourself (uid="$currentAdminUid").',
    );

    final batch = _db.batch()
      // Update the flat's admin pointer.
      ..update(
        _db.collection(collectionFlats).doc(flatId),
        {fieldFlatAdminUid: newAdminUid},
      )
      // Downgrade the outgoing admin to a regular member.
      ..update(
        _membersCollection(flatId).doc(currentAdminUid),
        {fieldPersonRole: 'member'},
      )
      // Promote the incoming admin.
      ..update(
        _membersCollection(flatId).doc(newAdminUid),
        {fieldPersonRole: 'admin'},
      );

    await batch.commit();
  }
}
