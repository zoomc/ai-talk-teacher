import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../runtime/runtime_config.dart';

/// Secure storage for API keys
/// Uses platform-specific secure storage:
/// - iOS/macOS: Keychain
/// - Android: EncryptedSharedPreferences
/// - Web: browser storage provided by the plugin. This is not equivalent to
///   iOS Keychain or Android Keystore; browser XSS and profile compromise are
///   part of the web threat model, so users should prefer scoped keys or a
///   self-hosted relay when that risk is unacceptable.
class SecureStorageService {
  static const _storage = FlutterSecureStorage();
  static String get _keyPrefix =>
      'speakflow_${RuntimeConfig.storageNamespace}_key_';

  /// Store an API key
  static Future<void> storeApiKey(String profileId, String apiKey) async {
    await _storage.write(key: '$_keyPrefix$profileId', value: apiKey);
  }

  /// Retrieve an API key
  static Future<String?> getApiKey(String profileId) async {
    return _storage.read(key: '$_keyPrefix$profileId');
  }

  /// Delete an API key
  static Future<void> deleteApiKey(String profileId) async {
    await _storage.delete(key: '$_keyPrefix$profileId');
  }

  /// Check if an API key exists
  static Future<bool> hasApiKey(String profileId) async {
    return _storage.containsKey(key: '$_keyPrefix$profileId');
  }

  /// Clear all stored API keys
  static Future<void> clearAll() async {
    final all = await _storage.readAll();
    for (final key in all.keys) {
      if (key.startsWith(_keyPrefix)) {
        await _storage.delete(key: key);
      }
    }
  }
}
