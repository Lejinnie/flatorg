// BDD widget tests for TaskCard optimistic UI behaviour.
//
// Every action (complete, vacation, swap) applies a local state change
// immediately — before the async write resolves — so the user sees instant
// visual feedback.  If the write fails the card rolls back and shows a
// user-friendly error snackbar.
//
// Naming: "Given <precondition>, when <action>, then <outcome>"

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flatorg/constants/app_theme.dart';
import 'package:flatorg/constants/strings.dart';
import 'package:flatorg/models/person.dart';
import 'package:flatorg/models/task.dart';
import 'package:flatorg/widgets/task_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Fixtures ──────────────────────────────────────────────────────────────────

final _kFutureDue = Timestamp.fromDate(DateTime(2099, 12, 31, 12));

const _kAliceUid  = 'alice-uid';

Task _task({
  String    id         = 't1',
  String    assignedTo = _kAliceUid,
  TaskState state      = TaskState.pending,
}) =>
    Task(
      id:                 id,
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
  String uid        = _kAliceUid,
  bool   onVacation = false,
  int    tokens     = 3,
}) =>
    Person(
      uid:                 uid,
      name:                'Alice',
      email:               'alice@flat.test',
      role:                PersonRole.member,
      onVacation:          onVacation,
      swapTokensRemaining: tokens,
    );

// ── Harness ───────────────────────────────────────────────────────────────────

/// Pumps an owner TaskCard (Alice is the assignee and the current user).
///
/// [onComplete] and [onVacation] default to no-ops; pass a custom future to
/// control when the write resolves or rejects.
Future<void> _pumpOwnerCard(
  WidgetTester tester, {
  Task?   task,
  Person? currentPerson,
  Future<void> Function()? onComplete,
  Future<void> Function()? onVacation,
}) async {
  final t = task ?? _task();
  final p = currentPerson ?? _person();
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: TaskCard(
          task:                  t,
          assigneeName:          p.name,
          isCurrentUserAssignee: true,
          currentPerson:         p,
          assigneePerson:        p,
          onComplete:            onComplete ?? () async {},
          onVacation:            onVacation ?? () async {},
          onRequestSwap:         ({required isImmediate}) async {},
        ),
      ),
    ),
  );
  await tester.pump();
}

Color _cardColor(WidgetTester tester) =>
    tester.widget<Card>(find.byType(Card).first).color!;

/// Taps a button by label and confirms the dialog with [confirmLabel].
Future<void> _tapAndConfirm(
  WidgetTester tester,
  String buttonLabel,
  String confirmLabel,
) async {
  await tester.tap(find.widgetWithText(ElevatedButton, buttonLabel));
  await tester.pump(); // open dialog
  await tester.tap(find.text(confirmLabel).last);
  await tester.pump(); // close dialog + trigger optimistic setState
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  // ── Situation 10 — optimistic complete ───────────────────────────────────────

  group('Situation 10 — optimistic task completion', () {
    testWidgets(
      'Given a pending task assigned to the current user, '
      'when they confirm Complete, '
      'then the card immediately turns green before the write resolves',
      (tester) async {
        // Completer that we never complete during this test — the card must be
        // green while the write is still in flight.
        final completer = Completer<void>();

        await _pumpOwnerCard(
          tester,
          onComplete: () => completer.future,
        );

        // Card should start amber (pending).
        expect(
          _cardColor(tester),
          AppTheme.statePending.withValues(alpha: 0.5),
        );

        await _tapAndConfirm(tester, buttonCompleteTask, confirmCompleteLabel);

        // Card must be green immediately — the write has NOT resolved yet.
        expect(
          _cardColor(tester),
          AppTheme.stateCompleted.withValues(alpha: 0.5),
        );

        // Action buttons must have disappeared (completed state hides them).
        expect(find.widgetWithText(ElevatedButton, buttonCompleteTask), findsNothing);
      },
    );

    testWidgets(
      'Given the card is showing green optimistically, '
      'when onComplete throws (network error), '
      'then the card reverts to amber and shows an error snackbar',
      (tester) async {
        final completer = Completer<void>();

        await _pumpOwnerCard(
          tester,
          onComplete: () => completer.future,
        );

        await _tapAndConfirm(tester, buttonCompleteTask, confirmCompleteLabel);

        // Optimistic green.
        expect(
          _cardColor(tester),
          AppTheme.stateCompleted.withValues(alpha: 0.5),
        );

        // Simulate network failure.
        completer.completeError(Exception('network error'));
        await tester.pump(); // process error + rollback setState
        await tester.pump(); // flush SnackBar animation frame

        // Card must revert to pending amber.
        expect(
          _cardColor(tester),
          AppTheme.statePending.withValues(alpha: 0.5),
        );

        // Error snackbar must be visible.
        expect(find.text(errorCompleteTaskFailed), findsOneWidget);

        // Complete button must reappear so the user can retry.
        expect(
          find.widgetWithText(ElevatedButton, buttonCompleteTask),
          findsOneWidget,
        );
      },
    );
  });

  // ── Situation 11 — optimistic vacation ───────────────────────────────────────

  group('Situation 11 — optimistic vacation', () {
    testWidgets(
      'Given the current user is NOT on vacation, '
      'when they confirm Vacation, '
      'then the vacation button is immediately disabled before the write resolves',
      (tester) async {
        final completer = Completer<void>();

        await _pumpOwnerCard(
          tester,
          currentPerson: _person(),
          onVacation: () => completer.future,
        );

        // Vacation button should be enabled.
        final vacationBtn = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, buttonVacation),
        );
        expect(vacationBtn.onPressed, isNotNull);

        await _tapAndConfirm(tester, buttonVacation, confirmVacationLabel);

        // Button must be disabled optimistically.
        final vacationBtnAfter = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, buttonVacation),
        );
        expect(vacationBtnAfter.onPressed, isNull);

        // Card should turn blue (assignee on vacation).
        expect(
          _cardColor(tester),
          AppTheme.stateVacant.withValues(alpha: 0.5),
        );
      },
    );

    testWidgets(
      'Given the button is disabled optimistically, '
      'when onVacation throws (network error), '
      'then the vacation button reverts to enabled and shows an error snackbar',
      (tester) async {
        final completer = Completer<void>();

        await _pumpOwnerCard(
          tester,
          currentPerson: _person(),
          onVacation: () => completer.future,
        );

        await _tapAndConfirm(tester, buttonVacation, confirmVacationLabel);

        // Simulate failure.
        completer.completeError(Exception('network error'));
        await tester.pump();
        await tester.pump();

        // Button must re-enable.
        final vacationBtnAfter = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, buttonVacation),
        );
        expect(vacationBtnAfter.onPressed, isNotNull);

        // Error snackbar visible.
        expect(find.text(errorVacationFailed), findsOneWidget);
      },
    );
  });

  // ── Situation 12 — swap double-tap prevention ─────────────────────────────────

  group('Situation 12 — swap button disabled while action is in flight', () {
    testWidgets(
      'Given a non-assignee views a vacant task with tokens available, '
      'when they confirm the swap and the write is in flight, '
      'then the swap button is disabled until the write completes',
      (tester) async {
        final completer = Completer<void>();

        final vacantTask = _task(assignedTo: '');
        final bob = _person(uid: 'bob-uid');

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: TaskCard(
                task:                  vacantTask,
                assigneeName:          '',
                isCurrentUserAssignee: false,
                currentPerson:         bob,
                onComplete:            () async {},
                onVacation:            () async {},
                onRequestSwap:         ({required isImmediate}) => completer.future,
              ),
            ),
          ),
        );
        await tester.pump();

        // Swap button should start enabled.
        final swapBefore = tester.widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, buttonSwap),
        );
        expect(swapBefore.onPressed, isNotNull);

        // Tap swap and confirm.
        await tester.tap(find.widgetWithText(OutlinedButton, buttonSwap));
        await tester.pump();
        await tester.tap(find.text(buttonSwap).last);
        await tester.pump(); // close dialog + _actionInFlight = true

        // Swap button must be disabled while write is in flight.
        final swapDuring = tester.widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, buttonSwap),
        );
        expect(swapDuring.onPressed, isNull);

        // Complete the write — button should re-enable.
        completer.complete();
        await tester.pump();

        final swapAfter = tester.widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, buttonSwap),
        );
        expect(swapAfter.onPressed, isNotNull);
      },
    );

    testWidgets(
      'Given the swap write fails, '
      'when onRequestSwap throws, '
      'then the swap button re-enables and shows an error snackbar',
      (tester) async {
        final completer = Completer<void>();

        final vacantTask = _task(assignedTo: '');
        final bob = _person(uid: 'bob-uid');

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: TaskCard(
                task:                  vacantTask,
                assigneeName:          '',
                isCurrentUserAssignee: false,
                currentPerson:         bob,
                onComplete:            () async {},
                onVacation:            () async {},
                onRequestSwap:         ({required isImmediate}) => completer.future,
              ),
            ),
          ),
        );
        await tester.pump();

        await tester.tap(find.widgetWithText(OutlinedButton, buttonSwap));
        await tester.pump();
        await tester.tap(find.text(buttonSwap).last);
        await tester.pump();

        // Fail the write.
        completer.completeError(Exception('network error'));
        await tester.pump();
        await tester.pump();

        // Button re-enables.
        final swapAfter = tester.widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, buttonSwap),
        );
        expect(swapAfter.onPressed, isNotNull);

        // Error snackbar visible.
        expect(find.text(errorSwapFailed), findsOneWidget);
      },
    );
  });
}
