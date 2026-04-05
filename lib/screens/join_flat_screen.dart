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
/// The user is already registered and verified at this point. They enter only
/// the flat invite code; their name and email are read from the signed-in
/// Firebase Auth user.
class JoinFlatScreen extends StatefulWidget {
  const JoinFlatScreen({super.key});

  @override
  State<JoinFlatScreen> createState() => _JoinFlatScreenState();
}

class _JoinFlatScreenState extends State<JoinFlatScreen> {
  final _formKey  = GlobalKey<FormState>();
  final _codeCtrl = TextEditingController();
  var _isLoading = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
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

      // 2. User is already signed in — read identity from Auth.
      final user = authProvider.currentUser;
      if (user == null) {
        _showError(errorGeneric);
        return;
      }

      // 3. Write Person document.
      // Preserve admin role if this user is the flat's designated admin —
      // e.g. when the admin reinstalls and rejoins via invite code.
      final role = user.uid == flat.adminUid ? PersonRole.admin : PersonRole.member;
      final person = Person(
        uid: user.uid,
        name: user.displayName ?? user.email ?? '',
        email: user.email ?? '',
        role: role,
        onVacation: false,
        swapTokensRemaining: swapTokensPerSemester,
      );
      await personRepo.createMember(flat.id, person);

      // 4. Persist flat and navigate.
      await flatProvider.setFlatId(flat.id, user.uid);
      if (mounted) {
        context.go(routeTasks);
      }
    } on Exception {
      _showError(errorJoiningFlat);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
  Widget build(BuildContext context) =>
      Scaffold(
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
