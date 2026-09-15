import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/constants.dart';

/// The only place the user's API keys are ever persisted — one instance per
/// key: Groq by default, Gemini with [kGeminiApiKeyStorageKey].
///
/// Backed by the platform keystore (Android EncryptedSharedPreferences,
/// iOS Keychain) — a key never lands in the drift database, in
/// SharedPreferences, or in a log line.
class ApiKeyStore {
  ApiKeyStore({
    FlutterSecureStorage? storage,
    this.storageKey = kGroqApiKeyStorageKey,
  }) : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              // The queue worker reads this key on its own schedule, including
              // right after a reboot while the phone is still locked. The
              // Keychain default (`unlocked_this_device`) would hand it back
              // `null` there, which the classifier would read as "no key set"
              // and park every queued chunk as a permanent failure. `first
              // unlock` keeps the item unavailable until the user has unlocked
              // once since booting, and available from then on.
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  final FlutterSecureStorage _storage;
  final String storageKey;

  /// Returns the stored key, or null if none is set. Whitespace-only values
  /// are treated as absent so a stray paste can't produce a 401 loop.
  Future<String?> read() async {
    final value = await _storage.read(key: storageKey);
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  Future<void> write(String key) =>
      _storage.write(key: storageKey, value: key.trim());

  Future<void> delete() => _storage.delete(key: storageKey);

  Future<bool> hasKey() async => await read() != null;

  /// A safe-to-display form of the stored key, e.g. `gsk_…f31a`.
  /// Returns null when no key is stored.
  Future<String?> maskedKey() async {
    final key = await read();
    if (key == null) return null;
    if (key.length <= 8) return '•' * key.length;
    return '${key.substring(0, 4)}…${key.substring(key.length - 4)}';
  }
}
