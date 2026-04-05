// BDD widget tests for ShoppingItemTile.
//
// ShoppingItemTile is a pure widget: it receives a ShoppingItem and a callback
// and renders the correct visual state and hit-target behaviour.  No Firebase
// calls are made.
//
// Naming: "Given <precondition>, when <action>, then <outcome>"

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flatorg/constants/app_theme.dart';
import 'package:flatorg/models/issue.dart';
import 'package:flatorg/widgets/shopping_item_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Fixtures ──────────────────────────────────────────────────────────────────

ShoppingItem _item({
  String id       = 'item-1',
  String text     = 'Milk',
  bool   isBought = false,
  int    order    = 1000,
}) =>
    ShoppingItem(
      id:       id,
      text:     text,
      addedBy:  'alice-uid',
      isBought: isBought,
      boughtAt: isBought ? Timestamp.fromDate(DateTime(2024)) : null,
      order:    order,
    );

// ── Harness ───────────────────────────────────────────────────────────────────

/// Pumps a [ShoppingItemTile] inside a minimal [MaterialApp] with the app
/// light theme.  [onToggleBought] defaults to a no-op; pass a custom callback
/// to assert it was called.
Future<void> _pumpTile(
  WidgetTester tester,
  ShoppingItem item, {
  VoidCallback? onToggleBought,
  Widget? dragHandle,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: ShoppingItemTile(
          item:           item,
          onToggleBought: onToggleBought ?? () {},
          dragHandle:     dragHandle,
        ),
      ),
    ),
  );
  await tester.pump();
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    // Prevent google_fonts from hitting the network during tests; Public Sans
    // will fall back to the system font.  Font shape is irrelevant for these tests.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  // ── Situation 8: unbought item visual state ────────────────────────────────

  group('Situation 8 — unbought item: visual representation', () {
    testWidgets(
      'Given an unbought item, '
      'when the tile is rendered, '
      'then an outline checkbox icon is shown',
      (tester) async {
        await _pumpTile(tester, _item());
        expect(find.byIcon(Icons.check_box_outline_blank), findsOneWidget);
        expect(find.byIcon(Icons.check_box), findsNothing);
      },
    );

    testWidgets(
      'Given an unbought item, '
      'when the tile is rendered, '
      'then the item text is displayed',
      (tester) async {
        await _pumpTile(tester, _item(text: 'Orange juice'));
        expect(find.text('Orange juice'), findsOneWidget);
      },
    );

    testWidgets(
      'Given an unbought item, '
      'when the tile is rendered, '
      'then the text has no strikethrough decoration',
      (tester) async {
        await _pumpTile(tester, _item(text: 'Bread'));
        final text = tester.widget<Text>(find.text('Bread'));
        expect(text.style?.decoration, isNot(TextDecoration.lineThrough),
            reason: 'Unbought items must not be struck-through');
      },
    );
  });

  // ── Situation 9: bought item visual state ──────────────────────────────────

  group('Situation 9 — bought item: visual representation', () {
    testWidgets(
      'Given a bought item, '
      'when the tile is rendered, '
      'then a filled checkbox icon is shown',
      (tester) async {
        await _pumpTile(tester, _item(isBought: true));
        expect(find.byIcon(Icons.check_box), findsOneWidget);
        expect(find.byIcon(Icons.check_box_outline_blank), findsNothing);
      },
    );

    testWidgets(
      'Given a bought item, '
      'when the tile is rendered, '
      'then the item text is displayed',
      (tester) async {
        await _pumpTile(tester, _item(text: 'Eggs', isBought: true));
        expect(find.text('Eggs'), findsOneWidget);
      },
    );

    testWidgets(
      'Given a bought item, '
      'when the tile is rendered, '
      'then the text has a lineThrough decoration',
      (tester) async {
        await _pumpTile(tester, _item(text: 'Butter', isBought: true));
        final text = tester.widget<Text>(find.text('Butter'));
        expect(text.style?.decoration, TextDecoration.lineThrough,
            reason: 'Bought items must appear struck-through');
      },
    );

    testWidgets(
      'Given a bought item, '
      'when the tile is rendered, '
      'then the text color is grayMid (greyed out)',
      (tester) async {
        await _pumpTile(tester, _item(text: 'Cheese', isBought: true));
        final text = tester.widget<Text>(find.text('Cheese'));
        expect(text.style?.color, AppTheme.grayMid,
            reason: 'Bought items should be visually de-emphasised');
      },
    );
  });

  // ── Situation 10: checkbox tap triggers callback ───────────────────────────

  group('Situation 10 — checkbox interaction: onToggleBought callback', () {
    testWidgets(
      'Given an unbought item, '
      'when the checkbox icon is tapped, '
      'then onToggleBought is called exactly once',
      (tester) async {
        var callCount = 0;
        await _pumpTile(
          tester,
          _item(),
          onToggleBought: () => callCount++,
        );

        await tester.tap(find.byIcon(Icons.check_box_outline_blank));
        await tester.pump();

        expect(callCount, 1);
      },
    );

    testWidgets(
      'Given a bought item, '
      'when the checkbox icon is tapped, '
      'then onToggleBought is called exactly once',
      (tester) async {
        var callCount = 0;
        await _pumpTile(
          tester,
          _item(isBought: true),
          onToggleBought: () => callCount++,
        );

        await tester.tap(find.byIcon(Icons.check_box));
        await tester.pump();

        expect(callCount, 1);
      },
    );

    testWidgets(
      'Given an item, '
      'when the checkbox is tapped three times, '
      'then onToggleBought fires three times',
      (tester) async {
        var callCount = 0;
        await _pumpTile(
          tester,
          _item(),
          onToggleBought: () => callCount++,
        );

        // Tap three times — each tap must reach the callback independently.
        for (var i = 0; i < 3; i++) {
          await tester.tap(find.byIcon(Icons.check_box_outline_blank));
          await tester.pump();
        }

        expect(callCount, 3);
      },
    );
  });

  // ── Situation 11: drag handle presence ────────────────────────────────────

  group('Situation 11 — drag handle: trailing widget visibility', () {
    testWidgets(
      'Given a drag handle widget is provided, '
      'when the tile is rendered, '
      'then the drag handle icon appears in the trailing slot',
      (tester) async {
        const handleKey = Key('drag-handle');
        await _pumpTile(
          tester,
          _item(),
          dragHandle: const Icon(Icons.drag_handle, key: handleKey),
        );
        expect(find.byKey(handleKey), findsOneWidget);
        expect(find.byIcon(Icons.drag_handle), findsOneWidget);
      },
    );

    testWidgets(
      'Given no drag handle is provided, '
      'when the tile is rendered, '
      'then no drag handle icon appears',
      (tester) async {
        await _pumpTile(tester, _item());
        expect(find.byIcon(Icons.drag_handle), findsNothing);
      },
    );
  });

  // ── Situation 12: item text content ───────────────────────────────────────

  group('Situation 12 — text content: item text is always rendered', () {
    testWidgets(
      'Given an item with a long text, '
      'when rendered, '
      'then the text widget shows the full item text',
      (tester) async {
        const longText = 'Extra virgin olive oil 500 ml cold pressed';
        await _pumpTile(tester, _item(text: longText));
        expect(find.text(longText), findsOneWidget);
      },
    );

    testWidgets(
      'Given an unbought item and a bought item rendered separately, '
      'when inspecting their text styles, '
      'then only the bought one has lineThrough and grayMid color',
      (tester) async {
        // Unbought
        await _pumpTile(tester, _item(text: 'Apples'));
        final unboughtText = tester.widget<Text>(find.text('Apples'));
        expect(unboughtText.style?.decoration, isNot(TextDecoration.lineThrough));
        expect(unboughtText.style?.color, isNot(AppTheme.grayMid));

        // Bought (new pump)
        await _pumpTile(tester, _item(text: 'Pears', isBought: true));
        final boughtText = tester.widget<Text>(find.text('Pears'));
        expect(boughtText.style?.decoration, TextDecoration.lineThrough);
        expect(boughtText.style?.color, AppTheme.grayMid);
      },
    );
  });
}
