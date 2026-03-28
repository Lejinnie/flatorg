import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../constants/strings.dart';
import '../providers/auth_provider.dart';

/// Shown after registration until the user verifies their email.
///
/// Polls Firebase every 5 seconds so the router redirect fires automatically
/// once verification is confirmed.
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  late Timer _pollTimer;

  @override
  void initState() {
    super.initState();
    // Poll Firebase every 5 seconds to detect when the user clicks the link.
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      await context.read<AuthProvider>().reloadUser();
    });
  }

  @override
  void dispose() {
    _pollTimer.cancel();
    super.dispose();
  }

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
              const Icon(
                Icons.mark_email_unread_outlined,
                size: 64,
                color: AppTheme.featureColor,
              ),
              const SizedBox(height: AppTheme.spacingLg),
              Text(
                verifyEmailHeading,
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.spacingMd),
              Text(
                verifyEmailBody,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.spacingXl),
              ElevatedButton(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await context.read<AuthProvider>().sendVerificationEmail();
                  if (!mounted) return;
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Verification email resent!')),
                  );
                },
                child: const Text(buttonResendEmail),
              ),
              const SizedBox(height: AppTheme.spacingSm),
              OutlinedButton(
                onPressed: () => context.read<AuthProvider>().signOut(),
                child: const Text(buttonSignOut),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
