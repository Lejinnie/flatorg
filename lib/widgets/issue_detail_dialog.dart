import 'dart:async';

import 'package:flutter/material.dart';

import '../constants/app_theme.dart';
import '../constants/strings.dart';
import '../models/issue.dart';

/// Full-screen detail popup for a single issue.
void showIssueDetailDialog(BuildContext context, Issue issue) {
  unawaited(showDialog<void>(
    context: context,
    builder: (_) => _IssueDetailDialog(issue: issue),
  ));
}

class _IssueDetailDialog extends StatelessWidget {
  const _IssueDetailDialog({required this.issue});

  final Issue issue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      title: Text(issue.title, style: theme.textTheme.titleMedium),
      content: SingleChildScrollView(
        child: Text(issue.description, style: theme.textTheme.bodyMedium),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(buttonCancel),
        ),
      ],
    );
  }
}
