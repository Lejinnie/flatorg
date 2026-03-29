import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../constants/app_theme.dart';
import '../constants/strings.dart';
import '../models/issue.dart';
import '../models/task.dart';
import '../providers/flat_provider.dart';
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

class _TasksBody extends StatelessWidget {
  const _TasksBody();

  @override
  Widget build(BuildContext context) {
    final flatProvider = context.watch<FlatProvider>();
    final flatId       = flatProvider.flatId;
    final flatName     = flatProvider.flat?.name ?? '';
    final currentPerson = flatProvider.currentPerson;
    final currentUid    = currentPerson?.uid ?? '';
    final theme         = Theme.of(context);

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
      body: StreamBuilder<List<Task>>(
        stream: TaskRepository().watchTasks(flatId),
        builder: (ctx, taskSnap) {
          if (taskSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final tasks = taskSnap.data ?? [];
          if (tasks.isEmpty) {
            return Center(
              child: Text(
                'No tasks yet.',
                style: theme.textTheme.bodyMedium?.copyWith(color: AppTheme.grayMid),
              ),
            );
          }

          // Fetch all members for name resolution.
          return StreamBuilder<List<dynamic>>(
            stream: _membersStream(flatId),
            builder: (ctx, memberSnap) {
              final memberMap = <String, String>{};
              if (memberSnap.hasData) {
                for (final m in memberSnap.data!) {
                  if (m is Map<String, dynamic>) {
                    final uid  = m['uid'] as String? ?? '';
                    final name = m['name'] as String? ?? '';
                    if (uid.isNotEmpty) {
                      memberMap[uid] = name;
                    }
                  }
                }
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingSm),
                itemCount: tasks.length,
                itemBuilder: (ctx, i) {
                  final task         = tasks[i];
                  final assigneeName = memberMap[task.assignedTo] ?? '';
                  final isOwner      = task.assignedTo == currentUid;

                  return TaskCard(
                    task: task,
                    assigneeName: assigneeName,
                    isCurrentUserAssignee: isOwner,
                    currentPerson: currentPerson,
                    onComplete: () => _completeTask(ctx, flatId, task),
                    onVacation: () => _markVacation(ctx, flatId, currentUid),
                    onRequestSwap: () => _requestSwap(ctx, flatId, task, currentUid, currentPerson?.uid ?? ''),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Stream<List<dynamic>> _membersStream(String flatId) =>
      FirebaseFirestore.instance
          .collection('flats')
          .doc(flatId)
          .collection('members')
          .snapshots()
          .map((snap) => snap.docs.map((d) {
                final data = d.data();
                data['uid'] = d.id;
                return data;
              }).toList());

  Future<void> _completeTask(
    BuildContext context,
    String flatId,
    Task task,
  ) async {
    await TaskRepository().updateTask(flatId, task.id, {
      'state': 'completed',
      'weeks_not_cleaned': 0,
    });
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
    String currentUid,
    String requesterUid,
  ) async {
    // Find the requester's own task.
    final tasks = await TaskRepository().fetchTasks(flatId);
    final myTask = tasks.firstWhere(
      (t) => t.assignedTo == requesterUid,
      orElse: () => tasks.first,
    );

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
    );

    await SwapRequestRepository().createSwapRequest(flatId, request);
  }
}

/// App bar action showing the notification bell with a live badge count.
class _NotificationBadge extends StatelessWidget {
  const _NotificationBadge({
    required this.flatId,
    required this.currentUid,
    required this.currentPersonName,
  });

  final String flatId;
  final String currentUid;
  final String currentPersonName;

  @override
  Widget build(BuildContext context) {
    final repo = SwapRequestRepository();

    return StreamBuilder<List<SwapRequest>>(
      stream: repo.watchPendingRequestsForUser(flatId, currentUid),
      builder: (ctx, snap) {
        final count = snap.data?.length ?? 0;

        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              tooltip: labelNotifications,
              onPressed: () {
                NotificationPanel.show(
                  ctx,
                  flatId: flatId,
                  currentUid: currentUid,
                  // Look up member names from the flat's member stream.
                  // For simplicity we return the uid as fallback.
                  getRequesterName: (uid) => uid,
                );
              },
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
    );
  }
}
