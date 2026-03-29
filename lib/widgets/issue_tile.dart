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
    final theme     = Theme.of(context);
    final onCooldown = issue.isOnCooldown;
    final isDark    = theme.brightness == Brightness.dark;

    final cardColor = isSelected
        ? AppTheme.accentColor.withAlpha(100)
        : (isDark ? const Color(0xFF333333) : Colors.white);

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
          onTap: onTap,
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
                          color: onCooldown ? AppTheme.grayMid : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppTheme.spacingXs),
                      Text(
                        issue.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.grayMid,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (isSelectionMode)
                  GestureDetector(
                    onTap: onToggleSelect,
                    child: Padding(
                      padding: const EdgeInsets.only(left: AppTheme.spacingSm),
                      child: Icon(
                        isSelected
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                        color: isSelected
                            ? AppTheme.featureColor
                            : AppTheme.grayMid,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
