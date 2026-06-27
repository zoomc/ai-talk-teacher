import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';
import '../domain/profile_models.dart';

class ProfileRepository {
  // ========== LLM Profiles ==========

  Future<List<LlmProfile>> getAllLlmProfiles() async {
    final db = await DatabaseHelper.database;
    final maps = await db.query('llm_profiles', orderBy: 'created_at DESC');
    return maps.map((m) => LlmProfile.fromMap(m)).toList();
  }

  Future<LlmProfile?> getActiveLlmProfile() async {
    final db = await DatabaseHelper.database;
    final maps = await db.query('llm_profiles', where: 'is_active = 1', limit: 1);
    if (maps.isEmpty) return null;
    return LlmProfile.fromMap(maps.first);
  }

  Future<void> saveLlmProfile(LlmProfile profile) async {
    final db = await DatabaseHelper.database;
    await db.insert(
      'llm_profiles',
      profile.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> setActiveLlmProfile(String id) async {
    final db = await DatabaseHelper.database;
    await db.update('llm_profiles', {'is_active': 0});
    await db.update('llm_profiles', {'is_active': 1, 'updated_at': DateTime.now().toIso8601String()}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteLlmProfile(String id) async {
    final db = await DatabaseHelper.database;
    await db.delete('llm_profiles', where: 'id = ?', whereArgs: [id]);
  }

  // ========== STT Profiles ==========

  Future<List<SttProfile>> getAllSttProfiles() async {
    final db = await DatabaseHelper.database;
    final maps = await db.query('stt_profiles', orderBy: 'created_at DESC');
    return maps.map((m) => SttProfile.fromMap(m)).toList();
  }

  Future<SttProfile?> getActiveSttProfile() async {
    final db = await DatabaseHelper.database;
    final maps = await db.query('stt_profiles', where: 'is_active = 1', limit: 1);
    if (maps.isEmpty) return null;
    return SttProfile.fromMap(maps.first);
  }

  Future<void> saveSttProfile(SttProfile profile) async {
    final db = await DatabaseHelper.database;
    await db.insert(
      'stt_profiles',
      profile.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> setActiveSttProfile(String id) async {
    final db = await DatabaseHelper.database;
    await db.update('stt_profiles', {'is_active': 0});
    await db.update('stt_profiles', {'is_active': 1, 'updated_at': DateTime.now().toIso8601String()}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteSttProfile(String id) async {
    final db = await DatabaseHelper.database;
    await db.delete('stt_profiles', where: 'id = ?', whereArgs: [id]);
  }

  // ========== TTS Profiles ==========

  Future<List<TtsProfile>> getAllTtsProfiles() async {
    final db = await DatabaseHelper.database;
    final maps = await db.query('tts_profiles', orderBy: 'created_at DESC');
    return maps.map((m) => TtsProfile.fromMap(m)).toList();
  }

  Future<TtsProfile?> getActiveTtsProfile() async {
    final db = await DatabaseHelper.database;
    final maps = await db.query('tts_profiles', where: 'is_active = 1', limit: 1);
    if (maps.isEmpty) return null;
    return TtsProfile.fromMap(maps.first);
  }

  Future<void> saveTtsProfile(TtsProfile profile) async {
    final db = await DatabaseHelper.database;
    await db.insert(
      'tts_profiles',
      profile.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> setActiveTtsProfile(String id) async {
    final db = await DatabaseHelper.database;
    await db.update('tts_profiles', {'is_active': 0});
    await db.update('tts_profiles', {'is_active': 1, 'updated_at': DateTime.now().toIso8601String()}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteTtsProfile(String id) async {
    final db = await DatabaseHelper.database;
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
}
