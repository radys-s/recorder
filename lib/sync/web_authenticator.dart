import 'package:flutter/services.dart';

/// The student closed the sign-in sheet.
class WebAuthCancelled implements Exception {
  const WebAuthCancelled();
  @override
  String toString() => 'WebAuthCancelled';
}

/// There is no system sign-in sheet on this platform (Android, web).
class WebAuthUnsupported implements Exception {
  const WebAuthUnsupported();
  @override
  String toString() => 'WebAuthUnsupported';
}

/// Opens a sign-in page in the system browser sheet and hands back the URL it
/// redirected to.
abstract class WebAuthenticator {
  Future<Uri> authenticate(Uri url, {required String callbackScheme});

  /// The bundle id the app actually runs with — a sideloaded build may not
  /// carry the one in the project, and Google's iOS client must match it.
  Future<String?> bundleId();
}

/// `ASWebAuthenticationSession`, through `WebAuthPlugin` in `AppDelegate.swift`.
class ChannelWebAuthenticator implements WebAuthenticator {
  const ChannelWebAuthenticator();

  static const _channel = MethodChannel('recorder/web_auth');

  @override
  Future<Uri> authenticate(Uri url, {required String callbackScheme}) async {
    try {
      final result = await _channel.invokeMethod<String>('authenticate', {
        'url': url.toString(),
        'callbackScheme': callbackScheme,
      });
      if (result == null) throw const WebAuthCancelled();
      return Uri.parse(result);
    } on MissingPluginException {
      throw const WebAuthUnsupported();
    } on PlatformException catch (e) {
      if (e.code == 'CANCELED') throw const WebAuthCancelled();
      rethrow;
    }
  }

  @override
  Future<String?> bundleId() async {
    try {
      return await _channel.invokeMethod<String>('bundleId');
    } on MissingPluginException {
      return null;
    }
  }
}
