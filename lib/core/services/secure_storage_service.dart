import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure storage for API keys
/// Uses platform-specific secure storage:
/// - iOS/macOS: Keychain
/// - Android: EncryptedSharedPreferences
/// - Web: Encrypted localStorage
class SecureStorageService {
  static const _storage = FlutterSecureStorage();
  static const _keyPrefix = 'speakflow_key_';

  /// Store an API key
  static Future<void> storeApiKey(String profileId, String apiKey) async {
    await _storage.write(
      key: '$_keyPrefix$profileId',
      value: apiKey,
    );
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
