import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_theme.dart';
import '../constants/strings.dart';
import '../models/issue.dart';
import '../models/task.dart';
import '../providers/flat_provider.dart';
import '../repositories/issue_repository.dart';
import '../repositories/task_repository.dart';
import '../router/app_router.dart';
import '../widgets/confirmation_dialog.dart';
import '../widgets/issue_detail_dialog.dart';
import '../widgets/issue_tile.dart';
import 'main_scaffold.dart';

/// Issue-list screen.
///
/// Normal mode: scrollable list of issues.
/// Selection mode (entered by long-press): checkboxes, Send + Resolved buttons.
class IssuesScreen extends StatelessWidget {
  const IssuesScreen({super.key});

  @override
  Widget build(BuildContext context) => const MainScaffold(
        currentIndex: 2,
        child: _IssuesBody(),
      );
}

class _IssuesBody extends StatefulWidget {
  const _IssuesBody();

  @override
  State<_IssuesBody> createState() => _IssuesBodyState();
}

class _IssuesBodyState extends State<_IssuesBody> {
  var _selectionMode = false;
  final Set<String> _selectedIds = {};

  // Cached per flatId so a setState (e.g. toggle-select) never recreates the
  // stream or future — which would reset StreamBuilder/FutureBuilder to their
  // waiting state and cause the visible flicker.
  String? _cachedFlatId;
  Stream<List<Issue>>? _issuesStream;
  Future<List<Task>>? _tasksFuture;

  /// Call from build() before using _issuesStream / _tasksFuture.
  /// Re-initialises only when flatId changes (e.g. after switching flat).
  void _initStreamsIfNeeded(String flatId) {
    if (flatId == _cachedFlatId) {
      return;
    }
    _cachedFlatId  = flatId;
    _issuesStream  = IssueRepository().watchIssues(flatId);
    _tasksFuture   = TaskRepository().fetchTasks(flatId);
  }

  void _enterSelection(String firstId) {
    setState(() {
      _selectionMode = true;
      _selectedIds.add(firstId);
    });
  }

  void _exitSelection() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelect(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        // Exit selection mode automatically when the last item is deselected.
        if (_selectedIds.isEmpty) {
          _selectionMode = false;
        }
      } else {
        _selectedIds.add(id);
      }
    });
  }

  // ── Add issue dialog ──────────────────────────────────────────────────────

  Future<void> _showAddIssueDialog(
    BuildContext context,
    String flatId,
    String creatorUid,
  ) async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    // Use a List as a mutable holder so triedSubmit persists across StatefulBuilder rebuilds.
    final triedSubmit = [false];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          // Wider than the default — the description field needs more room.
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: AppTheme.spacingMd,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          title: const Text(buttonAddIssue),
          content: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 280),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(hintText: hintIssueTitle),
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setDialogState(() {}),
                ),
                if (triedSubmit[0] && titleCtrl.text.trim().isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: AppTheme.spacingXs),
                    child: Text(
                      errorIssueTitleRequired,
                      style: TextStyle(
                        color: AppTheme.destructiveRed,
                        fontSize: 12,
                      ),
                    ),
                  ),
                const SizedBox(height: AppTheme.spacingSm),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(hintText: hintIssueDescription),
                  // newline so Enter inserts a line break rather than submitting.
                  maxLines: 8,
                  textInputAction: TextInputAction.newline,
                  keyboardType: TextInputType.multiline,
                  onChanged: (_) => setDialogState(() {}),
                ),
                if (triedSubmit[0] && descCtrl.text.trim().isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: AppTheme.spacingXs),
                    child: Text(
                      errorIssueDescRequired,
                      style: TextStyle(
                        color: AppTheme.destructiveRed,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text(buttonCancel),
            ),
            ElevatedButton(
              onPressed: () {
                if (titleCtrl.text.trim().isEmpty ||
                    descCtrl.text.trim().isEmpty) {
                  setDialogState(() => triedSubmit[0] = true);
                  return;
                }
                Navigator.of(ctx).pop(true);
              },
              child: const Text(buttonConfirm),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) {
      return;
    }
    final title = titleCtrl.text.trim();
    final desc = descCtrl.text.trim();
    if (title.isEmpty) {
      return;
    }

    final issueId = FirebaseFirestore.instance
        .collection('flats')
        .doc(flatId)
        .collection('issues')
        .doc()
        .id;

    await IssueRepository().createIssue(
      flatId,
      Issue(
        id: issueId,
        title: title,
        description: desc,
        createdBy: creatorUid,
        createdAt: Timestamp.now(),
        lastSentAt: null,
      ),
    );
  }

  // ── Send issues ───────────────────────────────────────────────────────────

  Future<void> _sendIssues(
    BuildContext context,
    String flatId,
    List<Issue> sendableSelected,
    String senderName,
  ) async {
    // Capture context-dependent objects before any async gaps.
    final assetBundle = DefaultAssetBundle.of(context);

    final confirmed = await showConfirmationDialog(
      context,
      title: confirmSendTitle,
      message: confirmSendMessage,
      confirmLabel: confirmSendLabel,
    );
    if (!confirmed) {
      return;
    }

    // Pick a random email template.
    final templateIndex = Random().nextInt(3) + 1;
    final templatePath = 'email_templates/issue_template_$templateIndex.txt';

    // Load the template from assets.
    String template;
    try {
      template = await assetBundle.loadString(templatePath);
    } on Exception {
      template = '{{issues}}';
    }

    // Build the bullet list of selected issues.
    final issueLines = sendableSelected
        .map((i) => '- ${i.title}: ${i.description}')
        .join('\n');

    // Split sender name.
    final parts = senderName.trim().split(' ');
    final firstName = parts.first;
    final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';

    final body = template
        .replaceAll('{{issues}}', issueLines)
        .replaceAll('{{sender_first_name}}', firstName)
        .replaceAll('{{sender_last_name}}', lastName);

    final uri = Uri(
      scheme: 'mailto',
      path: livitEmailAddress,
      queryParameters: {
        'subject': livitEmailSubject,
        'body': body,
      },
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }

    // Mark each sent issue with last_sent_at.
    final repo = IssueRepository();
    for (final issue in sendableSelected) {
      await repo.markIssueAsSent(flatId, issue.id);
    }

    _exitSelection();
  }

  // ── Resolve issues ────────────────────────────────────────────────────────

  Future<void> _resolveIssues(
    BuildContext context,
    String flatId,
    List<Issue> selected,
  ) async {
    final confirmed = await showConfirmationDialog(
      context,
      title: confirmResolvedTitle,
      message: confirmResolvedMessage,
      confirmLabel: confirmResolvedLabel,
      confirmColor: AppTheme.stateCompleted,
      confirmTextColor: Colors.white,
    );
    if (!confirmed) {
      return;
    }

    final repo = IssueRepository();
    for (final issue in selected) {
      await repo.deleteIssue(flatId, issue.id);
    }
    _exitSelection();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final flatProvider = context.watch<FlatProvider>();
    final flatId = flatProvider.flatId;
    final currentPerson = flatProvider.currentPerson;
    final currentUid = currentPerson?.uid ?? '';
    final senderName = currentPerson?.name ?? '';

    _initStreamsIfNeeded(flatId);

    return Scaffold(
      appBar: AppBar(
        title: const Text(headingIssues),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: headingSettings,
            onPressed: () => context.push(routeSettings),
          ),
        ],
      ),
      body: StreamBuilder<List<Issue>>(
        stream: _issuesStream,
        builder: (ctx, snap) {
          final allIssues = snap.data ?? [];
          final sendable   = allIssues.where((i) => !i.isOnCooldown).toList();
          final onCooldown = allIssues.where((i) => i.isOnCooldown).toList();

          return Column(
            children: [
              if (_selectionMode)
                _SelectionBar(
                  onGoBack: _exitSelection,
                  allIssues: allIssues,
                  onSelectAll: (issues) {
                    setState(() => _selectedIds.addAll(issues.map((i) => i.id)));
                  },
                ),
              Expanded(child: Builder(builder: (ctx) {
          if (snap.connectionState == ConnectionState.waiting && allIssues.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          // Determine whether the current user can send (assigned to Shopping).
          return FutureBuilder<List<Task>>(
            future: _tasksFuture,
            builder: (ctx, taskSnap) {
              final tasks = taskSnap.data ?? [];
              final shopTask = tasks.where(
                (t) => t.ringIndex == shoppingRingIndex,
              );
              final canSend = shopTask.isNotEmpty &&
                  shopTask.first.assignedTo == currentUid;

              final selectedSendable =
                  sendable.where((i) => _selectedIds.contains(i.id)).toList();
              final selectedAll =
                  allIssues.where((i) => _selectedIds.contains(i.id)).toList();

              return Stack(
                children: [
                  RefreshIndicator(
                    onRefresh: () async {},
                  child: ListView(
                    padding: EdgeInsets.only(
                      bottom: _selectionMode ? 80 : AppTheme.spacingSm,
                      top: AppTheme.spacingXs,
                    ),
                    children: [
                      // Sendable issues.
                      ...sendable.map(
                        (issue) => IssueTile(
                          issue: issue,
                          isSelectionMode: _selectionMode,
                          isSelected: _selectedIds.contains(issue.id),
                          onTap: () => showIssueDetailDialog(ctx, issue),
                          onLongPress: () => _enterSelection(issue.id),
                          onToggleSelect: () => _toggleSelect(issue.id),
                        ),
                      ),

                      // Add Issue button (normal mode only).
                      if (!_selectionMode)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spacingMd,
                            vertical: AppTheme.spacingSm,
                          ),
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.add),
                            label: const Text(buttonAddIssue),
                            onPressed: () => _showAddIssueDialog(
                              ctx,
                              flatId,
                              currentUid,
                            ),
                          ),
                        ),

                      // On-cooldown (recently sent) section.
                      if (onCooldown.isNotEmpty) ...[
                        const Divider(height: AppTheme.spacingLg),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spacingMd,
                            vertical: AppTheme.spacingXs,
                          ),
                          child: Text(
                            labelRecentlySent,
                            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                  color: AppTheme.grayMid,
                                ),
                          ),
                        ),
                        ...onCooldown.map(
                          (issue) => IssueTile(
                            issue: issue,
                            isSelectionMode: _selectionMode,
                            isSelected: _selectedIds.contains(issue.id),
                            onTap: () => showIssueDetailDialog(ctx, issue),
                            onLongPress: () => _enterSelection(issue.id),
                            onToggleSelect: () => _toggleSelect(issue.id),
                          ),
                        ),
                      ],
                    ],
                  ), // ListView
                  ), // RefreshIndicator

                  // Selection mode bottom action bar.
                  if (_selectionMode)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: _SelectionActionBar(
                        canSend: canSend && selectedSendable.isNotEmpty,
                        canResolve: selectedAll.isNotEmpty,
                        onSend: () => _sendIssues(
                          ctx,
                          flatId,
                          selectedSendable,
                          senderName,
                        ),
                        onResolve: () => _resolveIssues(
                          ctx,
                          flatId,
                          selectedAll,
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        })), // Builder + Expanded
            ],
          ); // Column
        }, // StreamBuilder.builder
      ), // StreamBuilder (body)
    );
  }
}

/// Bar shown below the AppBar title when selection mode is active.
/// Provides "Go Back" (exit selection) and "Select All" controls.
class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.onGoBack,
    required this.onSelectAll,
    required this.allIssues,
  });

  final VoidCallback onGoBack;
  final void Function(List<Issue> allIssues) onSelectAll;

  /// Current issue list passed down from the parent StreamBuilder so this
  /// widget does not need its own Firestore subscription.
  final List<Issue> allIssues;

  @override
  Widget build(BuildContext context) => Container(
        color: Theme.of(context).colorScheme.surface,
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingSm,
          vertical: AppTheme.spacingXs,
        ),
        child: Row(
          children: [
            TextButton(
              onPressed: onGoBack,
              child: const Text(buttonGoBack),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => onSelectAll(allIssues),
              child: const Text(buttonSelectAll),
            ),
          ],
        ),
      );
}

/// The "Send" + "Resolved" bottom bar shown during selection mode.
class _SelectionActionBar extends StatelessWidget {
  const _SelectionActionBar({
    required this.canSend,
    required this.canResolve,
    required this.onSend,
    required this.onResolve,
  });

  final bool canSend;
  final bool canResolve;
  final VoidCallback onSend;
  final VoidCallback onResolve;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = theme.brightness == Brightness.dark
        ? const Color(0xFF333333)
        : Colors.white;

    return Container(
      color: bg,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMd,
        vertical: AppTheme.spacingSm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Tooltip(
              message: canSend ? '' : tooltipSendRestricted,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.send_outlined),
                label: const Text(buttonSend),
                onPressed: canSend ? onSend : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      canSend ? AppTheme.featureColor : AppTheme.grayLight,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spacingSm),
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check_circle_outline),
              label: const Text(buttonResolved),
              onPressed: canResolve ? onResolve : null,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    canResolve ? AppTheme.stateCompleted : AppTheme.grayLight,
                foregroundColor: canResolve ? Colors.white : AppTheme.grayMid,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ring index for the Shopping task (last in the ring).
const shoppingRingIndex = 8;
