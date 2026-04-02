import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../constants/app_theme.dart';
import '../constants/strings.dart';
import '../constants/task_constants.dart';
import '../models/person.dart';
import '../models/task.dart';
import 'confirmation_dialog.dart';

/// A card displaying one household task.
///
/// Shows the task state colour bar, name, due date, and assignee.  Expands
/// to reveal subtasks when the user taps "Show more".  Action buttons at the
/// bottom differ depending on whether the viewing user is the assignee.
class TaskCard extends StatefulWidget {
  const TaskCard({
    required this.task,
    required this.assigneeName,
    required this.isCurrentUserAssignee,
    required this.currentPerson,
    required this.onComplete,
    required this.onVacation,
    required this.onRequestSwap,
    this.assigneePerson,
    this.currentUserTaskDone = false,
    super.key,
  });

  final Task task;

  /// Display name of the person assigned to this task.
  final String assigneeName;

  /// True when the signed-in user is the assignee of this task.
  final bool isCurrentUserAssignee;

  /// The signed-in user's Person document (for token counts, vacation flag).
  final Person? currentPerson;

  /// Full Person document of the task's assignee, used to detect on-vacation
  /// status so the swap confirmation can note that no reply is needed.
  final Person? assigneePerson;

  /// True when the current user has already completed their own task this week.
  /// Hides the swap button on every other card when true.
  final bool currentUserTaskDone;

  /// Called when the assignee confirms task completion.
  final VoidCallback onComplete;

  /// Called when the assignee confirms going on vacation.
  final VoidCallback onVacation;

  /// Called when another user requests a swap with the task owner.
  final VoidCallback onRequestSwap;

  @override
  State<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<TaskCard> {
  var _expanded = false;

  Color get _stateColor {
    final task = widget.task;
    if (task.state == TaskState.vacant) {
      return AppTheme.stateVacant;
    }
    // Unassigned task (no one has this slot yet) → blue like vacant.
    if (task.assignedTo.isEmpty) {
      return AppTheme.stateVacant;
    }
    // Completed always wins — per spec, completing a task marks the person
    // as back from vacation. This check must come before onVacation so a
    // vacation+completed card stays green and never flashes blue.
    if (task.state == TaskState.completed) {
      return AppTheme.stateCompleted;
    }
    // Assignee on vacation → blue for all non-completed states.
    if (widget.assigneePerson?.onVacation ?? false) {
      return AppTheme.stateVacant;
    }
    if (task.state == TaskState.notDone) {
      return AppTheme.stateNotDone;
    }
    return AppTheme.statePending;
  }

  String get _dueLabel {
    final dt = widget.task.dueDateTime.toDate();
    return DateFormat('EEE d MMM, HH:mm').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final task = widget.task;
    final isDark = theme.brightness == Brightness.dark;
    final secondaryTextColor = isDark ? AppTheme.grayLight : AppTheme.grayMid;
    return Card(
      color: _stateColor.withValues(alpha: 0.5),
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMd,
        vertical: AppTheme.spacingXs,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── State colour bar ──────────────────────────────────────────────
          Container(
            height: AppTheme.taskStateBarHeight,
            color: _stateColor,
          ),

          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header row ────────────────────────────────────────────
                Text(
                  task.name,
                  style: theme.textTheme.titleMedium,
                ),

                const SizedBox(height: AppTheme.spacingXs),

                // ── Due date & assignee ───────────────────────────────────
                Text(
                  '$labelDue$_dueLabel',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: secondaryTextColor,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingXs),
                Text(
                  '$labelAssignee${widget.assigneeName.isEmpty ? labelUnassigned : widget.assigneeName}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: secondaryTextColor,
                  ),
                ),

                // ── Subtasks (expanded) ───────────────────────────────────
                if (_expanded && task.description.isNotEmpty) ...[
                  const SizedBox(height: AppTheme.spacingSm),
                  const Divider(),
                  ...task.description.map(
                    (step) => Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppTheme.spacingXs,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• '),
                          Expanded(
                            child: Text(
                              step,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // ── Show more / less toggle ───────────────────────────────
                if (task.description.isNotEmpty)
                  GestureDetector(
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: Padding(
                      padding: const EdgeInsets.only(top: AppTheme.spacingXs),
                      child: Row(
                        children: [
                          Text(
                            _expanded ? buttonShowLess : buttonShowMore,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppTheme.featureColor,
                            ),
                          ),
                          Icon(
                            _expanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            size: 16,
                            color: AppTheme.featureColor,
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: AppTheme.spacingSm),

                // ── Action buttons ────────────────────────────────────────
                _buildActions(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    if (widget.isCurrentUserAssignee) {
      // Once the task is done, no further actions are needed on this card.
      if (widget.task.state == TaskState.completed) {
        return const SizedBox.shrink();
      }
      return _buildOwnerActions(context);
    }
    // Hide swap button on all other cards once the current user is done.
    if (widget.currentUserTaskDone) {
      return const SizedBox.shrink();
    }
    return _buildSwapAction(context);
  }

  Widget _buildOwnerActions(BuildContext context) {
    final onVacation = widget.currentPerson?.onVacation ?? false;

    return Row(
      children: [
        // Complete button
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.check, size: 18),
            label: const Text(buttonCompleteTask),
            onPressed: () => _confirmComplete(context),
          ),
        ),
        const SizedBox(width: AppTheme.spacingSm),
        // Vacation button (grayed if already on vacation)
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.beach_access, size: 18),
            label: const Text(buttonVacation),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  onVacation ? AppTheme.grayLight : AppTheme.stateVacant,
              foregroundColor: onVacation ? AppTheme.grayMid : Colors.white,
            ),
            onPressed: onVacation ? null : () => _confirmVacation(context),
          ),
        ),
      ],
    );
  }

  Widget _buildSwapAction(BuildContext context) {
    final tokens = widget.currentPerson?.swapTokensRemaining ?? 0;
    final canSwap = tokens > 0;
    // Vacant means no person is assigned → swap is immediate, label is "Swap".
    // A person is assigned (even if on vacation) → send a request, label is "Request Swap".
    final isVacant = widget.task.assignedTo.isEmpty ||
        widget.task.state == TaskState.vacant;
    final label = isVacant ? buttonSwap : buttonRequestSwap;

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: const Icon(Icons.swap_horiz, size: 18),
        label: Text(canSwap ? label : '$label (0/$swapTokensPerSemester)'),
        onPressed: canSwap ? () => _confirmSwap(context, tokens) : null,
      ),
    );
  }

  // ── Confirmation helpers ──────────────────────────────────────────────────

  Future<void> _confirmComplete(BuildContext context) async {
    final confirmed = await showConfirmationDialog(
      context,
      title: confirmCompleteTitle,
      message: confirmCompleteMessage,
      confirmLabel: confirmCompleteLabel,
      confirmColor: AppTheme.stateCompleted,
      confirmTextColor: Colors.white,
    );
    if (confirmed) {
      widget.onComplete();
    }
  }

  Future<void> _confirmVacation(BuildContext context) async {
    final confirmed = await showConfirmationDialog(
      context,
      title: confirmVacationTitle,
      message: confirmVacationMessage,
      confirmLabel: confirmVacationLabel,
      confirmColor: AppTheme.stateVacant,
      confirmTextColor: Colors.white,
    );
    if (confirmed) {
      widget.onVacation();
    }
  }

  Future<void> _confirmSwap(BuildContext context, int tokens) async {
    final isVacant = widget.task.assignedTo.isEmpty ||
        widget.task.state == TaskState.vacant;
    final isOnVacation = widget.assigneePerson?.onVacation ?? false;

    final baseMsg = confirmSwapMessage.replaceFirst(
      '{tokens}',
      '$tokens/$swapTokensPerSemester',
    );
    // Append the immediate note when the swap won't need a reply from anyone.
    final msg = (isVacant || isOnVacation)
        ? '$baseMsg\n\n$confirmSwapImmediateNote'
        : baseMsg;

    // "Swap" when unassigned (no one to ask); "Request" when a person holds the task.
    final confirmLabel = isVacant ? buttonSwap : confirmSwapLabel;

    final confirmed = await showConfirmationDialog(
      context,
      title: confirmSwapTitle,
      message: msg,
      confirmLabel: confirmLabel,
    );
    if (confirmed) {
      widget.onRequestSwap();
    }
  }
}
