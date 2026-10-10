import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../models/shopping_list.dart';
import '../models/supermarket.dart';
import '../services/api_client.dart';
import '../state/lists_controller.dart';
import '../widgets/permission_picker.dart';
import '../widgets/photo_picker.dart';
import '../widgets/ui.dart';

/// Creazione (list == null) o modifica di nome, data/ora, supermercato, note e promemoria di una lista.
/// Alla creazione si possono indicare subito i destinatari con il loro permesso; il proprietario
/// decide anche se chi può modificare la lista può cambiarne il nome.
/// Con [copyOf] crea una copia di quella lista: il modulo parte dai suoi dati, il server copia articoli e foto.
class ListFormScreen extends StatefulWidget {
  const ListFormScreen({super.key, this.list, this.copyOf});

  final ShoppingList? list;
  final ShoppingList? copyOf;

  @override
  State<ListFormScreen> createState() => _ListFormScreenState();
}

class _ListFormScreenState extends State<ListFormScreen> {
  final _form = GlobalKey<FormState>();

  /// Lista da cui partono i campi: quella da modificare o quella da copiare.
  late final ShoppingList? _source = widget.list ?? widget.copyOf;
  late final _name = TextEditingController(text: _source?.name);
  late final _notes = TextEditingController(text: _source?.notes);
  late String _supermarket = _source?.supermarket ?? '';

  /// Catene note, suggerite mentre si scrive il supermercato.
  List<Supermarket> _chains = const [];
  final _recipientEmail = TextEditingController();
  late DateTime _date;
  late TimeOfDay _time;
  late int? _reminderMinutes = _source?.reminderMinutes;
  late ReminderTarget _reminderTarget = _source?.reminderTarget ?? ReminderTarget.all;
  late bool _membersCanRename = _source?.membersCanRename ?? false;

  /// Copiando una propria lista si propongono le stesse persone, con lo stesso permesso.
  late final List<ShareRequest> _recipients = [
    if (widget.copyOf?.isOwner ?? false)
      for (final u in widget.copyOf!.sharedWith) ShareRequest(u.email, canEdit: u.canEdit != false),
  ];

  /// Foto della lista scelta alla creazione: si carica appena la lista esiste.
  String? _photoPath;
  String? _recipientError;
  bool _busy = false;

  /// Cambia a ogni scelta del promemoria per ricreare il menu (anche se "Personalizzato…" viene annullato).
  int _reminderFieldVersion = 0;

  bool get _editing => widget.list != null;
  bool get _copying => widget.copyOf != null;
  bool get _isOwner => widget.list?.isOwner ?? true;
  bool get _canRename => widget.list?.canRename ?? true;

  @override
  void initState() {
    super.initState();
    final initial = widget.list?.scheduledAt ?? (_copying ? _nextAt(widget.copyOf!.scheduledAt) : _defaultSchedule());
    _date = DateTime(initial.year, initial.month, initial.day);
    _time = TimeOfDay.fromDateTime(initial);
    _loadChains();
  }

  Future<void> _loadChains() async {
    try {
      final chains = await context.read<ApiClient>().supermarkets();
      if (mounted) setState(() => _chains = chains);
    } catch (_) {
      // Senza suggerimenti il supermercato si scrive comunque.
    }
  }

  /// Proposta: la prossima ora piena.
  static DateTime _defaultSchedule() {
    final next = DateTime.now().add(const Duration(hours: 1));
    return DateTime(next.year, next.month, next.day, next.hour);
  }

  /// Copia: la prima volta, da adesso in poi, alla stessa ora della lista copiata.
  static DateTime _nextAt(DateTime original) {
    final now = DateTime.now();
    var next = DateTime(now.year, now.month, now.day, original.hour, original.minute);
    if (!next.isAfter(now)) next = DateTime(now.year, now.month, now.day + 1, original.hour, original.minute);
    return next;
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

  Future<void> _pickPhoto() async {
    final choice = await askPhotoSource(context, canRemove: _photoPath != null, title: context.l10n.listPhoto);
    if (choice == null) return;
    if (choice == PhotoChoice.remove) {
      setState(() => _photoPath = null);
      return;
    }
    try {
      final path = await pickPhoto(choice);
      if (path != null && mounted) setState(() => _photoPath = path);
    } catch (e) {
      if (mounted) showError(context, e);
    }
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
    final api = context.read<ApiClient>();
    final notes = _notes.text.trim().isEmpty ? null : _notes.text.trim();
    final supermarket = _supermarket.trim().isEmpty ? null : _supermarket.trim();
    try {
      if (_editing) {
        await lists.update(
          widget.list!.id,
          name: _name.text.trim(),
          scheduledAt: _scheduledAt,
          notes: notes,
          supermarket: supermarket,
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
          supermarket: supermarket,
          reminderMinutes: _reminderMinutes,
          reminderTarget: _reminderTarget,
          membersCanRename: _membersCanRename,
          shares: _recipients,
          copyFrom: widget.copyOf?.id,
        );
        if (_photoPath != null) {
          try {
            await api.uploadListImage(created.id, _photoPath!);
            await lists.load();
          } catch (_) {
            // La lista c'è comunque: la foto si può aggiungere dopo dal menu.
            if (mounted) showMessage(context, context.l10n.listPhotoUploadFailed);
          }
        }
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
      appBar: AppBar(
        title: _editing
            ? ScreenTitle(widget.list!.name, subtitle: l.editList)
            : _copying
            ? ScreenTitle(widget.copyOf!.name, subtitle: l.duplicateList)
            : Text(l.newList),
      ),
      body: Wallpaper(
        child: Form(
          key: _form,
          child: ListView(
            // In fondo anche lo spazio della barra di navigazione di Android, che altrimenti copre "Crea lista".
            padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + MediaQuery.viewPaddingOf(context).bottom),
            children: [
              if (_copying) ...[
                Text(l.copyInfo, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 16),
              ],
              // Alla creazione: foto della lista (fa da sfondo alla testata della lista).
              if (!_editing) ...[_ListPhotoPicker(path: _photoPath, onPressed: _pickPhoto), const SizedBox(height: 16)],
              TextFormField(
                controller: _name,
                autofocus: !_editing && !_copying,
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
              Autocomplete<Supermarket>(
                initialValue: TextEditingValue(text: _supermarket),
                displayStringForOption: (s) => s.name,
                optionsBuilder: (value) {
                  final query = value.text.trim().toLowerCase();
                  return _chains.where((s) => query.isEmpty || s.name.toLowerCase().contains(query));
                },
                onSelected: (s) => _supermarket = s.name,
                fieldViewBuilder: (context, controller, focusNode, onSubmitted) => TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  onChanged: (v) => _supermarket = v,
                  onFieldSubmitted: (_) => onSubmitted(),
                  maxLength: 100,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: l.supermarketLabel,
                    hintText: l.supermarketHint,
                    helperText: l.supermarketHelper,
                    helperMaxLines: 2,
                    counterText: '',
                    prefixIcon: const Icon(Icons.storefront_outlined),
                  ),
                ),
                optionsViewBuilder: (context, onSelected, options) => Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(16),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 260, maxWidth: 360),
                      child: ListView(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        children: [
                          for (final s in options)
                            ListTile(
                              dense: true,
                              title: Text(s.name),
                              subtitle: s.description == null ? null : Text(s.description!),
                              onTap: () => onSelected(s),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
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
                    subtitle: PermissionPicker(
                      canEdit: r.canEdit,
                      onChanged: (v) => setState(() => _recipients[i] = ShareRequest(r.email, canEdit: v)),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: l.remove,
                      onPressed: () => setState(() => _recipients.removeAt(i)),
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
                label: Text(_editing ? l.saveChanges : (_copying ? l.createCopy : l.createList)),
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

/// Foto della lista nel modulo di creazione: un pulsante, o l'anteprima della foto scelta (toccala per cambiarla
/// o toglierla).
class _ListPhotoPicker extends StatelessWidget {
  const _ListPhotoPicker({required this.path, required this.onPressed});

  final String? path;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    if (path == null) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.add_a_photo_outlined),
        label: Text(l.addPhoto),
      );
    }
    return Semantics(
      button: true,
      label: l.changePhoto,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: 150,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(File(path!), fit: BoxFit.cover),
              Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: FilledButton.tonalIcon(
                    onPressed: onPressed,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: Text(l.changePhoto),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
