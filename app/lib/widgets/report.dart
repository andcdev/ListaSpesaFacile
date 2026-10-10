import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../services/api_client.dart';
import '../state/auth_controller.dart';
import 'ui.dart';

/// Tipo di segnalazione: un problema dell'app, una persona o un messaggio della chat.
enum ReportType {
  problem('problem'),
  user('user'),
  message('message');

  const ReportType(this.value);

  final String value;
}

/// Segnalazione all'assistenza (arriva per email a support@). Per un problema il testo è obbligatorio, per una
/// persona o un messaggio è facoltativo.
Future<void> showReportDialog(
  BuildContext context, {
  required ReportType type,
  required String title,
  int? userId,
  int? listId,
  int? messageId,
}) async {
  final sent = await showDialog<bool>(
    context: context,
    builder: (_) => _ReportDialog(type: type, title: title, userId: userId, listId: listId, messageId: messageId),
  );
  if (sent == true && context.mounted) showMessage(context, context.l10n.reportSent);
}

/// Chiede conferma e blocca la persona: le condivisioni fra voi vengono tolte. true se è stata bloccata.
Future<bool> blockPerson(BuildContext context, {required int userId, required String name}) async {
  final l = context.l10n;
  if (!await confirm(context, title: l.blockUserQuestion(name), message: l.blockUserInfo, action: l.block)) {
    return false;
  }
  if (!context.mounted) return false;
  try {
    await context.read<AuthController>().blockUser(userId);
    if (context.mounted) showMessage(context, l.userBlocked(name));
    return true;
  } catch (e) {
    if (context.mounted) showError(context, e);
    return false;
  }
}

/// Menu con "Segnala" e "Blocca" per una persona (chi condivide le liste con te, il proprietario di una lista…).
Future<void> showPersonActions(BuildContext context, {required int userId, required String name, int? listId}) async {
  final l = context.l10n;
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: Text(l.reportUser(name)),
            onTap: () => Navigator.pop(context, 'report'),
          ),
          ListTile(
            leading: Icon(Icons.block, color: Theme.of(context).colorScheme.error),
            title: Text(l.blockUser(name), style: TextStyle(color: Theme.of(context).colorScheme.error)),
            onTap: () => Navigator.pop(context, 'block'),
          ),
        ],
      ),
    ),
  );
  if (!context.mounted) return;
  if (choice == 'report') {
    await showReportDialog(context, type: ReportType.user, title: l.reportUser(name), userId: userId, listId: listId);
  } else if (choice == 'block') {
    await blockPerson(context, userId: userId, name: name);
  }
}

class _ReportDialog extends StatefulWidget {
  const _ReportDialog({required this.type, required this.title, this.userId, this.listId, this.messageId});

  final ReportType type;
  final String title;
  final int? userId;
  final int? listId;
  final int? messageId;

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  final _text = TextEditingController();
  String? _error;
  bool _sending = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _text.text.trim();
    if (widget.type == ReportType.problem && body.isEmpty) {
      setState(() => _error = context.l10n.reportProblemRequired);
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await context.read<ApiClient>().report(
        widget.type.value,
        body: body.isEmpty ? null : body,
        userId: widget.userId,
        listId: widget.listId,
        messageId: widget.messageId,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _text,
            autofocus: true,
            minLines: 3,
            maxLines: 8,
            maxLength: 5000,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: widget.type == ReportType.problem ? l.reportProblemHint : l.reportReasonHint,
              errorText: _error,
              errorMaxLines: 3,
              counterText: '',
            ),
          ),
          const SizedBox(height: 12),
          Text(l.reportInfo, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      actions: [
        TextButton(onPressed: _sending ? null : () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(
          onPressed: _sending ? null : _send,
          child: _sending
              ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(l.send),
        ),
      ],
    );
  }
}
