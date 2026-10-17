import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../models/chat_message.dart';
import '../services/api_client.dart';
import '../state/auth_controller.dart';
import '../state/chat_controller.dart';
import 'photo_picker.dart';
import 'report.dart';
import 'ui.dart';
import 'voice_input.dart';

/// Prodotti scritti in un messaggio della chat: uno per riga o separati da virgole (al massimo 20).
List<String> chatProductNames(String body) =>
    body.split(RegExp(r'[\n,;]')).map((s) => s.trim()).where((s) => s.isNotEmpty && s.length <= 255).take(20).toList();

/// Chat interna di una lista, sotto la lista nella stessa schermata. Si possono inviare foto (galleria o
/// fotocamera), emoji di base e dettare i messaggi a voce; tenendo premuto un messaggio si mette una reazione; si risponde a un singolo messaggio scorrendolo verso destra o tenendolo
/// premuto. Tenendo premuto un messaggio: rispondere, copiarlo, aggiungerlo alla lista come prodotti, eliminarlo
/// (i propri; il proprietario della lista anche quelli degli altri), segnalarlo o bloccare chi l'ha scritto.
/// Gli eventi della lista (spesa finita, "Continuo io"…) compaiono in grigio tra i messaggi.
class ChatPanel extends StatefulWidget {
  const ChatPanel({super.key, required this.isOwner, this.scrollController, this.onAddToList});

  final bool isOwner;

  /// Quello del foglio trascinabile: tirando i messaggi il foglio si allarga.
  final ScrollController? scrollController;

  /// Aggiunge i prodotti scritti in un messaggio (null se l'utente non può modificare la lista).
  final Future<void> Function(List<String> names)? onAddToList;

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  late final ScrollController _scroll = widget.scrollController ?? ScrollController();
  bool _sending = false;

  /// Messaggio a cui si sta rispondendo (anteprima sopra il campo).
  ChatMessage? _replyTo;

  /// Riga con le emoji di base sotto il campo.
  bool _emojiOpen = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    _scroll.removeListener(_onScroll);
    if (widget.scrollController == null) _scroll.dispose();
    super.dispose();
  }

  void _reply(ChatMessage message) {
    setState(() => _replyTo = message);
    _focus.requestFocus();
  }

  void _toggleEmoji() => setState(() => _emojiOpen = !_emojiOpen);

  /// Inserisce l'emoji dove c'è il cursore (o in fondo).
  void _insertEmoji(String emoji) {
    final value = _text.value;
    final start = value.selection.isValid ? value.selection.start : value.text.length;
    final end = value.selection.isValid ? value.selection.end : value.text.length;
    _text.value = TextEditingValue(
      text: value.text.replaceRange(start, end, emoji),
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
  }

  Future<void> _addToList(ChatMessage message) async {
    final names = chatProductNames(message.body);
    if (names.isEmpty) return;
    try {
      await widget.onAddToList!(names);
      if (mounted) showMessage(context, context.l10n.addedToList(names.length));
    } catch (e) {
      if (mounted) showError(context, e);
    }
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
      await chat.send(body, imagePath: imagePath, replyTo: _replyTo);
      chat.typing(false);
      _text.clear();
      if (mounted) setState(() => _replyTo = null);
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

  Future<void> _react(ChatMessage message, String emoji) async {
    try {
      await context.read<ChatController>().react(message, emoji);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  /// Tenendo premuto un messaggio: rispondere, copiare, aggiungere alla lista; i propri si eliminano, quelli degli
  /// altri si segnalano (e il proprietario della lista li può eliminare).
  Future<void> _messageMenu(ChatMessage message, {required bool mine}) async {
    final l = context.l10n;
    final error = Theme.of(context).colorScheme.error;
    final name = message.userName ?? '';
    final canDelete = mine || widget.isOwner;
    final canAdd = widget.onAddToList != null && chatProductNames(message.body).isNotEmpty;
    final myId = context.read<ChatController>().userId;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Reazioni: una per persona; quella già messa è evidenziata (toccala di nuovo per toglierla).
            if (!message.isEvent)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (final emoji in Reaction.emojis)
                      _ReactionButton(
                        emoji: emoji,
                        selected: message.reactions.any((r) => r.userId == myId && r.emoji == emoji),
                        onTap: () => Navigator.pop(context, 'react:$emoji'),
                      ),
                  ],
                ),
              ),
            if (!message.isEvent)
              ListTile(
                leading: const Icon(Icons.reply),
                title: Text(l.reply),
                onTap: () => Navigator.pop(context, 'reply'),
              ),
            if (message.body.isNotEmpty && !message.isEvent)
              ListTile(
                leading: const Icon(Icons.copy),
                title: Text(l.copy),
                onTap: () => Navigator.pop(context, 'copy'),
              ),
            if (canAdd && !message.isEvent)
              ListTile(
                leading: const Icon(Icons.playlist_add),
                title: Text(l.addToList),
                subtitle: Text(chatProductNames(message.body).join(', '), maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () => Navigator.pop(context, 'add'),
              ),
            if (!mine && message.userId != null && !message.isEvent) ...[
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: Text(l.reportMessage),
                onTap: () => Navigator.pop(context, 'report'),
              ),
              ListTile(
                leading: const Icon(Icons.block),
                title: Text(l.blockUser(name)),
                onTap: () => Navigator.pop(context, 'block'),
              ),
            ],
            if (canDelete)
              ListTile(
                leading: Icon(Icons.delete_outline, color: error),
                title: Text(l.delete, style: TextStyle(color: error)),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice.startsWith('react:')) {
      await _react(message, choice.substring(6));
      return;
    }
    switch (choice) {
      case 'reply':
        _reply(message);
      case 'copy':
        await Clipboard.setData(ClipboardData(text: message.body));
        if (mounted) showMessage(context, l.copied);
      case 'add':
        await _addToList(message);
      case 'report':
        await showReportDialog(
          context,
          type: ReportType.message,
          title: l.reportMessage,
          listId: message.listId,
          messageId: message.id,
        );
      case 'block':
        await blockPerson(context, userId: message.userId!, name: name);
      case 'delete':
        await _delete(message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatController>();
    // I messaggi delle persone bloccate non compaiono (anche quelli arrivati in tempo reale).
    final blocked = context.select<AuthController, Set<int>>((auth) => auth.user?.blockedIds ?? const {});
    final messages = chat.messages.reversed.where((m) => !blocked.contains(m.userId)).toList();

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
                        if (message.isEvent)
                          _EventLine(
                            message: message,
                            onLongPress: widget.isOwner ? () => _messageMenu(message, mine: false) : null,
                          )
                        else
                          _SwipeToReply(
                            onReply: () => _reply(message),
                            child: _Bubble(
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
                              showName: !mine && (older == null || older.userId != message.userId || older.isEvent),
                              myId: chat.userId,
                              onLongPress: () => _messageMenu(message, mine: mine),
                              onReact: (emoji) => _react(message, emoji),
                            ),
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_replyTo != null)
                  _ReplyPreview(
                    message: _replyTo!,
                    mine: _replyTo!.userId == chat.userId,
                    onClose: () => setState(() => _replyTo = null),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      IconButton(
                        onPressed: _sending ? null : _sendPhoto,
                        icon: const Icon(Icons.photo_outlined),
                        tooltip: context.l10n.sendPhoto,
                      ),
                      IconButton(
                        onPressed: _toggleEmoji,
                        icon: Icon(_emojiOpen ? Icons.keyboard_outlined : Icons.emoji_emotions_outlined),
                        tooltip: _emojiOpen ? context.l10n.keyboard : context.l10n.emoji,
                      ),
                      Expanded(
                        child: TextField(
                          controller: _text,
                          focusNode: _focus,
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
                if (_emojiOpen) BasicEmojiRow(onPick: _insertEmoji),
              ],
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
    this.myId,
    this.onReact,
  });

  /// Tocco su una reazione già presente: la propria si toglie, un'altra emoji diventa la propria.
  final ValueChanged<String>? onReact;

  final ChatMessage message;

  /// L'utente corrente: nella citazione di un proprio messaggio si legge "Tu".
  final int? myId;

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
                if (message.replyTo != null) _Quote(quoted: message.replyTo!, onColor: onColor),
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
                if (message.reactions.isNotEmpty) _Reactions(message: message, myId: myId, onReact: onReact),
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

/// Messaggio citato dentro una risposta: chi l'ha scritto e l'inizio del testo.
class _Quote extends StatelessWidget {
  const _Quote({required this.quoted, required this.onColor});

  final QuotedMessage quoted;
  final Color onColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final body = quoted.body.isNotEmpty ? quoted.body : (quoted.hasImage ? '📷 ${context.l10n.chatPhoto}' : '');
    return Container(
      margin: const EdgeInsets.only(top: 2, bottom: 4),
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      decoration: BoxDecoration(
        color: onColor.withValues(alpha: 0.07),
        border: Border(left: BorderSide(color: scheme.tertiary, width: 3)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            quoted.userName ?? context.l10n.deletedUser,
            style: text.labelSmall?.copyWith(color: scheme.tertiary, fontWeight: FontWeight.w700),
          ),
          Text(
            body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: text.bodySmall?.copyWith(color: onColor),
          ),
        ],
      ),
    );
  }
}

/// Sopra il campo di scrittura: a quale messaggio si sta rispondendo, con la ✕ per annullare.
class _ReplyPreview extends StatelessWidget {
  const _ReplyPreview({required this.message, required this.mine, required this.onClose});

  final ChatMessage message;
  final bool mine;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final name = mine ? l.you : (message.userName ?? l.deletedUser);
    final body = message.body.isNotEmpty ? message.body : (message.hasImage ? '📷 ${l.chatPhoto}' : '');
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 8, 0),
      padding: const EdgeInsets.fromLTRB(10, 4, 0, 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        border: Border(left: BorderSide(color: scheme.tertiary, width: 3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.reply, size: 18, color: scheme.tertiary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.replyingTo(name), style: text.labelMedium?.copyWith(color: scheme.tertiary)),
                Text(body, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodySmall),
              ],
            ),
          ),
          IconButton(icon: const Icon(Icons.close, size: 20), tooltip: l.cancel, onPressed: onClose),
        ],
      ),
    );
  }
}

/// Scorrendo un messaggio verso destra si risponde (come in WhatsApp): compare la freccia e al rilascio parte.
class _SwipeToReply extends StatefulWidget {
  const _SwipeToReply({required this.onReply, required this.child});

  final VoidCallback onReply;
  final Widget child;

  @override
  State<_SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<_SwipeToReply> {
  static const _trigger = 64.0;
  double _dx = 0;
  bool _armed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: (d) {
        final dx = (_dx + d.delta.dx).clamp(0.0, _trigger * 1.3);
        final armed = dx >= _trigger;
        if (armed && !_armed) HapticFeedback.selectionClick();
        setState(() {
          _dx = dx;
          _armed = armed;
        });
      },
      onHorizontalDragEnd: (_) {
        if (_armed) widget.onReply();
        setState(() {
          _dx = 0;
          _armed = false;
        });
      },
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          if (_dx > 8)
            Opacity(
              opacity: (_dx / _trigger).clamp(0.0, 1.0),
              child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(Icons.reply, color: Theme.of(context).colorScheme.tertiary),
              ),
            ),
          Transform.translate(offset: Offset(_dx, 0), child: widget.child),
        ],
      ),
    );
  }
}

/// Evento della lista in grigio tra i messaggi: spesa finita, "Continuo io", chi fa la spesa.
class _EventLine extends StatelessWidget {
  const _EventLine({required this.message, this.onLongPress});

  final ChatMessage message;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final name = message.userName ?? l.deletedUser;
    final params = message.eventParams;
    final text = switch (message.event) {
      'finished' => l.eventFinished(name, (params['missing'] as num?)?.toInt() ?? 0),
      'took_over' => l.eventTookOver(name),
      'shopper_changed' => l.eventShopperChanged(name, '${params['shopper'] ?? ''}'),
      _ => message.body,
    };
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return GestureDetector(
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
        child: Text(
          '$text · ${timeLabel(message.createdAt)}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted, fontStyle: FontStyle.italic),
        ),
      ),
    );
  }
}

/// Emoji di base, in una riga che scorre sotto il campo: si toccano e finiscono nel messaggio.
class BasicEmojiRow extends StatelessWidget {
  const BasicEmojiRow({super.key, required this.onPick});

  final ValueChanged<String> onPick;

  static const emojis = ['😀', '😂', '😊', '😍', '😉', '😢', '😮', '😡', '👍', '👎', '👏', '🙏', '❤️', '🔥', '✅', '🛒'];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          for (final e in emojis)
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => onPick(e),
              child: SizedBox(
                width: 44,
                child: Center(child: Text(e, style: const TextStyle(fontSize: 26))),
              ),
            ),
        ],
      ),
    );
  }
}

/// Una delle sei reazioni nel menu del messaggio.
class _ReactionButton extends StatelessWidget {
  const _ReactionButton({required this.emoji, required this.selected, required this.onTap});

  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? scheme.primaryContainer : scheme.surfaceContainerHigh,
          border: selected ? Border.all(color: scheme.primary, width: 2) : null,
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 24)),
      ),
    );
  }
}

/// Sotto il messaggio: le reazioni raggruppate per emoji con quante sono (tieni premuto per vedere chi).
class _Reactions extends StatelessWidget {
  const _Reactions({required this.message, required this.myId, this.onReact});

  final ChatMessage message;
  final int? myId;
  final ValueChanged<String>? onReact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final groups = <String, List<Reaction>>{};
    for (final r in message.reactions) {
      groups.putIfAbsent(r.emoji, () => []).add(r);
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          for (final MapEntry(key: emoji, value: people) in groups.entries)
            Tooltip(
              message: people.map((r) => r.userId == myId ? context.l10n.you : (r.userName ?? '')).join(', '),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onReact == null ? null : () => onReact!(emoji),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: people.any((r) => r.userId == myId) ? scheme.primary : scheme.outlineVariant,
                    ),
                  ),
                  child: Text(
                    people.length > 1 ? '$emoji ${people.length}' : emoji,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
