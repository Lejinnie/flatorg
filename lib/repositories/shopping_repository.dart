import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/issue.dart';
import '../constants/strings.dart';

/// Repository for ShoppingItem documents under flats/{flatId}/shoppingItems.
class ShoppingRepository {
  final FirebaseFirestore _db;

  ShoppingRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _shoppingCollection(String flatId) {
    return _db
        .collection(collectionFlats)
        .doc(flatId)
        .collection(collectionShoppingItems);
  }

  /// Returns a real-time stream of all shopping items.
  /// Unbought items are returned before bought ones (Firestore orderBy on bool not supported;
  /// ordering is done client-side in the UI).
  Stream<List<ShoppingItem>> watchShoppingItems(String flatId) {
    return _shoppingCollection(flatId)
        .snapshots()
        .map((snap) => snap.docs.map((d) => ShoppingItem.fromFirestore(d)).toList());
  }

  /// Adds a new shopping item.
  Future<void> addShoppingItem(String flatId, ShoppingItem item) async {
    await _shoppingCollection(flatId).doc(item.id).set(item.toFirestore());
  }

  /// Marks an item as bought and records the time (for Cloud Function cleanup).
  Future<void> markBought(String flatId, String itemId) async {
    await _shoppingCollection(flatId).doc(itemId).update({
      fieldShoppingIsBought: true,
      fieldShoppingBoughtAt: Timestamp.now(),
    });
  }

  /// Deletes a shopping item.
  Future<void> deleteItem(String flatId, String itemId) async {
    await _shoppingCollection(flatId).doc(itemId).delete();
  }
}
