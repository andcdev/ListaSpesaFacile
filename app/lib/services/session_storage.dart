import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Indirizzo del server predefinito: il server di produzione.
/// Per il backend in locale: `flutter run --dart-define=API_URL=http://10.0.2.2` (10.0.2.2 è il localhost della
/// macchina host visto dall'emulatore Android), oppure la voce "Server" nella schermata di accesso.
const defaultServerUrl = String.fromEnvironment('API_URL', defaultValue: 'https://api.listaspesafacile.com');

/// Persistenza del token (in modo sicuro) e dell'indirizzo del server.
class SessionStorage {
  static const _tokenKey = 'auth_token';
  static const _serverKey = 'server_url';

  final _secure = const FlutterSecureStorage();

  Future<String?> readToken() => _secure.read(key: _tokenKey);

  Future<void> writeToken(String? token) =>
      token == null ? _secure.delete(key: _tokenKey) : _secure.write(key: _tokenKey, value: token);

  Future<String> readServerUrl() async =>
      (await SharedPreferences.getInstance()).getString(_serverKey) ?? defaultServerUrl;

  Future<void> writeServerUrl(String url) async => (await SharedPreferences.getInstance()).setString(_serverKey, url);
}
