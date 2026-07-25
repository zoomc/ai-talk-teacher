// Web-only E2E bridge for SpeakFlow.
//
// When the app is built with `--dart-define=E2E=true`, this file:
//   1. Exposes a global `window.speakflowE2E` JS object with methods for
//      resetting/seeding the SQLite database, toggling mock mode, and
//      inspecting DB state.
//   2. Provides Dart-side mock services that short-circuit LLM/STT/TTS
//      HTTP calls with canned responses (the primary mocking path).
//
// When `--dart-define=E2E=true` is NOT passed, `kE2E` is `false` and
// `maybeInit()` returns immediately — the JS hooks are never exposed and
// the mock services never activate. The compiler tree-shakes the entire
// bridge out of production builds.
//
// The bridge must be exposed AFTER `runApp()` so the JS context is ready.
// Call `E2eBridge.exposeHooks()` from a `WidgetsBinding.instance.addPostFrameCallback`
// in `main.dart`.
@JS()
library speakflow.e2e;

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import 'e2e_bridge_stub.dart' show kE2E;

/// All SQLite tables that the bridge can reset/seed. Keep in sync with
/// `database_helper.dart` `_onCreate`.
const List<String> _allTables = <String>[
  'llm_profiles',
  'stt_profiles',
  'tts_profiles',
  'chat_sessions',
  'messages',
  'corrections',
  'review_queue',
  'scenarios',
  'scenario_items',
  'scenario_review_queue',
  'practice_log',
  'skill_mastery',
  'user_goals',
  'settings',
  'projects',
  'project_links',
  'project_activities',
  'teacher_persona',
];

/// In-memory map of LLM prompt-substring → canned reply. Populated by
/// `setMockLlmResponse` from the JS bridge.
final Map<String, String> _llmOverrides = <String, String>{};

/// The default canned LLM response (used when no override matches).
const String _defaultLlmReply =
    "That's interesting! Tell me more about your day.";

/// The current mock STT transcript (set by `setMockSttResult`).
String _mockSttTranscript = 'Hello, this is a mock transcription.';

/// The current mock TTS audio bytes (base64; set by `setMockTtsAudio`).
String _mockTtsAudioBase64 =
    'UklGRiQAAABXQVZFZm10IBAAAAABAAEARKwAAIhYAQACABAAZGF0YQAAAAA=';

/// Whether mock mode is enabled (set by `setMockMode`).
bool _mockModeEnabled = false;

// ============================================================================
//  Public Dart API — called from `main.dart` and from service files
// ============================================================================

/// Whether mock mode is enabled (Dart-side check by services).
bool get mockModeEnabled => kE2E && _mockModeEnabled;

/// Returns a canned LLM reply for the given prompt, or null if no override
/// matches and mock mode is disabled.
String? cannedLlmReply(String prompt) {
  if (!mockModeEnabled) return null;
  final lower = prompt.toLowerCase();
  for (final entry in _llmOverrides.entries) {
    if (lower.contains(entry.key)) return entry.value;
  }
  return _defaultLlmReply;
}

/// Returns the mock STT transcript, or null if mock mode is disabled.
String? get cannedSttTranscript => mockModeEnabled ? _mockSttTranscript : null;

/// Returns the mock TTS audio bytes (base64), or null if mock mode is disabled.
String? get cannedTtsAudioBase64 => mockModeEnabled ? _mockTtsAudioBase64 : null;

// ============================================================================
//  E2eBridge — called from main.dart
// ============================================================================

/// Web-only E2E bridge. Exposes JS hooks when `kE2E` is true.
class E2eBridge {
  /// Called once from `main()` after `WidgetsFlutterBinding.ensureInitialized()`.
  /// On non-web/non-E2E builds, returns immediately.
  static Future<void> maybeInit() async {
    if (!kE2E) return;
    // Trigger DB initialization so the bridge can act on it immediately.
    try {
      await DatabaseHelper.database;
      debugPrint('[E2E] Bridge initialized; database ready.');
    } catch (e, st) {
      debugPrint('[E2E] Bridge init failed: $e\n$st');
    }
  }

  /// Called after `runApp()` to expose the `window.speakflowE2E` JS hooks.
  /// No-op on non-web/non-E2E builds.
  static void exposeHooks() {
    if (!kE2E) return;
    // Bind each Dart function to the global JS object.
    globalContext['speakflowE2E'] = _buildJsBridge().toJS;
    debugPrint('[E2E] Bridge hooks exposed as window.speakflowE2E');
  }

  /// Whether the E2E bridge is active (web + E2E flag).
  static bool get isActive => kE2E;
}

/// Construct the JS-exposable bridge object.
SpeakflowE2E _buildJsBridge() {
  return SpeakflowE2E(
    resetDatabase: () => _resetDatabase().toJS,
    seedFixture: (JSString name, JSString json) =>
        _seedFixture(name.toDart, json.toDart).toJS,
    seedProjects: (JSString json) => _seedTable('projects', json.toDart).toJS,
    seedChatSessions: (JSString json) =>
        _seedTable('chat_sessions', json.toDart).toJS,
    seedMessages: (JSString json) => _seedTable('messages', json.toDart).toJS,
    seedCorrections: (JSString json) =>
        _seedTable('corrections', json.toDart).toJS,
    seedReviewQueue: (JSString json) =>
        _seedTable('review_queue', json.toDart).toJS,
    seedScenarios: (JSString json) => _seedScenarios(json.toDart).toJS,
    seedProfiles: (JSString json) => _seedProfiles(json.toDart).toJS,
    setMockMode: (JSBoolean enabled) {
      _mockModeEnabled = enabled.toDart;
      return Future<void>.value().toJS;
    },
    setMockLlmResponse: (JSString promptSubstring, JSString reply) {
      _llmOverrides[promptSubstring.toDart.toLowerCase()] = reply.toDart;
      return Future<void>.value().toJS;
    },
    setMockSttResult: (JSString transcript) {
      _mockSttTranscript = transcript.toDart;
      return Future<void>.value().toJS;
    },
    setMockTtsAudio: (JSString base64Audio) {
      _mockTtsAudioBase64 = base64Audio.toDart;
      return Future<void>.value().toJS;
    },
    getDatabaseSnapshot: () => _getSnapshot().then((s) => s.toJS).toJS,
    setSetting: (JSString key, JSString value) =>
        _setSetting(key.toDart, value.toDart).toJS,
    completeOnboarding: () => _completeOnboarding().toJS,
  );
}

// ============================================================================
//  Bridge method implementations
// ============================================================================

Future<void> _resetDatabase() async {
  final db = await DatabaseHelper.database;
  await db.transaction((txn) async {
    for (final table in _allTables) {
      await txn.delete(table);
    }
  });
  // Re-mark onboarding complete by default — tests that want a fresh
  // first-run state should call setSetting('onboarding_complete','false').
  await _completeOnboarding();
}

Future<void> _seedFixture(String name, String json) async {
  // A "fixture" is a JSON object with optional arrays per table.
  // Example: {"projects": [...], "chat_sessions": [...]}
  final Map<String, dynamic> data =
      jsonDecode(json) as Map<String, dynamic>;
  if (data['projects'] is List) {
    await _seedTable('projects', jsonEncode(data['projects']));
  }
  if (data['chat_sessions'] is List) {
    await _seedTable('chat_sessions', jsonEncode(data['chat_sessions']));
  }
  if (data['messages'] is List) {
    await _seedTable('messages', jsonEncode(data['messages']));
  }
  if (data['corrections'] is List) {
    await _seedTable('corrections', jsonEncode(data['corrections']));
  }
  if (data['review_queue'] is List) {
    await _seedTable('review_queue', jsonEncode(data['review_queue']));
  }
  if (data['scenarios'] is List) {
    await _seedScenarios(jsonEncode(data['scenarios']));
  }
  if (data['profiles'] is List) {
    await _seedProfiles(jsonEncode(data['profiles']));
  }
  if (data['settings'] is Map) {
    final settings = data['settings'] as Map<String, dynamic>;
    for (final entry in settings.entries) {
      await _setSetting(entry.key, entry.value.toString());
    }
  }
  if (data['complete_onboarding'] == true) {
    await _completeOnboarding();
  }
}

Future<void> _seedTable(String table, String json) async {
  final List<dynamic> rows = jsonDecode(json) as List<dynamic>;
  final db = await DatabaseHelper.database;
  await db.transaction((txn) async {
    for (final row in rows) {
      final Map<String, dynamic> rowMap = Map<String, dynamic>.from(row as Map);
      await txn.insert(
        table,
        rowMap,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  });
}

Future<void> _seedScenarios(String json) async {
  // Scenarios live in two tables: `scenarios` (parent) and `scenario_items` (child).
  // The fixture may include an `_items` array per scenario. For simplicity in v1,
  // we just seed the parent table — child items are auto-created by the app.
  await _seedTable('scenarios', json);
}

Future<void> _seedProfiles(String json) async {
  // Profiles can be LLM, STT, or TTS — distinguished by the presence of fields.
  // The fixture JSON should be a flat array; we route each row to the right table
  // based on its shape (LLM has `model` only; STT has `language`; TTS has `voice_id`).
  final List<dynamic> rows = jsonDecode(json) as List<dynamic>;
  final db = await DatabaseHelper.database;
  await db.transaction((txn) async {
    for (final row in rows) {
      final Map<String, dynamic> rowMap = Map<String, dynamic>.from(row as Map);
      String table;
      if (rowMap.containsKey('voice_id') || rowMap.containsKey('voice_name')) {
        table = 'tts_profiles';
      } else if (rowMap.containsKey('language')) {
        table = 'stt_profiles';
      } else {
        table = 'llm_profiles';
      }
      await txn.insert(
        table,
        rowMap,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  });
}

Future<String> _getSnapshot() async {
  final db = await DatabaseHelper.database;
  final Map<String, dynamic> snapshot = <String, dynamic>{};
  for (final table in _allTables) {
    try {
      final rows = await db.query(table);
      snapshot[table] = rows;
    } catch (e) {
      // Table may not exist in this schema version — record null.
      snapshot[table] = null;
    }
  }
  return jsonEncode(snapshot);
}

Future<void> _setSetting(String key, String value) async {
  final db = await DatabaseHelper.database;
  await db.insert(
    'settings',
    <String, dynamic>{
      'key': key,
      'value': value,
      'updated_at': DateTime.now().toIso8601String(),
    },
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}

Future<void> _completeOnboarding() async {
  await _setSetting('onboarding_complete', 'true');
  await _setSetting('placement_complete', 'true');
}

// ============================================================================
//  JS interop types
// ============================================================================

/// The JS-exposable bridge object shape. Each field is a function that
/// returns a Promise (for async methods) or void (for sync setters).
@JS()
extension type SpeakflowE2E._(JSObject _) implements JSObject {
  external SpeakflowE2E({
    required JSPromise Function() resetDatabase,
    required JSPromise Function(JSString, JSString) seedFixture,
    required JSPromise Function(JSString) seedProjects,
    required JSPromise Function(JSString) seedChatSessions,
    required JSPromise Function(JSString) seedMessages,
    required JSPromise Function(JSString) seedCorrections,
    required JSPromise Function(JSString) seedReviewQueue,
    required JSPromise Function(JSString) seedScenarios,
    required JSPromise Function(JSString) seedProfiles,
    required JSPromise Function(JSBoolean) setMockMode,
    required JSPromise Function(JSString, JSString) setMockLlmResponse,
    required JSPromise Function(JSString) setMockSttResult,
    required JSPromise Function(JSString) setMockTtsAudio,
    required JSPromise Function() getDatabaseSnapshot,
    required JSPromise Function(JSString, JSString) setSetting,
    required JSPromise Function() completeOnboarding,
  });
}
