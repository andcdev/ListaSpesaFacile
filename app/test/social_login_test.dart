import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lista_spesa_facile/services/api_client.dart';
import 'package:lista_spesa_facile/services/social_login.dart';

void main() {
  late List<http.Request> requests;
  late ApiClient api;

  setUp(() {
    requests = [];
    api = ApiClient(
      baseUrl: 'https://spesa.example.com/',
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode({
            'token': 'tok',
            'user': {'id': 1, 'name': 'Giulia', 'email': 'g@example.com'},
          }),
          200,
        );
      }),
    );
  });

  test('apre la pagina del server con la challenge PKCE e scambia il codice con il verifier', () async {
    late Uri opened;
    final login = SocialLogin(
      api,
      authenticator: (url, scheme) async {
        opened = url;
        expect(scheme, 'listaspesafacile');
        return 'listaspesafacile://auth?code=abc';
      },
    );

    final (token, user) = (await login.signIn('google'))!;

    expect(token, 'tok');
    expect(user.name, 'Giulia');
    expect(opened.toString(), startsWith('https://spesa.example.com/auth/google/redirect?code_challenge='));

    final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
    expect(requests.single.url.path, '/api/auth/social/exchange');
    expect(body['code'], 'abc');
    final expected = base64Url
        .encode(sha256.convert(ascii.encode(body['code_verifier'] as String)).bytes)
        .replaceAll('=', '');
    expect(opened.queryParameters['code_challenge'], expected);
  });

  test('annullamento restituisce null senza chiamare il server', () async {
    final login = SocialLogin(api, authenticator: (_, _) async => throw PlatformException(code: 'CANCELED'));

    expect(await login.signIn('amazon'), isNull);
    expect(requests, isEmpty);
  });

  test('errore restituito dal server viene mostrato all\'utente', () async {
    final login = SocialLogin(
      api,
      authenticator: (_, _) async => 'listaspesafacile://auth?error=Il+tuo+account+Amazon+non+condivide+l%27email',
    );

    await expectLater(
      login.signIn('amazon'),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('non condivide'))),
    );
  });

  test('verifier conforme a RFC 7636', () {
    final v = SocialLogin.generateVerifier();
    expect(v.length, inInclusiveRange(43, 128));
    expect(RegExp(r'^[A-Za-z0-9\-._~]+$').hasMatch(v), isTrue);
    expect(SocialLogin.challengeFor(v), hasLength(43));
    expect(SocialLogin.generateVerifier(), isNot(v));
  });
}
