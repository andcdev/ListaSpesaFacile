import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../models/app_user.dart';
import '../services/api_client.dart';
import '../state/auth_controller.dart';
import '../widgets/ui.dart';

/// Persone bloccate (dal menu del profilo): si possono sbloccare.
class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  List<AppUser>? _users;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final users = await context.read<ApiClient>().blockedUsers();
      if (mounted) setState(() => _users = users);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _unblock(AppUser user) async {
    final l = context.l10n;
    if (!await confirm(context, title: l.unblockQuestion(user.name), message: l.unblockInfo, action: l.unblock)) {
      return;
    }
    if (!mounted) return;
    try {
      await context.read<AuthController>().unblockUser(user.id);
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
      appBar: AppBar(title: Text(l.blockedPeople)),
      body: Wallpaper(
        child: users == null
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (users.isEmpty) Padding(padding: const EdgeInsets.all(8), child: Text(l.noBlockedPeople)),
                    for (final u in users)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: UserAvatar(
                          initials: initialsOf(u.name),
                          radius: 18,
                          image: avatarImage(context.read<ApiClient>(), u),
                        ),
                        title: Text(u.name),
                        subtitle: Text(u.email, overflow: TextOverflow.ellipsis),
                        trailing: TextButton(onPressed: () => _unblock(u), child: Text(l.unblock)),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}
