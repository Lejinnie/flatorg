import 'package:flutter/material.dart';

import '../constants/app_theme.dart';
import '../models/issue.dart';

/// A single row in the shopping list.
///
/// Shows a checkbox on the left, item text in the middle, and an optional
/// drag handle on the right (supplied by the parent when inside a
/// [ReorderableListView]).
class ShoppingItemTile extends StatelessWidget {
  const ShoppingItemTile({
    required this.item,
    required this.onToggleBought,
    this.dragHandle,
    super.key,
  });

  final ShoppingItem item;

  /// Called when the user taps the checkbox to toggle the bought state.
  final VoidCallback onToggleBought;

  /// Pre-built drag handle widget supplied by the parent (a
  /// [ReorderableDragStartListener] wrapping an [Icons.drag_handle] icon).
  final Widget? dragHandle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isBought = item.isBought;

    return ListTile(
      leading: GestureDetector(
        onTap: onToggleBought,
        child: Icon(
          isBought ? Icons.check_box : Icons.check_box_outline_blank,
          color: Colors.white,
        ),
      ),
      title: Text(
        item.text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: isBought ? AppTheme.grayMid : null,
          decoration: isBought ? TextDecoration.lineThrough : null,
          decorationColor: isBought ? AppTheme.grayMid : null,
        ),
      ),
      trailing: dragHandle,
      dense: true,
    );
  }
}
