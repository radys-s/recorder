import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/data/db/app_database.dart';
import 'package:recorder/data/secure/api_key_store.dart';
import 'package:recorder/sync/drive_api.dart';
import 'package:recorder/sync/google_auth.dart';
import 'package:recorder/sync/web_authenticator.dart';

const _clientId = '1234-abcdef.apps.googleusercontent.com';

/// Answers each request with the next queued response and keeps what was
/// sent, decoded.
class _Adapter implements HttpClientAdapter {
  _Adapter(this.responses);

  final List<(int, Object)> responses;
  final requests = <RequestOptions>[];
  final bodies = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    bodies.add(
      requestStream == null
          ? ''
          : utf8.decode(await requestStream.expand((b) => b).toList()),
    );
    final (status, body) = responses.removeAt(0);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Tokens implements ApiKeyStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String key) async => value = key;

  @override
  Future<void> delete() async => value = null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Answers the sign-in sheet with whatever [reply] builds from the request.
class _Web implements WebAuthenticator {
  _Web(this.reply);

  final Uri Function(Uri url) reply;
  Uri? opened;
  String? scheme;

  @override
  Future<Uri> authenticate(Uri url, {required String callbackScheme}) async {
    opened = url;
    scheme = callbackScheme;
    return reply(url);
  }

  @override
  Future<String?> bundleId() async => 'com.example.app';
}

Uri _okCallback(Uri url) => Uri.parse(
  '${reversedClientId(_clientId)}:/oauth2redirect'
  '?code=the-code&state=${url.queryParameters['state']}',
);

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('pure helpers', () {
    test('PKCE challenge matches the RFC 7636 example', () {
      expect(
        Pkce.challengeFor('dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk'),
        'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM',
      );
      final pkce = Pkce.generate();
      expect(pkce.verifier.length, 64);
      expect(pkce.verifier, matches(RegExp(r'^[A-Za-z0-9\-._~]+$')));
    });

    test('client id check and the reversed redirect scheme', () {
      expect(isValidGoogleClientId(' $_clientId '), isTrue);
      expect(isValidGoogleClientId('abc.apps.googleusercontent.com'), isFalse);
      expect(isValidGoogleClientId('1234-abc'), isFalse);
      expect(
        redirectUriFor(_clientId),
        'com.googleusercontent.apps.1234-abcdef:/oauth2redirect',
      );
    });

    test('authorization url asks for drive.file with PKCE and consent', () {
      final url = authorizationUrl(
        clientId: _clientId,
        codeChallenge: 'ch',
        state: 'st',
      );
      final q = url.queryParameters;
      expect(url.host, 'accounts.google.com');
      expect(q['scope'], 'https://www.googleapis.com/auth/drive.file');
      expect(q['code_challenge_method'], 'S256');
      expect(q['code_challenge'], 'ch');
      expect(q['state'], 'st');
      expect(q['redirect_uri'], redirectUriFor(_clientId));
      expect(q['prompt'], contains('consent'));
    });

    test('callback: code, wrong state, denial', () {
      final base = redirectUriFor(_clientId);
      expect(codeFromCallback(Uri.parse('$base?code=c&state=s'), 's'), 'c');
      expect(
        () => codeFromCallback(Uri.parse('$base?code=c&state=x'), 's'),
        throwsA(isA<GoogleSignInException>()),
      );
      expect(
        () => codeFromCallback(Uri.parse('$base?error=access_denied'), 's'),
        throwsA(
          isA<GoogleSignInException>().having(
            (e) => e.message,
            'message',
            contains('nebyl povolen'),
          ),
        ),
      );
      expect(
        () => codeFromCallback(Uri.parse('$base?state=s'), 's'),
        throwsA(isA<GoogleSignInException>()),
      );
    });
  });

  group('GoogleAuthClient', () {
    final now = DateTime(2026, 9, 19, 10);

    test('exchanges the code with the verifier and reads the expiry', () async {
      final adapter = _Adapter([
        (200, {'access_token': 'at', 'expires_in': 3599, 'refresh_token': 'rt'}),
      ]);
      final client = GoogleAuthClient(
        Dio()..httpClientAdapter = adapter,
        now: () => now,
      );
      final tokens = await client.exchangeCode(
        clientId: _clientId,
        code: 'the-code',
        codeVerifier: 'v',
      );
      expect(tokens.accessToken, 'at');
      expect(tokens.refreshToken, 'rt');
      expect(tokens.expiresAt, now.add(const Duration(seconds: 3599)));
      final form = Uri.splitQueryString(adapter.bodies.single);
      expect(form['grant_type'], 'authorization_code');
      expect(form['code_verifier'], 'v');
      expect(form['redirect_uri'], redirectUriFor(_clientId));
      expect(form.containsKey('client_secret'), isFalse);
    });

    test('invalid_grant and an unknown client ask for a new sign-in', () async {
      Future<void> expectAuth(String error) async {
        final client = GoogleAuthClient(
          Dio()
            ..httpClientAdapter = _Adapter([
              (400, {'error': error}),
            ]),
        );
        await expectLater(
          client.refresh(clientId: _clientId, refreshToken: 'rt'),
          throwsA(isA<DriveAuthException>()),
        );
      }

      await expectAuth('invalid_grant');
      await expectAuth('invalid_client');
    });

    test('a 503 from the token endpoint is transient', () async {
      final client = GoogleAuthClient(
        Dio()
          ..httpClientAdapter = _Adapter([
            (503, {'error': 'backendError'}),
          ]),
      );
      await expectLater(
        client.refresh(clientId: _clientId, refreshToken: 'rt'),
        throwsA(isA<DriveTransientException>()),
      );
    });
  });

  group('GoogleAccount', () {
    late AppDatabase db;
    late _Tokens tokens;
    var clock = DateTime(2026, 9, 19, 10);

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      tokens = _Tokens();
      clock = DateTime(2026, 9, 19, 10);
      await db.preferencesDao.setGoogleClientId(_clientId);
    });

    tearDown(() => db.close());

    GoogleAccount account(_Adapter adapter, {WebAuthenticator? web}) =>
        GoogleAccount(
          prefs: db.preferencesDao,
          refreshTokenStore: tokens,
          authenticator: web ?? _Web(_okCallback),
          auth: GoogleAuthClient(
            Dio()..httpClientAdapter = adapter,
            now: () => clock,
          ),
          now: () => clock,
        );

    test('sign-in stores the refresh token and the email', () async {
      final web = _Web(_okCallback);
      final adapter = _Adapter([
        (200, {'access_token': 'at', 'expires_in': 3600, 'refresh_token': 'rt'}),
        (200, {'user': {'emailAddress': 'student@example.com'}}),
      ]);
      final acc = account(adapter, web: web);

      expect(await acc.signIn(), isNull);
      expect(tokens.value, 'rt');
      expect(
        (await db.preferencesDao.current()).googleAccountEmail,
        'student@example.com',
      );
      expect(web.scheme, 'com.googleusercontent.apps.1234-abcdef');
      expect(await acc.accessToken(), 'at');
      expect(adapter.requests, hasLength(2));
    });

    test('sign-in without Drive API enabled still signs in, with a warning',
        () async {
      final acc = account(
        _Adapter([
          (200, {'access_token': 'at', 'expires_in': 3600, 'refresh_token': 'rt'}),
          (403, {'error': {'status': 'PERMISSION_DENIED', 'message': 'SERVICE_DISABLED'}}),
        ]),
      );
      expect(await acc.signIn(), contains('Google Drive API'));
      expect((await db.preferencesDao.current()).googleAccountEmail, '');
    });

    test('no client id, no sheet', () async {
      await db.preferencesDao.setGoogleClientId(null);
      final web = _Web(_okCallback);
      await expectLater(
        account(_Adapter([]), web: web).signIn(),
        throwsA(isA<GoogleSignInException>()),
      );
      expect(web.opened, isNull);
    });

    test('an expiring access token is refreshed once for parallel callers',
        () async {
      tokens.value = 'rt';
      await db.preferencesDao.setGoogleAccountEmail('s@example.com');
      final adapter = _Adapter([
        (200, {'access_token': 'fresh', 'expires_in': 3600}),
      ]);
      final acc = account(adapter);

      final both = await Future.wait([acc.accessToken(), acc.accessToken()]);
      expect(both, ['fresh', 'fresh']);
      expect(adapter.requests, hasLength(1));
      expect(tokens.value, 'rt', reason: 'a refresh keeps the old token');
    });

    test('a dead grant signs the student out everywhere', () async {
      tokens.value = 'rt';
      await db.preferencesDao.setGoogleAccountEmail('s@example.com');
      final acc = account(
        _Adapter([
          (400, {'error': 'invalid_grant'}),
        ]),
      );

      await expectLater(acc.accessToken(), throwsA(isA<DriveAuthException>()));
      expect(tokens.value, isNull);
      expect((await db.preferencesDao.current()).googleAccountEmail, isNull);
    });

    test('sign-out revokes and forgets, even when revoking fails', () async {
      tokens.value = 'rt';
      await db.preferencesDao.setGoogleAccountEmail('s@example.com');
      final adapter = _Adapter([
        (500, {'error': 'x'}),
      ]);
      await account(adapter).signOut();
      expect(adapter.requests.single.uri.toString(), contains('revoke'));
      expect(tokens.value, isNull);
      expect((await db.preferencesDao.current()).googleAccountEmail, isNull);
    });
  });
}
