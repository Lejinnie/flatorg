import 'dart:async';

import 'package:flutter/material.dart';

import '../constants/app_theme.dart';
import '../constants/strings.dart';
import '../models/app_notification.dart';
import '../models/issue.dart';
import '../repositories/notification_repository.dart';
import '../repositories/swap_request_repository.dart';

/// Bottom-sheet notification panel showing pending swap requests and
/// general in-app notifications (reminders, grace-period alerts, task-completed
/// broadcasts).
///
/// Swap-request tiles have Yes/No buttons (no dismiss needed — responding
/// removes them).  General notification tiles have a Dismiss button only.
///
/// Both streams are injected so the widget has no direct Firebase dependency
/// and can be tested with plain [StreamController]s.
class NotificationPanel extends StatelessWidget {
  const NotificationPanel({
    required this.requestStream,
    required this.notifStream,
    required this.getRequesterName,
    required this.getRequesterTaskName,
    required this.scrollController,
    required this.onRespond,
    required this.onDismiss,
    super.key,
  });

  /// Live stream of pending swap requests targeting the current user's tasks.
  /// Must be a stable reference — do NOT create inside a builder callback.
  final Stream<List<SwapRequest>> requestStream;

  /// Live stream of general in-app notifications for the current user.
  /// Must be a stable reference — do NOT create inside a builder callback.
  final Stream<List<AppNotification>> notifStream;

  /// Callback to look up a member's display name by UID.
  final String Function(String uid) getRequesterName;

  /// Callback to look up a task's display name by task ID.
  final String Function(String taskId) getRequesterTaskName;

  /// Provided by [DraggableScrollableSheet] so the inner list and the sheet
  /// drag gesture share the same scroll physics — prevents flickering.
  final ScrollController scrollController;

  /// Called when the user taps Accept or Decline on a swap-request tile.
  final Future<void> Function(SwapRequest request, SwapRequestStatus response)
      onRespond;

  /// Called when the user taps Dismiss on a general notification tile.
  final Future<void> Function(AppNotification notif) onDismiss;

  static void show(
    BuildContext context, {
    required String flatId,
    required String currentUid,
    required String Function(String uid) getRequesterName,
    required String Function(String taskId) getRequesterTaskName,
  }) {
    final swapRepo  = SwapRequestRepository();
    final notifRepo = NotificationRepository();

    // Streams created once here — NOT inside DraggableScrollableSheet.builder.
    // The sheet builder fires on every drag frame; creating streams there
    // would accumulate Firestore listener registrations.
    final requestStream = swapRepo.watchPendingRequestsForUser(flatId, currentUid);
    final notifStream   = notifRepo.watchNotificationsForUser(flatId, currentUid);

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
          requestStream:        requestStream,
          notifStream:          notifStream,
          getRequesterName:     getRequesterName,
          getRequesterTaskName: getRequesterTaskName,
          scrollController:     scrollController,
          onRespond: (req, response) =>
              swapRepo.respondToSwapRequest(flatId, req, response),
          onDismiss: (notif) =>
              notifRepo.dismissNotification(flatId, currentUid, notif.id),
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StreamBuilder<List<SwapRequest>>(
      stream: requestStream,
      builder: (ctx, swapSnap) {
        final requests = swapSnap.data ?? <SwapRequest>[];

        return StreamBuilder<List<AppNotification>>(
          stream: notifStream,
          builder: (ctx, notifSnap) {
            final notifs = notifSnap.data ?? <AppNotification>[];

            final isLoading = swapSnap.connectionState == ConnectionState.waiting
                || notifSnap.connectionState == ConnectionState.waiting;
            final isEmpty = requests.isEmpty && notifs.isEmpty;

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
                      itemCount: requests.length + notifs.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (ctx, i) {
                        // Swap-request tiles come first.
                        if (i < requests.length) {
                          final req      = requests[i];
                          final name     = getRequesterName(req.requesterUid);
                          final taskName = getRequesterTaskName(req.requesterTaskId);
                          return _SwapRequestTile(
                            requesterName:     name,
                            requesterTaskName: taskName,
                            onAccept:  () => onRespond(req, SwapRequestStatus.accepted),
                            onDecline: () => onRespond(req, SwapRequestStatus.declined),
                            key: ValueKey(req.id),
                          );
                        }
                        // General notification tiles follow.
                        final notif = notifs[i - requests.length];
                        return _AppNotificationTile(
                          title:     notif.title,
                          body:      notif.body,
                          onDismiss: () => onDismiss(notif),
                          key: ValueKey(notif.id),
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
  }
}

// ── Swap request tile ─────────────────────────────────────────────────────────

/// A single swap-request row with optimistic hide-on-respond behaviour.
///
/// When the user taps Accept or Decline the tile hides itself immediately
/// (optimistic) while the write completes.  If the write fails the tile
/// reappears and shows a generic error snackbar so the user can retry.
class _SwapRequestTile extends StatefulWidget {
  const _SwapRequestTile({
    required this.requesterName,
    required this.requesterTaskName,
    required this.onAccept,
    required this.onDecline,
    super.key,
  });

  final String requesterName;

  /// The display name of the task the requester currently holds.
  final String requesterTaskName;

  final Future<void> Function() onAccept;
  final Future<void> Function() onDecline;

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
        const SnackBar(content: Text(errorGeneric)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_responded) {
      return const SizedBox.shrink();
    }

    final theme     = Theme.of(context);
    final taskLabel = widget.requesterTaskName.isNotEmpty
        ? ' (${widget.requesterTaskName})'
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
                child: const Text(buttonAccept),
              ),
              const SizedBox(width: AppTheme.spacingSm),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.stateNotDone,
                  side: const BorderSide(color: AppTheme.stateNotDone),
                ),
                onPressed: () => _handleRespond(
                  context,
                  action: widget.onDecline,
                ),
                child: const Text(buttonDecline),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── General notification tile ─────────────────────────────────────────────────

/// A single in-app notification tile (reminder, grace-period, task-completed).
///
/// Shows title + body text and a Dismiss button.  Uses the same optimistic-hide
/// pattern as [_SwapRequestTile]: the tile hides immediately on dismiss and
/// rolls back if the Firestore delete fails.
class _AppNotificationTile extends StatefulWidget {
  const _AppNotificationTile({
    required this.title,
    required this.body,
    required this.onDismiss,
    super.key,
  });

  final String title;
  final String body;
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
        const SnackBar(content: Text(errorGeneric)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    return Padding(
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
    );
  }
}
