import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../constants/app_theme.dart';
import '../constants/strings.dart';
import '../models/task.dart';

/// A read-only popup that shows the full details of a task, including the
/// subtask bullet list. Opened when the user taps a task card.
class TaskDetailDialog extends StatelessWidget {
  const TaskDetailDialog({
    required this.task,
    required this.assigneeName,
    super.key,
  });

  final Task task;
  final String assigneeName;

  static void show(
    BuildContext context, {
    required Task task,
    required String assigneeName,
  }) {
    // ignore: discarded_futures — dialog result is intentionally unused.
    showDialog<void>(
      context: context,
      builder: (_) => TaskDetailDialog(task: task, assigneeName: assigneeName),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme      = Theme.of(context);
    final dueFmt     = DateFormat('d MMM yyyy, HH:mm').format(
      task.dueDateTime.toDate(),
    );
    final displayAssignee =
        assigneeName.isEmpty ? labelUnassigned : assigneeName;

    return AlertDialog(
      title: Text(task.name, style: theme.textTheme.titleMedium),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$labelDue$dueFmt',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.secondaryTextColor,
              ),
            ),
            const SizedBox(height: AppTheme.spacingXs),
            Text(
              '$labelAssignee$displayAssignee',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.secondaryTextColor,
              ),
            ),
            if (task.description.isNotEmpty) ...[
              const SizedBox(height: AppTheme.spacingMd),
              const Divider(),
              const SizedBox(height: AppTheme.spacingXs),
              Text(labelSubtasks, style: theme.textTheme.labelSmall),
              const SizedBox(height: AppTheme.spacingXs),
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
                        child: Text(step, style: theme.textTheme.bodySmall),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(buttonDismiss),
        ),
      ],
    );
  }
}
