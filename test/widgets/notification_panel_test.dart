// BDD widget tests for NotificationPanel.
//
// NotificationPanel receives a Stream<List<SwapRequest>> as a constructor
// parameter, so every scenario runs without Firebase by pushing values through
// a StreamController.
//
// Naming convention: "Given <precondition>, when <action>, then <outcome>"

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flatorg/constants/app_theme.dart';
import 'package:flatorg/constants/strings.dart';
import 'package:flatorg/models/issue.dart';
import 'package:flatorg/widgets/notification_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ── Fixtures ──────────────────────────────────────────────────────────────────

const _kAliceUid = 'alice-uid';
const _kBobUid   = 'bob-uid';
const _kCarlaUid = 'carla-uid';

SwapRequest _request({
  String id           = 'req-1',
  String requesterUid = _kBobUid,
  String targetTaskId = 'task-toilet',
  String requesterTaskId = 'task-kitchen',
}) =>
    SwapRequest(
      id:             id,
      requesterUid:   requesterUid,
      targetTaskId:   targetTaskId,
      requesterTaskId: requesterTaskId,
      status:         SwapRequestStatus.pending,
      createdAt:      Timestamp.fromDate(DateTime(2099)),
    );

String _nameFor(String uid) => switch (uid) {
  _kBobUid   => 'Bob',
  _kAliceUid => 'Alice',
  _kCarlaUid => 'Carla',
  _          => uid,
};

// ── Harness ───────────────────────────────────────────────────────────────────

/// Pumps a [NotificationPanel] inside a [MaterialApp] with a fixed-size
/// scaffold so the sliver layout has a finite height.
///
/// Returns the [StreamController] so tests can push new events.
Future<StreamController<List<SwapRequest>>> _pump(
  WidgetTester tester, {
  void Function(SwapRequest, SwapRequestStatus)? onRespond,
  ScrollController? scrollController,
}) async {
  final controller = StreamController<List<SwapRequest>>();
  final scroll     = scrollController ?? ScrollController();

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: SizedBox(
          height: 600,
          child: NotificationPanel(
            requestStream:   controller.stream,
            getRequesterName: _nameFor,
            scrollController: scroll,
            onRespond:        onRespond ?? (_, __) {},
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
        expect(find.text(buttonAccept), findsNothing);
      },
    );
  });

  // ── Situation 2: displaying requests ───────────────────────────────────────

  group('Situation 2 — displaying requests', () {
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
      'then both Accept (Yes) and Decline (No) buttons are present and enabled',
      (tester) async {
        final ctrl = await _pump(tester);
        addTearDown(ctrl.close);
        ctrl.add([_request()]);
        await tester.pump();

        final accept  = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, buttonAccept),
        );
        final decline = tester.widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, buttonDecline),
        );

        expect(accept.onPressed,  isNotNull);
        expect(decline.onPressed, isNotNull);
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
        expect(find.text(buttonAccept), findsNWidgets(3));
      },
    );
  });

  // ── Situation 3: declining a request ───────────────────────────────────────

  group('Situation 3 — declining a request', () {
    testWidgets(
      'Given one tile is shown, '
      'when the user taps Decline, '
      'then onRespond is called with declined status exactly once',
      (tester) async {
        SwapRequest? respondedRequest;
        SwapRequestStatus? respondedStatus;

        final ctrl = await _pump(
          tester,
          onRespond: (req, status) {
            respondedRequest = req;
            respondedStatus  = status;
          },
        );
        addTearDown(ctrl.close);
        final req = _request();
        ctrl.add([req]);
        await tester.pump();

        await tester.tap(find.widgetWithText(OutlinedButton, buttonDecline));
        await tester.pump();

        expect(respondedRequest?.id, req.id);
        expect(respondedStatus, SwapRequestStatus.declined);
      },
    );

    testWidgets(
      'Given one tile is shown and the user taps Decline, '
      'when the stream then emits an empty list, '
      'then the tile disappears and "No notifications" is shown',
      (tester) async {
        final ctrl = await _pump(tester);
        addTearDown(ctrl.close);
        ctrl.add([_request()]);
        await tester.pump();
        expect(find.text(buttonDecline), findsOneWidget);

        // Simulate: backend processed the decline and emitted an empty list.
        ctrl.add([]);
        await tester.pump();

        expect(find.text(labelNoNotifications), findsOneWidget);
        expect(find.text(buttonDecline), findsNothing);
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
          onRespond: (req, status) {
            respondedRequest = req;
            respondedStatus  = status;
          },
        );
        addTearDown(ctrl.close);
        final req = _request();
        ctrl.add([req]);
        await tester.pump();

        await tester.tap(find.widgetWithText(ElevatedButton, buttonAccept));
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
        expect(find.text(buttonAccept), findsOneWidget);

        ctrl.add([]);
        await tester.pump();

        expect(find.text(buttonAccept), findsNothing);
        expect(find.text(labelNoNotifications), findsOneWidget);
      },
    );
  });

  // ── Situation 5: cascading invalidation ────────────────────────────────────

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
        expect(find.text(buttonAccept), findsNWidgets(3));

        // Bob's request was accepted; Task A is now Bob's → Alice's and Carla's
        // requests are filtered out by the stream. Only one request remains.
        ctrl.add([
          _request(id: 'r2', requesterUid: _kAliceUid, targetTaskId: 'task-kitchen'),
        ]);
        await tester.pump();

        expect(find.text(buttonAccept), findsOneWidget);
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
          onRespond: (req, status) {
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
        expect(find.text(buttonAccept), findsNWidgets(3));

        // Tap Accept on the second tile (Alice's request, the middle one).
        await tester.tap(find.widgetWithText(ElevatedButton, buttonAccept).at(1));
        await tester.pump();
        expect(acceptedReq?.id, 'r2');

        // Simulate the backend: task reassigned → all 3 drop from stream.
        ctrl.add([]);
        await tester.pump();

        expect(find.text(labelNoNotifications), findsOneWidget);
        expect(find.text(buttonAccept), findsNothing);
      },
    );
  });
}
