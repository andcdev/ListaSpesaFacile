import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../models/app_notification.dart';
import '../state/notifications_controller.dart';
import '../widgets/ui.dart';

/// Elenco delle notifiche: condivisioni ricevute, nuove liste, promemoria, liste eliminate.
/// Toccando una notifica si apre la lista ([onOpenList]).
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key, required this.onOpenList});

  final void Function(int listId) onOpenList;

  static IconData _icon(String kind) => switch (kind) {
    'reminder' => Icons.alarm,
    'list_shared' || 'list_created' => Icons.playlist_add_check,
    'global_share' => Icons.group_outlined,
    'list_deleted' => Icons.delete_outline,
    'chat_message' => Icons.chat_bubble_outline,
    _ => Icons.notifications_none,
  };

  Future<void> _clear(BuildContext context, NotificationsController controller) async {
    if (!await confirm(context, title: context.l10n.deleteAllNotificationsQuestion)) return;
    try {
      await controller.clear();
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<NotificationsController>();
    final items = controller.items;
    final l = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.notifications),
        actions: [
          if (controller.unreadCount > 0) TextButton(onPressed: controller.markAllRead, child: Text(l.markAllRead)),
          if (items.isNotEmpty)
            IconButton(
              tooltip: l.deleteAll,
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () => _clear(context, controller),
            ),
        ],
      ),
      body: Wallpaper(
        child: RefreshIndicator(
          onRefresh: controller.load,
          child: items.isEmpty
              ? ListView(
                  children: [
                    const SizedBox(height: 120),
                    if (controller.loading)
                      const Center(child: CircularProgressIndicator())
                    else ...[
                      Icon(Icons.notifications_none, size: 72, color: Theme.of(context).disabledColor),
                      const SizedBox(height: 16),
                      Text(controller.error ?? l.noNotifications, textAlign: TextAlign.center),
                    ],
                  ],
                )
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) => _NotificationTile(
                    notification: items[i],
                    icon: _icon(items[i].kind),
                    onTap: () {
                      final n = items[i];
                      controller.markRead(n).catchError((_) {});
                      if (n.listId != null && n.kind != 'list_deleted') onOpenList(n.listId!);
                    },
                  ),
                ),
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.icon, required this.onTap});

  final AppNotification notification;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final unread = !notification.read;
    final when = notification.createdAt;

    return ListTile(
      onTap: onTap,
      tileColor: unread ? scheme.primaryContainer.withValues(alpha: 0.25) : null,
      leading: CircleAvatar(
        backgroundColor: unread ? scheme.primaryContainer : scheme.surfaceContainerHighest,
        foregroundColor: unread ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
        child: Icon(icon),
      ),
      title: Text(notification.title, style: unread ? const TextStyle(fontWeight: FontWeight.w600) : null),
      subtitle: Text('${notification.body}\n${dayLabel(when)} · ${timeLabel(when)}'),
      isThreeLine: true,
      trailing: unread ? Icon(Icons.circle, size: 10, color: scheme.primary) : null,
    );
  }
}
