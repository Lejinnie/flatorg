import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../constants/app_theme.dart';
import '../constants/strings.dart';
import '../constants/task_constants.dart';
import '../models/person.dart';
import '../models/task.dart';
import 'confirmation_dialog.dart';
import 'task_detail_dialog.dart';

/// A card displaying one household task.
///
/// Shows the task state colour bar, name, due date, and assignee.  Expands
/// to reveal subtasks when the user taps "Show more".  Action buttons at the
/// bottom differ depending on whether the viewing user is the assignee.
///
/// ## Optimistic UI
/// All write actions (complete, vacation, swap) update local state immediately
/// before the async write resolves so the UI feels instant.  If the write
/// fails, the card rolls back to its previous state and shows a user-friendly
/// error snackbar.  When Firestore confirms the change via didUpdateWidget,
/// the local override is cleared and the authoritative server state takes over.
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
  /// Must return a [Future] so the card can await it and roll back on failure.
  final Future<void> Function() onComplete;

  /// Called when the assignee confirms going on vacation.
  /// Must return a [Future] so the card can await it and roll back on failure.
  final Future<void> Function() onVacation;

  /// Called when another user requests a swap with the task owner.
  /// `isImmediate` is true when the swap takes effect without the assignee's
  /// approval (vacant slot or assignee is on vacation).
  /// Must return a [Future] so the card can catch network errors.
  final Future<void> Function({required bool isImmediate}) onRequestSwap;

  @override
  State<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<TaskCard> {
  // ── Optimistic state ────────────────────────────────────────────────────────

  /// Locally overrides widget.task after an optimistic write until Firestore
  /// confirms.  Null when no override is active (normal mode).
  Task? _optimisticTask;

  /// Locally overrides widget.assigneePerson after an optimistic vacation
  /// write — makes the card colour turn blue before Firestore responds.
  Person? _optimisticAssigneePerson;

  /// Locally overrides widget.currentPerson after an optimistic vacation
  /// write — disables the vacation button before Firestore responds.
  Person? _optimisticCurrentPerson;

  /// True while a write is in flight.  Prevents double-tapping the swap button
  /// (for which there is no other optimistic visual guard).
  var _actionInFlight = false;

  // ── Display getters (optimistic-state-aware) ────────────────────────────────

  Task   get _displayTask           => _optimisticTask           ?? widget.task;
  Person? get _displayAssigneePerson => _optimisticAssigneePerson ?? widget.assigneePerson;
  Person? get _displayCurrentPerson  => _optimisticCurrentPerson  ?? widget.currentPerson;

  // ── Lifecycle ────────────────────────────────────────────────────────────────

  @override
  void didUpdateWidget(TaskCard old) {
    super.didUpdateWidget(old);
    // When Firestore confirms (or contradicts) our optimistic update, drop the
    // local override so the card reflects the authoritative server state.
    if (widget.task != old.task) {
      _optimisticTask = null;
    }
    if (widget.assigneePerson != old.assigneePerson) {
      _optimisticAssigneePerson = null;
    }
    if (widget.currentPerson != old.currentPerson) {
      _optimisticCurrentPerson = null;
    }
  }

  // ── Colour derivation ────────────────────────────────────────────────────────

  Color get _stateColor {
    final task = _displayTask;
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
    if (_displayAssigneePerson?.onVacation ?? false) {
      return AppTheme.stateVacant;
    }
    if (task.state == TaskState.notDone) {
      return AppTheme.stateNotDone;
    }
    return AppTheme.statePending;
  }

  String get _dueLabel {
    final dt = _displayTask.dueDateTime.toDate();
    return DateFormat('EEE d MMM, HH:mm').format(dt);
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final task = _displayTask;
    final isDark = theme.brightness == Brightness.dark;
    final secondaryTextColor = isDark ? AppTheme.grayLight : AppTheme.grayMid;
    return Card(
      color: _stateColor.withValues(alpha: 0.5),
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMd,
        vertical: AppTheme.spacingXs,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        onTap: () => TaskDetailDialog.show(
          context,
          task: task,
          assigneeName: widget.assigneeName,
        ),
        child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.spacingMd,
          AppTheme.spacingMd,
          AppTheme.spacingMd,
          AppTheme.spacingMd,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── State colour pill ─────────────────────────────────────────
            // Sits between the card's top edge and the title, inset from
            // both sides by the card's horizontal padding.
            Container(
              height: AppTheme.taskStateBarHeight,
              decoration: BoxDecoration(
                color: _stateColor,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
            ),

            const SizedBox(height: AppTheme.spacingSm),

            Column(
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

                const SizedBox(height: AppTheme.spacingSm),

                // ── Action buttons ────────────────────────────────────────
                _buildActions(context),
              ],
            ),   // inner Column
          ],
        ),       // outer Column
      ),         // Padding
      ),         // InkWell
    );
  }

  Widget _buildActions(BuildContext context) {
    if (widget.isCurrentUserAssignee) {
      // Once the task is done (optimistic or confirmed), no further actions needed.
      if (_displayTask.state == TaskState.completed) {
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
    final onVacation = _displayCurrentPerson?.onVacation ?? false;

    return Row(
      children: [
        // Complete button — disabled while any action is in flight.
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.check, size: 18),
            label: const Text(buttonCompleteTask),
            onPressed: _actionInFlight ? null : () => _confirmComplete(context),
          ),
        ),
        const SizedBox(width: AppTheme.spacingSm),
        // Vacation button — grayed if already on vacation OR if action in flight.
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.beach_access, size: 18),
            label: const Text(buttonVacation),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  onVacation ? AppTheme.grayLight : AppTheme.stateVacant,
              foregroundColor: onVacation ? AppTheme.grayMid : Colors.white,
            ),
            onPressed: (onVacation || _actionInFlight)
                ? null
                : () => _confirmVacation(context),
          ),
        ),
      ],
    );
  }

  Widget _buildSwapAction(BuildContext context) {
    final tokens = _displayCurrentPerson?.swapTokensRemaining ?? 0;
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
        onPressed: (canSwap && !_actionInFlight)
            ? () => _confirmSwap(context, tokens)
            : null,
      ),
    );
  }

  // ── Confirmation + optimistic handlers ───────────────────────────────────────

  Future<void> _confirmComplete(BuildContext context) async {
    // Capture before any await to satisfy use_build_context_synchronously.
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showConfirmationDialog(
      context,
      title: confirmCompleteTitle,
      message: confirmCompleteMessage,
      confirmLabel: confirmCompleteLabel,
      confirmColor: AppTheme.stateCompleted,
      confirmTextColor: Colors.white,
    );
    if (!confirmed || !mounted) {
      return;
    }

    // Optimistic: immediately show the card as completed so the user gets
    // instant visual feedback without waiting for the Firestore round-trip.
    setState(() {
      _optimisticTask = widget.task.copyWith(state: TaskState.completed);
      _actionInFlight = true;
    });
    try {
      await widget.onComplete();
    } on Exception catch (_) {
      if (!mounted) {
        return;
      }
      // Roll back to the previous state before the network error.
      setState(() => _optimisticTask = null);
      messenger.showSnackBar(
        const SnackBar(content: Text(errorCompleteTaskFailed)),
      );
    } finally {
      if (mounted) {
        setState(() => _actionInFlight = false);
      }
    }
  }

  Future<void> _confirmVacation(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showConfirmationDialog(
      context,
      title: confirmVacationTitle,
      message: confirmVacationMessage,
      confirmLabel: confirmVacationLabel,
      confirmColor: AppTheme.stateVacant,
      confirmTextColor: Colors.white,
    );
    if (!confirmed || !mounted) {
      return;
    }

    // Optimistic: immediately gray out the vacation button and tint the card
    // blue so the user sees an instant response.
    setState(() {
      _optimisticAssigneePerson =
          widget.assigneePerson?.copyWith(onVacation: true) ??
          widget.currentPerson?.copyWith(onVacation: true);
      _optimisticCurrentPerson = widget.currentPerson?.copyWith(onVacation: true);
      _actionInFlight = true;
    });
    try {
      await widget.onVacation();
    } on Exception catch (_) {
      if (!mounted) {
        return;
      }
      // Roll back to the pre-vacation state.
      setState(() {
        _optimisticAssigneePerson = null;
        _optimisticCurrentPerson  = null;
      });
      messenger.showSnackBar(
        const SnackBar(content: Text(errorVacationFailed)),
      );
    } finally {
      if (mounted) {
        setState(() => _actionInFlight = false);
      }
    }
  }

  Future<void> _confirmSwap(BuildContext context, int tokens) async {
    final messenger = ScaffoldMessenger.of(context);
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
    if (!confirmed || !mounted) {
      return;
    }

    // No local visual change for swap (it affects two cards managed by the
    // parent). Just guard against double-taps while the write is in flight.
    setState(() => _actionInFlight = true);
    try {
      await widget.onRequestSwap(isImmediate: isVacant || isOnVacation);
    } on Exception catch (_) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        const SnackBar(content: Text(errorSwapFailed)),
      );
    } finally {
      if (mounted) {
        setState(() => _actionInFlight = false);
      }
    }
  }
}
