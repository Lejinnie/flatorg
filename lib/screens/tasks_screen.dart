import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../constants/app_theme.dart';
import '../constants/strings.dart';
import '../models/app_notification.dart';
import '../models/issue.dart';
import '../models/person.dart';
import '../models/task.dart';
import '../providers/flat_provider.dart';
import '../repositories/notification_repository.dart';
import '../repositories/person_repository.dart';
import '../repositories/swap_request_repository.dart';
import '../repositories/task_repository.dart';
import '../router/app_router.dart';
import '../widgets/notification_panel.dart';
import '../widgets/task_card.dart';
import 'main_scaffold.dart';

/// Home screen showing all 9 task cards for the flat.
class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context) => const MainScaffold(
    currentIndex: 0,
    child: _TasksBody(),
  );
}

class _TasksBody extends StatefulWidget {
  const _TasksBody();

  @override
  State<_TasksBody> createState() => _TasksBodyState();
}

class _TasksBodyState extends State<_TasksBody> {
  var _cachedFlatId = '';
  var _cachedUid = '';
  Stream<List<Task>>? _tasksStream;
  Stream<List<Person>>? _membersStream;
  Stream<List<SwapRequest>>? _outgoingSwapStream;

  /// Only recreates Firestore streams when the flat ID actually changes.
  /// Without this, every FlatProvider.notifyListeners() (e.g. when _flat or
  /// _currentPerson arrives from Firestore) rebuilds this widget and creates
  /// a new stream object, causing StreamBuilder to reset and briefly flash
  /// "No tasks yet."
  void _updateStreamsIfNeeded(String flatId, String uid) {
    if (flatId == _cachedFlatId && uid == _cachedUid) {
      return;
    }
    _cachedFlatId = flatId;
    _cachedUid    = uid;
    _tasksStream  = flatId.isEmpty ? null : TaskRepository().watchTasks(flatId);
    _membersStream =
        flatId.isEmpty ? null : PersonRepository().watchMembers(flatId);
    _outgoingSwapStream = (flatId.isEmpty || uid.isEmpty)
        ? null
        : SwapRequestRepository().watchOutgoingPendingRequests(flatId, uid);
  }

  @override
  Widget build(BuildContext context) {
    final flatProvider = context.watch<FlatProvider>();
    final flatId       = flatProvider.flatId;
    final flatName     = flatProvider.flat?.name ?? '';
    final currentPerson = flatProvider.currentPerson;
    final currentUid    = currentPerson?.uid ?? '';
    final theme         = Theme.of(context);

    _updateStreamsIfNeeded(flatId, currentUid);

    // Flat document hasn't arrived from Firestore yet — show a spinner rather
    // than an empty AppBar that blends into the background (both share bgLight).
    if (flatProvider.flat == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('$welcomePrefix$flatName!'),
        actions: [
          // Notification bell with badge
          _NotificationBadge(
            flatId: flatId,
            currentUid: currentUid,
            currentPersonName: currentPerson?.name ?? '',
          ),
          // Settings gear
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: headingSettings,
            onPressed: () => context.push(routeSettings),
          ),
        ],
      ),
      // Wrap the body in a StreamBuilder for outgoing swap requests so we
      // can disable swap buttons on every card while a request is pending.
      body: StreamBuilder<List<SwapRequest>>(
        stream: _outgoingSwapStream,
        builder: (ctx, outSnap) {
          final hasOutgoing = outSnap.data?.isNotEmpty ?? false;

          return StreamBuilder<List<Task>>(
            stream: _tasksStream,
            builder: (ctx, taskSnap) {
              if (taskSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              // Put the current user's task first; preserve original ring order for the rest.
              final rawTasks = taskSnap.data ?? [];
              final tasks = [
                ...rawTasks.where((t) => t.assignedTo == currentUid),
                ...rawTasks.where((t) => t.assignedTo != currentUid),
              ];
              if (tasks.isEmpty) {
                return Center(
                  child: Text(
                    'No tasks yet.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: AppTheme.grayMid),
                  ),
                );
              }

              // Whether the current user has already completed their own task.
              final myTaskDone = rawTasks.any(
                (t) => t.assignedTo == currentUid && t.state == TaskState.completed,
              );

              // Fetch all members for name + vacation-status resolution.
              return StreamBuilder<List<Person>>(
                stream: _membersStream,
                builder: (ctx, memberSnap) {
                  final memberMap = <String, Person>{};
                  for (final m in memberSnap.data ?? <Person>[]) {
                    memberMap[m.uid] = m;
                  }

                  return RefreshIndicator(
                    onRefresh: () async {},
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingSm),
                      itemCount: tasks.length,
                      itemBuilder: (ctx, i) {
                        final task           = tasks[i];
                        final assigneePerson = memberMap[task.assignedTo];
                        final assigneeName   = assigneePerson?.name ?? '';
                        final isOwner        = task.assignedTo == currentUid;

                        return TaskCard(
                          task: task,
                          assigneeName: assigneeName,
                          isCurrentUserAssignee: isOwner,
                          currentPerson: currentPerson,
                          assigneePerson: assigneePerson,
                          currentUserTaskDone: myTaskDone,
                          hasOutgoingSwapRequest: hasOutgoing,
                          onComplete: () => _completeTask(ctx, flatId, task),
                          onVacation: () => _markVacation(ctx, flatId, currentUid),
                          onRequestSwap: ({required isImmediate}) => _requestSwap(
                              ctx, flatId, task, currentPerson?.uid ?? '',
                              isImmediate: isImmediate),
                        );
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }


  Future<void> _completeTask(
    BuildContext context,
    String flatId,
    Task task,
  ) async {
    await TaskRepository().updateTask(flatId, task.id, {
      'state': 'completed',
      'weeks_not_cleaned': 0,
    });
    // Per spec: completing a task marks the person as back from vacation.
    // Clear on_vacation so their Firestore state is consistent with the green card.
    if (task.assignedTo.isNotEmpty) {
      await PersonRepository().setVacation(
        flatId,
        task.assignedTo,
        onVacation: false,
      );
    }
    // Notify all flat members via FCM (Android) and Firestore in-app docs (iOS).
    // Fire-and-forget: notification failure must never block the task-completion UX.
    unawaited(
      FirebaseFunctions.instance
          .httpsCallable(callableNotifyTaskCompleted)
          .call<Map<String, dynamic>>({
            'flatId':         flatId,
            'taskId':         task.id,
            'completedByUid': task.assignedTo,
          }),
    );
  }

  Future<void> _markVacation(
    BuildContext context,
    String flatId,
    String uid,
  ) async {
    await PersonRepository().setVacation(flatId, uid, onVacation: true);
  }

  Future<void> _requestSwap(
    BuildContext context,
    String flatId,
    Task targetTask,
    String requesterUid, {
    required bool isImmediate,
  }) async {
    // Find the requester's own task.
    final tasks = await TaskRepository().fetchTasks(flatId);
    final myTaskMatches = tasks.where((t) => t.assignedTo == requesterUid);
    if (myTaskMatches.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(duration: Duration(seconds: 3), content: Text(errorNoTaskAssigned)),
        );
      }
      return;
    }
    final myTask = myTaskMatches.first;

    final requestId = FirebaseFirestore.instance
        .collection('flats')
        .doc(flatId)
        .collection('swapRequests')
        .doc()
        .id;

    final request = SwapRequest(
      id: requestId,
      requesterUid: requesterUid,
      targetTaskId: targetTask.id,
      requesterTaskId: myTask.id,
      status: SwapRequestStatus.pending,
      createdAt: Timestamp.now(),
      // Vacation/vacant swaps happen immediately and cost 1 token.
      // Mutual non-vacation swaps require agreement and cost 0 tokens.
      isVacationSwap: isImmediate,
    );

    final repo = SwapRequestRepository();
    await repo.createSwapRequest(flatId, request);

    // Vacant slots and vacation assignees don't require the other person's
    // approval — accept immediately so the token is deducted right away.
    if (isImmediate) {
      await repo.respondToSwapRequest(flatId, request, SwapRequestStatus.accepted);
    } else {
      // Send an FCM push to the target on Android.  iOS already sees the
      // request in the panel via the swapRequests Firestore stream.
      // Fire-and-forget: failure must never block the swap-request UX.
      unawaited(
        FirebaseFunctions.instance
            .httpsCallable(callableNotifySwapRequest)
            .call<Map<String, dynamic>>({
              'flatId':         flatId,
              'swapRequestId':  request.id,
            }),
      );
    }
  }
}

/// App bar action showing the notification bell with a live badge count.
///
/// Stateful so that stream subscriptions are created once in initState and
/// reused across rebuilds. Creating streams inside build (the StatelessWidget
/// anti-pattern) causes a new Firestore listener on every parent rebuild,
/// which makes the badge count grow by 1 on each tab switch.
class _NotificationBadge extends StatefulWidget {
  const _NotificationBadge({
    required this.flatId,
    required this.currentUid,
    required this.currentPersonName,
  });

  final String flatId;
  final String currentUid;
  final String currentPersonName;

  @override
  State<_NotificationBadge> createState() => _NotificationBadgeState();
}

class _NotificationBadgeState extends State<_NotificationBadge> {
  late Stream<List<Person>>          _membersStream;
  late Stream<List<Task>>            _tasksStream;
  late Stream<List<SwapRequest>>     _swapStream;
  late Stream<List<SwapRequest>>     _outgoingSwapStream;
  late Stream<List<AppNotification>> _notifStream;

  // Caches updated on each StreamBuilder rebuild so the panel-opening
  // callback can resolve names/UIDs without subscribing to the streams again.
  Map<String, String> _memberNameMap     = const {};
  Map<String, String> _taskNameMap       = const {};
  Map<String, String> _taskAssigneeUidMap = const {};

  @override
  void initState() {
    super.initState();
    _membersStream = PersonRepository().watchMembers(widget.flatId);
    _tasksStream   = TaskRepository().watchTasks(widget.flatId);
    _swapStream    = SwapRequestRepository()
        .watchPendingRequestsForUser(widget.flatId, widget.currentUid);
    _outgoingSwapStream = SwapRequestRepository()
        .watchOutgoingPendingRequests(widget.flatId, widget.currentUid);
    _notifStream   = NotificationRepository()
        .watchNotificationsForUser(widget.flatId, widget.currentUid);
  }

  // ── Orchestration ───────────────────────────────────────────────────────────

  /// Handles Accept / Reject on an incoming swap-request tile.  Performs the
  /// Firestore writes (status update + task swap on accept), notifies the
  /// requester of the outcome, and on accept auto-rejects every other pending
  /// request targeting the same task plus notifies each affected requester.
  Future<void> _handleSwapResponse(
    SwapRequest request,
    SwapRequestStatus response,
  ) async {
    final swapRepo  = SwapRequestRepository();
    final responderName = widget.currentPersonName;
    final accepted = response == SwapRequestStatus.accepted;

    // 1. Apply the response in Firestore (status update + task swap on accept).
    await swapRepo.respondToSwapRequest(widget.flatId, request, response);

    // 2. Notify the requester of the outcome (in-app + FCM push fire-and-forget).
    unawaited(_notifyRequesterOutcome(
      requesterUid: request.requesterUid,
      responderName: responderName,
      accepted: accepted,
    ));

    // 3. On accept, auto-decline every other pending request for the same
    //    target task and notify each affected requester individually.
    if (accepted) {
      final rejectedUids = await swapRepo.declineAllOtherPendingForTarget(
        widget.flatId,
        request.targetTaskId,
        request.id,
      );
      for (final uid in rejectedUids) {
        unawaited(_notifyRequesterOutcome(
          requesterUid: uid,
          responderName: responderName,
          accepted: false,
        ));
      }
    }
  }

  /// Writes the outcome notification to the requester's notifications
  /// subcollection AND fires the Cloud Function for an FCM push.
  Future<void> _notifyRequesterOutcome({
    required String requesterUid,
    required String responderName,
    required bool accepted,
  }) async {
    final notifRepo = NotificationRepository();
    final type  = accepted ? notifTypeSwapAccepted : notifTypeSwapRejected;
    final title = accepted ? notifTitleSwapAccepted : notifTitleSwapRejected;
    final tpl   = accepted
        ? notifBodySwapAcceptedTemplate
        : notifBodySwapRejectedTemplate;
    final body  = tpl.replaceFirst('{name}', responderName);

    try {
      await notifRepo.writeNotification(
        widget.flatId,
        requesterUid,
        type:  type,
        title: title,
        body:  body,
      );
    } on Exception catch (e) {
      debugPrint('writeNotification failed (response outcome): $e');
    }
    // Fire-and-forget FCM push.
    unawaited(
      FirebaseFunctions.instance
          .httpsCallable(callableNotifySwapResponse)
          .call<Map<String, dynamic>>({
            'flatId':        widget.flatId,
            'requesterUid':  requesterUid,
            'responderName': responderName,
            'accepted':      accepted,
          }),
    );
  }

  /// Handles Withdraw on an outgoing swap-request tile.  Deletes the swap
  /// request document (B's incoming-tile stream auto-removes it) and notifies
  /// the target person.
  Future<void> _handleSwapWithdraw(SwapRequest request) async {
    final swapRepo  = SwapRequestRepository();
    final notifRepo = NotificationRepository();

    // 1. Delete the swap request document.
    await swapRepo.withdrawSwapRequest(widget.flatId, request.id);

    // 2. Resolve the target person UID from the cached task→assignee map.
    final targetUid = _taskAssigneeUidMap[request.targetTaskId] ?? '';
    if (targetUid.isEmpty) {
      return;
    }

    // 3. Write in-app notification to the target.
    final body = notifBodySwapWithdrawnTemplate
        .replaceFirst('{name}', widget.currentPersonName);
    try {
      await notifRepo.writeNotification(
        widget.flatId,
        targetUid,
        type:  notifTypeSwapWithdrawn,
        title: notifTitleSwapWithdrawn,
        body:  body,
      );
    } on Exception catch (e) {
      debugPrint('writeNotification failed (withdraw): $e');
    }

    // 4. Fire-and-forget FCM push.
    unawaited(
      FirebaseFunctions.instance
          .httpsCallable(callableNotifySwapWithdrawn)
          .call<Map<String, dynamic>>({
            'flatId':        widget.flatId,
            'targetUid':     targetUid,
            'requesterName': widget.currentPersonName,
          }),
    );
  }

  /// Dismisses (deletes) a single in-app notification.
  Future<void> _handleDismiss(AppNotification notif) =>
      NotificationRepository().dismissNotification(
        widget.flatId,
        widget.currentUid,
        notif.id,
      );

  void _openPanel(BuildContext context) {
    // Fresh Firestore streams just for this panel session.  Reusing the
    // badge's streams would leave the panel's StreamBuilders stuck in the
    // waiting state — broadcast streams don't replay past emissions to new
    // subscribers, so the spinner would never clear until the next
    // Firestore change.  These per-panel streams are auto-disposed when the
    // bottom sheet closes.
    final swapRepo  = SwapRequestRepository();
    final notifRepo = NotificationRepository();
    NotificationPanel.show(
      context,
      requestStream: swapRepo.watchPendingRequestsForUser(
        widget.flatId,
        widget.currentUid,
      ),
      outgoingRequestStream: swapRepo.watchOutgoingPendingRequests(
        widget.flatId,
        widget.currentUid,
      ),
      notifStream: notifRepo.watchNotificationsForUser(
        widget.flatId,
        widget.currentUid,
      ),
      getRequesterName:     (uid)    => _memberNameMap[uid]  ?? uid,
      getRequesterTaskName: (taskId) => _taskNameMap[taskId] ?? taskId,
      getTargetPersonName:  (taskId) {
        final assigneeUid = _taskAssigneeUidMap[taskId] ?? '';
        return _memberNameMap[assigneeUid] ?? assigneeUid;
      },
      onRespond:  _handleSwapResponse,
      onWithdraw: _handleSwapWithdraw,
      onDismiss:  _handleDismiss,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Honour the FCM-tap intent: open the panel post-frame and clear the flag.
    final flatProvider = context.watch<FlatProvider>();
    if (flatProvider.shouldOpenNotificationPanel) {
      flatProvider.clearNotificationPanelRequest();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _openPanel(context);
        }
      });
    }

    // Stream members and tasks so we can resolve IDs to display names in
    // the panel without re-creating Firestore listeners on each rebuild.
    return StreamBuilder<List<Person>>(
      stream: _membersStream,
      builder: (ctx, memberSnap) {
        final memberMap = <String, String>{};
        for (final m in (memberSnap.data ?? <Person>[])) {
          memberMap[m.uid] = m.name.isNotEmpty ? m.name : m.email;
        }
        _memberNameMap = memberMap;

        return StreamBuilder<List<Task>>(
          stream: _tasksStream,
          builder: (ctx, taskSnap) {
            final taskMap = <String, String>{};
            final assigneeMap = <String, String>{};
            for (final t in (taskSnap.data ?? <Task>[])) {
              taskMap[t.id] = t.name;
              assigneeMap[t.id] = t.assignedTo;
            }
            _taskNameMap = taskMap;
            _taskAssigneeUidMap = assigneeMap;

            return StreamBuilder<List<SwapRequest>>(
              stream: _swapStream,
              builder: (ctx, swapSnap) =>
                  StreamBuilder<List<SwapRequest>>(
                stream: _outgoingSwapStream,
                builder: (ctx, outSnap) =>
                    StreamBuilder<List<AppNotification>>(
                  stream: _notifStream,
                  builder: (ctx, notifSnap) {
                    final count = (swapSnap.data?.length ?? 0)
                        + (outSnap.data?.length ?? 0)
                        + (notifSnap.data?.length ?? 0);

                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.notifications_outlined),
                          tooltip: labelNotifications,
                          onPressed: () => _openPanel(ctx),
                        ),
                        if (count > 0)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: const BoxDecoration(
                                color: AppTheme.stateNotDone,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '$count',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}
