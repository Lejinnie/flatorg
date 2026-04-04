// BDD widget tests for TaskCard swap-token behaviour.
//
// These tests document the bug where immediate swaps (vacant slot or vacation
// assignee) did not deduct a token because onRequestSwap was a VoidCallback
// that gave no information to the caller about whether the swap was immediate.
//
// After the fix, onRequestSwap carries {required bool isImmediate} so the
// tasks screen can auto-accept and deduct the token for immediate swaps.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flatorg/constants/app_theme.dart';
import 'package:flatorg/constants/strings.dart';
import 'package:flatorg/constants/task_constants.dart';
import 'package:flatorg/models/person.dart';
import 'package:flatorg/models/task.dart';
import 'package:flatorg/widgets/task_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ── Fixtures ──────────────────────────────────────────────────────────────────

final _kFutureDue = Timestamp.fromDate(DateTime(2099, 12, 31, 12));

const _kAliceUid  = 'alice-uid';
const _kBobUid    = 'bob-uid';

Task _task({
  String    assignedTo = '',
  TaskState state      = TaskState.pending,
}) =>
    Task(
      id:                 't1',
      name:               'Toilet',
      description:        const [],
      dueDateTime:        _kFutureDue,
      assignedTo:         assignedTo,
      originalAssignedTo: '',
      state:              state,
      weeksNotCleaned:    0,
      ringIndex:          0,
    );

Person _person({
  String uid              = _kAliceUid,
  int    swapTokens       = swapTokensPerSemester,
  bool   onVacation       = false,
}) =>
    Person(
      uid:                 uid,
      name:                'Alice',
      email:               'alice@flat.test',
      role:                PersonRole.member,
      onVacation:          onVacation,
      swapTokensRemaining: swapTokens,
    );

// ── Harness ───────────────────────────────────────────────────────────────────

/// Pumps a TaskCard for a non-assignee user so the swap button is visible.
/// Captures the isImmediate value passed to onRequestSwap.
Future<bool?> _pumpAndSwap(
  WidgetTester tester, {
  required Task   task,
  required Person currentPerson,
  Person?         assigneePerson,
}) async {
  bool? capturedImmediate;

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: TaskCard(
          task:                  task,
          assigneeName:          'Bob',
          isCurrentUserAssignee: false,
          currentPerson:         currentPerson,
          assigneePerson:        assigneePerson,
          onComplete:            () async {},
          onVacation:            () async {},
          onRequestSwap:         ({required isImmediate}) async {
            capturedImmediate = isImmediate;
          },
        ),
      ),
    ),
  );
  await tester.pump();

  // Tap whichever swap button is visible — vacant tasks show "Swap",
  // others show "Request Swap".
  final buttonLabels = [buttonSwap, buttonRequestSwap];
  Finder? tappable;
  for (final label in buttonLabels) {
    final f = find.widgetWithText(OutlinedButton, label);
    if (f.evaluate().isNotEmpty) {
      tappable = f.first;
      break;
    }
  }
  if (tappable == null) {
    return capturedImmediate;
  }

  await tester.tap(tappable);
  await tester.pumpAndSettle();

  // Confirm in the dialog — label is "Swap" for vacant, "Request" otherwise.
  for (final label in [buttonSwap, confirmSwapLabel]) {
    final f = find.text(label);
    if (f.evaluate().length > 1) {
      // The last match is the dialog confirm button (first is the card button).
      await tester.tap(f.last);
      await tester.pumpAndSettle();
      break;
    } else if (f.evaluate().length == 1) {
      await tester.tap(f.first);
      await tester.pumpAndSettle();
      break;
    }
  }

  return capturedImmediate;
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('TaskCard swap token — regression for unlimited swaps bug', () {
    // ── isImmediate flag ────────────────────────────────────────────────────

    testWidgets(
      'Given a vacant task (no assignee), '
      'when the user confirms swap, '
      'then onRequestSwap is called with isImmediate: true',
      (tester) async {
        final isImmediate = await _pumpAndSwap(
          tester,
          task:          _task(),
          currentPerson: _person(),
        );

        expect(
          isImmediate,
          isTrue,
          reason: 'Vacant slots need no approval — isImmediate must be true '
              'so the caller auto-accepts and deducts the token.',
        );
      },
    );

    testWidgets(
      'Given a task whose assignee is on vacation, '
      'when the user confirms swap, '
      'then onRequestSwap is called with isImmediate: true',
      (tester) async {
        final assignee = _person(uid: _kBobUid, onVacation: true);
        final isImmediate = await _pumpAndSwap(
          tester,
          task:           _task(assignedTo: _kBobUid),
          currentPerson:  _person(),
          assigneePerson: assignee,
        );

        expect(
          isImmediate,
          isTrue,
          reason: 'Vacation assignees need no approval per spec — '
              'isImmediate must be true so the token is deducted.',
        );
      },
    );

    testWidgets(
      'Given a task assigned to a non-vacation user, '
      'when the user confirms swap, '
      'then onRequestSwap is called with isImmediate: false',
      (tester) async {
        final assignee = _person(uid: _kBobUid);
        final isImmediate = await _pumpAndSwap(
          tester,
          task:           _task(assignedTo: _kBobUid),
          currentPerson:  _person(),
          assigneePerson: assignee,
        );

        expect(
          isImmediate,
          isFalse,
          reason: 'Active assignees must accept before the swap is effective.',
        );
      },
    );

    // ── Zero-token guard ────────────────────────────────────────────────────

    testWidgets(
      'Given a user with 0 swap tokens remaining, '
      'when a vacant task card is rendered, '
      'then the swap button is disabled',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: TaskCard(
                task:                  _task(),
                assigneeName:          '',
                isCurrentUserAssignee: false,
                currentPerson:         _person(swapTokens: 0),
                onComplete:            () async {},
                onVacation:            () async {},
                onRequestSwap:         ({required isImmediate}) async {},
              ),
            ),
          ),
        );
        await tester.pump();

        final buttons = tester.widgetList<OutlinedButton>(
          find.byType(OutlinedButton),
        );
        expect(
          buttons.any((b) => b.onPressed == null),
          isTrue,
          reason: 'Swap button must be disabled when the user has 0 tokens.',
        );
      },
    );

    testWidgets(
      'Given a user with 0 swap tokens remaining, '
      'when a task assigned to a vacation user is rendered, '
      'then the swap button is disabled (cannot exploit immediate path to bypass check)',
      (tester) async {
        final vacationAssignee = _person(uid: _kBobUid, onVacation: true);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: TaskCard(
                task:                  _task(assignedTo: _kBobUid),
                assigneeName:          'Bob',
                isCurrentUserAssignee: false,
                currentPerson:         _person(swapTokens: 0),
                assigneePerson:        vacationAssignee,
                onComplete:            () async {},
                onVacation:            () async {},
                onRequestSwap:         ({required isImmediate}) async {},
              ),
            ),
          ),
        );
        await tester.pump();

        final buttons = tester.widgetList<OutlinedButton>(
          find.byType(OutlinedButton),
        );
        expect(
          buttons.any((b) => b.onPressed == null),
          isTrue,
          reason: 'Zero-token check must apply even for the immediate swap '
              'path — the button must be disabled.',
        );
      },
    );
  });
}
