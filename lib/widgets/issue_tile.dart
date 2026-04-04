import 'package:flutter/material.dart';

import '../constants/app_theme.dart';
import '../models/issue.dart';

/// A single row in the issue list.
///
/// In normal mode: tappable card showing title and a truncated description
/// preview.  Long-pressing enters selection mode (handled by the parent).
///
/// In selection mode a checkbox appears on the right; tapping the tile still
/// opens the detail view while the checkbox toggles selection.
class IssueTile extends StatelessWidget {
  const IssueTile({
    required this.issue,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
    required this.onToggleSelect,
    super.key,
  });

  final Issue issue;
  final bool isSelectionMode;
  final bool isSelected;

  /// Opens the detail view.
  final VoidCallback onTap;

  /// Enters selection mode (handled by parent).
  final VoidCallback onLongPress;

  /// Toggles this issue's selected state during selection mode.
  final VoidCallback onToggleSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onCooldown = issue.isOnCooldown;
    final isDark = theme.brightness == Brightness.dark;

    final defaultCardColor = theme.cardTheme.color ?? theme.cardColor;

    final Color cardColor;
    final Color descriptionTextColor;
    final Color? titleTextColor;
    final IconData checkboxIcon;
    final Color checkboxColor;
    if (isSelected) {
      // Coloured selection background — use explicit dark text for contrast.
      cardColor = isDark ? AppTheme.selectionColor : AppTheme.highlightColorDark;
      descriptionTextColor = AppTheme.grayDark;
      titleTextColor = onCooldown ? AppTheme.grayMid : AppTheme.grayDark;
      checkboxIcon = Icons.check_box;
      checkboxColor = isDark ? AppTheme.highlightColorDark : AppTheme.featureColor;
    } else {
      // Default card — let the theme drive text colour via null.
      cardColor = defaultCardColor;
      descriptionTextColor = AppTheme.grayMid;
      titleTextColor = onCooldown ? AppTheme.grayMid : null;
      checkboxIcon = Icons.check_box_outline_blank;
      checkboxColor = AppTheme.grayMid;
    }

    return GestureDetector(
      onLongPress: onLongPress,
      child: Card(
        color: cardColor,
        margin: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingMd,
          vertical: AppTheme.spacingXs,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          // In selection mode the whole tile toggles selection; tapping the
          // text area to open the detail view is secondary to making the
          // hit target large enough to be comfortable.
          onTap: isSelectionMode ? onToggleSelect : onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        issue.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: titleTextColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppTheme.spacingXs),
                      Text(
                        issue.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          // When selected the background becomes a sage-green
                          // tint; grayMid loses contrast against it in dark
                          // mode.  Use a high-contrast colour instead.
                          color: descriptionTextColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (isSelectionMode)
                  Padding(
                    padding: const EdgeInsets.only(left: AppTheme.spacingSm),
                    child: Icon(checkboxIcon, color: checkboxColor),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
