import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/person.dart';
import '../constants/strings.dart';

/// Repository for Person documents under flats/{flatId}/members.
/// All Firestore access for members goes through this class (Repository pattern).
class PersonRepository {
  final FirebaseFirestore _db;

  PersonRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _membersCollection(String flatId) {
    return _db
        .collection(collectionFlats)
        .doc(flatId)
        .collection(collectionMembers);
  }

  /// Returns a real-time stream of all members in a flat.
  Stream<List<Person>> watchMembers(String flatId) {
    return _membersCollection(flatId).snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => Person.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
              .toList(),
        );
  }

  /// Returns a real-time stream of a single member.
  Stream<Person?> watchMember(String flatId, String uid) {
    return _membersCollection(flatId).doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Person.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>);
    });
  }

  /// Fetches a single member once.
  Future<Person?> fetchMember(String flatId, String uid) async {
    final doc = await _membersCollection(flatId).doc(uid).get();
    if (!doc.exists) return null;
    return Person.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>);
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
}
