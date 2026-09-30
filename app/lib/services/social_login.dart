import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

import '../l10n/l10n.dart';
import '../models/app_user.dart';
import 'api_client.dart';

typedef WebAuthenticator = Future<String> Function(Uri url, String callbackScheme);

/// Login con Google / Amazon tramite il backend.
///
/// Apre la pagina del server nel browser di sistema (Custom Tabs su Android,
/// ASWebAuthenticationSession su iOS); al termine il server riapre l'app su
/// `listaspesafacile://auth?code=…` e il codice viene scambiato con un token
/// insieme al code_verifier PKCE, che non lascia mai il dispositivo.
class SocialLogin {
  SocialLogin(this._api, {WebAuthenticator? authenticator}) : _authenticate = authenticator ?? _systemBrowser;

  /// Deve coincidere con SOCIAL_APP_CALLBACK del backend e con l'intent-filter Android.
  static const callbackScheme = 'listaspesafacile';

  static const labels = {'google': 'Google', 'amazon': 'Amazon'};

  final ApiClient _api;
  final WebAuthenticator _authenticate;

  /// Restituisce token e utente, oppure null se l'utente ha annullato.
  Future<(String, AppUser)?> signIn(String provider) async {
    final verifier = generateVerifier();
    final String result;
    try {
      result = await _authenticate(
        _api.socialLoginUrl(provider, codeChallenge: challengeFor(verifier)),
        callbackScheme,
      );
    } on PlatformException catch (e) {
      if (e.code == 'CANCELED') return null;
      throw ApiException(appL10n.socialOpenFailed(labels[provider] ?? provider));
    }

    final params = Uri.parse(result).queryParameters;
    final code = params['code'];
    if (code == null) throw ApiException(params['error'] ?? appL10n.socialFailed);
    return _api.exchangeSocialCode(code, verifier);
  }

  static String generateVerifier() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final random = Random.secure();
    return List.generate(64, (_) => chars[random.nextInt(chars.length)]).join();
  }

  static String challengeFor(String verifier) =>
      base64Url.encode(sha256.convert(ascii.encode(verifier)).bytes).replaceAll('=', '');

  static Future<String> _systemBrowser(Uri url, String callbackScheme) =>
      FlutterWebAuth2.authenticate(url: url.toString(), callbackUrlScheme: callbackScheme);
}
