import 'package:flutter/material.dart';
import '../constants/app_theme.dart';
import '../constants/strings.dart';

/// A reusable confirmation dialog used throughout the app.
///
/// Shows a [title], a [message] body, a cancel button, and a styled confirm
/// button.  The [confirmColor] defaults to [AppTheme.featureColor] but can be
/// overridden — e.g. [AppTheme.destructiveRed] for irreversible actions.
Future<bool> showConfirmationDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  Color? confirmColor,
  Color? confirmTextColor,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => _ConfirmationDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      confirmColor: confirmColor ?? AppTheme.featureColor,
      confirmTextColor: confirmTextColor,
    ),
  );
  return result ?? false;
}

class _ConfirmationDialog extends StatelessWidget {
  const _ConfirmationDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.confirmColor,
    this.confirmTextColor,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final Color confirmColor;
  final Color? confirmTextColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = confirmTextColor ??
        (confirmColor == AppTheme.destructiveRed
            ? Colors.white
            : AppTheme.grayDark);

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      title: Text(title, style: theme.textTheme.titleMedium),
      content: Text(message, style: theme.textTheme.bodyMedium),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppTheme.spacingMd,
        0,
        AppTheme.spacingMd,
        AppTheme.spacingMd,
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(buttonCancel),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: confirmColor,
            foregroundColor: textColor,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}
