import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import 'permission_picker.dart';

/// Campo email + permesso (solo lettura oppure lettura e modifica), per la condivisione di una lista e per quella
/// di tutte le liste.
class ShareForm extends StatefulWidget {
  const ShareForm({super.key, required this.onShare});

  final Future<void> Function(String email, bool canEdit) onShare;

  @override
  State<ShareForm> createState() => _ShareFormState();
}

class _ShareFormState extends State<ShareForm> {
  final _email = TextEditingController();
  bool _canEdit = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      setState(() => _error = context.l10n.enterRegisteredEmail);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onShare(email, _canEdit);
      _email.clear();
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            labelText: context.l10n.userEmail,
            errorText: _error,
            suffixIcon: IconButton(
              icon: _busy
                  ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send),
              onPressed: _busy ? null : _submit,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Text(context.l10n.permission),
              const SizedBox(width: 12),
              Expanded(
                child: PermissionPicker(canEdit: _canEdit, onChanged: (v) => setState(() => _canEdit = v)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
