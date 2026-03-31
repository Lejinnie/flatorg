import 'package:flutter/material.dart';

import '../constants/app_theme.dart';
import '../models/issue.dart';

/// A single row in the shopping list.
///
/// In normal mode: checkbox on the left, item text in the middle, optional
/// drag handle (or nothing) on the right.
/// In deletion mode: the whole tile taps to delete; red trashcan on the right.
class ShoppingItemTile extends StatelessWidget {
  const ShoppingItemTile({
    required this.item,
    required this.onToggleBought,
    this.onDelete,
    this.onLongPress,
    this.dragHandle,
    this.isDeletionMode = false,
    super.key,
  });

  final ShoppingItem item;

  /// Called when the user taps the checkbox to toggle the bought state.
  /// Ignored in deletion mode.
  final VoidCallback onToggleBought;

  /// Called when the user taps the tile (or its trashcan) in deletion mode.
  final VoidCallback? onDelete;

  /// Called when the user long-presses the tile to enter deletion mode.
  final VoidCallback? onLongPress;

  /// Pre-built drag handle widget supplied by the parent (a
  /// [ReorderableDragStartListener] wrapping an [Icons.drag_handle] icon).
  /// Shown as the trailing widget in normal mode when non-null.
  final Widget? dragHandle;

  /// When true the tile shows red trashcan UI and tapping deletes the item.
  final bool isDeletionMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isBought = item.isBought;

    return GestureDetector(
      onLongPress: isDeletionMode ? null : onLongPress,
      child: ListTile(
        onTap: isDeletionMode ? onDelete : null,
        leading: isDeletionMode
            ? null
            : GestureDetector(
                onTap: onToggleBought,
                child: Icon(
                  isBought ? Icons.check_box : Icons.check_box_outline_blank,
                  color: Colors.white,
                ),
              ),
        title: Text(
          item.text,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isDeletionMode
                ? AppTheme.destructiveRed
                : isBought
                    ? AppTheme.grayMid
                    : null,
            decoration: isBought && !isDeletionMode
                ? TextDecoration.lineThrough
                : null,
            decorationColor: isBought ? AppTheme.grayMid : null,
          ),
        ),
        trailing: isDeletionMode
            ? IconButton(
                icon: const Icon(Icons.delete_outline, color: AppTheme.destructiveRed),
                onPressed: onDelete,
              )
            : dragHandle,
        dense: true,
      ),
    );
  }
}
