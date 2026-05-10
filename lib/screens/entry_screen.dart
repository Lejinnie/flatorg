import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../constants/app_theme.dart';
import '../constants/strings.dart';
import '../providers/auth_provider.dart';
import '../router/app_router.dart';
import '../widgets/confirmation_dialog.dart';

/// Entry screen shown when the user is authenticated but hasn't joined a flat.
///
/// Two large buttons: create a new flat or join an existing one.
/// A profile icon in the AppBar opens an account management sheet (logout /
/// delete account) accessible before any flat is joined.
class EntryScreen extends StatelessWidget {
  const EntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: headingAccount,
            onPressed: () => _showAccountSheet(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                  child: Image.asset(
                    assetAppIcon,
                    height: 100,
                    width: 100,
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacingMd),
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

void _showAccountSheet(BuildContext context) {
  unawaited(showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppTheme.radiusLg),
      ),
    ),
    builder: (_) => const _AccountSheet(),
  ));
}

/// Minimal account management sheet shown from the entry screen.
///
/// Only Logout and Delete Account are offered here — the user has no flat at
/// this point so no flat-removal step is needed.
class _AccountSheet extends StatelessWidget {
  const _AccountSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacingLg,
        AppTheme.spacingMd,
        AppTheme.spacingLg,
        AppTheme.spacingXl,
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
                color: AppTheme.grayLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacingMd),
          Text(
            headingAccount,
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: AppTheme.spacingLg),
          OutlinedButton.icon(
            icon: const Icon(Icons.logout),
            label: const Text(buttonLogOut),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.destructiveRed,
              side: const BorderSide(color: AppTheme.destructiveRed),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              unawaited(context.read<AuthProvider>().signOut());
            },
          ),
          const SizedBox(height: AppTheme.spacingSm),
          OutlinedButton.icon(
            icon: const Icon(Icons.delete_forever_outlined),
            label: const Text(buttonDeleteAccount),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.destructiveRed,
              side: const BorderSide(color: AppTheme.destructiveRed),
            ),
            onPressed: () => _confirmDeleteAccount(context),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    final messenger    = ScaffoldMessenger.of(context);

    final confirmed = await showConfirmationDialog(
      context,
      title: confirmDeleteAccountTitle,
      message: confirmDeleteAccountMessage,
      confirmLabel: confirmDeleteAccountLabel,
      confirmColor: AppTheme.destructiveRed,
      confirmTextColor: Colors.white,
    );
    if (!confirmed) {
      return;
    }

    // No flat to clean up — the entry screen is only reachable when hasFlat == false.
    final deleted = await authProvider.deleteAccount();
    if (!deleted) {
      messenger.showSnackBar(
        SnackBar(content: Text(authProvider.errorMessage)),
      );
    }
    // Router detects isSignedIn == false and redirects to /login.
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
