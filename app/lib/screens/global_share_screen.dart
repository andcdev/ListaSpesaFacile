import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../models/app_user.dart';
import '../services/api_client.dart';
import '../widgets/permission_picker.dart';
import '../widgets/report.dart';
import '../widgets/share_form.dart';
import '../widgets/ui.dart';

/// Condivisione globale: tutte le mie liste (anche future) con altri utenti,
/// e le condivisioni globali che ho ricevuto.
class GlobalShareScreen extends StatefulWidget {
  const GlobalShareScreen({super.key});

  @override
  State<GlobalShareScreen> createState() => _GlobalShareScreenState();
}

class _GlobalShareScreenState extends State<GlobalShareScreen> {
  GlobalShares? _shares;

  ApiClient get _api => context.read<ApiClient>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final shares = await _api.globalShares();
      if (mounted) setState(() => _shares = shares);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _share(String email, bool canEdit) async {
    final shares = await _api.addGlobalShare(email, canEdit: canEdit);
    if (!mounted) return;
    setState(() => _shares = shares);
    showMessage(context, context.l10n.allListsSharedWith(email));
  }

  /// Solo lettura oppure lettura e modifica, su tutte le mie liste, per chi le riceve già.
  Future<void> _setPermission(AppUser user, bool canEdit) async {
    try {
      final shares = await _api.updateGlobalShare(user.id, canEdit: canEdit);
      if (mounted) setState(() => _shares = shares);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _remove(AppUser user) async {
    final l = context.l10n;
    if (!await confirm(context, title: l.stopSharingWith(user.name), action: l.remove)) return;
    await _guard(() => _api.removeGlobalShare(user.id));
  }

  Future<void> _leave(AppUser owner) async {
    final l = context.l10n;
    if (!await confirm(context, title: l.stopReceivingFrom(owner.name), action: l.confirm)) return;
    await _guard(() => _api.leaveGlobalShare(owner.id));
  }

  /// Segnala o blocca chi mi condivide le sue liste (bloccandolo non le ricevo più).
  Future<void> _personActions(AppUser user) async {
    await showPersonActions(context, userId: user.id, name: user.name);
    await _load();
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
      await _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shares = _shares;
    final titleStyle = Theme.of(context).textTheme.titleSmall;
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.globalSharing)),
      body: Wallpaper(
        child: shares == null
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(l.globalShareInfo, style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 16),
                    ShareForm(onShare: _share),
                    Text(l.iShareWith, style: titleStyle),
                    if (shares.sharedWith.isEmpty)
                      Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(l.nobody)),
                    for (final u in shares.sharedWith)
                      _UserTile(
                        user: u,
                        onPermission: (v) => _setPermission(u, v),
                        trailing: IconButton(
                          icon: const Icon(Icons.person_remove_outlined),
                          tooltip: l.remove,
                          onPressed: () => _remove(u),
                        ),
                      ),
                    const Divider(height: 32),
                    Text(l.sharedWithMe, style: titleStyle),
                    if (shares.sharedBy.isEmpty)
                      Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(l.nobody)),
                    for (final u in shares.sharedBy)
                      _UserTile(
                        user: u,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.logout),
                              tooltip: l.stopReceiving,
                              onPressed: () => _leave(u),
                            ),
                            IconButton(
                              icon: const Icon(Icons.more_vert),
                              tooltip: l.reportOrBlock(u.name),
                              onPressed: () => _personActions(u),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user, required this.trailing, this.onPermission});

  final AppUser user;
  final Widget trailing;

  /// Solo per chi riceve le mie liste: si può cambiare il permesso. Per le liste ricevute si mostra e basta.
  final ValueChanged<bool>? onPermission;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: UserAvatar(
        initials: initialsOf(user.name),
        radius: 18,
        image: avatarImage(context.read<ApiClient>(), user),
      ),
      title: Text(user.name),
      subtitle: onPermission == null
          ? Text('${user.email} · ${user.canEdit == false ? context.l10n.userReadOnly : context.l10n.userCanEdit}')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.email, overflow: TextOverflow.ellipsis),
                PermissionPicker(canEdit: user.canEdit != false, onChanged: onPermission),
              ],
            ),
      trailing: trailing,
    );
  }
}
