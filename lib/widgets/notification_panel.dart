import 'dart:async';

import 'package:flutter/material.dart';

import '../constants/app_theme.dart';
import '../constants/strings.dart';
import '../models/app_notification.dart';
import '../models/issue.dart';

/// Bottom-sheet notification panel showing the user's swap state and
/// general in-app notifications (reminders, grace-period alerts, task-completed
/// broadcasts, swap outcomes).
///
/// Three sections are rendered top-to-bottom:
///   1. Outgoing swap requests (the user is the requester) — shows a Withdraw
///      button.  Not swipeable.
///   2. Incoming swap requests (the user is the target) — shows Accept/Reject
///      buttons.  Not swipeable.
///   3. General notifications — shows a Dismiss button AND supports swipe-to-
///      dismiss.
///
/// All three streams are injected so the widget has no direct Firebase
/// dependency and can be tested with plain [StreamController]s.
class NotificationPanel extends StatelessWidget {
  const NotificationPanel({
    required this.requestStream,
    required this.outgoingRequestStream,
    required this.notifStream,
    required this.getRequesterName,
    required this.getRequesterTaskName,
    required this.getTargetPersonName,
    required this.scrollController,
    required this.onRespond,
    required this.onWithdraw,
    required this.onDismiss,
    super.key,
  });

  /// Live stream of pending swap requests targeting the current user's tasks.
  /// Must be a stable reference — do NOT create inside a builder callback.
  final Stream<List<SwapRequest>> requestStream;

  /// Live stream of pending swap requests created BY the current user.
  /// Must be a stable reference — do NOT create inside a builder callback.
  final Stream<List<SwapRequest>> outgoingRequestStream;

  /// Live stream of general in-app notifications for the current user.
  /// Must be a stable reference — do NOT create inside a builder callback.
  final Stream<List<AppNotification>> notifStream;

  /// Callback to look up a member's display name by UID.
  final String Function(String uid) getRequesterName;

  /// Callback to look up a task's display name by task ID.
  final String Function(String taskId) getRequesterTaskName;

  /// Callback to look up the assignee's display name for a given task ID.
  /// Used by the outgoing-request tile to show
  /// `swap with {name} ({task})`.
  final String Function(String taskId) getTargetPersonName;

  /// Provided by [DraggableScrollableSheet] so the inner list and the sheet
  /// drag gesture share the same scroll physics — prevents flickering.
  final ScrollController scrollController;

  /// Called when the user taps Accept or Reject on an incoming swap-request
  /// tile.
  final Future<void> Function(SwapRequest request, SwapRequestStatus response)
      onRespond;

  /// Called when the user taps Withdraw on an outgoing swap-request tile.
  final Future<void> Function(SwapRequest request) onWithdraw;

  /// Called when the user taps Dismiss (or swipes) a general notification.
  final Future<void> Function(AppNotification notif) onDismiss;

  /// Convenience helper that wraps the panel inside a modal bottom sheet
  /// with a draggable scrollable sheet.  Streams must be created by the
  /// caller and kept as stable references — do NOT recreate them inside the
  /// sheet builder (it fires every drag frame and would accumulate listeners).
  static void show(
    BuildContext context, {
    required Stream<List<SwapRequest>> outgoingRequestStream,
    required Stream<List<SwapRequest>> requestStream,
    required Stream<List<AppNotification>> notifStream,
    required String Function(String uid) getRequesterName,
    required String Function(String taskId) getRequesterTaskName,
    required String Function(String taskId) getTargetPersonName,
    required Future<void> Function(SwapRequest, SwapRequestStatus) onRespond,
    required Future<void> Function(SwapRequest) onWithdraw,
    required Future<void> Function(AppNotification) onDismiss,
  }) {
    unawaited(showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLg),
        ),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.45,
        maxChildSize: 0.85,
        expand: false,
        builder: (ctx, scrollController) => NotificationPanel(
          requestStream:         requestStream,
          outgoingRequestStream: outgoingRequestStream,
          notifStream:           notifStream,
          getRequesterName:      getRequesterName,
          getRequesterTaskName:  getRequesterTaskName,
          getTargetPersonName:   getTargetPersonName,
          scrollController:      scrollController,
          onRespond:             onRespond,
          onWithdraw:            onWithdraw,
          onDismiss:             onDismiss,
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StreamBuilder<List<SwapRequest>>(
      stream: outgoingRequestStream,
      builder: (ctx, outSnap) {
        final outgoing = outSnap.data ?? <SwapRequest>[];

        return StreamBuilder<List<SwapRequest>>(
          stream: requestStream,
          builder: (ctx, swapSnap) {
            final incoming = swapSnap.data ?? <SwapRequest>[];

            return StreamBuilder<List<AppNotification>>(
              stream: notifStream,
              builder: (ctx, notifSnap) {
                final notifs = notifSnap.data ?? <AppNotification>[];

                final isLoading = outSnap.connectionState == ConnectionState.waiting
                    || swapSnap.connectionState == ConnectionState.waiting
                    || notifSnap.connectionState == ConnectionState.waiting;
                final isEmpty = outgoing.isEmpty && incoming.isEmpty && notifs.isEmpty;

                return CustomScrollView(
                  controller: scrollController,
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppTheme.spacingMd,
                          AppTheme.spacingMd,
                          AppTheme.spacingMd,
                          AppTheme.spacingSm,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Drag handle
                            Center(
                              child: Container(
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: AppTheme.grayLight,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            const SizedBox(height: AppTheme.spacingMd),
                            Text(
                              labelNotifications,
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: AppTheme.spacingSm),
                          ],
                        ),
                      ),
                    ),

                    if (isLoading)
                      const SliverFillRemaining(
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (isEmpty)
                      SliverFillRemaining(
                        child: Center(
                          child: Text(
                            labelNoNotifications,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppTheme.grayMid,
                            ),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingMd,
                        ),
                        sliver: SliverList.separated(
                          itemCount: outgoing.length + incoming.length + notifs.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (ctx, i) {
                            // 1) Outgoing swap-request tiles first (the user
                            //    is the requester — they see Withdraw).
                            if (i < outgoing.length) {
                              final req       = outgoing[i];
                              final targetName = getTargetPersonName(req.targetTaskId);
                              final taskName   = getRequesterTaskName(req.targetTaskId);
                              return _OutgoingSwapRequestTile(
                                targetName:   targetName,
                                targetTaskName: taskName,
                                onWithdraw:   () => onWithdraw(req),
                                key: ValueKey('outgoing-${req.id}'),
                              );
                            }
                            // 2) Incoming swap-request tiles (the user is the
                            //    target — they see Accept/Reject).
                            final iIncoming = i - outgoing.length;
                            if (iIncoming < incoming.length) {
                              final req      = incoming[iIncoming];
                              final name     = getRequesterName(req.requesterUid);
                              // Show the TARGET task name (the user's own
                              // task being requested), not the requester's task.
                              final taskName = getRequesterTaskName(req.targetTaskId);
                              return _SwapRequestTile(
                                requesterName:    name,
                                targetTaskName:   taskName,
                                onAccept:  () => onRespond(req, SwapRequestStatus.accepted),
                                onReject:  () => onRespond(req, SwapRequestStatus.declined),
                                key: ValueKey('incoming-${req.id}'),
                              );
                            }
                            // 3) General notification tiles.
                            final notif = notifs[i - outgoing.length - incoming.length];
                            return _AppNotificationTile(
                              title:     notif.title,
                              body:      notif.body,
                              notifId:   notif.id,
                              onDismiss: () => onDismiss(notif),
                              key: ValueKey('notif-${notif.id}'),
                            );
                          },
                        ),
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

// ── Incoming swap-request tile (the user is the target) ──────────────────────

/// Tile shown to the target of a swap request.  Renders
/// "[requester name] ([target task name]) wants to swap with you. Do you accept?"
/// with Accept and Reject buttons.  Not wrapped in Dismissible — the user
/// must explicitly accept or reject.
class _SwapRequestTile extends StatefulWidget {
  const _SwapRequestTile({
    required this.requesterName,
    required this.targetTaskName,
    required this.onAccept,
    required this.onReject,
    super.key,
  });

  final String requesterName;

  /// The display name of the target task (the task the requester wants).
  /// Shown so the recipient knows which of their tasks is being requested.
  final String targetTaskName;

  final Future<void> Function() onAccept;
  final Future<void> Function() onReject;

  @override
  State<_SwapRequestTile> createState() => _SwapRequestTileState();
}

class _SwapRequestTileState extends State<_SwapRequestTile> {
  var _responded = false;

  Future<void> _handleRespond(
    BuildContext context, {
    required Future<void> Function() action,
  }) async {
    setState(() => _responded = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
    } on Exception catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _responded = false);
      messenger.showSnackBar(
        const SnackBar(duration: Duration(seconds: 3), content: Text(errorGeneric)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_responded) {
      return const SizedBox.shrink();
    }

    final theme     = Theme.of(context);
    final taskLabel = widget.targetTaskName.isNotEmpty
        ? ' (${widget.targetTaskName})'
        : '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingSm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.requesterName}$taskLabel $swapRequestMessage',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppTheme.spacingSm),
          Row(
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.stateCompleted,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _handleRespond(
                  context,
                  action: widget.onAccept,
                ),
                child: const Text(buttonSwapAccept),
              ),
              const SizedBox(width: AppTheme.spacingSm),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.stateNotDone,
                  side: const BorderSide(color: AppTheme.stateNotDone),
                ),
                onPressed: () => _handleRespond(
                  context,
                  action: widget.onReject,
                ),
                child: const Text(buttonSwapReject),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Outgoing swap-request tile (the user is the requester) ───────────────────

/// Tile shown to the requester while their swap request is pending.  Renders
/// "You are requesting to swap with [target name] ([target task name])."
/// with a single Withdraw button.  Not wrapped in Dismissible.
class _OutgoingSwapRequestTile extends StatefulWidget {
  const _OutgoingSwapRequestTile({
    required this.targetName,
    required this.targetTaskName,
    required this.onWithdraw,
    super.key,
  });

  final String targetName;
  final String targetTaskName;
  final Future<void> Function() onWithdraw;

  @override
  State<_OutgoingSwapRequestTile> createState() =>
      _OutgoingSwapRequestTileState();
}

class _OutgoingSwapRequestTileState extends State<_OutgoingSwapRequestTile> {
  var _withdrawn = false;

  Future<void> _handleWithdraw(BuildContext context) async {
    setState(() => _withdrawn = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.onWithdraw();
    } on Exception catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _withdrawn = false);
      messenger.showSnackBar(
        const SnackBar(duration: Duration(seconds: 3), content: Text(errorGeneric)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_withdrawn) {
      return const SizedBox.shrink();
    }

    final theme     = Theme.of(context);
    final taskLabel = widget.targetTaskName.isNotEmpty
        ? ' (${widget.targetTaskName})'
        : '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingSm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$outgoingSwapPrefix ${widget.targetName}$taskLabel.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppTheme.spacingSm),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.stateNotDone,
              side: const BorderSide(color: AppTheme.stateNotDone),
            ),
            onPressed: () => _handleWithdraw(context),
            child: const Text(buttonWithdraw),
          ),
        ],
      ),
    );
  }
}

// ── General notification tile ────────────────────────────────────────────────

/// A single in-app notification tile (reminder, grace-period, task-completed,
/// swap-accepted/rejected/withdrawn).
///
/// Shows title + body text.  Supports BOTH:
///   - Tapping the Dismiss button (preserves the existing pattern).
///   - Swiping horizontally (Dismissible) — the user explicitly asked for this
///     for general notifications.
///
/// Uses optimistic-hide via a Dismissible key.  If the Firestore delete
/// fails the tile reappears on the next stream emission.
class _AppNotificationTile extends StatefulWidget {
  const _AppNotificationTile({
    required this.title,
    required this.body,
    required this.notifId,
    required this.onDismiss,
    super.key,
  });

  final String title;
  final String body;
  final String notifId;
  final Future<void> Function() onDismiss;

  @override
  State<_AppNotificationTile> createState() => _AppNotificationTileState();
}

class _AppNotificationTileState extends State<_AppNotificationTile> {
  var _dismissed = false;

  Future<void> _handleDismiss(BuildContext context) async {
    setState(() => _dismissed = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.onDismiss();
    } on Exception catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _dismissed = false);
      messenger.showSnackBar(
        const SnackBar(duration: Duration(seconds: 3), content: Text(errorGeneric)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    return Dismissible(
      // Stable key per notification so swipes target the correct tile.
      key: ValueKey('dismissible-${widget.notifId}'),
      background: Container(
        color: AppTheme.destructiveRed,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      secondaryBackground: Container(
        color: AppTheme.destructiveRed,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) {
        // Fire-and-forget the delete — Dismissible already removed the tile
        // visually; if the delete fails the tile will reappear on the next
        // Firestore stream emission.
        unawaited(widget.onDismiss());
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingSm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            )),
            const SizedBox(height: 4),
            Text(widget.body, style: theme.textTheme.bodySmall),
            const SizedBox(height: AppTheme.spacingSm),
            TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                foregroundColor: AppTheme.grayMid,
              ),
              onPressed: () => _handleDismiss(context),
              child: const Text(buttonDismissNotification),
            ),
          ],
        ),
      ),
    );
  }
}
