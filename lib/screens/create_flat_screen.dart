import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../constants/strings.dart';
import '../constants/task_constants.dart';
import '../models/flat.dart';
import '../models/person.dart';
import '../models/task.dart';
import '../providers/auth_provider.dart';
import '../providers/flat_provider.dart';
import '../repositories/flat_repository.dart';
import '../repositories/person_repository.dart';
import '../repositories/task_repository.dart';
import '../router/app_router.dart';

/// Flat creation screen.
///
/// Collects flat name, admin details, and the initial 9 task definitions.
/// On submit it:
///   1. Creates a Firebase Auth account for the admin.
///   2. Generates a random invite code.
///   3. Writes the Flat, Person, and Task documents to Firestore.
///   4. Saves the flatId and navigates to /tasks.
class CreateFlatScreen extends StatefulWidget {
  const CreateFlatScreen({super.key});

  @override
  State<CreateFlatScreen> createState() => _CreateFlatScreenState();
}

class _CreateFlatScreenState extends State<CreateFlatScreen> {
  final _formKey      = GlobalKey<FormState>();
  final _flatNameCtrl = TextEditingController();
  final _nameCtrl     = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _passwordVisible = false;
  bool _isLoading = false;

  // One entry per task: (nameController, subtasksController, dueDate)
  late final List<_TaskEntry> _taskEntries;

  @override
  void initState() {
    super.initState();
    _taskEntries = List.generate(
      taskRingNames.length,
      (i) => _TaskEntry(
        name: taskRingNames[i],
        dueDate: DateTime.now().add(const Duration(days: 7)),
      ),
    );
  }

  @override
  void dispose() {
    _flatNameCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    for (final e in _taskEntries) {
      e.dispose();
    }
    super.dispose();
  }

  // ── Invite code ───────────────────────────────────────────────────────────

  /// Generates a random 6-character uppercase alphanumeric invite code.
  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng   = Random.secure();
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final flatProvider = context.read<FlatProvider>();

      // 1. Create Firebase Auth account.
      final user = await authProvider.register(
        _emailCtrl.text,
        _passwordCtrl.text,
      );
      if (user == null) {
        _showError(authProvider.errorMessage);
        return;
      }
      await authProvider.sendVerificationEmail();

      // 2. Build Firestore documents.
      final flatId     = _db.collection(collectionFlats).doc().id;
      final inviteCode = _generateInviteCode();

      final flat = Flat(
        id: flatId,
        name: _flatNameCtrl.text.trim(),
        adminUid: user.uid,
        inviteCode: inviteCode,
        vacationThresholdWeeks: defaultVacationThresholdWeeks,
        gracePeriodHours: defaultGracePeriodHours,
        reminderHoursBeforeDeadline: defaultReminderHoursBeforeDeadline,
        shoppingCleanupHours: defaultShoppingCleanupHours,
        createdAt: Timestamp.now(),
      );

      final adminPerson = Person(
        uid: user.uid,
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        role: PersonRole.admin,
        onVacation: false,
        swapTokensRemaining: swapTokensPerSemester,
      );

      final tasks = <Task>[];
      for (int i = 0; i < _taskEntries.length; i++) {
        final entry = _taskEntries[i];
        final taskId = _db.collection(collectionTasks).doc().id;
        tasks.add(Task(
          id: taskId,
          name: entry.nameCtrl.text.trim(),
          description: entry.subtasksCtrl.text
              .split('\n')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList(),
          dueDateTime: Timestamp.fromDate(entry.dueDate),
          assignedTo: '',
          originalAssignedTo: '',
          state: TaskState.pending,
          weeksNotCleaned: 0,
          ringIndex: i,
        ));
      }

      // 3. Write to Firestore.
      final flatRepo   = FlatRepository();
      final personRepo = PersonRepository();
      final taskRepo   = TaskRepository();

      await flatRepo.createFlat(flat);
      await personRepo.createMember(flatId, adminPerson);
      for (final task in tasks) {
        await taskRepo.createTask(flatId, task);
      }

      // 4. Persist flatId and navigate.
      await flatProvider.setFlatId(flatId, user.uid);
      if (mounted) context.go(routeTasks);
    } catch (e) {
      _showError(errorCreatingFlat);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.stateNotDone,
      ),
    );
  }

  // ── Due-date picker ───────────────────────────────────────────────────────

  Future<void> _pickDueDate(int index) async {
    final entry = _taskEntries[index];
    final date  = await showDatePicker(
      context: context,
      initialDate: entry.dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(entry.dueDate),
    );
    if (time == null || !mounted) return;

    setState(() {
      _taskEntries[index].dueDate = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(headingCreateFlat),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          children: [
            // ── Flat details ───────────────────────────────────────────
            TextFormField(
              controller: _flatNameCtrl,
              decoration: const InputDecoration(hintText: hintEnterFlatName),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Flat name is required' : null,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: AppTheme.spacingSm),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(hintText: hintEnterName),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Your name is required' : null,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: AppTheme.spacingSm),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(hintText: hintEnterEmail),
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
                hintText: hintEnterPassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _passwordVisible ? Icons.visibility_off : Icons.visibility,
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
              textInputAction: TextInputAction.next,
            ),

            const SizedBox(height: AppTheme.spacingLg),

            // ── Tasks section ──────────────────────────────────────────
            Text(labelWhatTasks, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppTheme.spacingSm),

            ..._taskEntries.asMap().entries.map((e) {
              final i     = e.key;
              final entry = e.value;
              return _buildTaskEntry(context, i, entry);
            }),

            const SizedBox(height: AppTheme.spacingSm),
            OutlinedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text(buttonAddMore),
              onPressed: () {
                setState(() {
                  _taskEntries.add(
                    _TaskEntry(
                      name: '',
                      dueDate: DateTime.now().add(const Duration(days: 7)),
                    ),
                  );
                });
              },
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
                  : const Text(buttonCreateFlat),
            ),
            const SizedBox(height: AppTheme.spacingXl),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskEntry(BuildContext context, int index, _TaskEntry entry) {
    final theme     = Theme.of(context);
    final dueFmt    = DateFormat('d MMM yyyy, HH:mm').format(entry.dueDate);
    final canRemove = _taskEntries.length > 1;

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.grayLight),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: entry.nameCtrl,
                  decoration: const InputDecoration(hintText: 'Task name'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Name required' : null,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              if (canRemove)
                IconButton(
                  icon: const Icon(Icons.remove_circle, color: AppTheme.stateNotDone),
                  tooltip: buttonRemoveTask,
                  onPressed: () => setState(() => _taskEntries.removeAt(index)),
                ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingSm),
          TextFormField(
            controller: entry.subtasksCtrl,
            decoration: const InputDecoration(hintText: hintSubtasks),
            maxLines: 3,
            textInputAction: TextInputAction.newline,
          ),
          const SizedBox(height: AppTheme.spacingSm),
          InkWell(
            onTap: () => _pickDueDate(index),
            child: InputDecorator(
              decoration: const InputDecoration(
                hintText: hintDueDate,
                suffixIcon: Icon(Icons.calendar_today, size: 18),
              ),
              child: Text(dueFmt, style: theme.textTheme.bodyMedium),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mutable state for one task entry in the creation form.
class _TaskEntry {
  final TextEditingController nameCtrl;
  final TextEditingController subtasksCtrl;
  DateTime dueDate;

  _TaskEntry({required String name, required this.dueDate})
      : nameCtrl     = TextEditingController(text: name),
        subtasksCtrl = TextEditingController();

  void dispose() {
    nameCtrl.dispose();
    subtasksCtrl.dispose();
  }
}
