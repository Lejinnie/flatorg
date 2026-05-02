import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_theme.dart';
import '../constants/strings.dart';
import '../providers/auth_provider.dart';

/// Login / Register screen.
///
/// Both sections live on one scrollable page — the user can log in or create
/// a new account without switching tabs. Social sign-in buttons (Google, and
/// Apple on iOS) sit between the Login form and the email-based Register form.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Login form
  final _loginEmailCtrl    = TextEditingController();
  final _loginPasswordCtrl = TextEditingController();
  final _loginFormKey      = GlobalKey<FormState>();
  var _loginPasswordVisible = false;

  // Register form
  final _regNameCtrl     = TextEditingController();
  final _regEmailCtrl    = TextEditingController();
  final _regPasswordCtrl = TextEditingController();
  final _regFormKey      = GlobalKey<FormState>();
  var _regPasswordVisible = false;

  @override
  void dispose() {
    _loginEmailCtrl.dispose();
    _loginPasswordCtrl.dispose();
    _regNameCtrl.dispose();
    _regEmailCtrl.dispose();
    _regPasswordCtrl.dispose();
    super.dispose();
  }

  // ── Validators ────────────────────────────────────────────────────────────

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) {
      return 'Email is required';
    }
    if (!v.contains('@')) {
      return 'Enter a valid email';
    }
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) {
      return 'Password is required';
    }
    if (v.length < 6) {
      return errorWeakPassword;
    }
    if (!v.contains(RegExp(r'\d'))) {
      return errorWeakPassword;
    }
    return null;
  }

  String? _validateName(String? v) {
    if (v == null || v.trim().isEmpty) {
      return 'Name is required';
    }
    return null;
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _login() async {
    if (!_loginFormKey.currentState!.validate()) {
      return;
    }
    final auth = context.read<AuthProvider>();
    final user = await auth.signIn(
      _loginEmailCtrl.text,
      _loginPasswordCtrl.text,
    );
    if (user == null && mounted) {
      _showError(auth.errorMessage);
    }
    // On success the router redirect handles navigation automatically.
  }

  Future<void> _register() async {
    if (!_regFormKey.currentState!.validate()) {
      return;
    }
    final auth = context.read<AuthProvider>();
    final user = await auth.register(
      _regEmailCtrl.text,
      _regPasswordCtrl.text,
    );
    if (user == null && mounted) {
      _showError(auth.errorMessage);
      return;
    }
    // Persist name in Firebase Auth so create/join flat screens can read it.
    await auth.saveDisplayName(_regNameCtrl.text.trim());
    final emailError = await auth.sendVerificationEmail();
    if (emailError.isNotEmpty && mounted) {
      _showError(emailError);
    }
    // Router redirect will move to /verify-email.
  }

  Future<void> _forgotPassword() async {
    final email = _loginEmailCtrl.text.trim();
    if (email.isEmpty) {
      _showError('Enter your email above first.');
      return;
    }
    final auth    = context.read<AuthProvider>();
    final success = await auth.sendPasswordReset(email);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? resetLinkSent : auth.errorMessage),
          backgroundColor: success ? AppTheme.featureColor : AppTheme.stateNotDone,
        ),
      );
    }
  }

  Future<void> _signInWithGoogle() async {
    final auth = context.read<AuthProvider>();
    final user = await auth.signInWithGoogle();
    if (user == null && auth.errorMessage.isNotEmpty && mounted) {
      _showError(auth.errorMessage);
    }
    // On success the router redirect handles navigation automatically.
  }

  Future<void> _signInWithApple() async {
    final auth = context.read<AuthProvider>();
    final user = await auth.signInWithApple();
    if (user == null && auth.errorMessage.isNotEmpty && mounted) {
      _showError(auth.errorMessage);
    }
    // On success the router redirect handles navigation automatically.
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.stateNotDone,
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme   = Theme.of(context);
    final isLoading = context.watch<AuthProvider>().isLoading;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppTheme.spacingXl),
              Image.asset(
                'assets/images/logo.png',
                height: 100,
                width: 100,
              ),
              const SizedBox(height: AppTheme.spacingMd),
              Text(
                headingWelcome,
                style: theme.textTheme.displayLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.spacingXl),

              // ── Login section ─────────────────────────────────────────
              Text(labelLogin, style: theme.textTheme.titleMedium),
              const SizedBox(height: AppTheme.spacingSm),
              Form(
                key: _loginFormKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _loginEmailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(hintText: hintEnterEmail),
                      validator: _validateEmail,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: AppTheme.spacingSm),
                    TextFormField(
                      controller: _loginPasswordCtrl,
                      obscureText: !_loginPasswordVisible,
                      decoration: InputDecoration(
                        hintText: hintEnterPassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _loginPasswordVisible
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () => setState(
                            () => _loginPasswordVisible = !_loginPasswordVisible,
                          ),
                        ),
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Password is required' : null,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _login(),
                    ),
                    const SizedBox(height: AppTheme.spacingXs),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _forgotPassword,
                        child: const Text(buttonForgotPassword),
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _login,
                        child: isLoading
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text(buttonLogin),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.spacingLg),

              // ── Social sign-in ────────────────────────────────────────
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingSm),
                    child: Text(
                      labelOrContinueWith,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppTheme.grayMid),
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: AppTheme.spacingMd),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: isLoading ? null : _signInWithGoogle,
                  icon: const Text(
                    'G',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4285F4),
                    ),
                  ),
                  label: const Text(buttonSignInWithGoogle),
                ),
              ),
              if (defaultTargetPlatform == TargetPlatform.iOS) ...[
                const SizedBox(height: AppTheme.spacingSm),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: isLoading ? null : _signInWithApple,
                    icon: const Icon(Icons.apple, size: 22),
                    label: const Text(buttonSignInWithApple),
                  ),
                ),
              ],

              const SizedBox(height: AppTheme.spacingXl),
              const Divider(),
              const SizedBox(height: AppTheme.spacingLg),

              // ── Register section ──────────────────────────────────────
              Text(labelRegister, style: theme.textTheme.titleMedium),
              const SizedBox(height: AppTheme.spacingSm),
              Form(
                key: _regFormKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _regNameCtrl,
                      decoration: const InputDecoration(hintText: hintEnterName),
                      validator: _validateName,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: AppTheme.spacingSm),
                    TextFormField(
                      controller: _regEmailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(hintText: hintEnterEmail),
                      validator: _validateEmail,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: AppTheme.spacingSm),
                    TextFormField(
                      controller: _regPasswordCtrl,
                      obscureText: !_regPasswordVisible,
                      decoration: InputDecoration(
                        hintText: hintEnterPassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _regPasswordVisible
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () => setState(
                            () => _regPasswordVisible = !_regPasswordVisible,
                          ),
                        ),
                      ),
                      validator: _validatePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _register(),
                    ),
                    const SizedBox(height: AppTheme.spacingMd),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _register,
                        child: isLoading
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text(buttonRegister),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.spacingXl),
            ],
          ),
        ),
      ),
    );
  }
}
