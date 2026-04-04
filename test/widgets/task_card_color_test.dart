// BDD widget tests for TaskCard status-colour behaviour.
//
// TaskCard is a pure widget: its background colour is derived entirely from
// task state + person data passed in as constructor arguments, with no
// Firebase calls. Every scenario below runs in isolation without mocking
// any repository.
//
// Naming convention: "Given <precondition>, when <action>, then <outcome>"
// mirrors Gherkin-style BDD specifications.

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

/// A due-date far in the future so a "pending" task never auto-transitions
/// to "notDone" just because the test clock ticks past midnight.
final _kFutureDue = Timestamp.fromDate(DateTime(2099, 12, 31, 12));

const _kAdminUid  = 'admin-uid';
const _kAdminName = 'Admin';
const _kAliceUid  = 'alice-uid';
const _kAliceName = 'Alice';

Task _task({
  String    id         = 't1',
  String    name       = 'Toilet',
  String    assignedTo = '',
  TaskState state      = TaskState.pending,
}) =>
    Task(
      id:                 id,
      name:               name,
      description:        const [],
      dueDateTime:        _kFutureDue,
      assignedTo:         assignedTo,
      originalAssignedTo: '',
      state:              state,
      weeksNotCleaned:    0,
      ringIndex:          0,
    );

Person _person({
  String     uid        = _kAliceUid,
  String     name       = _kAliceName,
  bool       onVacation = false,
  PersonRole role       = PersonRole.member,
}) =>
    Person(
      uid:                 uid,
      name:                name,
      email:               '$name@flat.test',
      role:                role,
      onVacation:          onVacation,
      swapTokensRemaining: 3,
    );

// ── Harness ───────────────────────────────────────────────────────────────────

/// Pumps a single [TaskCard] inside a [MaterialApp] with the app's light theme.
Future<void> _pumpCard(
  WidgetTester tester, {
  required Task task,
  String  assigneeName          = '',
  bool    isCurrentUserAssignee = false,
  Person? currentPerson,
  Person? assigneePerson,
  bool    currentUserTaskDone   = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: TaskCard(
          task:                  task,
          assigneeName:          assigneeName,
          isCurrentUserAssignee: isCurrentUserAssignee,
          currentPerson:         currentPerson,
          assigneePerson:        assigneePerson,
          currentUserTaskDone:   currentUserTaskDone,
          onComplete:            () async {},
          onVacation:            () async {},
          onRequestSwap:         ({required isImmediate}) async {},
        ),
      ),
    ),
  );
  // Let layout and painting settle fully before assertions.
  await tester.pump();
}

/// Returns the [Card] background colour driven by the task-state colour getter.
/// Fails loudly if the Card has no explicit colour — every TaskCard must set one.
Color _cardBackgroundColor(WidgetTester tester) {
  final card = tester.widget<Card>(find.byType(Card).first);
  assert(
    card.color != null,
    'TaskCard must always set an explicit Card.color. '
    'A null colour means the state-colour getter returned null — fix the logic.',
  );
  return card.color!;
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    // Prevent google_fonts from hitting the network during tests; Public Sans
    // will fall back to the system font. Font shape is irrelevant for colour tests.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  // ── Situation 1: no one assigned to any task ──────────────────────────────

  group('Situation 1 – no one is assigned to any task', () {
    testWidgets(
      'Given a task with no assignee, '
      'when the card is rendered, '
      'then the card background is blue (stateVacant at 50 % opacity)',
      (tester) async {
        await _pumpCard(tester, task: _task());

        expect(
          _cardBackgroundColor(tester),
          AppTheme.stateVacant.withValues(alpha: 0.5),
          reason: 'Empty assignedTo must render blue regardless of state.',
        );
      },
    );

    testWidgets(
      'Given a task with no assignee, '
      'when the card is rendered, '
      'then the assignee label reads "$labelUnassigned"',
      (tester) async {
        await _pumpCard(tester, task: _task());

        // The card renders "$labelAssignee$labelUnassigned" as a single Text.
        expect(
          find.textContaining(labelUnassigned),
          findsOneWidget,
          reason: 'Unassigned tasks must display "$labelUnassigned".',
        );
      },
    );

    testWidgets(
      'Given all nine canonical tasks have no assignee, '
      'when each card is rendered in turn, '
      'then every card is blue',
      (tester) async {
        final taskNames = [
          'Toilet', 'Kitchen', 'Recycling', 'Shower',
          'Floor(A)', 'Washing Rags', 'Bathroom', 'Floor(B)', 'Shopping',
        ];

        for (var i = 0; i < taskNames.length; i++) {
          await _pumpCard(
            tester,
            task: _task(id: 't$i', name: taskNames[i]),
          );
          expect(
            _cardBackgroundColor(tester),
            AppTheme.stateVacant.withValues(alpha: 0.5),
            reason: '"${taskNames[i]}" card should be blue when unassigned.',
          );
        }
      },
    );
  });

  // ── Situation 2: only the admin is assigned to one task ───────────────────

  group('Situation 2 – admin assigned to exactly one task', () {
    testWidgets(
      'Given the admin is the assignee of a pending task, '
      'when that card is rendered, '
      'then the card background is amber (statePending at 50 % opacity)',
      (tester) async {
        final admin = _person(
          uid:  _kAdminUid,
          name: _kAdminName,
          role: PersonRole.admin,
        );

        await _pumpCard(
          tester,
          task:           _task(assignedTo: _kAdminUid),
          assigneeName:   _kAdminName,
          assigneePerson: admin,
        );

        expect(
          _cardBackgroundColor(tester),
          AppTheme.statePending.withValues(alpha: 0.5),
          reason: 'An assigned pending task must render amber.',
        );
      },
    );

    testWidgets(
      'Given the admin is assigned to a task, '
      'when the card is rendered, '
      "then the assignee label shows the admin's name",
      (tester) async {
        await _pumpCard(
          tester,
          task:         _task(assignedTo: _kAdminUid),
          assigneeName: _kAdminName,
        );

        expect(
          find.textContaining(_kAdminName),
          findsWidgets,
          reason: 'Assignee name must appear on the card.',
        );
      },
    );

    testWidgets(
      'Given only the admin task is assigned, '
      'when one of the remaining unassigned cards is rendered, '
      'then that card remains blue',
      (tester) async {
        await _pumpCard(tester, task: _task(id: 't2'));

        expect(
          _cardBackgroundColor(tester),
          AppTheme.stateVacant.withValues(alpha: 0.5),
          reason: 'Unassigned tasks must stay blue even when another task is assigned.',
        );
      },
    );
  });

  // ── Situation 4: immediately after week_reset ────────────────────────────
  //
  // week_reset sets every task to TaskState.pending and writes fresh assignedTo
  // values. Tests here model the exact post-reset document state the UI will
  // receive from Firestore and assert the correct colour for each outcome.

  group('Situation 4 – immediately after week_reset', () {
    testWidgets(
      'Given week_reset produced an unassigned slot '
      '(assignedTo empty, state: pending — not enough active people), '
      'when the card is rendered, '
      'then the card is blue',
      (tester) async {
        // All tasks start as pending after reset; empty assignedTo means the
        // algorithm found no eligible person for this slot.
        await _pumpCard(
          tester,
          task: _task(),
        );

        expect(
          _cardBackgroundColor(tester),
          AppTheme.stateVacant.withValues(alpha: 0.5),
          reason: 'An unassigned post-reset slot must render blue, not amber.',
        );
      },
    );

    testWidgets(
      'Given week_reset assigned a short-vacation person to an L1 task '
      '(state: pending, onVacation: true), '
      'when the card is rendered, '
      'then the card is blue',
      (tester) async {
        // Short-vacation people are assigned in step 1 of the algorithm.
        // Their presence means the task is covered but they are absent —
        // blue signals this to the rest of the flat.
        final aliceOnVacation = _person(onVacation: true);
        await _pumpCard(
          tester,
          task:           _task(assignedTo: aliceOnVacation.uid),
          assigneeName:   aliceOnVacation.name,
          assigneePerson: aliceOnVacation,
        );

        expect(
          _cardBackgroundColor(tester),
          AppTheme.stateVacant.withValues(alpha: 0.5),
          reason: 'Vacation assignee after reset must render blue, not amber.',
        );
      },
    );

    testWidgets(
      'Given week_reset assigned a long-vacation person to a leftover slot '
      '(state: pending, onVacation: true, weeksNotCleaned > threshold), '
      'when the card is rendered, '
      'then the card is blue',
      (tester) async {
        // Long-vacation people fill remaining slots in step 8 of the algorithm.
        // Their card must also be blue regardless of weeksNotCleaned value.
        final bobOnLongVacation = _person(uid: 'bob-uid', name: 'Bob', onVacation: true);
        await _pumpCard(
          tester,
          task: Task(
            id:                 't1',
            name:               'Toilet',
            description:        const [],
            dueDateTime:        _kFutureDue,
            assignedTo:         bobOnLongVacation.uid,
            originalAssignedTo: '',
            state:              TaskState.pending,
            weeksNotCleaned:    5,
            ringIndex:          0,
          ),
          assigneeName:   bobOnLongVacation.name,
          assigneePerson: bobOnLongVacation,
        );

        expect(
          _cardBackgroundColor(tester),
          AppTheme.stateVacant.withValues(alpha: 0.5),
          reason: 'Long-vacation assignee after reset must render blue.',
        );
      },
    );

    testWidgets(
      'Given week_reset assigned an active (non-vacation) person to a task '
      '(state: pending, onVacation: false), '
      'when the card is rendered, '
      'then the card is amber',
      (tester) async {
        // Control case: an active person getting a fresh task after reset
        // must be amber, not blue. Confirms vacation check does not over-fire.
        final alice = _person();
        await _pumpCard(
          tester,
          task:           _task(assignedTo: alice.uid),
          assigneeName:   alice.name,
          assigneePerson: alice,
        );

        expect(
          _cardBackgroundColor(tester),
          AppTheme.statePending.withValues(alpha: 0.5),
          reason: 'Active assignee after reset must render amber, not blue.',
        );
      },
    );
  });

  // ── Situation 3: mixed states across the task lifecycle ───────────────────
  //
  // Lifecycle per task within one week:
  //   pending (assigned)   → amber
  //   pending (unassigned) → blue
  //   notDone (grace period active) → red
  //   completed            → green  (holds through grace period until week_reset)
  //   week_reset fires     → back to pending; colour re-determined by new state
  //   vacant / on-vacation → blue

  group('Situation 3 – mixed assignment and lifecycle states', () {
    testWidgets(
      'Given a task is assigned and pending (deadline not yet reached), '
      'when the card is rendered, '
      'then the card is amber',
      (tester) async {
        final alice = _person();
        await _pumpCard(
          tester,
          task:           _task(assignedTo: alice.uid),
          assigneeName:   alice.name,
          assigneePerson: alice,
        );

        expect(
          _cardBackgroundColor(tester),
          AppTheme.statePending.withValues(alpha: 0.5),
        );
      },
    );

    testWidgets(
      'Given a task was completed before the deadline, '
      'when the card is rendered during the grace period, '
      'then the card is green',
      (tester) async {
        final alice = _person();
        await _pumpCard(
          tester,
          task:                  _task(assignedTo: alice.uid, state: TaskState.completed),
          assigneeName:          alice.name,
          assigneePerson:        alice,
          isCurrentUserAssignee: true,
          currentPerson:         alice,
        );

        expect(
          _cardBackgroundColor(tester),
          AppTheme.stateCompleted.withValues(alpha: 0.5),
        );
      },
    );

    testWidgets(
      'Given a task was completed, '
      'when the card is rendered after the grace period ends (before week_reset fires), '
      'then the card remains green',
      (tester) async {
        // Completed state is sticky until week_reset explicitly resets it to
        // pending — passing time alone does not change the card colour.
        final alice = _person();
        await _pumpCard(
          tester,
          task:           _task(assignedTo: alice.uid, state: TaskState.completed),
          assigneeName:   alice.name,
          assigneePerson: alice,
        );

        expect(
          _cardBackgroundColor(tester),
          AppTheme.stateCompleted.withValues(alpha: 0.5),
        );
      },
    );

    testWidgets(
      'Given the task deadline has passed without completion (grace period active), '
      'when the card is rendered, '
      'then the card is red',
      (tester) async {
        final alice = _person();
        await _pumpCard(
          tester,
          task:           _task(assignedTo: alice.uid, state: TaskState.notDone),
          assigneeName:   alice.name,
          assigneePerson: alice,
        );

        expect(
          _cardBackgroundColor(tester),
          AppTheme.stateNotDone.withValues(alpha: 0.5),
        );
      },
    );

    testWidgets(
      'Given week_reset has fired and the task is now pending with a new assignee, '
      'when the card is rendered, '
      'then the card is amber (previous red/green is gone)',
      (tester) async {
        // week_reset resets every task to TaskState.pending and writes new
        // assignedTo values — the colour must purely reflect the fresh state.
        final bob = _person(uid: 'bob-uid', name: 'Bob');
        await _pumpCard(
          tester,
          task:           _task(assignedTo: bob.uid),
          assigneeName:   bob.name,
          assigneePerson: bob,
        );

        expect(
          _cardBackgroundColor(tester),
          AppTheme.statePending.withValues(alpha: 0.5),
          reason: 'After reset the task starts fresh as pending+assigned → amber.',
        );
      },
    );

    testWidgets(
      'Given week_reset has fired and the slot has no new assignee, '
      'when the card is rendered, '
      'then the card is blue (unassigned after reset)',
      (tester) async {
        await _pumpCard(tester, task: _task());

        expect(
          _cardBackgroundColor(tester),
          AppTheme.stateVacant.withValues(alpha: 0.5),
          reason: 'Unassigned slot after reset must render blue.',
        );
      },
    );

    testWidgets(
      'Given a task is in the "vacant" state (assignee was removed mid-week), '
      'when the card is rendered, '
      'then the card is blue',
      (tester) async {
        await _pumpCard(tester, task: _task(state: TaskState.vacant));

        expect(
          _cardBackgroundColor(tester),
          AppTheme.stateVacant.withValues(alpha: 0.5),
        );
      },
    );

    testWidgets(
      'Given the assignee has marked themselves on vacation (pending task), '
      'when the card is rendered, '
      "then the card is blue regardless of the task's own state",
      (tester) async {
        // Vacation overrides the normal pending colour so the assignee's
        // absence is visually identical to an unoccupied slot.
        final aliceOnVacation = _person(onVacation: true);
        await _pumpCard(
          tester,
          task:           _task(assignedTo: aliceOnVacation.uid),
          assigneeName:   aliceOnVacation.name,
          assigneePerson: aliceOnVacation,
        );

        expect(
          _cardBackgroundColor(tester),
          AppTheme.stateVacant.withValues(alpha: 0.5),
          reason: 'On-vacation assignee must render blue even if state is pending.',
        );
      },
    );

    testWidgets(
      'Given the assignee is on vacation AND has completed their task, '
      'when the card is rendered, '
      'then the card is green (completion takes priority over vacation)',
      (tester) async {
        // Reproduces the green→blue flash: the person completed their task which
        // per spec means they are back from vacation. The completed check must
        // come before the onVacation check in _stateColor, otherwise the card
        // stays blue even though the work was done.
        final aliceOnVacation = _person(onVacation: true);
        await _pumpCard(
          tester,
          task:                  _task(
            assignedTo: aliceOnVacation.uid,
            state:      TaskState.completed,
          ),
          assigneeName:          aliceOnVacation.name,
          assigneePerson:        aliceOnVacation,
          isCurrentUserAssignee: true,
          currentPerson:         aliceOnVacation,
        );

        expect(
          _cardBackgroundColor(tester),
          AppTheme.stateCompleted.withValues(alpha: 0.5),
          reason:
              'Completing a task marks the person as back from vacation — '
              'the card must be green, not blue.',
        );
      },
    );

    testWidgets(
      'Given the assignee person data has not yet loaded (null assigneePerson) '
      'and the task is completed, '
      'when the card is rendered, '
      'then the card is green and does not flash blue when member data arrives',
      (tester) async {
        // Reproduces the stream-race: tasks stream fires first (assigneePerson=null
        // because the members stream has not yet emitted), so onVacation defaults
        // to false → completed check fires → green. If the member data then arrives
        // with onVacation=true the card must STILL stay green (completed wins).
        //
        // Phase 1: render with no assigneePerson yet.
        await _pumpCard(
          tester,
          task:         _task(assignedTo: _kAliceUid, state: TaskState.completed),
          assigneeName: _kAliceName,
        );
        expect(
          _cardBackgroundColor(tester),
          AppTheme.stateCompleted.withValues(alpha: 0.5),
          reason: 'Must be green when member data has not yet loaded.',
        );

        // Phase 2: member data arrives with onVacation=true — card must not
        //          flip to blue because the task is already completed.
        await _pumpCard(
          tester,
          task:           _task(assignedTo: _kAliceUid, state: TaskState.completed),
          assigneeName:   _kAliceName,
          assigneePerson: _person(onVacation: true),
        );
        expect(
          _cardBackgroundColor(tester),
          AppTheme.stateCompleted.withValues(alpha: 0.5),
          reason:
              'Must remain green after member data loads — '
              'completed must not be overridden by onVacation.',
        );
      },
    );
  });
}
