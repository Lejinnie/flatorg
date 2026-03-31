import 'dart:async';

import 'package:flutter/material.dart';

import '../constants/app_theme.dart';
import '../constants/strings.dart';
import '../models/issue.dart';
import '../repositories/swap_request_repository.dart';

/// Bottom-sheet notification panel showing pending swap requests.
///
/// Each request shows who wants to swap and offers Yes/No buttons.
/// Accepting or declining removes the item from the list immediately
/// (the Firestore stream will confirm).
class NotificationPanel extends StatelessWidget {
  const NotificationPanel({
    required this.flatId,
    required this.currentUid,
    required this.getRequesterName,
    super.key,
  });

  final String flatId;
  final String currentUid;

  /// Callback to look up a member's display name by UID.
  final String Function(String uid) getRequesterName;

  static void show(
    BuildContext context, {
    required String flatId,
    required String currentUid,
    required String Function(String uid) getRequesterName,
  }) {
    unawaited(showModalBottomSheet<void>(
      context: context,
      // isScrollControlled lets the sheet expand past half-screen and avoids
      // conflict between the dismiss gesture and an inner scroll view.
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLg),
        ),
      ),
      builder: (_) => NotificationPanel(
        flatId: flatId,
        currentUid: currentUid,
        getRequesterName: getRequesterName,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final repo  = SwapRequestRepository();

    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
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

          Text(labelNotifications, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppTheme.spacingSm),

          StreamBuilder<List<SwapRequest>>(
            stream: repo.watchPendingRequestsForUser(flatId, currentUid),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final requests = snap.data ?? [];

              if (requests.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppTheme.spacingLg,
                  ),
                  child: Center(
                    child: Text(
                      labelNoNotifications,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.grayMid,
                      ),
                    ),
                  ),
                );
              }

              return ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.5,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: requests.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (ctx, i) {
                    final req = requests[i];
                    final name = getRequesterName(req.requesterUid);
                    return _SwapRequestTile(
                      requesterName: name,
                      onAccept: () => repo.respondToSwapRequest(
                        flatId,
                        req,
                        SwapRequestStatus.accepted,
                      ),
                      onDecline: () => repo.respondToSwapRequest(
                        flatId,
                        req,
                        SwapRequestStatus.declined,
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SwapRequestTile extends StatelessWidget {
  const _SwapRequestTile({
    required this.requesterName,
    required this.onAccept,
    required this.onDecline,
  });

  final String requesterName;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingSm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$requesterName $swapRequestMessage',
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
                onPressed: onAccept,
                child: const Text(buttonAccept),
              ),
              const SizedBox(width: AppTheme.spacingSm),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.stateNotDone,
                  side: const BorderSide(color: AppTheme.stateNotDone),
                ),
                onPressed: onDecline,
                child: const Text(buttonDecline),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
