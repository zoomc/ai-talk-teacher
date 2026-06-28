import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/services/secure_storage_service.dart';
import '../domain/profile_models.dart';
import '../domain/provider_catalog.dart';

class ProfileRepository {
  // ========== LLM Profiles ==========

  Future<List<LlmProfile>> getAllLlmProfiles() async {
    final db = await DatabaseHelper.database;
    final maps = await db.query('llm_profiles', orderBy: 'created_at DESC');
    final profiles = <LlmProfile>[];
    for (final map in maps) {
      final profile = LlmProfile.fromMap(map);
      // Load API key from secure storage
      final apiKey = await SecureStorageService.getApiKey(profile.id);
      profiles.add(profile.copyWith(apiKey: apiKey ?? ''));
    }
    return profiles;
  }

  Future<LlmProfile?> getActiveLlmProfile() async {
    final db = await DatabaseHelper.database;
    final maps = await db.query('llm_profiles', where: 'is_active = 1', limit: 1);
    if (maps.isEmpty) return null;
    final profile = LlmProfile.fromMap(maps.first);
    final apiKey = await SecureStorageService.getApiKey(profile.id);
    return profile.copyWith(apiKey: apiKey ?? '');
  }

  Future<void> saveLlmProfile(LlmProfile profile) async {
    final db = await DatabaseHelper.database;
    // Store API key in secure storage, placeholder in SQLite
    await SecureStorageService.storeApiKey(profile.id, profile.apiKey);
    final mapForDb = profile.toMap();
    mapForDb['api_key'] = '***stored***'; // placeholder
    await db.insert(
      'llm_profiles',
      mapForDb,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> setActiveLlmProfile(String id) async {
    final db = await DatabaseHelper.database;
    await db.transaction((txn) async {
      await txn.update('llm_profiles', {'is_active': 0});
      await txn.update('llm_profiles', {'is_active': 1, 'updated_at': DateTime.now().toIso8601String()}, where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> deleteLlmProfile(String id) async {
    final db = await DatabaseHelper.database;
    // Check if active
    final maps = await db.query('llm_profiles', where: 'id = ? AND is_active = 1', whereArgs: [id], limit: 1);
    if (maps.isNotEmpty) throw Exception('Cannot delete active profile');
    await SecureStorageService.deleteApiKey(id);
    await db.delete('llm_profiles', where: 'id = ?', whereArgs: [id]);
  }

  // ========== STT Profiles ==========

  Future<List<SttProfile>> getAllSttProfiles() async {
    final db = await DatabaseHelper.database;
    final maps = await db.query('stt_profiles', orderBy: 'created_at DESC');
    final profiles = <SttProfile>[];
    for (final map in maps) {
      final profile = SttProfile.fromMap(map);
      final apiKey = await SecureStorageService.getApiKey(profile.id);
      profiles.add(profile.copyWith(apiKey: apiKey ?? ''));
    }
    return profiles;
  }

  Future<SttProfile?> getActiveSttProfile() async {
    final db = await DatabaseHelper.database;
    final maps = await db.query('stt_profiles', where: 'is_active = 1', limit: 1);
    if (maps.isEmpty) return null;
    final profile = SttProfile.fromMap(maps.first);
    final apiKey = await SecureStorageService.getApiKey(profile.id);
    return profile.copyWith(apiKey: apiKey ?? '');
  }

  Future<void> saveSttProfile(SttProfile profile) async {
    final db = await DatabaseHelper.database;
    await SecureStorageService.storeApiKey(profile.id, profile.apiKey);
    final mapForDb = profile.toMap();
    mapForDb['api_key'] = '***stored***';
    await db.insert(
      'stt_profiles',
      mapForDb,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> setActiveSttProfile(String id) async {
    final db = await DatabaseHelper.database;
    await db.transaction((txn) async {
      await txn.update('stt_profiles', {'is_active': 0});
      await txn.update('stt_profiles', {'is_active': 1, 'updated_at': DateTime.now().toIso8601String()}, where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> deleteSttProfile(String id) async {
    final db = await DatabaseHelper.database;
    final maps = await db.query('stt_profiles', where: 'id = ? AND is_active = 1', whereArgs: [id], limit: 1);
    if (maps.isNotEmpty) throw Exception('Cannot delete active profile');
    await SecureStorageService.deleteApiKey(id);
    await db.delete('stt_profiles', where: 'id = ?', whereArgs: [id]);
  }

  // ========== TTS Profiles ==========

  Future<List<TtsProfile>> getAllTtsProfiles() async {
    final db = await DatabaseHelper.database;
    final maps = await db.query('tts_profiles', orderBy: 'created_at DESC');
    final profiles = <TtsProfile>[];
    for (final map in maps) {
      final profile = TtsProfile.fromMap(map);
      final apiKey = await SecureStorageService.getApiKey(profile.id);
      profiles.add(profile.copyWith(apiKey: apiKey ?? ''));
    }
    return profiles;
  }

  Future<TtsProfile?> getActiveTtsProfile() async {
    final db = await DatabaseHelper.database;
    final maps = await db.query('tts_profiles', where: 'is_active = 1', limit: 1);
    if (maps.isEmpty) return null;
    final profile = TtsProfile.fromMap(maps.first);
    final apiKey = await SecureStorageService.getApiKey(profile.id);
    return profile.copyWith(apiKey: apiKey ?? '');
  }

  Future<void> saveTtsProfile(TtsProfile profile) async {
    final db = await DatabaseHelper.database;
    await SecureStorageService.storeApiKey(profile.id, profile.apiKey);
    final mapForDb = profile.toMap();
    mapForDb['api_key'] = '***stored***';
    await db.insert(
      'tts_profiles',
      mapForDb,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> setActiveTtsProfile(String id) async {
    final db = await DatabaseHelper.database;
    await db.transaction((txn) async {
      await txn.update('tts_profiles', {'is_active': 0});
      await txn.update('tts_profiles', {'is_active': 1, 'updated_at': DateTime.now().toIso8601String()}, where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> deleteTtsProfile(String id) async {
    final db = await DatabaseHelper.database;
    final maps = await db.query('tts_profiles', where: 'id = ? AND is_active = 1', whereArgs: [id], limit: 1);
    if (maps.isNotEmpty) throw Exception('Cannot delete active profile');
    await SecureStorageService.deleteApiKey(id);
    await db.delete('tts_profiles', where: 'id = ?', whereArgs: [id]);
  }

  // ========== User Settings ==========

  Future<String?> getSetting(String key) async {
    final db = await DatabaseHelper.database;
    final maps = await db.query('user_settings', where: 'key = ?', whereArgs: [key], limit: 1);
    if (maps.isEmpty) return null;
    return maps.first['value'] as String;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await DatabaseHelper.database;
    await db.insert(
      'user_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<bool> hasCompletedOnboarding() async {
    final value = await getSetting('onboarding_completed');
    return value == 'true';
  }

  Future<void> setOnboardingCompleted() async {
    await setSetting('onboarding_completed', 'true');
  }

  Future<bool> hasCompletedPlacement() async {
    final value = await getSetting('placement_completed');
    return value == 'true';
  }

  Future<void> setPlacementCompleted() async {
    await setSetting('placement_completed', 'true');
  }

  Future<String?> getUserLevel() async {
    return getSetting('user_level');
  }

  Future<void> setUserLevel(String level) async {
    await setSetting('user_level', level);
  }

  // ========== Import / Export ==========

  Future<String> exportAllProfilesJson() async {
    final llm = await getAllLlmProfiles();
    final stt = await getAllSttProfiles();
    final tts = await getAllTtsProfiles();
    String maskKey(String k) {
      if (k.length <= 8) return '****';
      return '${k.substring(0, 4)}****${k.substring(k.length - 4)}';
    }
    final data = {
      'version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'llm': llm.map((p) => {...p.toMap(), 'api_key': maskKey(p.apiKey)}).toList(),
      'stt': stt.map((p) => {...p.toMap(), 'api_key': maskKey(p.apiKey)}).toList(),
      'tts': tts.map((p) => {...p.toMap(), 'api_key': maskKey(p.apiKey)}).toList(),
    };
    return jsonEncode(data);
  }

  Future<int> importProfilesJson(String jsonStr) async {
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    int count = 0;
    if (data['llm'] is List) {
      for (final m in data['llm'] as List) {
        final map = Map<String, dynamic>.from(m as Map);
        final profile = LlmProfile(
          name: '${map['name'] ?? ''} (imported)',
          providerId: (map['provider_id'] as String?) ?? LlmProviderCatalog.customId,
          baseUrl: map['base_url'] as String? ?? '',
          apiKey: map['api_key'] as String? ?? '',
          model: map['model'] as String? ?? '',
        );
        await saveLlmProfile(profile);
        count++;
      }
    }
    if (data['stt'] is List) {
      for (final m in data['stt'] as List) {
        final map = Map<String, dynamic>.from(m as Map);
        // Prefer provider_id; fall back to legacy `provider` enum string.
        final providerId = (map['provider_id'] as String?) ??
            _legacySttEnumToId(map['provider'] as String?) ??
            SttProviderCatalog.customId;
        final profile = SttProfile(
          name: '${map['name'] ?? ''} (imported)',
          providerId: providerId,
          baseUrl: map['base_url'] as String? ?? '',
          apiKey: map['api_key'] as String? ?? '',
          model: map['model'] as String? ?? '',
          language: map['language'] as String? ?? 'en-US',
          extraConfig: map['extra_config'] as String?,
        );
        await saveSttProfile(profile);
        count++;
      }
    }
    if (data['tts'] is List) {
      for (final m in data['tts'] as List) {
        final map = Map<String, dynamic>.from(m as Map);
        final providerId = (map['provider_id'] as String?) ??
            _legacyTtsEnumToId(map['provider'] as String?) ??
            TtsProviderCatalog.customId;
        final profile = TtsProfile(
          name: '${map['name'] ?? ''} (imported)',
          providerId: providerId,
          baseUrl: map['base_url'] as String? ?? '',
          apiKey: map['api_key'] as String? ?? '',
          model: map['model'] as String? ?? '',
          voiceId: map['voice_id'] as String?,
          voiceName: map['voice_name'] as String?,
          speed: (map['speed'] as num?)?.toDouble() ?? 1.0,
          extraConfig: map['extra_config'] as String?,
        );
        await saveTtsProfile(profile);
        count++;
      }
    }
    return count;
  }

  /// Maps a legacy closed-enum `provider` string (pre-v2 schema) to a catalog
  /// id for STT profiles. Returns null for unknown/empty values.
  static String? _legacySttEnumToId(String? legacy) {
    switch (legacy) {
      case 'deepgram':
        return 'deepgram';
      case 'openaiWhisper':
        return 'openai_whisper';
      case 'googleCloud':
        return 'google';
      case 'azure':
        return 'azure';
      default:
        return null;
    }
  }

  /// Maps a legacy closed-enum `provider` string (pre-v2 schema) to a catalog
  /// id for TTS profiles. Returns null for unknown/empty values.
  static String? _legacyTtsEnumToId(String? legacy) {
    switch (legacy) {
      case 'fishAudio':
        return 'fish_audio';
      case 'elevenLabs':
        return 'elevenlabs';
      case 'openaiTts':
        return 'openai_tts';
      case 'azure':
        return 'azure_tts';
      default:
        return null;
    }
  }
}
