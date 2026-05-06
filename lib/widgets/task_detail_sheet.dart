import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../constants/app_theme.dart';
import '../constants/strings.dart';
import '../models/task.dart';

/// Read-only bottom sheet showing full task details (title, due date, assignee,
/// subtasks). Replaces the old centered [AlertDialog] — slides up from the
/// bottom for a more native feel on both Android and iOS.
///
/// Dismiss by tapping the X button, tapping the scrim, or swiping down.
class TaskDetailSheet {
  TaskDetailSheet._();

  static void show(
    BuildContext context, {
    required Task task,
    required String assigneeName,
  }) {
    // ignore: discarded_futures — sheet result is intentionally unused.
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x730E1E16), // rgba(14,30,22,0.45)
      isScrollControlled: true,
      builder: (_) => _SheetContent(task: task, assigneeName: assigneeName),
    );
  }
}

class _SheetContent extends StatelessWidget {
  const _SheetContent({required this.task, required this.assigneeName});

  final Task task;
  final String assigneeName;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppTheme.cardColorDark : AppTheme.bgMintSoft;
    final inkPrimary =
        isDark ? Colors.white : const Color(0xFF0E2E1E);
    final inkMuted = isDark
        ? Colors.white.withValues(alpha: 0.55)
        : const Color(0xFF0E2E1E).withValues(alpha: 0.60);

    final due = DateFormat('EEE, d MMM · HH:mm').format(
      task.dueDateTime.toDate(),
    );
    final assignee = assigneeName.isEmpty ? labelUnassigned : assigneeName;
    final metaLine = '$due  ·  $assignee';

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2E000000),
            blurRadius: 40,
            offset: Offset(0, -10),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        22,
        10,
        22,
        28 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF0E2E1E).withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Title row + close button
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.name,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        height: 1.1,
                        color: inkPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      metaLine,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.10)
                        : const Color(0xFF0E2E1E).withValues(alpha: 0.06),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: inkPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Status chips
          Row(
            children: [
              const _Chip(label: labelCadenceWeekly),
              const SizedBox(width: 8),
              _StatusChip(state: task.state),
            ],
          ),
          const SizedBox(height: 14),

          // Hairline divider
          Container(
            height: 1,
            color: const Color(0xFF0E2E1E).withValues(alpha: 0.10),
          ),

          if (task.description.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              '${labelSubtasks.toUpperCase()} · ${task.description.length}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: AppTheme.featureColor,
              ),
            ),
            const SizedBox(height: 8),
            ...task.description.map(
              (step) => Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppTheme.featureColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        step,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          height: 1.35,
                          color: inkPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Cadence chip — neutral teal tone.
class _Chip extends StatelessWidget {
  const _Chip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF0E5648).withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
            color: AppTheme.featureColor,
          ),
        ),
      );
}

/// Status chip — background and foreground match the task card's state colour.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.state});

  final TaskState state;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, String label) = switch (state) {
      TaskState.completed => (
        AppTheme.stateCompleted.withValues(alpha: 0.14),
        const Color(0xFF047857),
        labelStatusDone,
      ),
      TaskState.notDone => (
        AppTheme.stateNotDone.withValues(alpha: 0.12),
        const Color(0xFFB91C1C),
        labelStatusOverdue,
      ),
      TaskState.vacant => (
        AppTheme.stateVacant.withValues(alpha: 0.12),
        const Color(0xFF1D4ED8),
        labelStatusVacant,
      ),
      TaskState.pending => (
        AppTheme.statePending.withValues(alpha: 0.14),
        const Color(0xFFB45309),
        labelStatusPending,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          color: fg,
        ),
      ),
    );
  }
}
