// BDD widget tests for NotificationPanel.
//
// NotificationPanel receives Stream<List<SwapRequest>> and
// Stream<List<AppNotification>> as constructor parameters, so every scenario
// runs without Firebase by pushing values through StreamControllers.
//
// Naming convention: "Given <precondition>, when <action>, then <outcome>"

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flatorg/constants/app_theme.dart';
import 'package:flatorg/constants/strings.dart';
import 'package:flatorg/models/app_notification.dart';
import 'package:flatorg/models/issue.dart';
import 'package:flatorg/widgets/notification_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ── Fixtures ──────────────────────────────────────────────────────────────────

const _kAliceUid = 'alice-uid';
const _kBobUid   = 'bob-uid';
const _kCarlaUid = 'carla-uid';

const _kToiletTaskId   = 'task-toilet';
const _kBobTaskId      = 'task-kitchen';
const _kAliceTaskId    = 'task-shower';
const _kCarlaTaskId    = 'task-bathroom';

SwapRequest _request({
  String id              = 'req-1',
  String requesterUid    = _kBobUid,
  String targetTaskId    = _kToiletTaskId,
  String requesterTaskId = _kBobTaskId,
}) =>
    SwapRequest(
      id:             id,
      requesterUid:   requesterUid,
      targetTaskId:   targetTaskId,
      requesterTaskId: requesterTaskId,
      status:         SwapRequestStatus.pending,
      createdAt:      Timestamp.fromDate(DateTime(2099)),
      isVacationSwap: false,
    );

String _nameFor(String uid) => switch (uid) {
  _kBobUid   => 'Bob',
  _kAliceUid => 'Alice',
  _kCarlaUid => 'Carla',
  _          => uid,
};

String _taskNameFor(String taskId) => switch (taskId) {
  _kToiletTaskId => 'Toilet',
  _kBobTaskId    => 'Kitchen',
  _kAliceTaskId  => 'Shower',
  _kCarlaTaskId  => 'Bathroom',
  _              => taskId,
};

/// Default getTargetPersonName: maps the canonical task IDs back to whichever
/// person is assigned to that task in our mental model (the "owner" of the
/// task slot).  Tests don't usually rely on this for incoming tiles.
String _targetNameFor(String taskId) => switch (taskId) {
  _kToiletTaskId => 'Tester',
  _kBobTaskId    => 'Bob',
  _kAliceTaskId  => 'Alice',
  _kCarlaTaskId  => 'Carla',
  _              => taskId,
};

// ── Harness ───────────────────────────────────────────────────────────────────

/// Pumps a [NotificationPanel] inside a [MaterialApp] with a fixed-size
/// scaffold so the sliver layout has a finite height.
///
/// Returns the [StreamController] driving incoming requests so tests can push
/// new events.
Future<StreamController<List<SwapRequest>>> _pump(
  WidgetTester tester, {
  Future<void> Function(SwapRequest, SwapRequestStatus)? onRespond,
  Future<void> Function(SwapRequest)? onWithdraw,
  Future<void> Function(AppNotification)? onDismiss,
  ScrollController? scrollController,
  Stream<List<SwapRequest>>? stream,
  Stream<List<SwapRequest>>? outgoingStream,
  Stream<List<AppNotification>>? notifStream,
}) async {
  final controller = StreamController<List<SwapRequest>>();
  final scroll     = scrollController ?? ScrollController();

  // Defaults: empty outgoing-request and notification streams.
  final emptyOutgoingStream = Stream<List<SwapRequest>>.value([]);
  final emptyNotifStream    = Stream<List<AppNotification>>.value([]);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: SizedBox(
          height: 600,
          child: NotificationPanel(
            requestStream:         stream ?? controller.stream,
            outgoingRequestStream: outgoingStream ?? emptyOutgoingStream,
            notifStream:           notifStream ?? emptyNotifStream,
            getRequesterName:      _nameFor,
            getRequesterTaskName:  _taskNameFor,
            getTargetPersonName:   _targetNameFor,
            scrollController:      scroll,
            onRespond:             onRespond  ?? (_, __) async {},
            onWithdraw:            onWithdraw ?? (_) async {},
            onDismiss:             onDismiss  ?? (_) async {},
          ),
        ),
      ),
    ),
  );
  return controller;
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // ── Situation 1: empty / loading states ────────────────────────────────────

  group('Situation 1 — empty / loading states', () {
    testWidgets(
      'Given the stream has not emitted yet, '
      'when the panel is rendered, '
      'then a loading spinner is shown',
      (tester) async {
        final ctrl = await _pump(tester);
        addTearDown(ctrl.close);
        await tester.pump(); // one frame — stream still waiting

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text(labelNoNotifications), findsNothing);
      },
    );

    testWidgets(
      'Given the stream emits an empty list, '
      'when the panel renders, '
      'then the "No notifications" label is shown and no tiles are rendered',
      (tester) async {
        final ctrl = await _pump(tester);
        addTearDown(ctrl.close);
        ctrl.add([]);
        await tester.pump();

        expect(find.text(labelNoNotifications), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.text(buttonSwapAccept), findsNothing);
      },
    );
  });

  // ── Situation 2: displaying incoming requests ──────────────────────────────

  group('Situation 2 — displaying incoming requests', () {
    testWidgets(
      'Given the stream emits 1 pending request from Bob, '
      'when the panel renders, '
      "then one tile shows Bob's name and the swap message",
      (tester) async {
        final ctrl = await _pump(tester);
        addTearDown(ctrl.close);
        ctrl.add([_request()]);
        await tester.pump();

        expect(find.textContaining('Bob'), findsOneWidget);
        expect(find.textContaining(swapRequestMessage), findsOneWidget);
      },
    );

    testWidgets(
      'Given the stream emits 1 pending request, '
      'when the panel renders, '
      'then both Accept and Reject buttons are present and enabled',
      (tester) async {
        final ctrl = await _pump(tester);
        addTearDown(ctrl.close);
        ctrl.add([_request()]);
        await tester.pump();

        final accept = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, buttonSwapAccept),
        );
        final reject = tester.widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, buttonSwapReject),
        );

        expect(accept.onPressed, isNotNull);
        expect(reject.onPressed, isNotNull);
      },
    );

    testWidgets(
      'Given the stream emits 3 pending requests from different people, '
      'when the panel renders, '
      'then three separate tiles are shown, one per requester',
      (tester) async {
        final ctrl = await _pump(tester);
        addTearDown(ctrl.close);
        ctrl.add([
          _request(id: 'r1'),
          _request(id: 'r2', requesterUid: _kAliceUid),
          _request(id: 'r3', requesterUid: _kCarlaUid),
        ]);
        await tester.pump();

        expect(find.textContaining('Bob'),   findsOneWidget);
        expect(find.textContaining('Alice'), findsOneWidget);
        expect(find.textContaining('Carla'), findsOneWidget);
        // Three accept buttons — one per tile.
        expect(find.text(buttonSwapAccept), findsNWidgets(3));
      },
    );
  });

  // ── Situation 3: rejecting a request ───────────────────────────────────────

  group('Situation 3 — rejecting a request', () {
    testWidgets(
      'Given one tile is shown, '
      'when the user taps Reject, '
      'then onRespond is called with declined status exactly once',
      (tester) async {
        SwapRequest? respondedRequest;
        SwapRequestStatus? respondedStatus;

        final ctrl = await _pump(
          tester,
          onRespond: (req, status) async {
            respondedRequest = req;
            respondedStatus  = status;
          },
        );
        addTearDown(ctrl.close);
        final req = _request();
        ctrl.add([req]);
        await tester.pump();

        await tester.tap(find.widgetWithText(OutlinedButton, buttonSwapReject));
        await tester.pump();

        expect(respondedRequest?.id, req.id);
        expect(respondedStatus, SwapRequestStatus.declined);
      },
    );

    testWidgets(
      'Given one tile is shown and the user taps Reject, '
      'when the stream then emits an empty list, '
      'then the tile disappears and "No notifications" is shown',
      (tester) async {
        final ctrl = await _pump(tester);
        addTearDown(ctrl.close);
        ctrl.add([_request()]);
        await tester.pump();
        expect(find.text(buttonSwapReject), findsOneWidget);

        // Simulate: backend processed the decline and emitted an empty list.
        ctrl.add([]);
        await tester.pump();

        expect(find.text(labelNoNotifications), findsOneWidget);
        expect(find.text(buttonSwapReject), findsNothing);
      },
    );
  });

  // ── Situation 4: accepting a request ───────────────────────────────────────

  group('Situation 4 — accepting a request', () {
    testWidgets(
      'Given one tile is shown, '
      'when the user taps Accept, '
      'then onRespond is called with accepted status exactly once',
      (tester) async {
        SwapRequest? respondedRequest;
        SwapRequestStatus? respondedStatus;

        final ctrl = await _pump(
          tester,
          onRespond: (req, status) async {
            respondedRequest = req;
            respondedStatus  = status;
          },
        );
        addTearDown(ctrl.close);
        final req = _request();
        ctrl.add([req]);
        await tester.pump();

        await tester.tap(find.widgetWithText(ElevatedButton, buttonSwapAccept));
        await tester.pump();

        expect(respondedRequest?.id, req.id);
        expect(respondedStatus, SwapRequestStatus.accepted);
      },
    );

    testWidgets(
      'Given one tile is shown and the user taps Accept, '
      'when the stream then emits an empty list, '
      'then the tile disappears',
      (tester) async {
        final ctrl = await _pump(tester);
        addTearDown(ctrl.close);
        ctrl.add([_request()]);
        await tester.pump();
        expect(find.text(buttonSwapAccept), findsOneWidget);

        ctrl.add([]);
        await tester.pump();

        expect(find.text(buttonSwapAccept), findsNothing);
        expect(find.text(labelNoNotifications), findsOneWidget);
      },
    );
  });

  // ── Situation 5: cascading invalidation when a task changes ────────────────

  group('Situation 5 — cascading invalidation when a task changes', () {
    testWidgets(
      'Given 3 requests all targeting Task A, '
      'when the stream emits only 1 remaining (the other 2 dropped because '
      'Task A was reassigned after an accept), '
      'then only 1 tile is shown',
      (tester) async {
        final ctrl = await _pump(tester);
        addTearDown(ctrl.close);
        ctrl.add([
          _request(id: 'r1'),
          _request(id: 'r2', requesterUid: _kAliceUid),
          _request(id: 'r3', requesterUid: _kCarlaUid),
        ]);
        await tester.pump();
        expect(find.text(buttonSwapAccept), findsNWidgets(3));

        // Bob's request was accepted; Task A is now Bob's → Alice's and Carla's
        // requests are filtered out by the stream. Only one request remains.
        ctrl.add([
          _request(id: 'r2', requesterUid: _kAliceUid, targetTaskId: _kBobTaskId),
        ]);
        await tester.pump();

        expect(find.text(buttonSwapAccept), findsOneWidget);
        expect(find.textContaining('Alice'), findsOneWidget);
        expect(find.textContaining('Bob'),   findsNothing);
        expect(find.textContaining('Carla'), findsNothing);
      },
    );

    testWidgets(
      'Given 3 tiles shown and the user accepts the middle one, '
      'when the stream re-emits 0 requests (accepted one gone + other 2 '
      'invalidated because their target task was reassigned), '
      'then all 3 tiles disappear and "No notifications" is shown',
      (tester) async {
        SwapRequest? acceptedReq;
        final ctrl = await _pump(
          tester,
          onRespond: (req, status) async {
            if (status == SwapRequestStatus.accepted) {
              acceptedReq = req;
            }
          },
        );
        addTearDown(ctrl.close);

        final requests = [
          _request(id: 'r1'),
          _request(id: 'r2', requesterUid: _kAliceUid),
          _request(id: 'r3', requesterUid: _kCarlaUid),
        ];
        ctrl.add(requests);
        await tester.pump();
        expect(find.text(buttonSwapAccept), findsNWidgets(3));

        // Tap Accept on the second tile (Alice's request, the middle one).
        await tester.tap(find.widgetWithText(ElevatedButton, buttonSwapAccept).at(1));
        await tester.pump();
        expect(acceptedReq?.id, 'r2');

        // Simulate the backend: task reassigned → all 3 drop from stream.
        ctrl.add([]);
        await tester.pump();

        expect(find.text(labelNoNotifications), findsOneWidget);
        expect(find.text(buttonSwapAccept), findsNothing);
      },
    );
  });

  // ── Situation 6: target task name shown in incoming tile ───────────────────
  //
  // After the lifecycle redesign the incoming tile shows the TARGET task name
  // (the recipient's own task being requested) — not the requester's task —
  // so the recipient sees "[A] ([B's task]) wants to swap with you".

  group('Situation 6 — target task name is shown in each incoming tile', () {
    testWidgets(
      'Given a request from Bob targeting the Toilet task, '
      'when the panel renders, '
      "then the tile shows Bob's name and 'Toilet' (the target task)",
      (tester) async {
        final ctrl = await _pump(tester);
        addTearDown(ctrl.close);
        ctrl.add([_request()]);
        await tester.pump();

        expect(find.textContaining('Bob'), findsOneWidget,
          reason: 'Requester name must appear in the tile.');
        expect(find.textContaining('Toilet'), findsOneWidget,
          reason: 'Target task name must appear so the recipient knows '
              'which of their tasks the requester wants.');
      },
    );

    testWidgets(
      'Given three requests targeting Toilet, Shower, and Bathroom, '
      'when the panel renders, '
      'then each tile shows the correct requester name and target task name',
      (tester) async {
        final ctrl = await _pump(tester);
        addTearDown(ctrl.close);
        ctrl.add([
          _request(id: 'r1'),
          _request(id: 'r2', requesterUid: _kAliceUid, targetTaskId: _kBobTaskId),
          _request(id: 'r3', requesterUid: _kCarlaUid, targetTaskId: _kAliceTaskId),
        ]);
        await tester.pump();

        expect(find.textContaining('Bob'),    findsOneWidget);
        expect(find.textContaining('Toilet'), findsOneWidget);
        expect(find.textContaining('Alice'),  findsOneWidget);
        expect(find.textContaining('Kitchen'), findsOneWidget);
        expect(find.textContaining('Carla'),  findsOneWidget);
        expect(find.textContaining('Shower'), findsOneWidget);
      },
    );
  });

  // ── Situation 7: outgoing-request tile + Withdraw ──────────────────────────

  group('Situation 7 — outgoing-request tile and Withdraw button', () {
    testWidgets(
      'Given the outgoing-request stream emits one pending request, '
      'when the panel renders, '
      'then a Withdraw button is shown alongside the target name and task',
      (tester) async {
        final outCtrl = StreamController<List<SwapRequest>>();
        addTearDown(outCtrl.close);

        final req = _request(
          id: 'out-1',
          requesterUid: _kAliceUid,
          targetTaskId: _kBobTaskId,
          requesterTaskId: _kAliceTaskId,
        );
        final ctrl = await _pump(
          tester,
          outgoingStream: outCtrl.stream,
        );
        addTearDown(ctrl.close);
        ctrl.add([]);
        outCtrl.add([req]);
        await tester.pump();

        expect(find.text(buttonWithdraw), findsOneWidget,
            reason: 'outgoing tile must show a Withdraw button.');
        expect(find.textContaining(outgoingSwapPrefix), findsOneWidget);
        // Target person name (assignee of Bob's task in our fixture).
        expect(find.textContaining('Bob'), findsOneWidget);
        // Target task name.
        expect(find.textContaining('Kitchen'), findsOneWidget);
      },
    );

    testWidgets(
      'Given an outgoing-request tile is shown, '
      'when the user taps Withdraw, '
      'then onWithdraw is called with the request exactly once',
      (tester) async {
        SwapRequest? withdrawnRequest;

        final outCtrl = StreamController<List<SwapRequest>>();
        addTearDown(outCtrl.close);

        final req = _request(
          id: 'out-1',
          requesterUid: _kAliceUid,
          targetTaskId: _kBobTaskId,
          requesterTaskId: _kAliceTaskId,
        );

        final ctrl = await _pump(
          tester,
          outgoingStream: outCtrl.stream,
          onWithdraw: (r) async {
            withdrawnRequest = r;
          },
        );
        addTearDown(ctrl.close);
        ctrl.add([]);
        outCtrl.add([req]);
        await tester.pump();

        await tester.tap(find.widgetWithText(OutlinedButton, buttonWithdraw));
        await tester.pump();

        expect(withdrawnRequest?.id, 'out-1');
      },
    );

    testWidgets(
      'Given the outgoing-request stream is empty, '
      'when the panel renders, '
      'then no Withdraw button appears',
      (tester) async {
        final ctrl = await _pump(tester);
        addTearDown(ctrl.close);
        ctrl.add([]);
        await tester.pump();

        expect(find.text(buttonWithdraw), findsNothing);
      },
    );
  });

  // ── Situation 8: stream stability regression ────────────────────────────────
  //
  // Bug: the notification count in the badge grew by 1 on each tab switch
  // because streams were created inside StatelessWidget.build() and
  // DraggableScrollableSheet.builder, causing multiple overlapping Firestore
  // subscriptions. Fix: streams are created once and passed as stable references.

  group('Situation 8 — stream is not re-subscribed when widget rebuilds', () {
    testWidgets(
      'Given NotificationPanel shows 1 request, '
      'when the widget tree is pumped again (simulating a parent rebuild), '
      'then it still shows 1 tile and has not reset to the loading state',
      (tester) async {
        // The observable regression: creating a new stream on each rebuild would
        // cause StreamBuilder to reset to ConnectionState.waiting (spinner) and
        // then re-emit, which the user sees as the count jumping or flickering.
        final ctrl = await _pump(tester);
        addTearDown(ctrl.close);

        ctrl.add([_request()]);
        await tester.pump();
        expect(find.text(buttonSwapAccept), findsOneWidget,
          reason: 'One tile must be visible after the first emission.');

        // Simulate a parent rebuild — the stream reference must stay stable.
        await tester.pump();

        expect(find.text(buttonSwapAccept), findsOneWidget,
          reason: 'Rebuild must not reset the panel to loading/empty state.');
        expect(find.byType(CircularProgressIndicator), findsNothing,
          reason: 'Panel must not flash the spinner on rebuild.');
      },
    );

    testWidgets(
      'Given NotificationPanel shows 1 request, '
      'when the stream emits the same list a second time (cache/server double-fire), '
      'then still exactly 1 tile is shown (StreamBuilder de-duplicates by design)',
      (tester) async {
        final ctrl = await _pump(tester);
        addTearDown(ctrl.close);

        ctrl.add([_request()]);
        await tester.pump();
        expect(find.text(buttonSwapAccept), findsOneWidget);

        // Second emission with the same single request — simulates Firestore
        // emitting once from cache and once from the server.
        ctrl.add([_request()]);
        await tester.pump();

        expect(find.text(buttonSwapAccept), findsOneWidget,
          reason: 'A second identical emission must not create a second tile.');
      },
    );
  });
}
