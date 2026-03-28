import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../constants/strings.dart';
import '../constants/task_constants.dart';
import '../models/person.dart';
import '../providers/auth_provider.dart';
import '../providers/flat_provider.dart';
import '../repositories/flat_repository.dart';
import '../repositories/person_repository.dart';
import '../router/app_router.dart';

/// Join-flat screen.
///
/// The user enters a flat invite code, their name, email, and password.
/// On submit a Firebase Auth account is created, a Person document is written
/// to the flat's members subcollection, and the flatId is persisted.
class JoinFlatScreen extends StatefulWidget {
  const JoinFlatScreen({super.key});

  @override
  State<JoinFlatScreen> createState() => _JoinFlatScreenState();
}

class _JoinFlatScreenState extends State<JoinFlatScreen> {
  final _formKey      = GlobalKey<FormState>();
  final _codeCtrl     = TextEditingController();
  final _nameCtrl     = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _passwordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final flatProvider = context.read<FlatProvider>();
      final flatRepo     = FlatRepository();
      final personRepo   = PersonRepository();

      // 1. Look up the flat by invite code.
      final flat = await flatRepo.findByInviteCode(_codeCtrl.text.trim().toUpperCase());
      if (flat == null) {
        _showError(errorFlatNotFound);
        return;
      }

      // 2. Create Firebase Auth account.
      final user = await authProvider.register(
        _emailCtrl.text,
        _passwordCtrl.text,
      );
      if (user == null) {
        _showError(authProvider.errorMessage);
        return;
      }
      final emailError = await authProvider.sendVerificationEmail();
      if (emailError.isNotEmpty && mounted) _showError(emailError);

      // 3. Write Person document.
      final person = Person(
        uid: user.uid,
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        role: PersonRole.member,
        onVacation: false,
        swapTokensRemaining: swapTokensPerSemester,
      );
      await personRepo.createMember(flat.id, person);

      // 4. Persist flat and navigate.
      await flatProvider.setFlatId(flat.id, user.uid);
      if (mounted) context.go(routeTasks);
    } catch (_) {
      _showError(errorJoiningFlat);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.stateNotDone,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(headingJoinFlat),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppTheme.spacingMd),
              TextFormField(
                controller: _codeCtrl,
                decoration: const InputDecoration(labelText: labelFlatCode),
                textCapitalization: TextCapitalization.characters,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Flat code is required' : null,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppTheme.spacingSm),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: labelYourName),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Name is required' : null,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppTheme.spacingSm),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: labelYourEmail),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Email is required';
                  if (!v.contains('@')) return 'Enter a valid email';
                  return null;
                },
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppTheme.spacingSm),
              TextFormField(
                controller: _passwordCtrl,
                obscureText: !_passwordVisible,
                decoration: InputDecoration(
                  labelText: labelYourPassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _passwordVisible
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => _passwordVisible = !_passwordVisible),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Password is required';
                  if (v.length < 6 || !v.contains(RegExp(r'\d'))) {
                    return errorWeakPassword;
                  }
                  return null;
                },
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: AppTheme.spacingXl),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(headingJoinFlat),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
