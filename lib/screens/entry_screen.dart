import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_theme.dart';
import '../constants/strings.dart';
import '../router/app_router.dart';

/// Entry screen shown when the user is authenticated but hasn't joined a flat.
///
/// Two large buttons: create a new flat or join an existing one.
class EntryScreen extends StatelessWidget {
  const EntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                headingWelcome,
                style: theme.textTheme.displayLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.spacingMd),
              Text(
                entrySubtitle,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppTheme.grayMid,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.spacingXl),
              _EntryButton(
                label: buttonCreateFlat,
                onTap: () => context.push(routeCreateFlat),
              ),
              const SizedBox(height: AppTheme.spacingMd),
              _EntryButton(
                label: buttonJoinFlat,
                onTap: () => context.push(routeJoinFlat),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Large, outlined entry button used on the entry screen.
class _EntryButton extends StatelessWidget {
  const _EntryButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.grayLight, width: 1.5),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        alignment: Alignment.center,
        child: Text(label, style: theme.textTheme.titleMedium),
      ),
    );
  }
}
