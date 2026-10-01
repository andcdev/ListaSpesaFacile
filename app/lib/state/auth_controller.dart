import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../services/api_client.dart';
import '../services/background_notifications.dart';
import '../services/notification_service.dart';
import '../services/realtime_client.dart';
import '../services/session_storage.dart';
import '../services/social_login.dart';

enum AuthStatus { unknown, signedOut, signedIn }

class AuthController extends ChangeNotifier {
  AuthController({
    required this.api,
    required this.realtime,
    required this.storage,
    SocialLogin? socialLogin,
    NotificationService? notifications,
  }) : socialLogin = socialLogin ?? SocialLogin(api),
       notifications = notifications ?? NotificationService() {
    api.onUnauthorized = () => _signOutLocally();
  }

  final ApiClient api;
  final RealtimeClient realtime;
  final SessionStorage storage;
  final SocialLogin socialLogin;
  final NotificationService notifications;

  AuthStatus status = AuthStatus.unknown;
  AppUser? user;

  /// Provider social attivi sul server (per mostrare i pulsanti nella schermata di accesso).
  List<String> socialProviders = [];

  /// Configurazione del server letta all'accesso (reparti, unità di misura…).
  ServerConfig? serverConfig;

  String get serverUrl => api.baseUrl;

  /// Ripristina la sessione salvata all'avvio dell'app.
  Future<void> init() async {
    api.baseUrl = await storage.readServerUrl();
    api.token = await storage.readToken();
    if (api.token == null) {
      status = AuthStatus.signedOut;
      notifyListeners();
      await loadSocialProviders();
      return;
    }
    try {
      user = await api.me();
      await _startSession();
    } on ApiException catch (e) {
      // Offline: si resta sulla schermata di accesso solo se il token non è più valido.
      if (e.statusCode == 401) {
        await _signOutLocally();
        return;
      }
      status = AuthStatus.signedOut;
      notifyListeners();
      await loadSocialProviders();
    }
  }

  Future<void> loadSocialProviders() async {
    try {
      socialProviders = (await api.serverConfig()).socialProviders;
    } catch (_) {
      socialProviders = [];
    }
    notifyListeners();
  }

  Future<void> setServerUrl(String url) async {
    var normalized = url.trim().replaceAll(RegExp(r'/+$'), '');
    if (!normalized.startsWith('http')) normalized = 'https://$normalized';
    api.baseUrl = normalized;
    await storage.writeServerUrl(normalized);
    notifyListeners();
    await loadSocialProviders();
  }

  Future<void> login(String email, String password) async {
    final (token, user) = await api.login(email.trim(), password);
    await _signedIn(token, user);
  }

  Future<void> register(
    String name,
    String email,
    String password, {
    required bool privacy,
    bool newsletter = false,
  }) async {
    final (token, user) = await api.register(
      name.trim(),
      email.trim(),
      password,
      privacy: privacy,
      newsletter: newsletter,
    );
    await _signedIn(token, user);
  }

  /// Foto profilo (dalla galleria o dalla fotocamera), mostrata agli altri accanto ai messaggi della chat.
  Future<void> setAvatar(String filePath) async {
    user = await api.uploadAvatar(filePath);
    notifyListeners();
  }

  Future<void> removeAvatar() async {
    user = await api.deleteAvatar();
    notifyListeners();
  }

  /// Recupero della password: il server invia un codice all'email.
  Future<String> forgotPassword(String email) => api.forgotPassword(email.trim());

  /// Codice ricevuto via email + nuova password: al termine l'utente è dentro.
  Future<void> resetPassword(String email, String code, String password) async {
    final (token, user) = await api.resetPassword(email.trim(), code.trim(), password);
    await _signedIn(token, user);
  }

  /// Accesso o registrazione con Google / Amazon. false se l'utente ha annullato.
  Future<bool> loginWithSocial(String provider) async {
    final result = await socialLogin.signIn(provider);
    if (result == null) return false;
    final (token, user) = result;
    await _signedIn(token, user);
    return true;
  }

  Future<void> logout() async {
    await notifications.endSession();
    try {
      await api.logout();
    } catch (_) {
      // Il token verrà comunque dimenticato localmente.
    }
    await _signOutLocally();
  }

  /// Elimina l'account sul server, poi esce come al logout. Se il server non risponde si resta collegati.
  Future<void> deleteAccount() async {
    await api.deleteAccount();
    // Il token non vale più: uscendo, nessuna chiamata deve usarlo (un 401 farebbe ripartire l'uscita).
    api.token = null;
    await _signOutLocally();
  }

  Future<void> _signedIn(String token, AppUser user) async {
    api.token = token;
    this.user = user;
    await storage.writeToken(token);
    await _startSession();
  }

  /// Lingua dell'app cambiata: reparti e unità tradotti dal server, lingua salvata sul profilo (per le notifiche).
  Future<void> languageChanged() async {
    try {
      if (status == AuthStatus.signedIn) {
        user = await api.me();
        serverConfig = await api.serverConfig();
      }
    } catch (e) {
      debugPrint('Lingua non aggiornata sul server: $e');
    }
    notifyListeners();
  }

  Future<void> _startSession() async {
    status = AuthStatus.signedIn;
    notifyListeners();
    await _connectServices();
  }

  Timer? _retry;

  /// Tempo reale e notifiche. Se il server non risponde (es. app aperta senza rete) si riprova da soli,
  /// altrimenti liste e messaggi nuovi comparirebbero solo riavviando l'app.
  Future<void> _connectServices() async {
    _retry?.cancel();
    try {
      final config = await api.serverConfig();
      serverConfig = config;
      notifyListeners();
      await realtime.connect(config.realtime);
      await notifications.startSession(api, serverPush: config.push);
      // Senza Firebase le notifiche ad app chiusa le mostra il servizio in background.
      if (notifications.pushActive) {
        await BackgroundNotifications.stop();
      } else {
        notifications.backgroundServiceActive = await BackgroundNotifications.start();
      }
    } catch (e) {
      debugPrint('Tempo reale non disponibile: $e');
      if (status == AuthStatus.signedIn) _retry = Timer(const Duration(seconds: 20), _connectServices);
    }
  }

  /// L'app torna in primo piano: connessione ripristinata subito e dati ricaricati (liste nuove comprese).
  void resume() {
    if (status != AuthStatus.signedIn) return;
    if (serverConfig == null) {
      _connectServices();
    } else {
      realtime.resume();
    }
  }

  Future<void> _signOutLocally() async {
    _retry?.cancel();
    notifications.backgroundServiceActive = false;
    await BackgroundNotifications.stop();
    await notifications.endSession();
    realtime.disconnect();
    api.token = null;
    user = null;
    await storage.writeToken(null);
    status = AuthStatus.signedOut;
    notifyListeners();
    await loadSocialProviders();
  }
}
