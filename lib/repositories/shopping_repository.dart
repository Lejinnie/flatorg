import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/strings.dart';
import '../models/issue.dart';

/// Repository for ShoppingItem documents under flats/{flatId}/shoppingItems.
class ShoppingRepository {
  final FirebaseFirestore _db;

  ShoppingRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _shoppingCollection(String flatId) =>
      _db
          .collection(collectionFlats)
          .doc(flatId)
          .collection(collectionShoppingItems);

  /// Returns a real-time stream of all shopping items sorted by [ShoppingItem.order].
  /// Sorting is done client-side because the `order` field may be absent on items
  /// created before this field was introduced.
  Stream<List<ShoppingItem>> watchShoppingItems(String flatId) =>
      _shoppingCollection(flatId).snapshots().map((snap) {
        final items = snap.docs.map(ShoppingItem.fromFirestore).toList()
          ..sort((a, b) => a.order.compareTo(b.order));
        return items;
      });

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

  /// Moves a bought item back to the active shopping list.
  Future<void> markUnbought(String flatId, String itemId) async {
    await _shoppingCollection(flatId).doc(itemId).update({
      fieldShoppingIsBought: false,
      fieldShoppingBoughtAt: null,
    });
  }

  /// Deletes a shopping item.
  Future<void> deleteItem(String flatId, String itemId) async {
    await _shoppingCollection(flatId).doc(itemId).delete();
  }

  /// Batch-writes a new [fieldShoppingOrder] value for each item based on its
  /// position in [items].  Used after the user reorders the list.
  Future<void> updateItemOrders(String flatId, List<ShoppingItem> items) async {
    final batch = _db.batch();
    for (var i = 0; i < items.length; i++) {
      batch.update(
        _shoppingCollection(flatId).doc(items[i].id),
        {fieldShoppingOrder: i},
      );
    }
    await batch.commit();
  }
}
