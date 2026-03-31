import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../constants/app_theme.dart';
import '../constants/strings.dart';
import '../constants/task_constants.dart';
import '../models/person.dart';
import '../models/task.dart';
import '../providers/auth_provider.dart';
import '../providers/flat_provider.dart';
import '../repositories/flat_repository.dart';
import '../repositories/person_repository.dart';
import '../repositories/task_repository.dart';
import '../widgets/confirmation_dialog.dart';

/// Settings screen.
///
/// All members see: the member list and invite code button.
/// Admin-only sections are hidden from regular members.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  /// Whether the admin is currently in "remove member" mode.
  var _removeMode = false;

  @override
  Widget build(BuildContext context) {
    final flatProvider  = context.watch<FlatProvider>();
    final currentPerson = flatProvider.currentPerson;
    final isAdmin       = currentPerson?.isAdmin ?? false;
    final flatId        = flatProvider.flatId;

    return GestureDetector(
      // Tapping outside the member list exits remove mode.
      onTap: () {
        if (_removeMode) {
          setState(() => _removeMode = false);
        }
      },
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(headingSettings),
          leading: BackButton(onPressed: () => context.pop()),
        ),
        body: ListView(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          children: [
            // ── Members ───────────────────────────────────────────────
            const _SectionHeader(labelMembers),
            _MembersSection(
              flatId: flatId,
              currentPerson: currentPerson,
              removeMode: _removeMode,
              isAdmin: isAdmin,
              onEnterRemoveMode: () => setState(() => _removeMode = true),
              onExitRemoveMode: () => setState(() => _removeMode = false),
            ),

            const SizedBox(height: AppTheme.spacingMd),

            // Generate invite code button (all members).
            ElevatedButton.icon(
              icon: const Icon(Icons.copy),
              label: const Text(buttonGenerateInvite),
              onPressed: () => _copyInviteCode(context, flatProvider.flat?.inviteCode ?? ''),
            ),

            // ── Admin-only settings ───────────────────────────────────
            if (isAdmin) ...[
              const SizedBox(height: AppTheme.spacingLg),
              const _SectionHeader(labelAdminOnlySettings),
              const SizedBox(height: AppTheme.spacingSm),
              _AdminSettings(flatId: flatId, flatProvider: flatProvider),
            ],

            // ── Log out (all members) ─────────────────────────────────
            const SizedBox(height: AppTheme.spacingLg),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.logout),
                label: const Text(buttonLogOut),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.destructiveRed,
                  side: const BorderSide(color: AppTheme.destructiveRed),
                ),
                onPressed: () => _confirmLogOut(context),
              ),
            ),
            const SizedBox(height: AppTheme.spacingXl),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLogOut(BuildContext context) async {
    // Capture before the async gap to avoid BuildContext-across-async-gap lint.
    final authProvider = context.read<AuthProvider>();
    final confirmed = await showConfirmationDialog(
      context,
      title: confirmLogOutTitle,
      message: confirmLogOutMessage,
      confirmLabel: confirmLogOutLabel,
      confirmColor: AppTheme.destructiveRed,
      confirmTextColor: Colors.white,
    );
    if (!confirmed || !mounted) {
      return;
    }
    await authProvider.signOut();
  }

  void _copyInviteCode(BuildContext context, String code) {
    if (code.isEmpty) {
      return;
    }
    unawaited(Clipboard.setData(ClipboardData(text: code)));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(inviteCodeCopied)),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppTheme.spacingXs),
    child: Text(
      label,
      style: Theme.of(context).textTheme.titleMedium,
    ),
  );
}

// ── Members section ───────────────────────────────────────────────────────────

class _MembersSection extends StatelessWidget {
  const _MembersSection({
    required this.flatId,
    required this.currentPerson,
    required this.removeMode,
    required this.isAdmin,
    required this.onEnterRemoveMode,
    required this.onExitRemoveMode,
  });

  final String flatId;
  final Person? currentPerson;
  final bool removeMode;
  final bool isAdmin;
  final VoidCallback onEnterRemoveMode;
  final VoidCallback onExitRemoveMode;

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<List<Person>>(
        stream: PersonRepository().watchMembers(flatId),
      builder: (ctx, snap) {
        final members = snap.data ?? [];
        return Column(
          children: members.map((member) {
            final isSelf = member.uid == currentPerson?.uid;
            final isThisAdmin = member.isAdmin;

            return GestureDetector(
              // opaque so the whole tile area (including padding) is a valid
              // long-press target, not just the text inside it.
              behavior: HitTestBehavior.opaque,
              onLongPress: isAdmin && !isSelf
                  ? onEnterRemoveMode
                  : null,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: AppTheme.spacingXs),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingMd,
                  vertical: AppTheme.spacingSm,
                ),
                decoration: BoxDecoration(
                  color: removeMode && !isSelf
                      ? AppTheme.stateNotDone.withAlpha(30)
                      : Theme.of(ctx).cardTheme.color,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(
                    color: removeMode && !isSelf
                        ? AppTheme.stateNotDone
                        : AppTheme.grayLight,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            member.name.isNotEmpty ? member.name : member.email,
                            style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                              color: removeMode && !isSelf
                                  ? AppTheme.stateNotDone
                                  : null,
                            ),
                          ),
                          if (isThisAdmin) ...[
                            const SizedBox(width: AppTheme.spacingXs),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.featureColor.withAlpha(60),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                labelAdminBadge,
                                style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                                  color: AppTheme.grayDark,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (removeMode && !isSelf)
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: AppTheme.stateNotDone,
                        ),
                        onPressed: () =>
                            _confirmRemove(ctx, flatId, member, onExitRemoveMode),
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
      );

  Future<void> _confirmRemove(
    BuildContext context,
    String flatId,
    Person member,
    VoidCallback onExit,
  ) async {
    final msg = confirmRemoveMessage.replaceFirst('{name}', member.name);
    final confirmed = await showConfirmationDialog(
      context,
      title: confirmRemoveTitle,
      message: msg,
      confirmLabel: confirmRemoveLabel,
      confirmColor: AppTheme.destructiveRed,
      confirmTextColor: Colors.white,
    );
    if (!confirmed) {
      return;
    }
    await PersonRepository().removeMember(flatId, member.uid);
    onExit();
  }
}

// ── Duration unit toggle ──────────────────────────────────────────────────────

/// Whether the user is currently editing duration in hours or days.
enum _DurationUnit { hours, days }

// ── Admin settings ────────────────────────────────────────────────────────────

class _AdminSettings extends StatefulWidget {
  const _AdminSettings({required this.flatId, required this.flatProvider});
  final String flatId;
  final FlatProvider flatProvider;

  @override
  State<_AdminSettings> createState() => _AdminSettingsState();
}

class _AdminSettingsState extends State<_AdminSettings> {
  // Flat settings controllers — initialised lazily when flat data arrives.
  late int _vacationWeeks;
  late int _gracePeriodHours;
  late int _cleanupHours;
  late int _reminderHours;

  var _settingsInitialised = false;

  // Duration unit toggles for grace period and reminder settings.
  _DurationUnit _gracePeriodUnit = _DurationUnit.hours;
  _DurationUnit _reminderUnit    = _DurationUnit.hours;

  void _initSettings() {
    final flat = widget.flatProvider.flat;
    if (flat != null && !_settingsInitialised) {
      _vacationWeeks    = flat.vacationThresholdWeeks;
      _gracePeriodHours = flat.gracePeriodHours;
      _cleanupHours     = flat.shoppingCleanupHours;
      _reminderHours    = flat.reminderHoursBeforeDeadline;
      _settingsInitialised = true;
    }
  }

  Future<void> _saveSetting(String field, dynamic value) async {
    await FlatRepository().updateFlatSettings(widget.flatId, {field: value});
  }

  @override
  Widget build(BuildContext context) {
    _initSettings();
    final flat = widget.flatProvider.flat;
    if (flat == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Vacation threshold
        _NumberSettingRow(
          label: labelVacationThreshold,
          value: _vacationWeeks,
          unit: labelUnitWeeks,
          onChanged: (v) {
            setState(() => _vacationWeeks = v);
            unawaited(_saveSetting('vacation_threshold_weeks', v));
          },
        ),
        const Divider(),

        // Grace period — supports hours or days unit toggle.
        _DurationSettingRow(
          label: labelGracePeriod,
          storedHours: _gracePeriodHours,
          unit: _gracePeriodUnit,
          onUnitChanged: (u) => setState(() => _gracePeriodUnit = u),
          onHoursChanged: (h) {
            setState(() => _gracePeriodHours = h);
            unawaited(_saveSetting('grace_period_hours', h));
          },
        ),
        const Divider(),

        // Shopping cleanup
        _NumberSettingRow(
          label: labelShoppingCleanup,
          value: _cleanupHours,
          unit: labelUnitHours,
          onChanged: (v) {
            setState(() => _cleanupHours = v);
            unawaited(_saveSetting('shopping_cleanup_hours', v));
          },
        ),
        const Divider(),

        // Reminder — supports hours or days unit toggle.
        _DurationSettingRow(
          label: labelReminderHours,
          storedHours: _reminderHours,
          unit: _reminderUnit,
          onUnitChanged: (u) => setState(() => _reminderUnit = u),
          onHoursChanged: (h) {
            setState(() => _reminderHours = h);
            unawaited(_saveSetting('reminder_hours_before_deadline', h));
          },
        ),
        const Divider(),

        const SizedBox(height: AppTheme.spacingMd),

        // Change Tasks section
        const _SectionHeader(labelChangeTasks),
        _TasksAdminSection(flatId: widget.flatId),

        const SizedBox(height: AppTheme.spacingMd),

        // Reset all admin settings to factory defaults.
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.restart_alt),
            label: const Text(buttonResetDefaults),
            onPressed: () => _resetToDefaults(context),
          ),
        ),

        const SizedBox(height: AppTheme.spacingSm),

        // Transfer admin rights
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.destructiveRed,
              side: const BorderSide(color: AppTheme.destructiveRed),
            ),
            onPressed: () => _showTransferAdminDialog(context),
            child: const Text(labelTransferAdmin),
          ),
        ),

        const SizedBox(height: AppTheme.spacingXl),
      ],
    );
  }

  Future<void> _resetToDefaults(BuildContext context) async {
    final confirmed = await showConfirmationDialog(
      context,
      title: confirmResetTitle,
      message: confirmResetMessage,
      confirmLabel: confirmResetLabel,
    );
    if (!confirmed || !mounted) {
      return;
    }

    await FlatRepository().updateFlatSettings(widget.flatId, {
      fieldFlatVacationThreshold:   defaultVacationThresholdWeeks,
      fieldFlatGracePeriodHours:    defaultGracePeriodHours,
      fieldFlatReminderHours:       defaultReminderHoursBeforeDeadline,
      fieldFlatShoppingCleanupHours: defaultShoppingCleanupHours,
    });

    // Force _initSettings to re-read from the flat document on next build.
    setState(() => _settingsInitialised = false);
  }

  Future<void> _showTransferAdminDialog(BuildContext outerCtx) async {
    final members = await PersonRepository().watchMembers(widget.flatId).first;
    final eligible = members
        .where((m) => m.uid != widget.flatProvider.currentPerson?.uid)
        .toList();

    if (eligible.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(labelTransferAdminAlone)),
      );
      return;
    }
    if (!mounted) {
      return;
    }

    String? selectedUid = eligible.first.uid;

    if (!mounted) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          title: const Text(labelTransferAdmin),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                labelSelectMember,
                style: Theme.of(ctx).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppTheme.spacingSm),
              DropdownButton<String>(
                value: selectedUid,
                isExpanded: true,
                items: eligible
                    .map((m) => DropdownMenuItem(
                          value: m.uid,
                          child: Text(m.name),
                        ))
                    .toList(),
                onChanged: (v) => setDialogState(() => selectedUid = v),
              ),
            ],
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text(buttonCancel),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.destructiveRed,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text(confirmAdminLabel),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || selectedUid == null) {
      return;
    }

    final newAdmin   = eligible.firstWhere((m) => m.uid == selectedUid);
    final confirmMsg = confirmAdminMessage.replaceFirst('{name}', newAdmin.name);
    if (!mounted) {
      return;
    }
    final doubleConfirmed = await showConfirmationDialog(
      context,
      title: confirmAdminTitle,
      message: confirmMsg,
      confirmLabel: confirmAdminLabel,
      confirmColor: AppTheme.destructiveRed,
      confirmTextColor: Colors.white,
    );
    if (!doubleConfirmed) {
      return;
    }

    final currentAdminUid = widget.flatProvider.currentPerson?.uid ?? '';

    // Update flat's admin_uid.
    await FlatRepository().updateFlatSettings(
      widget.flatId,
      {'admin_uid': selectedUid},
    );

    // Downgrade current admin to member.
    await PersonRepository().updateMember(
      widget.flatId,
      currentAdminUid,
      {'role': 'member'},
    );

    // Upgrade new admin.
    await PersonRepository().updateMember(
      widget.flatId,
      selectedUid!,
      {'role': 'admin'},
    );
  }
}

// ── Task editing section (admin) ──────────────────────────────────────────────

class _TasksAdminSection extends StatefulWidget {
  const _TasksAdminSection({required this.flatId});
  final String flatId;

  @override
  State<_TasksAdminSection> createState() => _TasksAdminSectionState();
}

class _TasksAdminSectionState extends State<_TasksAdminSection> {
  @override
  Widget build(BuildContext context) =>
      StreamBuilder<List<Task>>(
        stream: TaskRepository().watchTasks(widget.flatId),
        builder: (ctx, taskSnap) {
          final tasks = taskSnap.data ?? [];
          return StreamBuilder<List<Person>>(
            stream: PersonRepository().watchMembers(widget.flatId),
            builder: (ctx, memberSnap) {
              final members = memberSnap.data ?? [];
              return Column(
                children: tasks.map((task) => _TaskEditTile(
                  flatId: widget.flatId,
                  task: task,
                  members: members,
                )).toList(),
              );
            },
          );
        },
      );
}

class _TaskEditTile extends StatefulWidget {
  const _TaskEditTile({
    required this.flatId,
    required this.task,
    required this.members,
  });
  final String flatId;
  final Task task;

  /// All current flat members, used for the assignee dropdown.
  final List<Person> members;

  @override
  State<_TaskEditTile> createState() => _TaskEditTileState();
}

class _TaskEditTileState extends State<_TaskEditTile> {
  var _expanded = false;
  late TextEditingController _nameCtrl;
  late TextEditingController _subtasksCtrl;
  late DateTime _dueDate;
  late String _assignedTo;

  @override
  void initState() {
    super.initState();
    _nameCtrl     = TextEditingController(text: widget.task.name);
    _subtasksCtrl = TextEditingController(
      text: widget.task.description.join('\n'),
    );
    _dueDate    = widget.task.dueDateTime.toDate();
    _assignedTo = widget.task.assignedTo;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _subtasksCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) {
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dueDate),
    );
    if (time == null || !mounted) {
      return;
    }
    setState(() {
      _dueDate = DateTime(
        date.year, date.month, date.day, time.hour, time.minute,
      );
    });
  }

  Future<void> _save() async {
    final repo = TaskRepository();
    await repo.updateTaskDetails(
      widget.flatId,
      widget.task.id,
      name: _nameCtrl.text.trim(),
      description: _subtasksCtrl.text
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(),
    );
    await repo.updateDueDateTime(widget.flatId, widget.task.id, _dueDate);
    await repo.updateTask(widget.flatId, widget.task.id, {
      fieldTaskAssignedTo: _assignedTo,
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(labelChangeTasks)),
      );
      setState(() => _expanded = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme  = Theme.of(context);
    final dueFmt = DateFormat('d MMM yyyy, HH:mm').format(_dueDate);

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingSm),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.grayLight),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Column(
        children: [
          ListTile(
            title: Text(widget.task.name, style: theme.textTheme.bodyMedium),
            trailing: Icon(
              _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
            ),
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spacingMd,
                0,
                AppTheme.spacingMd,
                AppTheme.spacingMd,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(hintText: 'Task name'),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: AppTheme.spacingSm),
                  TextField(
                    controller: _subtasksCtrl,
                    decoration: const InputDecoration(hintText: hintSubtasks),
                    maxLines: 3,
                  ),
                  const SizedBox(height: AppTheme.spacingSm),
                  InkWell(
                    onTap: _pickDueDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        suffixIcon: Icon(Icons.calendar_today, size: 18),
                      ),
                      child: Text(dueFmt, style: theme.textTheme.bodyMedium),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingSm),

                  // Assignee dropdown — empty string means Vacant (no one).
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: labelAssignedToTask,
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: widget.members.any((m) => m.uid == _assignedTo)
                            ? _assignedTo
                            : '',
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem(
                            value: '',
                            child: Text(labelVacant),
                          ),
                          ...widget.members.map(
                            (m) => DropdownMenuItem(
                              value: m.uid,
                              child: Text(
                                m.name.isNotEmpty ? m.name : m.email,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (v) =>
                            setState(() => _assignedTo = v ?? ''),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingSm),
                  ElevatedButton(
                    onPressed: _save,
                    child: const Text(buttonConfirm),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Number setting row widget ─────────────────────────────────────────────────

class _NumberSettingRow extends StatelessWidget {
  const _NumberSettingRow({
    required this.label,
    required this.value,
    required this.unit,
    required this.onChanged,
  });

  final String label;
  final int value;
  final String unit;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingSm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppTheme.spacingXs),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: value > 1 ? () => onChanged(value - 1) : null,
              ),
              SizedBox(
                width: 48,
                child: Text(
                  '$value',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => onChanged(value + 1),
              ),
              const SizedBox(width: AppTheme.spacingXs),
              Text(unit, style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.grayMid,
              )),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Duration setting row (hours / days toggle) ────────────────────────────────

/// A [_NumberSettingRow] variant that lets the admin toggle between hours and
/// days.  Values are always stored internally as hours; the toggle changes only
/// the display granularity (1 day = 24 hours).
class _DurationSettingRow extends StatelessWidget {
  const _DurationSettingRow({
    required this.label,
    required this.storedHours,
    required this.unit,
    required this.onUnitChanged,
    required this.onHoursChanged,
  });

  final String label;

  /// The current value in hours as stored in Firestore.
  final int storedHours;

  final _DurationUnit unit;
  final ValueChanged<_DurationUnit> onUnitChanged;

  /// Called with the new value in hours whenever the stepper changes.
  final ValueChanged<int> onHoursChanged;

  int get _displayValue =>
      unit == _DurationUnit.days ? (storedHours / 24).round().clamp(1, 9999) : storedHours;

  /// Minimum storedHours: 1 h or 24 h (1 day) depending on unit.
  int get _minHours => unit == _DurationUnit.days ? 24 : 1;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingSm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppTheme.spacingXs),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: storedHours > _minHours
                    ? () => onHoursChanged(storedHours - _minHours)
                    : null,
              ),
              SizedBox(
                width: 48,
                child: Text(
                  '$_displayValue',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => onHoursChanged(storedHours + _minHours),
              ),
              const SizedBox(width: AppTheme.spacingXs),
              SegmentedButton<_DurationUnit>(
                segments: const [
                  ButtonSegment(
                    value: _DurationUnit.hours,
                    label: Text(labelUnitHours),
                  ),
                  ButtonSegment(
                    value: _DurationUnit.days,
                    label: Text(labelUnitDays),
                  ),
                ],
                selected: {unit},
                onSelectionChanged: (s) => onUnitChanged(s.first),
                style: SegmentedButton.styleFrom(
                  textStyle: theme.textTheme.bodySmall,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
