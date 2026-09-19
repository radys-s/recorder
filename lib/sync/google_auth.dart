import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/constants.dart';
import '../data/db/daos/preferences_dao.dart';
import '../data/secure/api_key_store.dart';
import 'drive_api.dart' show DriveAuthException, DriveTransientException;
import 'web_authenticator.dart';

final _clientIdPattern = RegExp(r'^\d+-[a-z0-9]+\.apps\.googleusercontent\.com$');

/// What Google Cloud shows for an iOS OAuth client.
bool isValidGoogleClientId(String value) =>
    _clientIdPattern.hasMatch(value.trim());

/// `123-abc.apps.googleusercontent.com` → `com.googleusercontent.apps.123-abc`,
/// the URL scheme Google redirects an iOS client back to.
String reversedClientId(String clientId) {
  final prefix = clientId.trim().replaceFirst('.apps.googleusercontent.com', '');
  return 'com.googleusercontent.apps.$prefix';
}

String redirectUriFor(String clientId) =>
    '${reversedClientId(clientId)}:/oauth2redirect';

/// Proof Key for Code Exchange: the app has no client secret, so this is what
/// stops anybody who catches the redirect from swapping the code for tokens.
class Pkce {
  const Pkce(this.verifier);

  factory Pkce.generate([Random? random]) {
    final r = random ?? Random.secure();
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    return Pkce(
      String.fromCharCodes(
        List.generate(64, (_) => chars.codeUnitAt(r.nextInt(chars.length))),
      ),
    );
  }

  final String verifier;

  String get challenge => challengeFor(verifier);

  static String challengeFor(String verifier) =>
      base64Url
          .encode(sha256.convert(ascii.encode(verifier)).bytes)
          .replaceAll('=', '');
}

String randomState([Random? random]) {
  final r = random ?? Random.secure();
  return base64Url
      .encode(List.generate(16, (_) => r.nextInt(256)))
      .replaceAll('=', '');
}

Uri authorizationUrl({
  required String clientId,
  required String codeChallenge,
  required String state,
}) => Uri.parse(kGoogleAuthUrl).replace(
  queryParameters: {
    'client_id': clientId.trim(),
    'redirect_uri': redirectUriFor(clientId),
    'response_type': 'code',
    'scope': kDriveScope,
    'code_challenge': codeChallenge,
    'code_challenge_method': 'S256',
    'state': state,
    // Always ask: a refresh token only comes with a fresh consent.
    'prompt': 'select_account consent',
  },
);

/// Sign-in did not finish; [message] is for the student.
class GoogleSignInException implements Exception {
  const GoogleSignInException(this.message);
  final String message;
  @override
  String toString() => 'GoogleSignInException: $message';
}

/// The authorization code from the redirect, after checking it answers the
/// request this app made.
String codeFromCallback(Uri callback, String expectedState) {
  final params = callback.queryParameters;
  final error = params['error'];
  if (error != null) {
    throw GoogleSignInException(
      error == 'access_denied'
          ? 'Přístup ke Google Disku nebyl povolen.'
          : 'Google přihlášení odmítl ($error).',
    );
  }
  if (params['state'] != expectedState) {
    throw const GoogleSignInException(
      'Odpověď od Googlu nepatří k tomuto přihlášení. Zkus to znovu.',
    );
  }
  final code = params['code'];
  if (code == null || code.isEmpty) {
    throw const GoogleSignInException('Google nevrátil přihlašovací kód.');
  }
  return code;
}

class GoogleTokens {
  const GoogleTokens({
    required this.accessToken,
    required this.expiresAt,
    this.refreshToken,
  });

  final String accessToken;
  final DateTime expiresAt;

  /// Only on the first exchange; a refresh keeps the old one.
  final String? refreshToken;
}

/// Google's OAuth endpoints for an installed app: no client secret, PKCE.
class GoogleAuthClient {
  GoogleAuthClient(this._dio, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final Dio _dio;
  final DateTime Function() _now;

  Future<GoogleTokens> exchangeCode({
    required String clientId,
    required String code,
    required String codeVerifier,
  }) => _token({
    'code': code,
    'client_id': clientId.trim(),
    'redirect_uri': redirectUriFor(clientId),
    'grant_type': 'authorization_code',
    'code_verifier': codeVerifier,
  });

  Future<GoogleTokens> refresh({
    required String clientId,
    required String refreshToken,
  }) => _token({
    'client_id': clientId.trim(),
    'refresh_token': refreshToken,
    'grant_type': 'refresh_token',
  });

  Future<void> revoke(String token) async {
    await _dio.post<dynamic>(
      kGoogleRevokeUrl,
      data: {'token': token},
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );
  }

  /// The account the tokens belong to, for „Přihlášeno jako …".
  Future<String?> accountEmail(String accessToken) async {
    final response = await _dio.get<dynamic>(
      kDriveAboutUrl,
      queryParameters: {'fields': 'user(emailAddress)'},
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    final data = response.data;
    if (data is Map && data['user'] is Map) {
      return (data['user'] as Map)['emailAddress'] as String?;
    }
    return null;
  }

  Future<GoogleTokens> _token(Map<String, String> form) async {
    try {
      final response = await _dio.post<dynamic>(
        kGoogleTokenUrl,
        data: form,
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      final data = response.data as Map;
      final access = data['access_token'] as String?;
      if (access == null) {
        throw const GoogleSignInException('Google nevrátil přístupový token.');
      }
      final seconds = (data['expires_in'] as num?)?.toInt() ?? 3600;
      return GoogleTokens(
        accessToken: access,
        expiresAt: _now().add(Duration(seconds: seconds)),
        refreshToken: data['refresh_token'] as String?,
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final body = e.response?.data;
      final error = body is Map ? body['error'] as String? : null;
      if (error == 'invalid_grant') {
        throw const DriveAuthException(
          'Přihlášení ke Googlu vypršelo. Přihlas se znovu.',
        );
      }
      if (error == 'invalid_client' || error == 'unauthorized_client') {
        throw const DriveAuthException(
          'Google nezná tohle Client ID. Zkontroluj ho v Nastavení.',
        );
      }
      if (status == null || status == 429 || status >= 500) {
        throw DriveTransientException('Google token: ${e.type.name} $status');
      }
      throw GoogleSignInException(
        'Google přihlášení odmítl (HTTP $status${error == null ? '' : ', $error'}).',
      );
    }
  }
}

/// The signed-in Google account: refresh token in the Keychain, access token
/// in memory, email in preferences (null = signed out).
class GoogleAccount {
  GoogleAccount({
    required this._prefs,
    required ApiKeyStore refreshTokenStore,
    required WebAuthenticator authenticator,
    required this._auth,
    DateTime Function()? now,
  }) : _tokens = refreshTokenStore,
       _web = authenticator,
       _now = now ?? DateTime.now;

  final PreferencesDao _prefs;
  final ApiKeyStore _tokens;
  final WebAuthenticator _web;
  final GoogleAuthClient _auth;
  final DateTime Function() _now;

  String? _accessToken;
  DateTime? _accessExpiresAt;
  Future<String>? _refreshing;

  Future<String?> _clientId() async {
    final id = (await _prefs.current()).googleClientId?.trim();
    return (id == null || id.isEmpty) ? null : id;
  }

  /// Opens Google's sign-in sheet. Returns a warning for the student when
  /// sign-in worked but something around it did not, else null.
  Future<String?> signIn() async {
    final clientId = await _clientId();
    if (clientId == null || !isValidGoogleClientId(clientId)) {
      throw const GoogleSignInException(
        'Nejdřív vlož Client ID z Google Cloud.',
      );
    }
    final pkce = Pkce.generate();
    final state = randomState();
    final Uri callback;
    try {
      callback = await _web.authenticate(
        authorizationUrl(
          clientId: clientId,
          codeChallenge: pkce.challenge,
          state: state,
        ),
        callbackScheme: reversedClientId(clientId),
      );
    } on WebAuthUnsupported {
      throw const GoogleSignInException(
        'Přihlášení ke Googlu zatím funguje jen na iPhonu.',
      );
    }
    final code = codeFromCallback(callback, state);
    final tokens = await _auth.exchangeCode(
      clientId: clientId,
      code: code,
      codeVerifier: pkce.verifier,
    );
    final refresh = tokens.refreshToken;
    if (refresh == null) {
      throw const GoogleSignInException(
        'Google nevrátil trvalé přihlášení. Zkus to znovu.',
      );
    }
    await _tokens.write(refresh);
    _accessToken = tokens.accessToken;
    _accessExpiresAt = tokens.expiresAt;

    String? warning;
    String email = '';
    try {
      email = await _auth.accountEmail(tokens.accessToken) ?? '';
    } on DioException catch (e) {
      final body = e.response?.data?.toString() ?? '';
      if (e.response?.statusCode == 403 &&
          (body.contains('accessNotConfigured') ||
              body.contains('SERVICE_DISABLED'))) {
        warning = 'Přihlášeno, ale v Google Cloud projektu není zapnuté '
            'Google Drive API. Zapni ho, jinak synchronizace nepůjde.';
      }
      debugPrint('google: account email failed: ${e.type.name}');
    }
    // An empty email still means signed in; the UI says „Přihlášeno".
    await _prefs.setGoogleAccountEmail(email);
    return warning;
  }

  /// A valid access token, refreshed when it is about to expire.
  Future<String> accessToken() async {
    final token = _accessToken;
    final expires = _accessExpiresAt;
    if (token != null &&
        expires != null &&
        _now().isBefore(expires.subtract(const Duration(seconds: 60)))) {
      return token;
    }
    return _refreshing ??= _refresh().whenComplete(() => _refreshing = null);
  }

  /// Forgets the access token, so the next call refreshes it (after a 401).
  void invalidateAccessToken() {
    _accessToken = null;
    _accessExpiresAt = null;
  }

  Future<String> _refresh() async {
    final clientId = await _clientId();
    final refresh = await _tokens.read();
    if (clientId == null || refresh == null) {
      throw const DriveAuthException('Nejsi přihlášený ke Googlu.');
    }
    try {
      final tokens = await _auth.refresh(
        clientId: clientId,
        refreshToken: refresh,
      );
      _accessToken = tokens.accessToken;
      _accessExpiresAt = tokens.expiresAt;
      return tokens.accessToken;
    } on DriveAuthException {
      // The grant is dead: say so everywhere instead of retrying forever.
      await _tokens.delete();
      await _prefs.setGoogleAccountEmail(null);
      invalidateAccessToken();
      rethrow;
    }
  }

  Future<void> signOut() async {
    final refresh = await _tokens.read();
    if (refresh != null) {
      try {
        await _auth.revoke(refresh);
      } catch (e) {
        debugPrint('google: revoke failed: $e');
      }
    }
    await _tokens.delete();
    invalidateAccessToken();
    await _prefs.setGoogleAccountEmail(null);
  }
}
