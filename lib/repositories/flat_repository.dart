import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/strings.dart';
import '../models/flat.dart';

/// Repository for Flat documents in the top-level 'flats' collection.
class FlatRepository {
  final FirebaseFirestore _db;

  FlatRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _flatRef(String flatId) =>
      _db.collection(collectionFlats).doc(flatId);

  /// Returns a real-time stream of the flat document.
  Stream<Flat?> watchFlat(String flatId) =>
      _flatRef(flatId).snapshots().map((doc) {
        if (!doc.exists) {
          return null;
        }
        return Flat.fromFirestore(doc);
      });

  /// Fetches the flat document once.
  Future<Flat?> fetchFlat(String flatId) async {
    final doc = await _flatRef(flatId).get();
    if (!doc.exists) {
      return null;
    }
    return Flat.fromFirestore(doc);
  }

  /// Creates a new flat document.
  Future<void> createFlat(Flat flat) async {
    await _flatRef(flat.id).set(flat.toFirestore());
  }

  /// Updates admin-configurable settings on the flat.
  Future<void> updateFlatSettings(
    String flatId,
    Map<String, dynamic> updates,
  ) async {
    await _flatRef(flatId).update(updates);
  }

  /// Deletes the flat document. Subcollection cleanup (members, tasks, etc.)
  /// is handled by a Cloud Function triggered on flat deletion.
  ///
  /// Caller must be the flat admin; Firestore security rules enforce this.
  Future<void> deleteFlat(String flatId) async {
    assert(flatId.isNotEmpty, 'deleteFlat: flatId must not be empty.');
    await _flatRef(flatId).delete();
  }

  /// Looks up a flat by its invite code.
  /// Returns null when no flat with that code exists.
  Future<Flat?> findByInviteCode(String inviteCode) async {
    final snapshot = await _db
        .collection(collectionFlats)
        .where(fieldFlatInviteCode, isEqualTo: inviteCode)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }
    return Flat.fromFirestore(snapshot.docs.first);
  }
}
