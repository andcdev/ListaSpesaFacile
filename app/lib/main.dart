import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'l10n/l10n.dart';

import 'screens/lists_screen.dart';
import 'screens/login_screen.dart';
import 'services/api_client.dart';
import 'services/background_notifications.dart';
import 'services/notification_service.dart';
import 'services/realtime_client.dart';
import 'services/session_storage.dart';
import 'state/appearance_controller.dart';
import 'state/auth_controller.dart';
import 'state/locale_controller.dart';
import 'state/lists_controller.dart';
import 'state/notifications_controller.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Nomi di giorni e mesi di tutte le lingue: la lingua si può cambiare mentre l'app è aperta.
  await initializeDateFormatting();
  final locale = LocaleController();
  await locale.load();

  // Servizio che mostra le notifiche con l'app chiusa (se Firebase non è configurato).
  BackgroundNotifications.init();
  await BackgroundNotifications.setAppInForeground(true);

  final api = ApiClient(baseUrl: defaultServerUrl)..language = locale.language;
  final realtime = RealtimeClient(api);
  final notifications = NotificationService();
  await notifications.init();
  final auth = AuthController(api: api, realtime: realtime, storage: SessionStorage(), notifications: notifications)
    ..init();
  final appearance = AppearanceController();
  await appearance.load();
  // Tornando nell'app: connessione in tempo reale ripristinata e liste ricaricate, senza aggiornare a mano.
  // Mentre l'app è sullo schermo le notifiche le mostra lei, altrimenti il servizio in background.
  AppLifecycleListener(
    onResume: () {
      BackgroundNotifications.setAppInForeground(true);
      notifications.openTapped();
      auth.resume();
    },
    onHide: () => BackgroundNotifications.setAppInForeground(false),
  );
  // Nuova lingua: il server la usa per errori, reparti e notifiche (anche push, salvata sul profilo).
  locale.addListener(() {
    if (api.language == locale.language) return;
    api.language = locale.language;
    auth.languageChanged();
  });

  runApp(
    MultiProvider(
      providers: [
        Provider.value(value: api),
        Provider.value(value: realtime),
        Provider.value(value: notifications),
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider.value(value: appearance),
        ChangeNotifierProvider.value(value: locale),
      ],
      child: const ListaSpesaApp(),
    ),
  );
}

class ListaSpesaApp extends StatelessWidget {
  const ListaSpesaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (_) => 'Lista Spesa Facile',
      debugShowCheckedModeBanner: false,
      // Sfondo chiaro o scuro scelto dall'utente (menu del profilo), oppure come il telefono.
      themeMode: context.watch<AppearanceController>().mode,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // Lingua scelta nell'app oppure quella del telefono (vedi LocaleController).
      locale: context.watch<LocaleController>().locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: const AuthGate(),
    );
  }
}

/// Mostra accesso o liste in base allo stato della sessione.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    return switch (auth.status) {
      AuthStatus.unknown => const Scaffold(body: Center(child: CircularProgressIndicator())),
      AuthStatus.signedOut => const LoginScreen(),
      AuthStatus.signedIn => MultiProvider(
        // Nuove istanze per ogni utente: la chiave forza la ricreazione dopo un cambio account.
        key: ValueKey(auth.user!.id),
        providers: [
          ChangeNotifierProvider(
            create: (context) => ListsController(
              api: context.read<ApiClient>(),
              realtime: context.read<RealtimeClient>(),
              notifications: context.read<NotificationService>(),
              userId: auth.user!.id,
            )..start(),
          ),
          ChangeNotifierProvider(
            create: (context) => NotificationsController(
              api: context.read<ApiClient>(),
              realtime: context.read<RealtimeClient>(),
              service: context.read<NotificationService>(),
              userId: auth.user!.id,
            )..start(),
          ),
        ],
        child: const ListsScreen(),
      ),
    };
  }
}
