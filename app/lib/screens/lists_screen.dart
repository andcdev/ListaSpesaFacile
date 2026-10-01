import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../models/app_user.dart';
import '../models/list_filter.dart';
import '../models/shopping_list.dart';
import '../services/api_client.dart';
import '../services/notification_service.dart';
import '../services/realtime_client.dart';
import '../state/appearance_controller.dart';
import '../state/auth_controller.dart';
import '../state/list_detail_controller.dart';
import '../state/lists_controller.dart';
import '../state/locale_controller.dart';
import '../state/notifications_controller.dart';
import '../widgets/language_picker.dart';
import '../widgets/photo_picker.dart';
import '../widgets/ui.dart';
import 'global_share_screen.dart';
import 'list_detail_screen.dart';
import 'list_form_screen.dart';
import 'my_prices_screen.dart';
import 'notifications_screen.dart';

class ListsScreen extends StatefulWidget {
  const ListsScreen({super.key});

  @override
  State<ListsScreen> createState() => _ListsScreenState();
}

class _ListsScreenState extends State<ListsScreen> {
  bool _showPast = false;

  /// Filtri e ordine di ciascuna sezione (false = in programma, true = passate).
  final _filters = <bool, ListFilter>{false: const ListFilter(), true: const ListFilter()};

  /// Lente: popup dei filtri della sezione aperta; la ricerca per prodotto la fa il server.
  Future<void> _openFilters(ListsController controller, int? meId) async {
    final current = _filters[_showPast]!;
    final past = _showPast;
    final result = await showModalBottomSheet<ListFilter>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _FilterSheet(initial: current, past: past, people: peopleIn(controller.lists, meId)),
    );
    if (result == null || !mounted) return;
    try {
      final next = await _searchProduct(result);
      if (mounted) setState(() => _filters[past] = next);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  /// Le liste che contengono il prodotto cercato (dal server), se il filtro ne ha uno.
  Future<ListFilter> _searchProduct(ListFilter filter) async {
    if (filter.product.isEmpty) return filter.copyWith(productListIds: () => null);
    final found = await context.read<ApiClient>().lists(product: filter.product);
    return filter.copyWith(productListIds: () => {for (final list in found) list.id});
  }

  /// Tira per aggiornare: liste e ricerche per prodotto.
  Future<void> _refresh(ListsController controller) async {
    await controller.load();
    for (final past in [false, true]) {
      final filter = _filters[past]!;
      if (filter.product.isEmpty) continue;
      try {
        final next = await _searchProduct(filter);
        if (mounted) setState(() => _filters[past] = next);
      } catch (_) {
        // Resta il risultato di prima.
      }
    }
  }

  late final NotificationService _notifications;

  @override
  void initState() {
    super.initState();
    _notifications = context.read<NotificationService>()..openRequest.addListener(_onNotificationOpened);
    // L'app potrebbe essere stata aperta toccando una notifica.
    WidgetsBinding.instance.addPostFrameCallback((_) => _onNotificationOpened());
  }

  @override
  void dispose() {
    _notifications.openRequest.removeListener(_onNotificationOpened);
    super.dispose();
  }

  void _onNotificationOpened() {
    final target = _notifications.openRequest.value;
    if (target == null || !mounted) return;
    _notifications.openRequest.value = null;
    _openList(target.listId, openChat: target.chat);
  }

  Future<void> _openNotifications() async {
    final notifications = context.read<NotificationsController>();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: notifications,
          child: NotificationsScreen(onOpenList: (listId) => _openList(listId)),
        ),
      ),
    );
  }

  Future<void> _openList(int listId, {bool openChat = false}) async {
    final auth = context.read<AuthController>();
    // Le route aperte con push non discendono da questa schermata: il ListsController va ripassato.
    final lists = context.read<ListsController>();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: lists),
            ChangeNotifierProvider(
              create: (context) => ListDetailController(
                api: context.read<ApiClient>(),
                realtime: context.read<RealtimeClient>(),
                listId: listId,
                userId: auth.user!.id,
              )..start(),
            ),
          ],
          child: ListDetailScreen(openChat: openChat),
        ),
      ),
    );
  }

  Future<void> _createList() async {
    final lists = context.read<ListsController>();
    final created = await Navigator.push<ShoppingList>(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(value: lists, child: const ListFormScreen()),
      ),
    );
    if (created != null && mounted) await _openList(created.id);
  }

  Future<void> _deleteList(ShoppingList list) async {
    final lists = context.read<ListsController>();
    if (!await confirm(
      context,
      title: context.l10n.deleteListNamed(list.name),
      message: context.l10n.deleteListSharedInfo,
    )) {
      return;
    }
    try {
      await lists.delete(list.id);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  /// Foto profilo: la vedono gli altri accanto ai tuoi messaggi nella chat.
  Future<void> _changeAvatar() async {
    final auth = context.read<AuthController>();
    final choice = await askPhotoSource(
      context,
      canRemove: auth.user?.avatarVersion != null,
      title: context.l10n.profilePhotoTitle,
    );
    if (choice == null || !mounted) return;
    try {
      if (choice == PhotoChoice.remove) {
        await auth.removeAvatar();
      } else {
        final path = await pickPhoto(choice);
        if (path == null) return;
        await auth.setAvatar(path);
      }
      if (mounted) showMessage(context, context.l10n.profilePhotoUpdated);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _deleteAccount() async {
    final l = context.l10n;
    final ok = await confirm(
      context,
      title: l.deleteAccountQuestion,
      message: l.deleteAccountMessage,
      action: l.deleteAccountConfirm,
    );
    if (!ok || !mounted) return;
    // Il messenger dell'app sopravvive a questa schermata, che uscendo lascia il posto a quella di accesso.
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<AuthController>().deleteAccount();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l.accountDeleted), behavior: SnackBarBehavior.floating));
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  static String _themeLabel(AppLocalizations l, ThemeMode mode) => switch (mode) {
    ThemeMode.light => l.themeLight,
    ThemeMode.dark => l.themeDark,
    ThemeMode.system => l.themeSystem,
  };

  /// Sfondo chiaro, scuro o come il telefono (salvato sul dispositivo).
  Future<void> _chooseAppearance() async {
    final appearance = context.read<AppearanceController>();
    final mode = await showDialog<ThemeMode>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(context.l10n.background),
        children: [
          RadioGroup<ThemeMode>(
            groupValue: appearance.mode,
            onChanged: (v) => Navigator.pop(context, v),
            child: Column(
              children: [
                for (final mode in [ThemeMode.light, ThemeMode.dark, ThemeMode.system])
                  RadioListTile<ThemeMode>(value: mode, title: Text(_themeLabel(context.l10n, mode))),
              ],
            ),
          ),
        ],
      ),
    );
    if (mode != null) await appearance.setMode(mode);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ListsController>();
    final auth = context.watch<AuthController>();
    final api = context.read<ApiClient>();
    final me = auth.user;
    final avatar = me == null ? null : avatarImage(api, me);
    final upcoming = controller.upcoming;
    final past = controller.past;
    final l = context.l10n;

    final filter = _filters[_showPast]!;
    final shown = filter.apply(_showPast ? past : upcoming, past: _showPast, now: DateTime.now());
    final people = {for (final person in peopleIn(controller.lists, me?.id)) person.id: person};

    return Scaffold(
      // Il nome dell'app sta nella pagina, sopra "Le mie liste": nella barra lo coprivano i pulsanti.
      appBar: AppBar(
        // Logo e nome sulla stessa riga dei comandi: se non c'è spazio si rimpiccioliscono.
        titleSpacing: 20,
        title: const AppName(),
        actions: [
          const _ConnectionIndicator(),
          _NotificationsButton(onPressed: _openNotifications),
          IconButton(
            tooltip: l.globalSharing,
            icon: const Icon(Icons.group_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GlobalShareScreen())),
          ),
          PopupMenuButton<String>(
            tooltip: l.profile,
            icon: UserAvatar(initials: initialsOf(me?.name ?? ''), radius: 17, image: avatar),
            onSelected: (value) async {
              if (value == 'avatar') await _changeAvatar();
              if (value == 'myPrices' && context.mounted) {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const MyPricesScreen()));
              }
              if (value == 'appearance') await _chooseAppearance();
              if (value == 'language' && context.mounted) await chooseLanguage(context);
              if (value == 'logout' &&
                  context.mounted &&
                  await confirm(context, title: l.logoutQuestion, action: l.logout)) {
                await auth.logout();
              }
              if (value == 'deleteAccount' && context.mounted) await _deleteAccount();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: UserAvatar(initials: initialsOf(me?.name ?? ''), radius: 18, image: avatar),
                  title: Text(me?.name ?? ''),
                  subtitle: Text(me?.email ?? ''),
                ),
              ),
              PopupMenuItem(
                value: 'avatar',
                child: Text(me?.avatarVersion == null ? l.addProfilePhoto : l.changeProfilePhoto),
              ),
              PopupMenuItem(value: 'myPrices', child: Text(l.myPrices)),
              PopupMenuItem(
                value: 'appearance',
                child: Text(l.backgroundValue(_themeLabel(l, context.read<AppearanceController>().mode))),
              ),
              PopupMenuItem(
                value: 'language',
                child: Text(l.languageValue(languageLabel(context, context.read<LocaleController>()))),
              ),
              PopupMenuItem(value: 'logout', child: Text(l.logout)),
              PopupMenuItem(
                value: 'deleteAccount',
                child: Text(l.deleteAccount, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      // Pulsante largo in fondo, come una barra: "Nuova lista".
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: SizedBox(
        width: MediaQuery.sizeOf(context).width - 32,
        height: 58,
        child: FloatingActionButton.extended(
          onPressed: _createList,
          icon: const Icon(Icons.add),
          label: Text(l.newList),
        ),
      ),
      body: Wallpaper(
        child: RefreshIndicator(
          onRefresh: () => _refresh(controller),
          child: controller.lists.isEmpty
              ? _EmptyState(loading: controller.loading, error: controller.error)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 104),
                  children: [
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: PageHeading(l.myLists)),
                    const SizedBox(height: 16),
                    // In programma / passate, e la lente dei filtri della sezione.
                    Row(
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            children: [
                              ChoiceChip(
                                label: Text(l.upcomingTab),
                                selected: !_showPast,
                                showCheckmark: false,
                                onSelected: (_) => setState(() => _showPast = false),
                              ),
                              if (past.isNotEmpty || _showPast)
                                ChoiceChip(
                                  label: Text(l.pastTab(past.length)),
                                  selected: _showPast,
                                  showCheckmark: false,
                                  onSelected: (_) => setState(() => _showPast = true),
                                ),
                            ],
                          ),
                        ),
                        IconButton.filledTonal(
                          tooltip: l.filterLists,
                          onPressed: () => _openFilters(controller, me?.id),
                          icon: Badge(isLabelVisible: filter.isActive, smallSize: 8, child: const Icon(Icons.search)),
                        ),
                      ],
                    ),
                    if (filter.isActive)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _ActiveFilters(
                          filter: filter,
                          past: _showPast,
                          people: people,
                          onChanged: (next) => setState(() => _filters[_showPast] = next),
                        ),
                      ),
                    const SizedBox(height: 12),
                    if (controller.error != null)
                      MaterialBanner(
                        content: Text(controller.error!),
                        actions: [TextButton(onPressed: controller.load, child: Text(l.retry))],
                      ),
                    if (shown.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(filter.isActive ? l.noListsMatch : l.noUpcoming, textAlign: TextAlign.center),
                      ),
                    for (final list in shown)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ListCard(
                          list: list,
                          onTap: () => _openList(list.id),
                          onDelete: list.isOwner ? () => _deleteList(list) : null,
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Una lista: nome, giorno e ora, quanti articoli mancano e barra di avanzamento.
class _ListCard extends StatelessWidget {
  const _ListCard({required this.list, required this.onTap, this.onDelete});

  final ShoppingList list;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l = context.l10n;
    final toBuy = list.itemsCount - list.checkedCount;
    final complete = list.itemsCount > 0 && toBuy == 0;
    final meta = [
      '${dayLabel(list.scheduledAt)} · ${timeLabel(list.scheduledAt)}',
      if (!list.isOwner && list.owner != null) l.byOwner(list.owner!.name),
      if (list.permission == 'view') l.userReadOnly,
    ].join(' · ');
    final api = context.read<ApiClient>();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 8, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (list.imageVersion != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(
                        api.listImageUrl(list.id, list.imageVersion!),
                        headers: api.authHeaders,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox.square(dimension: 48),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          list.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                meta,
                                style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ),
                            if (list.remindsMe) ...[
                              const SizedBox(width: 6),
                              Icon(Icons.notifications_active_outlined, size: 16, color: scheme.onSurfaceVariant),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _Badge(
                    text: list.itemsCount == 0
                        ? l.listEmptyBadge
                        : (complete ? l.listCompleteBadge : l.toBuyCount(toBuy)),
                    done: complete,
                  ),
                  if (onDelete != null)
                    SizedBox(
                      width: 36,
                      height: 32,
                      child: PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        iconSize: 20,
                        icon: Icon(Icons.more_vert, color: scheme.onSurfaceVariant),
                        onSelected: (_) => onDelete!(),
                        itemBuilder: (_) => [PopupMenuItem(value: 'delete', child: Text(l.delete))],
                      ),
                    )
                  else
                    const SizedBox(width: 10),
                ],
              ),
              if (list.itemsCount > 0) ...[
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: ShoppingProgress(done: list.checkedCount, total: list.itemsCount),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Etichetta arrotondata: arancio se mancano articoli, verde se la lista è completa.
class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.done});

  final String text;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: done ? scheme.primaryContainer : scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: done ? scheme.onPrimaryContainer : scheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.loading, this.error});

  final bool loading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    // ListView per consentire il "tira per aggiornare" anche quando è vuota.
    return ListView(
      children: [
        const SizedBox(height: 120),
        Icon(
          error == null ? Icons.shopping_cart_outlined : Icons.cloud_off,
          size: 72,
          color: Theme.of(context).disabledColor,
        ),
        const SizedBox(height: 16),
        Text(error ?? context.l10n.noLists, textAlign: TextAlign.center),
      ],
    );
  }
}

/// Icona che indica se gli aggiornamenti in tempo reale sono attivi.
class _ConnectionIndicator extends StatelessWidget {
  const _ConnectionIndicator();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: context.read<RealtimeClient>().connected,
      builder: (context, connected, _) => Tooltip(
        message: connected ? context.l10n.realtimeOn : context.l10n.realtimeOff,
        child: Icon(
          connected ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
          // Arancio quando manca la connessione.
          color: connected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.secondary,
        ),
      ),
    );
  }
}

/// Campanella con il numero di notifiche non lette.
class _NotificationsButton extends StatelessWidget {
  const _NotificationsButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final unread = context.select<NotificationsController, int>((c) => c.unreadCount);
    return IconButton(
      tooltip: context.l10n.notifications,
      onPressed: onPressed,
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text(unread > 99 ? '99+' : '$unread'),
        child: Icon(unread > 0 ? Icons.notifications : Icons.notifications_none),
      ),
    );
  }
}

String _dayLabel(DateTime day) => DateFormat('d MMM y').format(day);

/// Testo del periodo scelto ("Ultimi 15 giorni", "1 ott 2026 – 15 ott 2026"…).
String _periodLabel(ListFilter filter, bool past, AppLocalizations l) => switch (filter.period) {
  ListPeriod.all => l.allDates,
  ListPeriod.days15 => past ? l.last15Days : l.next15Days,
  ListPeriod.days30 => past ? l.last30Days : l.next30Days,
  ListPeriod.range =>
    filter.from == null || filter.to == null
        ? l.chooseDates
        : l.dateRange(_dayLabel(filter.from!), _dayLabel(filter.to!)),
};

/// Filtri attivi sotto le sezioni: uno per riga di popup, ciascuno si toglie con la X.
class _ActiveFilters extends StatelessWidget {
  const _ActiveFilters({required this.filter, required this.past, required this.people, required this.onChanged});

  final ListFilter filter;
  final bool past;
  final Map<int, AppUser> people;
  final ValueChanged<ListFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    Widget chip(IconData icon, String label, ListFilter cleared) => InputChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      visualDensity: VisualDensity.compact,
      onDeleted: () => onChanged(cleared),
    );
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        if (filter.ascending != null)
          chip(
            Icons.swap_vert,
            filter.ascending! ? l.dateAscending : l.dateDescending,
            filter.copyWith(ascending: () => null),
          ),
        if (filter.personId != null)
          chip(
            Icons.person_outline,
            people[filter.personId]?.name ?? l.filterPerson,
            filter.copyWith(personId: () => null),
          ),
        if (filter.period != ListPeriod.all)
          chip(
            Icons.event_outlined,
            _periodLabel(filter, past, l),
            filter.copyWith(period: ListPeriod.all, from: () => null, to: () => null),
          ),
        if (filter.product.isNotEmpty)
          chip(
            Icons.shopping_basket_outlined,
            l.containsProduct(filter.product),
            filter.copyWith(product: '', productListIds: () => null),
          ),
      ],
    );
  }
}

/// Popup della lente: ordine per data, persona, periodo (15 o 30 giorni, oppure da… a…) e prodotto nella lista.
class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.initial, required this.past, required this.people});

  final ListFilter initial;
  final bool past;
  final List<AppUser> people;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late bool? _ascending = widget.initial.ascending;
  late int? _personId = widget.people.any((p) => p.id == widget.initial.personId) ? widget.initial.personId : null;
  late ListPeriod _period = widget.initial.period;
  late DateTime? _from = widget.initial.from;
  late DateTime? _to = widget.initial.to;
  late final _product = TextEditingController(text: widget.initial.product);

  @override
  void dispose() {
    _product.dispose();
    super.dispose();
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: _from != null && _to != null ? DateTimeRange(start: _from!, end: _to!) : null,
      currentDate: now,
    );
    if (picked == null) return;
    setState(() {
      _period = ListPeriod.range;
      _from = picked.start;
      _to = picked.end;
    });
  }

  void _apply() {
    final product = _product.text.trim();
    final range = _period == ListPeriod.range && _from != null && _to != null;
    Navigator.pop(
      context,
      ListFilter(
        ascending: _ascending,
        personId: _personId,
        period: _period == ListPeriod.range && !range ? ListPeriod.all : _period,
        from: range ? _from : null,
        to: range ? _to : null,
        product: product,
        productListIds: product == widget.initial.product ? widget.initial.productListIds : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final text = Theme.of(context).textTheme;
    final filterNow = ListFilter(period: _period, from: _from, to: _to);
    Widget title(String s) => Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(s, style: text.titleSmall),
    );
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l.filterLists, style: text.titleLarge),
              title(l.sortOrder),
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(value: true, icon: const Icon(Icons.arrow_upward), label: Text(l.dateAscending)),
                  ButtonSegment(value: false, icon: const Icon(Icons.arrow_downward), label: Text(l.dateDescending)),
                ],
                selected: {_ascending ?? !widget.past},
                onSelectionChanged: (value) => setState(() => _ascending = value.first),
              ),
              if (widget.people.isNotEmpty) ...[
                title(l.filterPerson),
                DropdownButtonFormField<int?>(
                  initialValue: _personId,
                  isExpanded: true,
                  items: [
                    DropdownMenuItem(value: null, child: Text(l.everyone)),
                    for (final person in widget.people)
                      DropdownMenuItem(
                        value: person.id,
                        child: Text(person.name, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (value) => setState(() => _personId = value),
                ),
              ],
              title(l.filterPeriod),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final period in [ListPeriod.all, ListPeriod.days15, ListPeriod.days30])
                    ChoiceChip(
                      label: Text(_periodLabel(ListFilter(period: period), widget.past, l)),
                      selected: _period == period,
                      onSelected: (_) => setState(() => _period = period),
                    ),
                  ChoiceChip(
                    avatar: const Icon(Icons.date_range, size: 18),
                    label: Text(_periodLabel(filterNow.copyWith(period: ListPeriod.range), widget.past, l)),
                    selected: _period == ListPeriod.range,
                    onSelected: (_) => _pickRange(),
                  ),
                ],
              ),
              title(l.productInLists),
              TextField(
                controller: _product,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _apply(),
                decoration: InputDecoration(hintText: l.productInListsHint, prefixIcon: const Icon(Icons.search)),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  TextButton(onPressed: () => Navigator.pop(context, const ListFilter()), child: Text(l.resetFilters)),
                  const Spacer(),
                  FilledButton(onPressed: _apply, child: Text(l.applyFilters)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
