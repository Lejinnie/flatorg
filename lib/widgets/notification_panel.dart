import 'dart:async';

import 'package:flutter/material.dart';

import '../constants/app_theme.dart';
import '../constants/strings.dart';
import '../models/issue.dart';
import '../repositories/swap_request_repository.dart';

/// Bottom-sheet notification panel showing pending swap requests.
///
/// Each request shows who wants to swap, what task they hold, and offers
/// Yes/No buttons. Accepting or declining removes the item from the list
/// immediately (the Firestore stream will confirm).
class NotificationPanel extends StatelessWidget {
  const NotificationPanel({
    required this.requestStream,
    required this.getRequesterName,
    required this.getRequesterTaskName,
    required this.scrollController,
    required this.onRespond,
    super.key,
  });

  /// Live stream of pending swap requests targeting the current user's tasks.
  /// Injected so the widget has no direct Firebase dependency and can be
  /// tested with a plain [StreamController].
  ///
  /// Must be a stable reference — do NOT create this stream inside a builder
  /// callback that fires on every frame (e.g. DraggableScrollableSheet.builder)
  /// because each new Stream object causes StreamBuilder to re-subscribe,
  /// which accumulates duplicate Firestore listener registrations.
  final Stream<List<SwapRequest>> requestStream;

  /// Callback to look up a member's display name by UID.
  final String Function(String uid) getRequesterName;

  /// Callback to look up a task's display name by task ID.
  /// Shows the requester's task name so the recipient knows what they would
  /// be swapping into.
  final String Function(String taskId) getRequesterTaskName;

  /// Provided by [DraggableScrollableSheet] so the inner list and the sheet
  /// drag gesture share the same scroll physics — prevents flickering.
  final ScrollController scrollController;

  /// Called when the user taps Accept or Decline on a tile.
  /// Returns a [Future] so each tile can await the write and roll back its
  /// optimistic hide if the request fails.
  final Future<void> Function(SwapRequest request, SwapRequestStatus response) onRespond;

  static void show(
    BuildContext context, {
    required String flatId,
    required String currentUid,
    required String Function(String uid) getRequesterName,
    required String Function(String taskId) getRequesterTaskName,
  }) {
    final repo = SwapRequestRepository();
    // Stream created once here — NOT inside DraggableScrollableSheet.builder.
    // The sheet's builder fires on every drag frame; creating the stream there
    // would cause a new Firestore listener on each frame and accumulate counts.
    final requestStream = repo.watchPendingRequestsForUser(flatId, currentUid);
    unawaited(showModalBottomSheet<void>(
      context: context,
      // isScrollControlled is required for DraggableScrollableSheet to work
      // correctly — without it the sheet is capped at 50 % height and the
      // drag handle fights the inner ListView for scroll events.
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLg),
        ),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.45,
        maxChildSize: 0.85,
        // expand: false keeps the sheet within the bottom-sheet frame rather
        // than filling the entire screen when dragged to max.
        expand: false,
        builder: (ctx, scrollController) => NotificationPanel(
          requestStream:        requestStream,
          getRequesterName:     getRequesterName,
          getRequesterTaskName: getRequesterTaskName,
          scrollController:     scrollController,
          onRespond: (req, response) =>
              repo.respondToSwapRequest(flatId, req, response),
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StreamBuilder<List<SwapRequest>>(
      stream: requestStream,
      builder: (ctx, snap) {
        final requests = snap.data ?? [];

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

            if (snap.connectionState == ConnectionState.waiting)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (requests.isEmpty)
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
                  itemCount: requests.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (ctx, i) {
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
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

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
  /// Shown so the recipient knows what they would be swapping into.
  final String requesterTaskName;

  /// Called when the user taps Yes.  Returns a [Future] so the tile can
  /// detect failure and roll back its optimistic hide.
  final Future<void> Function() onAccept;

  /// Called when the user taps No.  Returns a [Future] so the tile can
  /// detect failure and roll back its optimistic hide.
  final Future<void> Function() onDecline;

  @override
  State<_SwapRequestTile> createState() => _SwapRequestTileState();
}

class _SwapRequestTileState extends State<_SwapRequestTile> {
  /// True after the user responds; collapses the tile immediately while the
  /// write is in flight.  Reverted to false if the write fails.
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
      // Roll back the optimistic hide so the user can try again.
      setState(() => _responded = false);
      messenger.showSnackBar(
        const SnackBar(content: Text(errorGeneric)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Collapsed while the write is in flight or after a successful response
    // (Firestore stream will remove this item on the next snapshot).
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
