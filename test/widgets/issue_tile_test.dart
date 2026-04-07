// BDD widget tests for IssueTile and the Issues-screen selection flow.
//
// Part 1 (Groups A–C): pure IssueTile widget tests — no state management, no
//   Firebase. Every scenario pumps a single IssueTile and asserts visual or
//   callback-routing behaviour.
//
// Part 2 (Groups D–G): selection-flow tests driven by _IssueListHarness — a
//   minimal StatefulWidget that replicates the selection-state machine from
//   _IssuesBodyState (enter/exit/toggle/select-all) and exposes the Send /
//   Resolved action-bar logic via ElevatedButton.onPressed being null or
//   non-null.  No Firebase calls are made.
//
// Naming convention: "Given <precondition>, when <action>, then <outcome>"

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flatorg/constants/app_theme.dart';
import 'package:flatorg/constants/strings.dart';
import 'package:flatorg/models/issue.dart';
import 'package:flatorg/widgets/issue_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// Fixtures
// ═══════════════════════════════════════════════════════════════════════════════

final _kCreatedAt = Timestamp.fromDate(DateTime(2025, 1, 1));

/// Not-on-cooldown: never sent.
Issue _sendableIssue({
  String id = 'issue-1',
  String title = 'Broken heater',
  String description = 'The heater in room 2 makes a loud noise.',
}) =>
    Issue(
      id: id,
      title: title,
      description: description,
      createdBy: 'alice-uid',
      createdAt: _kCreatedAt,
      lastSentAt: null,
    );

/// On-cooldown: sent 2 days ago (< 5-day threshold).
Issue _cooldownIssue({
  String id = 'issue-cool',
  String title = 'Leaky faucet',
  String description = 'The kitchen faucet drips constantly.',
}) =>
    Issue(
      id: id,
      title: title,
      description: description,
      createdBy: 'bob-uid',
      createdAt: _kCreatedAt,
      lastSentAt: Timestamp.fromDate(
        DateTime.now().subtract(const Duration(days: 2)),
      ),
    );

// ═══════════════════════════════════════════════════════════════════════════════
// Part 1 harness — single IssueTile
// ═══════════════════════════════════════════════════════════════════════════════

Future<void> _pumpTile(
  WidgetTester tester, {
  required Issue issue,
  bool isSelectionMode = false,
  bool isSelected = false,
  VoidCallback? onTap,
  VoidCallback? onLongPress,
  VoidCallback? onToggleSelect,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: IssueTile(
          issue: issue,
          isSelectionMode: isSelectionMode,
          isSelected: isSelected,
          onTap: onTap ?? () {},
          onLongPress: onLongPress ?? () {},
          onToggleSelect: onToggleSelect ?? () {},
        ),
      ),
    ),
  );
  await tester.pump();
}

// ═══════════════════════════════════════════════════════════════════════════════
// Part 2 harness — selection-flow harness (replicates _IssuesBodyState logic)
// ═══════════════════════════════════════════════════════════════════════════════

class _IssueListHarness extends StatefulWidget {
  final List<Issue> issues;

  /// When true the "current user is assigned to the Shopping task" rule is met,
  /// so canSend is driven purely by whether sendable issues are selected.
  final bool isShoppingAssignee;

  const _IssueListHarness({
    required this.issues,
    this.isShoppingAssignee = false,
  });

  @override
  State<_IssueListHarness> createState() => _IssueListHarnessState();
}

class _IssueListHarnessState extends State<_IssueListHarness> {
  var _selectionMode = false;
  final Set<String> _selectedIds = {};

  // Mirrors _IssuesBodyState._enterSelection
  void _enterSelection(String firstId) {
    setState(() {
      _selectionMode = true;
      _selectedIds.add(firstId);
    });
  }

  // Mirrors _IssuesBodyState._exitSelection
  void _exitSelection() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  // Mirrors _IssuesBodyState._toggleSelect
  void _toggleSelect(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _selectionMode = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final sendable =
        widget.issues.where((i) => !i.isOnCooldown).toList();
    final selectedSendable =
        sendable.where((i) => _selectedIds.contains(i.id)).toList();
    final selectedAll =
        widget.issues.where((i) => _selectedIds.contains(i.id)).toList();

    final canSend = widget.isShoppingAssignee && selectedSendable.isNotEmpty;
    final canResolve = selectedAll.isNotEmpty;

    return Scaffold(
      body: Column(
        children: [
          // Selection bar (visible only in selection mode)
          if (_selectionMode)
            Row(
              children: [
                TextButton(
                  key: const Key('go-back'),
                  onPressed: _exitSelection,
                  child: const Text(buttonGoBack),
                ),
                TextButton(
                  key: const Key('select-all'),
                  onPressed: () => setState(
                    () => _selectedIds.addAll(
                      widget.issues.map((i) => i.id),
                    ),
                  ),
                  child: const Text(buttonSelectAll),
                ),
              ],
            ),

          // Issue tiles
          Expanded(
            child: ListView(
              children: widget.issues
                  .map(
                    (issue) => IssueTile(
                      key: Key('tile-${issue.id}'),
                      issue: issue,
                      isSelectionMode: _selectionMode,
                      isSelected: _selectedIds.contains(issue.id),
                      onTap: () {},
                      onLongPress: () => _enterSelection(issue.id),
                      onToggleSelect: () => _toggleSelect(issue.id),
                    ),
                  )
                  .toList(),
            ),
          ),

          // Action bar (visible only in selection mode)
          if (_selectionMode)
            Row(
              children: [
                ElevatedButton(
                  key: const Key('send-btn'),
                  onPressed: canSend ? () {} : null,
                  child: const Text(buttonSend),
                ),
                ElevatedButton(
                  key: const Key('resolve-btn'),
                  onPressed: canResolve ? () {} : null,
                  child: const Text(buttonResolved),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

Future<void> _pumpHarness(
  WidgetTester tester, {
  required List<Issue> issues,
  bool isShoppingAssignee = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: _IssueListHarness(
        issues: issues,
        isShoppingAssignee: isShoppingAssignee,
      ),
    ),
  );
  await tester.pump();
}

/// Returns true when the button identified by [key] has a non-null onPressed
/// (i.e. the button is enabled).
bool _buttonEnabled(WidgetTester tester, Key key) {
  final btn = tester.widget<ElevatedButton>(find.byKey(key));
  return btn.onPressed != null;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Tests
// ═══════════════════════════════════════════════════════════════════════════════

void main() {
  setUpAll(() {
    // Prevent google_fonts from hitting the network during tests.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  // ─── Group A: IssueTile — normal mode rendering ────────────────────────────

  group('Group A — IssueTile normal mode: visual state', () {
    testWidgets(
      'Given a sendable issue in normal mode, '
      'when the tile is rendered, '
      'then the issue title is visible',
      (tester) async {
        await _pumpTile(tester, issue: _sendableIssue(title: 'Broken heater'));
        expect(find.text('Broken heater'), findsOneWidget);
      },
    );

    testWidgets(
      'Given a sendable issue in normal mode, '
      'when the tile is rendered, '
      'then the issue description is visible',
      (tester) async {
        await _pumpTile(
          tester,
          issue: _sendableIssue(description: 'Heater makes noise.'),
        );
        expect(find.text('Heater makes noise.'), findsOneWidget);
      },
    );

    testWidgets(
      'Given any issue in normal mode (isSelectionMode=false), '
      'when the tile is rendered, '
      'then no checkbox icon is shown',
      (tester) async {
        await _pumpTile(tester, issue: _sendableIssue());
        expect(find.byIcon(Icons.check_box_outline_blank), findsNothing);
        expect(find.byIcon(Icons.check_box), findsNothing);
      },
    );

    testWidgets(
      'Given a sendable (not-on-cooldown) issue in normal mode, '
      'when the tile is rendered, '
      'then the title color is null (inherits theme, not greyed out)',
      (tester) async {
        await _pumpTile(tester, issue: _sendableIssue(title: 'Active Issue'));
        final titleText = tester.widget<Text>(find.text('Active Issue'));
        // copyWith(color: null) means the theme default is used — not grayMid.
        expect(
          titleText.style?.color,
          isNot(AppTheme.grayMid),
          reason: 'Sendable issue title must not be greyed out.',
        );
      },
    );

    testWidgets(
      'Given an on-cooldown issue in normal mode, '
      'when the tile is rendered, '
      'then the title color is grayMid (greyed out to signal cooldown)',
      (tester) async {
        await _pumpTile(tester, issue: _cooldownIssue(title: 'Old Issue'));
        final titleText = tester.widget<Text>(find.text('Old Issue'));
        expect(
          titleText.style?.color,
          AppTheme.grayMid,
          reason: 'Cooldown issue title must be greyed out.',
        );
      },
    );

    testWidgets(
      'Given an issue in normal mode, '
      'when the tile is rendered, '
      'then the card has the default (non-selection) background color',
      (tester) async {
        await _pumpTile(tester, issue: _sendableIssue());
        final card = tester.widget<Card>(find.byType(Card).first);
        // Selection color in light mode is AppTheme.highlightColorDark.
        expect(
          card.color,
          isNot(AppTheme.highlightColorDark),
          reason: 'Unselected tile must not use the selection highlight color.',
        );
      },
    );
  });

  // ─── Group B: IssueTile — selection mode, unselected ──────────────────────

  group('Group B — IssueTile selection mode, unselected tile', () {
    testWidgets(
      'Given isSelectionMode=true and isSelected=false, '
      'when the tile is rendered, '
      'then an outline checkbox icon is shown',
      (tester) async {
        await _pumpTile(
          tester,
          issue: _sendableIssue(),
          isSelectionMode: true,
          isSelected: false,
        );
        expect(find.byIcon(Icons.check_box_outline_blank), findsOneWidget);
        expect(find.byIcon(Icons.check_box), findsNothing);
      },
    );

    testWidgets(
      'Given isSelectionMode=true, '
      'when the tile is tapped, '
      'then onToggleSelect fires (not onTap)',
      (tester) async {
        var tapCount = 0;
        var toggleCount = 0;

        await _pumpTile(
          tester,
          issue: _sendableIssue(),
          isSelectionMode: true,
          onTap: () => tapCount++,
          onToggleSelect: () => toggleCount++,
        );

        await tester.tap(find.byType(IssueTile));
        await tester.pump();

        expect(tapCount, 0, reason: 'onTap must not fire in selection mode.');
        expect(toggleCount, 1, reason: 'onToggleSelect must fire in selection mode.');
      },
    );

    testWidgets(
      'Given isSelectionMode=true, '
      'when the tile is long-pressed, '
      'then onLongPress fires',
      (tester) async {
        var longPressCount = 0;

        await _pumpTile(
          tester,
          issue: _sendableIssue(),
          isSelectionMode: true,
          onLongPress: () => longPressCount++,
        );

        await tester.longPress(find.byType(IssueTile));
        await tester.pump();

        expect(longPressCount, 1);
      },
    );
  });

  // ─── Group C: IssueTile — selection mode, selected ────────────────────────

  group('Group C — IssueTile selection mode, selected tile', () {
    testWidgets(
      'Given isSelectionMode=true and isSelected=true, '
      'when the tile is rendered, '
      'then a filled checkbox icon is shown',
      (tester) async {
        await _pumpTile(
          tester,
          issue: _sendableIssue(),
          isSelectionMode: true,
          isSelected: true,
        );
        expect(find.byIcon(Icons.check_box), findsOneWidget);
        expect(find.byIcon(Icons.check_box_outline_blank), findsNothing);
      },
    );

    testWidgets(
      'Given a selected sendable issue in selection mode (light theme), '
      'when the tile is rendered, '
      'then the card uses the highlight selection color',
      (tester) async {
        await _pumpTile(
          tester,
          issue: _sendableIssue(),
          isSelectionMode: true,
          isSelected: true,
        );
        final card = tester.widget<Card>(find.byType(Card).first);
        // In light mode isSelected → AppTheme.highlightColorDark.
        expect(card.color, AppTheme.highlightColorDark);
      },
    );

    testWidgets(
      'Given a selected sendable (not-on-cooldown) issue in selection mode, '
      'when the tile is rendered, '
      'then the title color is grayDark (high contrast against selection bg)',
      (tester) async {
        await _pumpTile(
          tester,
          issue: _sendableIssue(title: 'Selected Title'),
          isSelectionMode: true,
          isSelected: true,
        );
        final titleText = tester.widget<Text>(find.text('Selected Title'));
        expect(
          titleText.style?.color,
          AppTheme.grayDark,
          reason: 'Selected non-cooldown tile must use grayDark for contrast.',
        );
      },
    );

    testWidgets(
      'Given a selected on-cooldown issue in selection mode, '
      'when the tile is rendered, '
      'then the title color is grayMid (greyed out even when selected)',
      (tester) async {
        await _pumpTile(
          tester,
          issue: _cooldownIssue(title: 'Cool Title'),
          isSelectionMode: true,
          isSelected: true,
        );
        final titleText = tester.widget<Text>(find.text('Cool Title'));
        expect(
          titleText.style?.color,
          AppTheme.grayMid,
          reason: 'Selected cooldown tile title must remain greyed out.',
        );
      },
    );

    testWidgets(
      'Given isSelectionMode=true and isSelected=true, '
      'when the tile is tapped, '
      'then onToggleSelect fires (deselect path)',
      (tester) async {
        var toggleCount = 0;

        await _pumpTile(
          tester,
          issue: _sendableIssue(),
          isSelectionMode: true,
          isSelected: true,
          onToggleSelect: () => toggleCount++,
        );

        await tester.tap(find.byType(IssueTile));
        await tester.pump();

        expect(toggleCount, 1);
      },
    );
  });

  // ─── Group D: Selection flow ───────────────────────────────────────────────

  group('Group D — selection flow via _IssueListHarness', () {
    testWidgets(
      'Given normal mode with two issues, '
      'when one issue tile is long-pressed, '
      'then selection mode is entered',
      (tester) async {
        await _pumpHarness(
          tester,
          issues: [_sendableIssue(id: 'a'), _sendableIssue(id: 'b')],
        );

        await tester.longPress(find.byKey(const Key('tile-a')));
        await tester.pump();

        // Selection bar contains the Go Back button.
        expect(find.byKey(const Key('go-back')), findsOneWidget);
      },
    );

    testWidgets(
      'Given normal mode, '
      'when issue-a is long-pressed, '
      'then issue-a is pre-selected (filled checkbox) '
      'and issue-b has an outline checkbox',
      (tester) async {
        await _pumpHarness(
          tester,
          issues: [_sendableIssue(id: 'a'), _sendableIssue(id: 'b')],
        );

        await tester.longPress(find.byKey(const Key('tile-a')));
        await tester.pump();

        // Pre-selected tile shows filled checkbox; other shows outline.
        expect(find.byIcon(Icons.check_box), findsOneWidget);
        expect(find.byIcon(Icons.check_box_outline_blank), findsOneWidget);
      },
    );

    testWidgets(
      'Given selection mode with issue-a selected, '
      'when issue-a tile is tapped, '
      'then issue-a is deselected and selection mode exits automatically',
      (tester) async {
        await _pumpHarness(
          tester,
          issues: [_sendableIssue(id: 'a')],
        );

        // Enter selection mode.
        await tester.longPress(find.byKey(const Key('tile-a')));
        await tester.pump();

        // Deselect the only selected issue.
        await tester.tap(find.byKey(const Key('tile-a')));
        await tester.pump();

        // No selection bar means we're back in normal mode.
        expect(find.byKey(const Key('go-back')), findsNothing);
        // No checkboxes shown in normal mode.
        expect(find.byIcon(Icons.check_box), findsNothing);
        expect(find.byIcon(Icons.check_box_outline_blank), findsNothing);
      },
    );

    testWidgets(
      'Given selection mode with two issues selected, '
      'when one is deselected, '
      'then selection mode is still active (one remains)',
      (tester) async {
        await _pumpHarness(
          tester,
          issues: [
            _sendableIssue(id: 'a'),
            _sendableIssue(id: 'b'),
          ],
        );

        // Enter selection via long-press on issue-a (pre-selects a).
        await tester.longPress(find.byKey(const Key('tile-a')));
        await tester.pump();

        // Select issue-b as well.
        await tester.tap(find.byKey(const Key('tile-b')));
        await tester.pump();

        // Deselect issue-a — one issue still selected.
        await tester.tap(find.byKey(const Key('tile-a')));
        await tester.pump();

        // Selection bar must still be visible.
        expect(find.byKey(const Key('go-back')), findsOneWidget);
      },
    );

    testWidgets(
      'Given selection mode, '
      'when the Go Back button is tapped, '
      'then selection mode exits and all selections are cleared',
      (tester) async {
        await _pumpHarness(
          tester,
          issues: [
            _sendableIssue(id: 'a'),
            _sendableIssue(id: 'b'),
          ],
        );

        // Enter selection and select both issues.
        await tester.longPress(find.byKey(const Key('tile-a')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('tile-b')));
        await tester.pump();

        // Exit via Go Back.
        await tester.tap(find.byKey(const Key('go-back')));
        await tester.pump();

        // No selection bar, no checkboxes.
        expect(find.byKey(const Key('go-back')), findsNothing);
        expect(find.byIcon(Icons.check_box), findsNothing);
        expect(find.byIcon(Icons.check_box_outline_blank), findsNothing);
      },
    );

    testWidgets(
      'Given selection mode with no issues selected yet (edge case), '
      'when Select All is tapped with two issues in the list, '
      'then both issues become selected',
      (tester) async {
        await _pumpHarness(
          tester,
          issues: [
            _sendableIssue(id: 'a'),
            _sendableIssue(id: 'b'),
          ],
        );

        // Enter selection mode via long-press on issue-a.
        await tester.longPress(find.byKey(const Key('tile-a')));
        await tester.pump();

        // Deselect issue-a so nothing is selected.
        await tester.tap(find.byKey(const Key('tile-a')));
        await tester.pump();

        // Selection mode exits when last is deselected.
        // Enter selection mode again via issue-b.
        await tester.longPress(find.byKey(const Key('tile-b')));
        await tester.pump();

        // Now press Select All.
        await tester.tap(find.byKey(const Key('select-all')));
        await tester.pump();

        // Both tiles must show a filled checkbox.
        expect(find.byIcon(Icons.check_box), findsNWidgets(2));
      },
    );

    testWidgets(
      'Given selection mode with all issues selected via Select All, '
      'when Go Back is tapped, '
      'then selection is fully cleared and mode exits',
      (tester) async {
        await _pumpHarness(
          tester,
          issues: [
            _sendableIssue(id: 'a'),
            _sendableIssue(id: 'b'),
            _sendableIssue(id: 'c'),
          ],
        );

        await tester.longPress(find.byKey(const Key('tile-a')));
        await tester.pump();

        await tester.tap(find.byKey(const Key('select-all')));
        await tester.pump();

        await tester.tap(find.byKey(const Key('go-back')));
        await tester.pump();

        expect(find.byKey(const Key('go-back')), findsNothing);
        expect(find.byIcon(Icons.check_box), findsNothing);
      },
    );

    testWidgets(
      'Given selection mode with all three issues selected via Select All, '
      'when each is deselected one by one, '
      'then selection mode exits only after the last deselection',
      (tester) async {
        await _pumpHarness(
          tester,
          issues: [
            _sendableIssue(id: 'a'),
            _sendableIssue(id: 'b'),
            _sendableIssue(id: 'c'),
          ],
        );

        await tester.longPress(find.byKey(const Key('tile-a')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('select-all')));
        await tester.pump();

        // Deselect a — still two selected, still in selection mode.
        await tester.tap(find.byKey(const Key('tile-a')));
        await tester.pump();
        expect(find.byKey(const Key('go-back')), findsOneWidget);

        // Deselect b — one left.
        await tester.tap(find.byKey(const Key('tile-b')));
        await tester.pump();
        expect(find.byKey(const Key('go-back')), findsOneWidget);

        // Deselect c — none left, must exit.
        await tester.tap(find.byKey(const Key('tile-c')));
        await tester.pump();
        expect(find.byKey(const Key('go-back')), findsNothing);
      },
    );

    testWidgets(
      'Given normal mode, '
      'when an issue is long-pressed a second time (already in selection mode), '
      'then onLongPress fires again and the issue remains selected',
      (tester) async {
        await _pumpHarness(
          tester,
          issues: [_sendableIssue(id: 'a'), _sendableIssue(id: 'b')],
        );

        await tester.longPress(find.byKey(const Key('tile-a')));
        await tester.pump();

        // Long-pressing another issue in selection mode still fires onLongPress.
        await tester.longPress(find.byKey(const Key('tile-b')));
        await tester.pump();

        // Both checkboxes must be present (b was just added, a was pre-selected).
        expect(find.byIcon(Icons.check_box), findsNWidgets(2));
      },
    );
  });

  // ─── Group E: Send button rules ───────────────────────────────────────────

  group('Group E — Send button: enabled/disabled rules', () {
    testWidgets(
      'Given the user is NOT the Shopping assignee, '
      'when any sendable issue is selected, '
      'then the Send button is disabled',
      (tester) async {
        await _pumpHarness(
          tester,
          issues: [_sendableIssue(id: 'a')],
          isShoppingAssignee: false, // not allowed to send
        );

        await tester.longPress(find.byKey(const Key('tile-a')));
        await tester.pump();

        expect(
          _buttonEnabled(tester, const Key('send-btn')),
          isFalse,
          reason: 'Only the Shopping assignee may send issues to Livit.',
        );
      },
    );

    testWidgets(
      'Given the user IS the Shopping assignee '
      'but no sendable issue is selected, '
      'then the Send button is disabled',
      (tester) async {
        // Only a cooldown issue in the list — it cannot be sent.
        await _pumpHarness(
          tester,
          issues: [_cooldownIssue(id: 'cool')],
          isShoppingAssignee: true,
        );

        await tester.longPress(find.byKey(const Key('tile-cool')));
        await tester.pump();

        expect(
          _buttonEnabled(tester, const Key('send-btn')),
          isFalse,
          reason: 'Cooldown issues must not satisfy the "at least one sendable" requirement.',
        );
      },
    );

    testWidgets(
      'Given the user IS the Shopping assignee '
      'AND a sendable issue is selected, '
      'then the Send button is enabled',
      (tester) async {
        await _pumpHarness(
          tester,
          issues: [_sendableIssue(id: 'a')],
          isShoppingAssignee: true,
        );

        await tester.longPress(find.byKey(const Key('tile-a')));
        await tester.pump();

        expect(
          _buttonEnabled(tester, const Key('send-btn')),
          isTrue,
        );
      },
    );

    testWidgets(
      'Given the Shopping assignee is in selection mode '
      'with a cooldown issue selected AND a sendable issue selected, '
      'then the Send button is enabled (sendable count > 0)',
      (tester) async {
        await _pumpHarness(
          tester,
          issues: [
            _sendableIssue(id: 'a'),
            _cooldownIssue(id: 'cool'),
          ],
          isShoppingAssignee: true,
        );

        await tester.longPress(find.byKey(const Key('tile-a')));
        await tester.pump();

        // Also select the cooldown issue.
        await tester.tap(find.byKey(const Key('tile-cool')));
        await tester.pump();

        expect(
          _buttonEnabled(tester, const Key('send-btn')),
          isTrue,
          reason: 'Having at least one sendable selected enables Send.',
        );
      },
    );

    testWidgets(
      'Given the Shopping assignee with a sendable issue selected, '
      'when the sendable issue is deselected, '
      'then the Send button becomes disabled',
      (tester) async {
        await _pumpHarness(
          tester,
          issues: [
            _sendableIssue(id: 'a'),
            _cooldownIssue(id: 'cool'),
          ],
          isShoppingAssignee: true,
        );

        // Select both.
        await tester.longPress(find.byKey(const Key('tile-a')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('tile-cool')));
        await tester.pump();

        // Deselect the sendable one.
        await tester.tap(find.byKey(const Key('tile-a')));
        await tester.pump();

        expect(
          _buttonEnabled(tester, const Key('send-btn')),
          isFalse,
          reason: 'Only a cooldown issue remains selected — Send must be disabled.',
        );
      },
    );
  });

  // ─── Group F: Resolved button rules ───────────────────────────────────────

  group('Group F — Resolved button: enabled/disabled rules', () {
    testWidgets(
      'Given selection mode with nothing selected, '
      'when the action bar is rendered, '
      'then the Resolved button is disabled',
      (tester) async {
        // Enter selection mode by long-pressing then immediately deselecting.
        // Because deselecting the last exits selection mode we need two issues.
        await _pumpHarness(
          tester,
          issues: [
            _sendableIssue(id: 'a'),
            _sendableIssue(id: 'b'),
          ],
        );

        await tester.longPress(find.byKey(const Key('tile-a')));
        await tester.pump();

        // Select b so we stay in selection mode, then deselect a.
        await tester.tap(find.byKey(const Key('tile-b')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('tile-a')));
        await tester.pump();

        // Only b is selected — Resolved must be enabled (not this test's concern).
        // Now deselect b too.
        await tester.tap(find.byKey(const Key('tile-b')));
        await tester.pump();

        // Nothing selected — selection mode should have exited; no resolve btn.
        expect(find.byKey(const Key('resolve-btn')), findsNothing);
      },
    );

    testWidgets(
      'Given selection mode with a sendable issue selected, '
      'when the action bar is rendered, '
      'then the Resolved button is enabled',
      (tester) async {
        await _pumpHarness(
          tester,
          issues: [_sendableIssue(id: 'a')],
        );

        await tester.longPress(find.byKey(const Key('tile-a')));
        await tester.pump();

        expect(_buttonEnabled(tester, const Key('resolve-btn')), isTrue);
      },
    );

    testWidgets(
      'Given selection mode with a cooldown issue selected, '
      'when the action bar is rendered, '
      'then the Resolved button is enabled '
      '(resolved works on any issue regardless of cooldown)',
      (tester) async {
        await _pumpHarness(
          tester,
          issues: [_cooldownIssue(id: 'cool')],
        );

        await tester.longPress(find.byKey(const Key('tile-cool')));
        await tester.pump();

        expect(
          _buttonEnabled(tester, const Key('resolve-btn')),
          isTrue,
          reason: 'Resolved must be enabled for cooldown issues too.',
        );
      },
    );

    testWidgets(
      'Given a mix of cooldown and sendable issues all selected, '
      'when the action bar is rendered, '
      'then both Resolved is enabled and Send is disabled (non-Shopping user)',
      (tester) async {
        await _pumpHarness(
          tester,
          issues: [
            _sendableIssue(id: 'a'),
            _cooldownIssue(id: 'cool'),
          ],
          isShoppingAssignee: false,
        );

        await tester.longPress(find.byKey(const Key('tile-a')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('tile-cool')));
        await tester.pump();

        expect(_buttonEnabled(tester, const Key('resolve-btn')), isTrue);
        expect(_buttonEnabled(tester, const Key('send-btn')), isFalse);
      },
    );
  });

  // ─── Group G: Weird / interleaved scenarios ────────────────────────────────

  group('Group G — interleaved and edge-case scenarios', () {
    testWidgets(
      'Weird interleave: long-press issue-a → Select All → Go Back '
      'then long-press issue-b — starts fresh in selection mode with only b selected',
      (tester) async {
        await _pumpHarness(
          tester,
          issues: [
            _sendableIssue(id: 'a'),
            _sendableIssue(id: 'b'),
          ],
        );

        await tester.longPress(find.byKey(const Key('tile-a')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('select-all')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('go-back')));
        await tester.pump();

        // Now long-press b to start a new selection session.
        await tester.longPress(find.byKey(const Key('tile-b')));
        await tester.pump();

        // Exactly one filled checkbox (b) and one outline (a).
        expect(find.byIcon(Icons.check_box), findsOneWidget);
        expect(find.byIcon(Icons.check_box_outline_blank), findsOneWidget);
      },
    );

    testWidgets(
      'Weird interleave: long-press → Select All → deselect one → '
      'still in selection mode with remaining selected',
      (tester) async {
        await _pumpHarness(
          tester,
          issues: [
            _sendableIssue(id: 'a'),
            _sendableIssue(id: 'b'),
            _sendableIssue(id: 'c'),
          ],
        );

        await tester.longPress(find.byKey(const Key('tile-a')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('select-all')));
        await tester.pump();

        // Deselect c — two remain.
        await tester.tap(find.byKey(const Key('tile-c')));
        await tester.pump();

        // Still in selection mode.
        expect(find.byKey(const Key('go-back')), findsOneWidget);
        // Two filled, one outline.
        expect(find.byIcon(Icons.check_box), findsNWidgets(2));
        expect(find.byIcon(Icons.check_box_outline_blank), findsOneWidget);
      },
    );

    testWidgets(
      'Weird interleave: Shopping assignee selects sendable issue — '
      'Send is enabled; user deselects the sendable but cooldown remains selected '
      '— Send must flip to disabled while Resolved stays enabled',
      (tester) async {
        await _pumpHarness(
          tester,
          issues: [
            _sendableIssue(id: 'a'),
            _cooldownIssue(id: 'cool'),
          ],
          isShoppingAssignee: true,
        );

        // Select a (sendable).
        await tester.longPress(find.byKey(const Key('tile-a')));
        await tester.pump();

        expect(_buttonEnabled(tester, const Key('send-btn')), isTrue);
        expect(_buttonEnabled(tester, const Key('resolve-btn')), isTrue);

        // Also select the cooldown issue.
        await tester.tap(find.byKey(const Key('tile-cool')));
        await tester.pump();

        expect(_buttonEnabled(tester, const Key('send-btn')), isTrue);

        // Deselect the sendable (a) — only cooldown left.
        await tester.tap(find.byKey(const Key('tile-a')));
        await tester.pump();

        expect(
          _buttonEnabled(tester, const Key('send-btn')),
          isFalse,
          reason: 'No sendable selected → Send must be disabled.',
        );
        expect(
          _buttonEnabled(tester, const Key('resolve-btn')),
          isTrue,
          reason: 'Cooldown issue still selected → Resolved stays enabled.',
        );
      },
    );

    testWidgets(
      'Weird interleave: non-Shopping user selects all (mix) — '
      'Send is always disabled; Resolved is enabled',
      (tester) async {
        await _pumpHarness(
          tester,
          issues: [
            _sendableIssue(id: 'a'),
            _sendableIssue(id: 'b'),
            _cooldownIssue(id: 'cool'),
          ],
          isShoppingAssignee: false,
        );

        await tester.longPress(find.byKey(const Key('tile-a')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('select-all')));
        await tester.pump();

        expect(_buttonEnabled(tester, const Key('send-btn')), isFalse);
        expect(_buttonEnabled(tester, const Key('resolve-btn')), isTrue);
      },
    );

    testWidgets(
      'Weird interleave: long-press a cooldown issue first (non-Shopping user) — '
      'Send disabled, Resolved enabled, cooldown checkbox filled',
      (tester) async {
        await _pumpHarness(
          tester,
          issues: [
            _cooldownIssue(id: 'cool'),
            _sendableIssue(id: 'a'),
          ],
          isShoppingAssignee: false,
        );

        await tester.longPress(find.byKey(const Key('tile-cool')));
        await tester.pump();

        expect(find.byIcon(Icons.check_box), findsOneWidget);
        expect(_buttonEnabled(tester, const Key('send-btn')), isFalse);
        expect(_buttonEnabled(tester, const Key('resolve-btn')), isTrue);
      },
    );

    testWidgets(
      'Weird interleave: two rapid long-presses on different issues '
      'both end up selected',
      (tester) async {
        await _pumpHarness(
          tester,
          issues: [
            _sendableIssue(id: 'a'),
            _sendableIssue(id: 'b'),
          ],
        );

        await tester.longPress(find.byKey(const Key('tile-a')));
        await tester.pump();

        // Second long-press in selection mode adds b via onLongPress.
        await tester.longPress(find.byKey(const Key('tile-b')));
        await tester.pump();

        // Both should show filled checkboxes.
        expect(find.byIcon(Icons.check_box), findsNWidgets(2));
      },
    );

    testWidgets(
      'Weird interleave: tap a non-selected issue in selection mode '
      'selects it (toggle → selected), '
      'then tapping again deselects it',
      (tester) async {
        await _pumpHarness(
          tester,
          issues: [
            _sendableIssue(id: 'a'),
            _sendableIssue(id: 'b'),
          ],
        );

        // Enter selection with a.
        await tester.longPress(find.byKey(const Key('tile-a')));
        await tester.pump();

        // Tap b → selects it.
        await tester.tap(find.byKey(const Key('tile-b')));
        await tester.pump();
        expect(find.byIcon(Icons.check_box), findsNWidgets(2));

        // Tap b again → deselects it; a remains selected.
        await tester.tap(find.byKey(const Key('tile-b')));
        await tester.pump();
        expect(find.byIcon(Icons.check_box), findsOneWidget);
        expect(find.byIcon(Icons.check_box_outline_blank), findsOneWidget);
      },
    );

    testWidgets(
      'Given a single issue list and Shopping assignee, '
      'when in normal mode (no selection), '
      'then no action bar buttons are visible',
      (tester) async {
        await _pumpHarness(
          tester,
          issues: [_sendableIssue(id: 'a')],
          isShoppingAssignee: true,
        );

        expect(find.byKey(const Key('send-btn')), findsNothing);
        expect(find.byKey(const Key('resolve-btn')), findsNothing);
        expect(find.byKey(const Key('go-back')), findsNothing);
      },
    );
  });
}
