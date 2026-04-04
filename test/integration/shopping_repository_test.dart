// BDD integration tests for ShoppingRepository.
//
// Every method is exercised with FakeFirebaseFirestore so no real network
// call is made.  Tests verify both the Firestore document state written by
// the repository and the stream it exposes back to the UI.
//
// Scenarios are grouped by user interaction and named:
//   "Given <precondition>, when <action>, then <outcome>"

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flatorg/constants/strings.dart';
import 'package:flatorg/models/issue.dart';
import 'package:flatorg/repositories/shopping_repository.dart';
import 'package:flutter_test/flutter_test.dart';

// ── Fixtures ──────────────────────────────────────────────────────────────────

const _kFlatId    = 'flat-1';
const _kAliceUid  = 'alice-uid';
const _kBobUid    = 'bob-uid';

/// Creates an item seeded directly into [db] (bypasses the repository so we
/// can also test legacy items that lack an order field).
Future<void> _seedRaw(
  FakeFirebaseFirestore db,
  String itemId,
  Map<String, dynamic> fields,
) async {
  await db
      .collection(collectionFlats)
      .doc(_kFlatId)
      .collection(collectionShoppingItems)
      .doc(itemId)
      .set(fields);
}

/// Factory for a fully-populated [ShoppingItem].
ShoppingItem _item({
  String id       = 'item-1',
  String text     = 'Milk',
  String addedBy  = _kAliceUid,
  bool   isBought = false,
  int    order    = 1000,
}) =>
    ShoppingItem(
      id:       id,
      text:     text,
      addedBy:  addedBy,
      isBought: isBought,
      boughtAt: isBought ? Timestamp.fromDate(DateTime(2024)) : null,
      order:    order,
    );

/// Reads a single shopping document's raw data from [db].
Future<Map<String, dynamic>?> _readDoc(
  FakeFirebaseFirestore db,
  String itemId,
) async {
  final snap = await db
      .collection(collectionFlats)
      .doc(_kFlatId)
      .collection(collectionShoppingItems)
      .doc(itemId)
      .get();
  return snap.exists ? snap.data() : null;
}

/// Fetches one snapshot from [stream] and returns the emitted list.
Future<List<ShoppingItem>> _firstEmit(Stream<List<ShoppingItem>> stream) =>
    stream.first;

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late FakeFirebaseFirestore db;
  late ShoppingRepository repo;

  setUp(() {
    db   = FakeFirebaseFirestore();
    repo = ShoppingRepository(db: db);
  });

  // ── Situation 1: watchShoppingItems ────────────────────────────────────────

  group('Situation 1 — watchShoppingItems: stream ordering and content', () {
    test(
      'Given an empty flat, '
      'when the stream is observed, '
      'then it emits an empty list',
      () async {
        final items = await _firstEmit(repo.watchShoppingItems(_kFlatId));
        expect(items, isEmpty);
      },
    );

    test(
      'Given one item added via the repository, '
      'when the stream is observed, '
      'then it emits a list with that item',
      () async {
        await repo.addShoppingItem(_kFlatId, _item(text: 'Eggs'));
        final items = await _firstEmit(repo.watchShoppingItems(_kFlatId));
        expect(items, hasLength(1));
        expect(items.first.text, 'Eggs');
      },
    );

    test(
      'Given three items with different order values, '
      'when the stream is observed, '
      'then items are returned sorted descending by order (highest first)',
      () async {
        await repo.addShoppingItem(_kFlatId, _item(id: 'a', text: 'A', order: 10));
        await repo.addShoppingItem(_kFlatId, _item(id: 'b', text: 'B', order: 50));
        await repo.addShoppingItem(_kFlatId, _item(id: 'c', text: 'C', order: 30));

        final items = await _firstEmit(repo.watchShoppingItems(_kFlatId));
        expect(items.map((i) => i.text), ['B', 'C', 'A'],
            reason: 'DESC by order: B(50) > C(30) > A(10)');
      },
    );

    test(
      'Given a legacy item seeded without an order field, '
      'when the stream is observed, '
      'then the item is included with order defaulting to 0 (sorts to bottom)',
      () async {
        await _seedRaw(db, 'legacy', {
          fieldShoppingText:    'Legacy bread',
          fieldShoppingAddedBy: _kAliceUid,
          fieldShoppingIsBought: false,
          // order field intentionally absent
        });
        await repo.addShoppingItem(_kFlatId, _item(id: 'new', text: 'New item'));

        final items = await _firstEmit(repo.watchShoppingItems(_kFlatId));
        expect(items.map((i) => i.text), ['New item', 'Legacy bread'],
            reason: 'New item (order=1000) sorts above legacy item (order=0)');
      },
    );

    test(
      'Given a mix of bought and unbought items, '
      'when the stream is observed, '
      'then ALL items are returned (screen splits them client-side)',
      () async {
        await repo.addShoppingItem(_kFlatId, _item(id: 'a'));
        await repo.addShoppingItem(_kFlatId, _item(id: 'b', isBought: true));

        final items = await _firstEmit(repo.watchShoppingItems(_kFlatId));
        expect(items, hasLength(2));
      },
    );
  });

  // ── Situation 2: addShoppingItem ───────────────────────────────────────────

  group('Situation 2 — addShoppingItem: writing items to Firestore', () {
    test(
      'Given a valid item, '
      'when addShoppingItem is called, '
      'then the Firestore document is written with all correct fields',
      () async {
        final newItem = _item(id: 'item-x', text: 'Butter', order: 9999);
        await repo.addShoppingItem(_kFlatId, newItem);

        final data = await _readDoc(db, 'item-x');
        expect(data, isNotNull);
        expect(data![fieldShoppingText],     'Butter');
        expect(data[fieldShoppingAddedBy],   _kAliceUid);
        expect(data[fieldShoppingIsBought],  false);
        expect(data[fieldShoppingBoughtAt],  isNull);
        expect(data[fieldShoppingOrder],     9999);
      },
    );

    test(
      'Given two items added sequentially, '
      'when Firestore is read, '
      'then both documents exist with their respective content',
      () async {
        await repo.addShoppingItem(_kFlatId, _item());
        await repo.addShoppingItem(_kFlatId, _item(id: 'item-2', text: 'Cheese'));

        final d1 = await _readDoc(db, 'item-1');
        final d2 = await _readDoc(db, 'item-2');
        expect(d1![fieldShoppingText], 'Milk');
        expect(d2![fieldShoppingText], 'Cheese');
      },
    );

    test(
      'Given an item added by Bob, '
      'when Firestore is read, '
      "then added_by field is Bob's UID",
      () async {
        await repo.addShoppingItem(
            _kFlatId, _item(id: 'bob-item', addedBy: _kBobUid));
        final data = await _readDoc(db, 'bob-item');
        expect(data![fieldShoppingAddedBy], _kBobUid);
      },
    );
  });

  // ── Situation 3: markBought ────────────────────────────────────────────────

  group('Situation 3 — markBought: moving item to bought section', () {
    test(
      'Given an unbought item, '
      'when markBought is called, '
      'then is_bought is true and bought_at is a non-null timestamp',
      () async {
        await repo.addShoppingItem(_kFlatId, _item());
        await repo.markBought(_kFlatId, 'item-1');

        final data = await _readDoc(db, 'item-1');
        expect(data![fieldShoppingIsBought], isTrue);
        expect(data[fieldShoppingBoughtAt],  isNotNull,
            reason: 'bought_at must be set so the Cloud Function cleanup can trigger');
      },
    );

    test(
      'Given an already-bought item, '
      'when markBought is called again, '
      'then bought_at is overwritten with a fresh timestamp',
      () async {
        await _seedRaw(db, 'item-1', {
          fieldShoppingText:    'Milk',
          fieldShoppingAddedBy: _kAliceUid,
          fieldShoppingIsBought: true,
          fieldShoppingBoughtAt: Timestamp.fromDate(DateTime(2020)),
          fieldShoppingOrder:    0,
        });
        final before = (await _readDoc(db, 'item-1'))![fieldShoppingBoughtAt] as Timestamp;

        await repo.markBought(_kFlatId, 'item-1');

        final after = (await _readDoc(db, 'item-1'))![fieldShoppingBoughtAt] as Timestamp;
        expect(after.seconds >= before.seconds, isTrue,
            reason: 'New bought_at must be the same or later than the original');
      },
    );

    test(
      'Given two items where only one is marked bought, '
      'when Firestore is read, '
      'then the other item is unaffected',
      () async {
        await repo.addShoppingItem(_kFlatId, _item(id: 'a'));
        await repo.addShoppingItem(_kFlatId, _item(id: 'b', text: 'Bread'));
        await repo.markBought(_kFlatId, 'a');

        final dataB = await _readDoc(db, 'b');
        expect(dataB![fieldShoppingIsBought], isFalse,
            reason: 'Bread must remain unbought — only Milk was marked');
      },
    );
  });

  // ── Situation 4: markUnbought ──────────────────────────────────────────────

  group('Situation 4 — markUnbought: returning item to active list', () {
    test(
      'Given a bought item, '
      'when markUnbought is called, '
      'then is_bought is false and bought_at is null',
      () async {
        await _seedRaw(db, 'item-1', {
          fieldShoppingText:    'Milk',
          fieldShoppingAddedBy: _kAliceUid,
          fieldShoppingIsBought: true,
          fieldShoppingBoughtAt: Timestamp.now(),
          fieldShoppingOrder:    0,
        });

        await repo.markUnbought(_kFlatId, 'item-1');

        final data = await _readDoc(db, 'item-1');
        expect(data![fieldShoppingIsBought], isFalse);
        expect(data[fieldShoppingBoughtAt],  isNull,
            reason: 'bought_at must be cleared to avoid Cloud Function false-positive cleanup');
      },
    );

    test(
      'Given a bought item among others, '
      'when markUnbought is called on it, '
      'then the other items are unaffected',
      () async {
        await _seedRaw(db, 'a', {
          fieldShoppingText:    'Milk',
          fieldShoppingAddedBy: _kAliceUid,
          fieldShoppingIsBought: true,
          fieldShoppingBoughtAt: Timestamp.now(),
          fieldShoppingOrder:    0,
        });
        await repo.addShoppingItem(_kFlatId, _item(id: 'b', text: 'Bread'));

        await repo.markUnbought(_kFlatId, 'a');

        final dataB = await _readDoc(db, 'b');
        expect(dataB![fieldShoppingIsBought], isFalse,
            reason: 'Bread was never bought and must remain unchanged');
      },
    );

    test(
      'Given an item that goes through buy → unbuy, '
      'when the stream is observed after unbuy, '
      'then the item reappears in the list with isBought=false',
      () async {
        await repo.addShoppingItem(_kFlatId, _item());
        await repo.markBought(_kFlatId, 'item-1');
        await repo.markUnbought(_kFlatId, 'item-1');

        final items = await _firstEmit(repo.watchShoppingItems(_kFlatId));
        expect(items.single.isBought, isFalse);
        expect(items.single.text, 'Milk');
      },
    );
  });

  // ── Situation 5: deleteItem ────────────────────────────────────────────────

  group('Situation 5 — deleteItem: removing items from the list', () {
    test(
      'Given an existing item, '
      'when deleteItem is called, '
      'then the Firestore document no longer exists',
      () async {
        await repo.addShoppingItem(_kFlatId, _item());
        await repo.deleteItem(_kFlatId, 'item-1');

        final data = await _readDoc(db, 'item-1');
        expect(data, isNull);
      },
    );

    test(
      'Given two items, '
      'when one is deleted, '
      'then the other item is unaffected',
      () async {
        await repo.addShoppingItem(_kFlatId, _item(id: 'keep', text: 'Keep me'));
        await repo.addShoppingItem(_kFlatId, _item(id: 'del',  text: 'Delete me'));

        await repo.deleteItem(_kFlatId, 'del');

        final kept    = await _readDoc(db, 'keep');
        final deleted = await _readDoc(db, 'del');
        expect(kept,    isNotNull);
        expect(deleted, isNull);
      },
    );

    test(
      'Given a deleted item, '
      'when the stream is observed, '
      'then the deleted item does not appear',
      () async {
        await repo.addShoppingItem(_kFlatId, _item(id: 'a'));
        await repo.addShoppingItem(_kFlatId, _item(id: 'b', text: 'Eggs'));
        await repo.deleteItem(_kFlatId, 'a');

        final items = await _firstEmit(repo.watchShoppingItems(_kFlatId));
        expect(items, hasLength(1));
        expect(items.single.text, 'Eggs');
      },
    );

    test(
      'Given an unbought item deleted with an undo, '
      'when addShoppingItem is called with the original item, '
      'then the item reappears in the same list position '
      '(order value preserved from the original)',
      () async {
        final original = _item(order: 500);
        await repo.addShoppingItem(_kFlatId, original);
        await repo.deleteItem(_kFlatId, 'item-1');

        // Undo: re-add with the original object (same order).
        await repo.addShoppingItem(_kFlatId, original);

        final data = await _readDoc(db, 'item-1');
        expect(data![fieldShoppingText],  'Milk');
        expect(data[fieldShoppingOrder],  500,
            reason: 'Undo must restore the original order value so the item '
                'reappears in the correct list position');
      },
    );
  });

  // ── Situation 6: updateItemOrders ─────────────────────────────────────────

  group('Situation 6 — updateItemOrders: drag-to-reorder persistence', () {
    test(
      'Given three items in order [A, B, C], '
      'when updateItemOrders is called with that exact list, '
      'then A.order=2, B.order=1, C.order=0 '
      '(position 0 is highest — matches DESC sort in watchShoppingItems)',
      () async {
        final itemA = _item(id: 'a', text: 'A');
        final itemB = _item(id: 'b', text: 'B');
        final itemC = _item(id: 'c', text: 'C');
        for (final i in [itemA, itemB, itemC]) {
          await repo.addShoppingItem(_kFlatId, i);
        }

        await repo.updateItemOrders(_kFlatId, [itemA, itemB, itemC]);

        expect((await _readDoc(db, 'a'))![fieldShoppingOrder], 2,
            reason: 'A at position 0 → order = 3−1−0 = 2');
        expect((await _readDoc(db, 'b'))![fieldShoppingOrder], 1,
            reason: 'B at position 1 → order = 3−1−1 = 1');
        expect((await _readDoc(db, 'c'))![fieldShoppingOrder], 0,
            reason: 'C at position 2 → order = 3−1−2 = 0');
      },
    );

    test(
      'Given items [A, B, C], '
      'when C is moved to the top and updateItemOrders([C, A, B]) is called, '
      'then the stream returns C first',
      () async {
        final itemA = _item(id: 'a', text: 'A');
        final itemB = _item(id: 'b', text: 'B');
        final itemC = _item(id: 'c', text: 'C');
        for (final i in [itemA, itemB, itemC]) {
          await repo.addShoppingItem(_kFlatId, i);
        }

        await repo.updateItemOrders(_kFlatId, [itemC, itemA, itemB]);

        final items = await _firstEmit(repo.watchShoppingItems(_kFlatId));
        expect(items.map((i) => i.text), ['C', 'A', 'B'],
            reason: 'C moved to position 0 should have the highest order value');
      },
    );

    test(
      'Given items reordered to compact indices, '
      'when a new item is added afterwards, '
      'then the new item sorts above all reordered items '
      '(millisecond timestamp > compact index)',
      () async {
        final itemA = _item(id: 'a', text: 'A');
        final itemB = _item(id: 'b', text: 'B');
        for (final i in [itemA, itemB]) {
          await repo.addShoppingItem(_kFlatId, i);
        }
        await repo.updateItemOrders(_kFlatId, [itemA, itemB]);
        // After reorder: A.order=1, B.order=0 (compact indices, < 2^31)

        // New item uses DateTime.now().millisecondsSinceEpoch (~1.7 × 10^12)
        final newItem = _item(
          id:    'new',
          text:  'New (just added)',
          order: DateTime.now().millisecondsSinceEpoch,
        );
        await repo.addShoppingItem(_kFlatId, newItem);

        final items = await _firstEmit(repo.watchShoppingItems(_kFlatId));
        expect(items.first.text, 'New (just added)',
            reason: 'Millisecond timestamp always exceeds compact reorder index');
      },
    );

    test(
      'Given a single item, '
      'when updateItemOrders is called, '
      'then that item gets order=0',
      () async {
        final only = _item(id: 'solo', text: 'Solo');
        await repo.addShoppingItem(_kFlatId, only);
        await repo.updateItemOrders(_kFlatId, [only]);

        expect((await _readDoc(db, 'solo'))![fieldShoppingOrder], 0,
            reason: 'Single item: length−1−0 = 0');
      },
    );

    test(
      'Given items reordered, '
      'when the stream is observed, '
      'then stream order matches the new Firestore order values',
      () async {
        final items = [
          _item(id: 'x', text: 'X'),
          _item(id: 'y', text: 'Y'),
          _item(id: 'z', text: 'Z'),
        ];
        for (final i in items) {
          await repo.addShoppingItem(_kFlatId, i);
        }
        // Move Z to position 0 (top).
        await repo.updateItemOrders(_kFlatId, [items[2], items[0], items[1]]);

        final streamed = await _firstEmit(repo.watchShoppingItems(_kFlatId));
        expect(streamed.map((i) => i.id).toList(), ['z', 'x', 'y']);
      },
    );
  });

  // ── Situation 7: end-to-end user journey ──────────────────────────────────

  group('Situation 7 — end-to-end user journey across interactions', () {
    test(
      'Given a user adds three items, buys one, reorders the other two, '
      'then deletes a bought item — '
      'then the list reflects each action correctly',
      () async {
        // 1. User adds three items (newest-first by timestamp).
        final milk  = _item(id: 'milk',  order: 3000);
        final bread = _item(id: 'bread', text: 'Bread', order: 2000);
        final eggs  = _item(id: 'eggs',  text: 'Eggs');
        for (final i in [milk, bread, eggs]) {
          await repo.addShoppingItem(_kFlatId, i);
        }

        var items = await _firstEmit(repo.watchShoppingItems(_kFlatId));
        expect(items.map((i) => i.text), ['Milk', 'Bread', 'Eggs']);

        // 2. User marks Eggs as bought.
        await repo.markBought(_kFlatId, 'eggs');
        items = await _firstEmit(repo.watchShoppingItems(_kFlatId));
        expect(items.where((i) => i.isBought).map((i) => i.text), ['Eggs']);
        expect(items.where((i) => !i.isBought).map((i) => i.text),
            containsAll(['Milk', 'Bread']));

        // 3. User reorders unbought: [Bread, Milk].
        await repo.updateItemOrders(_kFlatId, [bread, milk]);
        items = await _firstEmit(repo.watchShoppingItems(_kFlatId));
        final unbought = items.where((i) => !i.isBought).toList();
        expect(unbought.first.text, 'Bread');

        // 4. User deletes Eggs (bought item).
        await repo.deleteItem(_kFlatId, 'eggs');
        items = await _firstEmit(repo.watchShoppingItems(_kFlatId));
        expect(items.where((i) => i.text == 'Eggs'), isEmpty);
        expect(items, hasLength(2));
      },
    );

    test(
      'Given a user deletes an item and immediately taps Undo, '
      'when the item is re-added with its original data, '
      'then the item is back in the stream with the same text and order',
      () async {
        const itemOrder = 42000;
        final original = _item(id: 'undo-me', text: 'Orange juice', order: itemOrder);
        await repo.addShoppingItem(_kFlatId, original);

        await repo.deleteItem(_kFlatId, 'undo-me');

        // Simulates SnackBar undo action in _ShoppingBodyState.
        await repo.addShoppingItem(_kFlatId, original);

        final items = await _firstEmit(repo.watchShoppingItems(_kFlatId));
        expect(items.single.text,  'Orange juice');
        expect(items.single.order, itemOrder);
      },
    );
  });
}
