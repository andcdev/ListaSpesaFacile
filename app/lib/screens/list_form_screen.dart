import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../models/shopping_list.dart';
import '../services/api_client.dart';
import '../state/lists_controller.dart';
import '../widgets/ui.dart';

/// Creazione (list == null) o modifica di nome, data/ora, note e promemoria di una lista.
/// Alla creazione si possono indicare subito i destinatari con il loro permesso; il proprietario
/// decide anche se chi può modificare la lista può cambiarne il nome.
class ListFormScreen extends StatefulWidget {
  const ListFormScreen({super.key, this.list});

  final ShoppingList? list;

  @override
  State<ListFormScreen> createState() => _ListFormScreenState();
}

class _ListFormScreenState extends State<ListFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.list?.name);
  late final _notes = TextEditingController(text: widget.list?.notes);
  final _recipientEmail = TextEditingController();
  late DateTime _date;
  late TimeOfDay _time;
  late int? _reminderMinutes = widget.list?.reminderMinutes;
  late ReminderTarget _reminderTarget = widget.list?.reminderTarget ?? ReminderTarget.all;
  late bool _membersCanRename = widget.list?.membersCanRename ?? false;
  final List<ShareRequest> _recipients = [];
  String? _recipientError;
  bool _busy = false;

  /// Cambia a ogni scelta del promemoria per ricreare il menu (anche se "Personalizzato…" viene annullato).
  int _reminderFieldVersion = 0;

  bool get _editing => widget.list != null;
  bool get _isOwner => widget.list?.isOwner ?? true;
  bool get _canRename => widget.list?.canRename ?? true;

  @override
  void initState() {
    super.initState();
    final initial = widget.list?.scheduledAt ?? _defaultSchedule();
    _date = DateTime(initial.year, initial.month, initial.day);
    _time = TimeOfDay.fromDateTime(initial);
  }

  /// Proposta: la prossima ora piena.
  static DateTime _defaultSchedule() {
    final next = DateTime.now().add(const Duration(hours: 1));
    return DateTime(next.year, next.month, next.day, next.hour);
  }

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    _recipientEmail.dispose();
    super.dispose();
  }

  DateTime get _scheduledAt => DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  /// Valore del menu che apre la scelta di un anticipo personalizzato.
  static const _customReminder = -1;

  Future<void> _onReminderChanged(int? value) async {
    if (value != _customReminder) {
      setState(() => _reminderMinutes = value);
      return;
    }
    final custom = await showDialog<int>(
      context: context,
      builder: (_) => _CustomReminderDialog(initialMinutes: _reminderMinutes),
    );
    setState(() {
      _reminderMinutes = custom ?? _reminderMinutes;
      _reminderFieldVersion++;
    });
  }

  void _addRecipient() {
    final email = _recipientEmail.text.trim().toLowerCase();
    setState(() {
      if (!email.contains('@')) {
        _recipientError = context.l10n.enterRegisteredEmail;
      } else if (_recipients.any((r) => r.email == email)) {
        _recipientError = context.l10n.alreadyAdded;
      } else {
        _recipients.add(ShareRequest(email));
        _recipientEmail.clear();
        _recipientError = null;
      }
    });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    // Email scritta ma non ancora aggiunta con il pulsante: la aggiungiamo noi.
    if (_recipientEmail.text.trim().isNotEmpty) {
      _addRecipient();
      if (_recipientError != null) return;
    }
    setState(() => _busy = true);
    final lists = context.read<ListsController>();
    final notes = _notes.text.trim().isEmpty ? null : _notes.text.trim();
    try {
      if (_editing) {
        await lists.update(
          widget.list!.id,
          name: _name.text.trim(),
          scheduledAt: _scheduledAt,
          notes: notes,
          reminderMinutes: _reminderMinutes,
          reminderTarget: _reminderTarget,
          membersCanRename: _isOwner ? _membersCanRename : null,
        );
        if (mounted) Navigator.pop(context);
      } else {
        final created = await lists.create(
          name: _name.text.trim(),
          scheduledAt: _scheduledAt,
          notes: notes,
          reminderMinutes: _reminderMinutes,
          reminderTarget: _reminderTarget,
          membersCanRename: _membersCanRename,
          shares: _recipients,
        );
        if (mounted) Navigator.pop(context, created);
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: _editing ? ScreenTitle(widget.list!.name, subtitle: l.editList) : Text(l.newList)),
      body: Wallpaper(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _name,
                autofocus: !_editing,
                readOnly: !_canRename,
                decoration: InputDecoration(
                  labelText: l.name,
                  hintText: l.listNameHint,
                  helperText: _canRename ? null : l.renameLocked,
                  suffixIcon: _canRename ? null : const Icon(Icons.lock_outline),
                ),
                textCapitalization: TextCapitalization.sentences,
                validator: (v) => (v == null || v.trim().isEmpty) ? l.listNameRequired : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text(DateFormat('EEE d MMM y').format(_date)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickTime,
                      icon: const Icon(Icons.schedule),
                      label: Text(_time.format(context)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notes,
                decoration: InputDecoration(labelText: l.notesLabel, hintText: l.notesHint),
                minLines: 2,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 24),
              _SectionTitle(icon: Icons.notifications_active_outlined, title: l.reminder),
              DropdownButtonFormField<int?>(
                initialValue: _reminderMinutes,
                decoration: const InputDecoration(isDense: true),
                items: [
                  DropdownMenuItem(value: null, child: Text(l.noReminder)),
                  DropdownMenuItem(value: 10, child: Text(l.durationBefore(durationLabel(10, l)))),
                  DropdownMenuItem(value: 60, child: Text(l.durationBefore(durationLabel(60, l)))),
                  if (_reminderMinutes != null && _reminderMinutes != 10 && _reminderMinutes != 60)
                    DropdownMenuItem(
                      value: _reminderMinutes,
                      child: Text(l.durationBefore(durationLabel(_reminderMinutes!, l))),
                    ),
                  DropdownMenuItem(value: _customReminder, child: Text(l.customReminderOption)),
                ],
                key: ValueKey(_reminderFieldVersion),
                onChanged: _onReminderChanged,
              ),
              if (_reminderMinutes != null) ...[
                const SizedBox(height: 12),
                Text(l.whoToNotify, style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 4),
                RadioGroup<ReminderTarget>(
                  groupValue: _reminderTarget,
                  onChanged: (v) => setState(() => _reminderTarget = v ?? _reminderTarget),
                  child: Column(
                    children: [
                      for (final target in ReminderTarget.values)
                        RadioListTile<ReminderTarget>(
                          value: target,
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(target.label(l)),
                        ),
                    ],
                  ),
                ),
              ],
              if (!_editing) ...[
                const SizedBox(height: 16),
                _SectionTitle(icon: Icons.person_add_alt_outlined, title: l.shareWith),
                TextField(
                  controller: _recipientEmail,
                  keyboardType: TextInputType.emailAddress,
                  onSubmitted: (_) => _addRecipient(),
                  decoration: InputDecoration(
                    labelText: l.userEmailOptional,
                    helperText: l.willBeNotified,
                    errorText: _recipientError,
                    suffixIcon: IconButton(icon: const Icon(Icons.add), tooltip: l.add, onPressed: _addRecipient),
                  ),
                ),
                for (final (i, r) in _recipients.indexed)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: UserAvatar(initials: r.email[0].toUpperCase()),
                    title: Text(r.email, overflow: TextOverflow.ellipsis),
                    subtitle: Text(r.canEdit ? l.canEdit : l.readOnly),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: r.canEdit,
                          onChanged: (v) => setState(() => _recipients[i] = ShareRequest(r.email, canEdit: v)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          tooltip: l.remove,
                          onPressed: () => setState(() => _recipients.removeAt(i)),
                        ),
                      ],
                    ),
                  ),
              ],
              if (_isOwner) ...[
                const SizedBox(height: 16),
                _SectionTitle(icon: Icons.admin_panel_settings_outlined, title: l.permissions),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _membersCanRename,
                  onChanged: (v) => setState(() => _membersCanRename = v),
                  title: Text(l.membersCanRenameTitle),
                  subtitle: Text(_membersCanRename ? l.membersCanRenameOn : l.membersCanRenameOff),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _busy ? null : _save,
                icon: const Icon(Icons.check),
                label: Text(_editing ? l.saveChanges : l.createList),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(title, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
        ],
      ),
    );
  }
}

/// Anticipo del promemoria a scelta: un numero di minuti, ore o giorni.
class _CustomReminderDialog extends StatefulWidget {
  const _CustomReminderDialog({this.initialMinutes});

  final int? initialMinutes;

  @override
  State<_CustomReminderDialog> createState() => _CustomReminderDialogState();
}

class _CustomReminderDialogState extends State<_CustomReminderDialog> {
  /// Minuti per unità: minuti, ore, giorni.
  static const _units = [1, 60, 1440];
  static const _maxMinutes = 43200; // 30 giorni, come sul server

  late int _unit;
  late final TextEditingController _amount;
  String? _error;

  @override
  void initState() {
    super.initState();
    final minutes = widget.initialMinutes ?? 30;
    _unit = _units.lastWhere((u) => minutes % u == 0);
    _amount = TextEditingController(text: '${minutes ~/ _unit}');
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _confirm() {
    final amount = int.tryParse(_amount.text.trim());
    final minutes = amount == null ? null : amount * _unit;
    if (minutes == null || minutes < 1 || minutes > _maxMinutes) {
      setState(() => _error = context.l10n.reminderRange);
      return;
    }
    Navigator.pop(context, minutes);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final unitLabels = {1: l.unitMinutes, 60: l.unitHours, 1440: l.unitDays};
    return AlertDialog(
      title: Text(l.customReminder),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _amount,
            autofocus: true,
            keyboardType: TextInputType.number,
            onSubmitted: (_) => _confirm(),
            decoration: InputDecoration(labelText: l.howEarly, errorText: _error),
          ),
          const SizedBox(height: 16),
          SegmentedButton<int>(
            segments: [for (final unit in _units) ButtonSegment(value: unit, label: Text(unitLabels[unit]!))],
            selected: {_unit},
            onSelectionChanged: (v) => setState(() => _unit = v.single),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(onPressed: _confirm, child: Text(l.ok)),
      ],
    );
  }
}
