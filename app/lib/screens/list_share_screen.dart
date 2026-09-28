import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../models/app_user.dart';
import '../services/api_client.dart';
import '../widgets/share_form.dart';
import '../widgets/ui.dart';

/// Condivisione di una lista con uno o più utenti registrati.
class ListShareScreen extends StatefulWidget {
  const ListShareScreen({super.key, required this.listId, required this.listName});

  final int listId;
  final String listName;

  @override
  State<ListShareScreen> createState() => _ListShareScreenState();
}

class _ListShareScreenState extends State<ListShareScreen> {
  List<AppUser>? _users;

  ApiClient get _api => context.read<ApiClient>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final users = await _api.shares(widget.listId);
      if (mounted) setState(() => _users = users);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _share(String email, bool canEdit) async {
    final users = await _api.addShare(widget.listId, email, canEdit: canEdit);
    if (!mounted) return;
    setState(() => _users = users);
    showMessage(context, context.l10n.listSharedWith(email));
  }

  Future<void> _remove(AppUser user) async {
    if (!await confirm(
      context,
      title: context.l10n.removeUserQuestion(user.name),
      message: context.l10n.removeUserInfo,
      action: context.l10n.remove,
    )) {
      return;
    }
    try {
      await _api.removeShare(widget.listId, user.id);
      await _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final users = _users;
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: ScreenTitle(widget.listName, subtitle: l.share)),
      body: Wallpaper(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ShareForm(onShare: _share),
            const SizedBox(height: 8),
            Text(l.sharedWith, style: Theme.of(context).textTheme.titleSmall),
            if (users == null)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (users.isEmpty)
              Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Text(l.nobodyYet))
            else
              for (final u in users)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: UserAvatar(
                    initials: initialsOf(u.name),
                    radius: 18,
                    image: avatarImage(context.read<ApiClient>(), u),
                  ),
                  title: Text(u.name),
                  subtitle: Text('${u.email} · ${u.canEdit == false ? l.userReadOnly : l.userCanEdit}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.person_remove_outlined),
                    tooltip: l.remove,
                    onPressed: () => _remove(u),
                  ),
                ),
            const SizedBox(height: 16),
            Text(l.globalShareHint, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
