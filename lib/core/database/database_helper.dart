import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// Conditional import: web uses the FFI WebAssembly factory, other
// platforms use the default sqflite platform channel.
import 'database_init_stub.dart'
    if (dart.library.js_interop) 'database_init_web.dart' as db_init;

class DatabaseHelper {
  static Database? _database;
  static const String _dbName = 'speakflow.db';
  static const int _dbVersion = 5;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    // Set up the correct database factory before opening (no-op on native).
    db_init.initDatabaseFactory();
    final String path;
    if (kIsWeb) {
      // On web the FFI factory stores files in IndexedDB — just the name
      // is sufficient; getApplicationDocumentsDirectory() doesn't exist.
      path = _dbName;
    } else {
      final dir = await getApplicationDocumentsDirectory();
      path = p.join(dir.path, _dbName);
    }
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    // LLM Profiles
    await db.execute('''
      CREATE TABLE llm_profiles (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        provider_id TEXT NOT NULL DEFAULT 'custom',
        base_url TEXT NOT NULL,
        api_key TEXT NOT NULL,
        model TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // STT Profiles
    await db.execute('''
      CREATE TABLE stt_profiles (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        provider_id TEXT NOT NULL DEFAULT 'custom',
        base_url TEXT NOT NULL DEFAULT '',
        api_key TEXT NOT NULL,
        model TEXT NOT NULL DEFAULT '',
        language TEXT NOT NULL DEFAULT 'en-US',
        extra_config TEXT,
        is_active INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // TTS Profiles
    await db.execute('''
      CREATE TABLE tts_profiles (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        provider_id TEXT NOT NULL DEFAULT 'custom',
        base_url TEXT NOT NULL DEFAULT '',
        api_key TEXT NOT NULL,
        model TEXT NOT NULL DEFAULT '',
        voice_id TEXT,
        voice_name TEXT,
        speed REAL NOT NULL DEFAULT 1.0,
        extra_config TEXT,
        is_active INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Chat Sessions
    await db.execute('''
      CREATE TABLE chat_sessions (
        id TEXT PRIMARY KEY,
        topic TEXT,
        scenario_id TEXT,
        status TEXT NOT NULL DEFAULT 'active',
        level_tag TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_guest INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Chat Messages
    await db.execute('''
      CREATE TABLE chat_messages (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        audio_path TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (session_id) REFERENCES chat_sessions(id)
      )
    ''');

    // Corrections (error records)
    await db.execute('''
      CREATE TABLE corrections (
        id TEXT PRIMARY KEY,
        original TEXT NOT NULL,
        corrected TEXT NOT NULL,
        type TEXT NOT NULL,
        explanation TEXT,
        message_id TEXT,
        session_id TEXT,
        review_count INTEGER NOT NULL DEFAULT 0,
        easiness_factor REAL NOT NULL DEFAULT 2.5,
        interval_days INTEGER NOT NULL DEFAULT 0,
        next_review_at TEXT,
        created_at TEXT NOT NULL,
        occurrence_count INTEGER NOT NULL DEFAULT 1,
        last_seen_at TEXT NOT NULL,
        importance INTEGER NOT NULL DEFAULT 50,
        is_favorite INTEGER NOT NULL DEFAULT 0,
        favorite_at TEXT,
        FOREIGN KEY (message_id) REFERENCES chat_messages(id),
        FOREIGN KEY (session_id) REFERENCES chat_sessions(id)
      )
    ''');

    // Scenarios
    await db.execute('''
      CREATE TABLE scenarios (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        icon TEXT NOT NULL,
        difficulty TEXT NOT NULL,
        category TEXT NOT NULL,
        system_prompt TEXT NOT NULL
      )
    ''');

    // User settings
    await db.execute('''
      CREATE TABLE user_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // P1 task 4 — phoneme-level pronunciation scoring.
    // A `phoneme_score_set` groups all phoneme scores for a single AI
    // message (or a single user utterance). It links to the correction
    // row so the review screen can surface pronunciation drills.
    await db.execute('''
      CREATE TABLE phoneme_score_sets (
        id TEXT PRIMARY KEY,
        message_id TEXT,
        correction_id TEXT,
        session_id TEXT,
        overall_score REAL NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (message_id) REFERENCES chat_messages(id),
        FOREIGN KEY (correction_id) REFERENCES corrections(id),
        FOREIGN KEY (session_id) REFERENCES chat_sessions(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE phoneme_scores (
        id TEXT PRIMARY KEY,
        set_id TEXT NOT NULL,
        phoneme TEXT NOT NULL,
        word TEXT NOT NULL DEFAULT '',
        score REAL NOT NULL DEFAULT 0,
        position INTEGER NOT NULL DEFAULT 0,
        feedback TEXT,
        audio_path TEXT,
        FOREIGN KEY (set_id) REFERENCES phoneme_score_sets(id)
      )
    ''');

    // Insert default scenarios
    await _insertDefaultScenarios(db);
  }

  static Future<void> _insertDefaultScenarios(Database db) async {
    final scenarios = [
      {
        'id': 'free_talk',
        'name': 'Free Talk',
        'description': 'Chat about anything you like',
        'icon': '💬',
        'difficulty': 'all',
        'category': 'general',
        'system_prompt':
            'You are a friendly English tutor. Have a natural conversation with the student. Correct their errors naturally by restating the correct version in your reply without interrupting the flow. Keep responses concise and engaging.',
      },
      {
        'id': 'restaurant',
        'name': 'At a Restaurant',
        'description': 'Order food and interact with waitstaff',
        'icon': '🍽️',
        'difficulty': 'beginner',
        'category': 'daily',
        'system_prompt':
            'You are a friendly English tutor. The student is practicing ordering food at a restaurant. You play the role of the waiter/waitress. Correct their errors naturally by restating the correct version in your reply.',
      },
      {
        'id': 'airport',
        'name': 'At the Airport',
        'description': 'Check-in, security, boarding',
        'icon': '✈️',
        'difficulty': 'beginner',
        'category': 'travel',
        'system_prompt':
            'You are a friendly English tutor. The student is practicing airport scenarios. You play various roles (check-in agent, security, etc). Correct errors naturally.',
      },
      {
        'id': 'job_interview',
        'name': 'Job Interview',
        'description': 'Practice common interview questions',
        'icon': '💼',
        'difficulty': 'intermediate',
        'category': 'career',
        'system_prompt':
            'You are a friendly English tutor. The student is practicing for a job interview. You play the interviewer. Ask common interview questions and correct errors naturally.',
      },
      {
        'id': 'business_meeting',
        'name': 'Business Meeting',
        'description': 'Discuss projects and ideas',
        'icon': '📊',
        'difficulty': 'advanced',
        'category': 'career',
        'system_prompt':
            'You are a friendly English tutor. The student is practicing business English in a meeting context. Correct errors naturally while keeping the meeting flowing.',
      },
      {
        'id': 'shopping',
        'name': 'Shopping',
        'description': 'Buy clothes, ask for sizes, make returns',
        'icon': '🛍️',
        'difficulty': 'beginner',
        'category': 'daily',
        'system_prompt':
            'You are a friendly English tutor. The student is practicing shopping scenarios. You play the store clerk. Correct errors naturally.',
      },
      {
        'id': 'doctor',
        'name': 'At the Doctor',
        'description': 'Describe symptoms and understand advice',
        'icon': '🏥',
        'difficulty': 'intermediate',
        'category': 'daily',
        'system_prompt':
            'You are a friendly English tutor. The student is practicing describing symptoms to a doctor. You play the doctor. Correct errors naturally.',
      },
      {
        'id': 'date',
        'name': 'On a Date',
        'description': 'Casual conversation and getting to know someone',
        'icon': '💕',
        'difficulty': 'intermediate',
        'category': 'social',
        'system_prompt':
            'You are a friendly English tutor. The student is practicing casual English conversation on a date. Be warm and engaging. Correct errors naturally.',
      },
    ];

    for (final scenario in scenarios) {
      await db.insert('scenarios', scenario);
    }
  }

  /// Schema migration v1 → v2: introduce the provider-catalog columns.
  ///
  /// - Adds `provider_id`, `base_url`, `model`, `language` (and keeps `extra_config`)
  ///   to `stt_profiles`.
  /// - Adds `provider_id`, `base_url`, `model`, `extra_config` to `tts_profiles`.
  /// - Adds `provider_id` to `llm_profiles`.
  /// - Remaps the legacy closed-enum `provider` column values to catalog ids and
  ///   back-fills `base_url` / `model` from the catalog defaults so existing users
  ///   keep working without reconfiguring.
  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      final batch = db.batch();

      // llm_profiles: add provider_id
      batch.execute(
        "ALTER TABLE llm_profiles ADD COLUMN provider_id TEXT NOT NULL DEFAULT 'custom'",
      );

      // stt_profiles: add new columns (extra_config already exists in v1)
      batch.execute(
        "ALTER TABLE stt_profiles ADD COLUMN provider_id TEXT NOT NULL DEFAULT 'custom'",
      );
      batch.execute(
        "ALTER TABLE stt_profiles ADD COLUMN base_url TEXT NOT NULL DEFAULT ''",
      );
      batch.execute(
        "ALTER TABLE stt_profiles ADD COLUMN model TEXT NOT NULL DEFAULT ''",
      );
      batch.execute(
        "ALTER TABLE stt_profiles ADD COLUMN language TEXT NOT NULL DEFAULT 'en-US'",
      );

      // tts_profiles: add new columns (extra_config did NOT exist in v1)
      batch.execute(
        "ALTER TABLE tts_profiles ADD COLUMN provider_id TEXT NOT NULL DEFAULT 'custom'",
      );
      batch.execute(
        "ALTER TABLE tts_profiles ADD COLUMN base_url TEXT NOT NULL DEFAULT ''",
      );
      batch.execute(
        "ALTER TABLE tts_profiles ADD COLUMN model TEXT NOT NULL DEFAULT ''",
      );
      batch.execute('ALTER TABLE tts_profiles ADD COLUMN extra_config TEXT');

      await batch.commit();

      // Remap legacy `provider` enum values to catalog ids + defaults.
      // STT mapping (matches SttProfile.fromMap backward-compat):
      await _remapLegacyStt(
        db,
        'deepgram',
        'deepgram',
        'https://api.deepgram.com',
        'nova-3',
      );
      await _remapLegacyStt(
        db,
        'openaiWhisper',
        'openai_whisper',
        'https://api.openai.com/v1',
        'whisper-1',
      );
      await _remapLegacyStt(
        db,
        'googleCloud',
        'google',
        'https://speech.googleapis.com',
        '',
      );
      await _remapLegacyStt(
        db,
        'azure',
        'azure',
        'https://{region}.stt.speech.microsoft.com',
        '',
      );

      // TTS mapping (matches TtsProfile.fromMap backward-compat):
      await _remapLegacyTts(
        db,
        'fishAudio',
        'fish_audio',
        'https://api.fish.audio',
        's1',
      );
      await _remapLegacyTts(
        db,
        'elevenLabs',
        'elevenlabs',
        'https://api.elevenlabs.io',
        'eleven_multilingual_v2',
      );
      await _remapLegacyTts(
        db,
        'openaiTts',
        'openai_tts',
        'https://api.openai.com/v1',
        'gpt-4o-mini-tts',
      );
      await _remapLegacyTts(
        db,
        'azure',
        'azure_tts',
        'https://{region}.tts.speech.microsoft.com',
        '',
      );

      // LLM profiles created before v2 default to 'custom' provider_id, which is
      // correct since they already carry their own base_url + model.
    }

    if (oldVersion < 3) {
      // v3 adds dedup tracking columns to corrections so the same mistake
      // flagged across sessions increments a counter instead of producing
      // duplicate rows. Back-fill existing rows: occurrence_count = 1 and
      // last_seen_at = created_at (the only timestamp we have).
      final batch = db.batch();
      batch.execute(
        'ALTER TABLE corrections ADD COLUMN occurrence_count INTEGER NOT NULL DEFAULT 1',
      );
      batch.execute(
        'ALTER TABLE corrections ADD COLUMN last_seen_at TEXT',
      );
      await batch.commit();
      // Populate last_seen_at for rows that pre-date the column. ALTER TABLE
      // ... ADD COLUMN with NOT NULL is impossible without a default, so we
      // added it nullable above and back-fill here.
      await db.execute(
        "UPDATE corrections SET last_seen_at = created_at WHERE last_seen_at IS NULL",
      );
    }

    if (oldVersion < 4) {
      // v4 adds Phase-1 P0 columns:
      //   corrections.importance / is_favorite / favorite_at — power the
      //     enhanced correction cards (sort by importance, user-starred).
      //   chat_sessions.is_guest — marks a guest-trial session so the
      //     chat screen can enforce the 3-minute time box and the home
      //     screen can offer a one-tap "try without configuring" entry.
      //
      // All columns ship with safe defaults so pre-existing rows continue
      // to work without a back-fill pass.
      final batch = db.batch();
      batch.execute(
        'ALTER TABLE corrections ADD COLUMN importance INTEGER NOT NULL DEFAULT 50',
      );
      batch.execute(
        'ALTER TABLE corrections ADD COLUMN is_favorite INTEGER NOT NULL DEFAULT 0',
      );
      batch.execute('ALTER TABLE corrections ADD COLUMN favorite_at TEXT');
      batch.execute(
        'ALTER TABLE chat_sessions ADD COLUMN is_guest INTEGER NOT NULL DEFAULT 0',
      );
      await batch.commit();
    }

    if (oldVersion < 5) {
      // v5 adds phoneme-level pronunciation scoring tables (P1 task 4).
      // These are new tables with no data to back-fill.
      await db.execute('''
        CREATE TABLE IF NOT EXISTS phoneme_score_sets (
          id TEXT PRIMARY KEY,
          message_id TEXT,
          correction_id TEXT,
          session_id TEXT,
          overall_score REAL NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL,
          FOREIGN KEY (message_id) REFERENCES chat_messages(id),
          FOREIGN KEY (correction_id) REFERENCES corrections(id),
          FOREIGN KEY (session_id) REFERENCES chat_sessions(id)
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS phoneme_scores (
          id TEXT PRIMARY KEY,
          set_id TEXT NOT NULL,
          phoneme TEXT NOT NULL,
          word TEXT NOT NULL DEFAULT '',
          score REAL NOT NULL DEFAULT 0,
          position INTEGER NOT NULL DEFAULT 0,
          feedback TEXT,
          audio_path TEXT,
          FOREIGN KEY (set_id) REFERENCES phoneme_score_sets(id)
        )
      ''');
    }
  }

  static Future<void> _remapLegacyStt(
    Database db,
    String legacyEnum,
    String providerId,
    String baseUrl,
    String model,
  ) async {
    await db.update(
      'stt_profiles',
      {'provider_id': providerId, 'base_url': baseUrl, 'model': model},
      where: 'provider = ?',
      whereArgs: [legacyEnum],
    );
  }

  static Future<void> _remapLegacyTts(
    Database db,
    String legacyEnum,
    String providerId,
    String baseUrl,
    String model,
  ) async {
    await db.update(
      'tts_profiles',
      {'provider_id': providerId, 'base_url': baseUrl, 'model': model},
      where: 'provider = ?',
      whereArgs: [legacyEnum],
    );
  }
}
