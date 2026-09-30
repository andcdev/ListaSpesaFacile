import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../models/chat_message.dart';
import '../services/api_client.dart';
import '../services/notification_service.dart';
import '../state/chat_controller.dart';
import 'photo_picker.dart';
import 'ui.dart';
import 'voice_input.dart';

/// Chat interna di una lista, mostrata sotto la lista nella stessa schermata: si può chattare
/// e intanto spuntare o aggiungere articoli. Si possono inviare foto (galleria o fotocamera) e dettare
/// i messaggi a voce. Il proprietario della lista può eliminare qualsiasi messaggio, gli altri solo
/// i propri (tenendo premuto sul messaggio).
class ChatPanel extends StatefulWidget {
  const ChatPanel({super.key, required this.isOwner});

  final bool isOwner;

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  late final NotificationService _notifications;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // Mentre la chat è aperta i suoi messaggi non generano notifiche.
    _notifications = context.read<NotificationService>()..activeChatListId = context.read<ChatController>().listId;
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _notifications.activeChatListId = null;
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// La lista è invertita (i più recenti in basso): vicino alla "fine" carica i messaggi precedenti.
  void _onScroll() {
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 200) {
      context.read<ChatController>().loadOlder();
    }
  }

  /// Invia il testo scritto e, se c'è, la foto [imagePath] (il testo diventa la didascalia).
  Future<void> _send({String? imagePath}) async {
    final body = _text.text.trim();
    if ((body.isEmpty && imagePath == null) || _sending) return;
    setState(() => _sending = true);
    try {
      final chat = context.read<ChatController>();
      await chat.send(body, imagePath: imagePath);
      chat.typing(false);
      _text.clear();
      if (_scroll.hasClients) _scroll.jumpTo(0);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendPhoto() async {
    final choice = await askPhotoSource(context, title: context.l10n.sendPhoto);
    if (choice == null || !mounted) return;
    try {
      final path = await pickPhoto(choice);
      if (path != null) await _send(imagePath: path);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _delete(ChatMessage message) async {
    final chat = context.read<ChatController>();
    final l = context.l10n;
    if (!await confirm(context, title: l.deleteMessageQuestion, message: l.deleteMessageInfo)) return;
    try {
      await chat.delete(message);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatController>();
    final messages = chat.messages.reversed.toList();

    return Column(
      children: [
        Expanded(
          child: chat.loading
              ? const Center(child: CircularProgressIndicator())
              : messages.isEmpty
              ? _EmptyChat(error: chat.error, onRetry: chat.load)
              : ListView.builder(
                  controller: _scroll,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: messages.length + (chat.hasMore ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i == messages.length) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      );
                    }
                    final message = messages[i];
                    final older = i + 1 < messages.length ? messages[i + 1] : null;
                    final mine = message.userId == chat.userId;
                    return Column(
                      children: [
                        if (older == null || !_sameDay(older.createdAt, message.createdAt))
                          _DaySeparator(date: message.createdAt),
                        _Bubble(
                          message: message,
                          imageUrl: message.hasImage
                              ? context.read<ApiClient>().messageImageUrl(message.listId, message.id)
                              : null,
                          mine: mine,
                          ticks: mine ? chat.ticks(message) : null,
                          avatar: message.userAvatarVersion == null || message.userId == null
                              ? null
                              : NetworkImage(
                                  context.read<ApiClient>().avatarUrl(message.userId!, message.userAvatarVersion!),
                                  headers: context.read<ApiClient>().authHeaders,
                                ),
                          // Il nome solo sul primo di una serie di messaggi dello stesso autore.
                          showName: !mine && (older == null || older.userId != message.userId),
                          onLongPress: mine || widget.isOwner ? () => _delete(message) : null,
                        ),
                      ],
                    );
                  },
                ),
        ),
        Material(
          elevation: 8,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: _sending ? null : _sendPhoto,
                    icon: const Icon(Icons.photo_outlined),
                    tooltip: context.l10n.sendPhoto,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _text,
                      // Gli altri vedono "sta scrivendo…" accanto al tuo nome in cima alla lista.
                      onChanged: (v) => context.read<ChatController>().typing(v.trim().isNotEmpty),
                      minLines: 1,
                      maxLines: 5,
                      maxLength: 2000,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: context.l10n.writeMessage,
                        isDense: true,
                        counterText: '',
                        suffixIcon: VoiceInputButton(controller: _text, append: true, compact: true),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send),
                    tooltip: context.l10n.send,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  static bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.mine,
    required this.showName,
    this.imageUrl,
    this.ticks,
    this.avatar,
    this.onLongPress,
  });

  final ChatMessage message;

  /// Foto profilo di chi scrive (null = sagoma vuota), accanto al primo messaggio di una serie degli altri.
  final ImageProvider? avatar;

  /// Solo sui propri messaggi: ✓ verde inviato, ✓✓ blu ricevuto.
  final MessageTicks? ticks;

  /// Foto allegata (protetta: si scarica con il token).
  final String? imageUrl;
  final bool mine;
  final bool showName;
  final VoidCallback? onLongPress;

  Widget _photo(BuildContext context) {
    final image = NetworkImage(imageUrl!, headers: context.read<ApiClient>().authHeaders);
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: GestureDetector(
        onTap: () => showPhoto(context, image),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image(
            image: image,
            width: 220,
            height: 220,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : const SizedBox.square(dimension: 220, child: Center(child: CircularProgressIndicator())),
            errorBuilder: (_, _, _) =>
                const SizedBox(width: 220, height: 80, child: Center(child: Icon(Icons.broken_image_outlined))),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final color = mine ? scheme.primaryContainer : scheme.surfaceContainerHighest;
    final onColor = mine ? scheme.onPrimaryContainer : scheme.onSurface;

    final bubble = Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
        child: GestureDetector(
          onLongPress: onLongPress,
          child: Container(
            margin: EdgeInsets.only(top: showName ? 10 : 3),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(mine ? 16 : 4),
                bottomRight: Radius.circular(mine ? 4 : 16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showName)
                  Text(
                    message.userName ?? context.l10n.deletedUser,
                    style: text.labelMedium?.copyWith(color: scheme.primary, fontWeight: FontWeight.w600),
                  ),
                if (imageUrl != null) _photo(context),
                if (message.body.isNotEmpty) Text(message.body, style: text.bodyMedium?.copyWith(color: onColor)),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        timeLabel(message.createdAt),
                        style: text.labelSmall?.copyWith(color: onColor.withValues(alpha: 0.7)),
                      ),
                      if (ticks != null) ...[const SizedBox(width: 4), _Ticks(ticks: ticks!)],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (mine) return bubble;
    // Messaggi degli altri: foto profilo (o sagoma vuota) sul primo di una serie, spazio vuoto sugli altri.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: showName ? 10 : 3, right: 6),
          child: showName
              ? _ProfilePhoto(image: avatar, name: message.userName)
              : const SizedBox(width: _ProfilePhoto.size),
        ),
        Expanded(child: bubble),
      ],
    );
  }
}

/// Foto profilo nella chat: la foto se l'utente l'ha impostata, altrimenti una sagoma vuota.
class _ProfilePhoto extends StatelessWidget {
  const _ProfilePhoto({required this.image, this.name});

  static const size = 32.0;

  final ImageProvider? image;
  final String? name;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: name ?? '',
      child: CircleAvatar(
        radius: size / 2,
        backgroundColor: scheme.surfaceContainerHighest,
        foregroundColor: scheme.onSurfaceVariant,
        backgroundImage: image,
        onBackgroundImageError: image == null ? null : (_, _) {},
        child: image == null ? const Icon(Icons.person, size: 20) : null,
      ),
    );
  }
}

/// ✓ verde: inviato. ✓✓ blu: ricevuto dal telefono di tutti gli altri della lista.
class _Ticks extends StatelessWidget {
  const _Ticks({required this.ticks});

  final MessageTicks ticks;

  static const _green = Color(0xFF2E7D32);
  static const _blue = Color(0xFF1E88E5);

  @override
  Widget build(BuildContext context) {
    final received = ticks == MessageTicks.received;
    return Tooltip(
      message: received ? context.l10n.messageReceived : context.l10n.messageSent,
      child: Icon(received ? Icons.done_all : Icons.done, size: 16, color: received ? _blue : _green),
    );
  }
}

class _DaySeparator extends StatelessWidget {
  const _DaySeparator({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Chip(label: Text(dayLabel(date)), visualDensity: VisualDensity.compact),
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat({this.error, required this.onRetry});

  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    // La chat sotto la lista può essere bassa: icona più piccola e testo che scorre, senza mai sforare.
    return LayoutBuilder(
      builder: (context, constraints) {
        final small = constraints.maxHeight < 220;
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: small ? 8 : 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      error == null ? Icons.chat_bubble_outline : Icons.cloud_off,
                      size: small ? 32 : 64,
                      color: Theme.of(context).disabledColor,
                    ),
                    SizedBox(height: small ? 8 : 16),
                    Text(error ?? context.l10n.emptyChat, textAlign: TextAlign.center),
                    if (error != null) TextButton(onPressed: onRetry, child: Text(context.l10n.retry)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
