import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class DatabaseHelper {
  static Database? _database;
  static const String _dbName = 'speakflow.db';
  static const int _dbVersion = 1;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    // LLM Profiles
    await db.execute('''
      CREATE TABLE llm_profiles (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
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
        provider TEXT NOT NULL,
        api_key TEXT NOT NULL,
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
        provider TEXT NOT NULL,
        api_key TEXT NOT NULL,
        voice_id TEXT,
        voice_name TEXT,
        speed REAL NOT NULL DEFAULT 1.0,
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
        updated_at TEXT NOT NULL
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
        'system_prompt': 'You are a friendly English tutor. Have a natural conversation with the student. Correct their errors naturally by restating the correct version in your reply without interrupting the flow. Keep responses concise and engaging.',
      },
      {
        'id': 'restaurant',
        'name': 'At a Restaurant',
        'description': 'Order food and interact with waitstaff',
        'icon': '🍽️',
        'difficulty': 'beginner',
        'category': 'daily',
        'system_prompt': 'You are a friendly English tutor. The student is practicing ordering food at a restaurant. You play the role of the waiter/waitress. Correct their errors naturally by restating the correct version in your reply.',
      },
      {
        'id': 'airport',
        'name': 'At the Airport',
        'description': 'Check-in, security, boarding',
        'icon': '✈️',
        'difficulty': 'beginner',
        'category': 'travel',
        'system_prompt': 'You are a friendly English tutor. The student is practicing airport scenarios. You play various roles (check-in agent, security, etc). Correct errors naturally.',
      },
      {
        'id': 'job_interview',
        'name': 'Job Interview',
        'description': 'Practice common interview questions',
        'icon': '💼',
        'difficulty': 'intermediate',
        'category': 'career',
        'system_prompt': 'You are a friendly English tutor. The student is practicing for a job interview. You play the interviewer. Ask common interview questions and correct errors naturally.',
      },
      {
        'id': 'business_meeting',
        'name': 'Business Meeting',
        'description': 'Discuss projects and ideas',
        'icon': '📊',
        'difficulty': 'advanced',
        'category': 'career',
        'system_prompt': 'You are a friendly English tutor. The student is practicing business English in a meeting context. Correct errors naturally while keeping the meeting flowing.',
      },
      {
        'id': 'shopping',
        'name': 'Shopping',
        'description': 'Buy clothes, ask for sizes, make returns',
        'icon': '🛍️',
        'difficulty': 'beginner',
        'category': 'daily',
        'system_prompt': 'You are a friendly English tutor. The student is practicing shopping scenarios. You play the store clerk. Correct errors naturally.',
      },
      {
        'id': 'doctor',
        'name': 'At the Doctor',
        'description': 'Describe symptoms and understand advice',
        'icon': '🏥',
        'difficulty': 'intermediate',
        'category': 'daily',
        'system_prompt': 'You are a friendly English tutor. The student is practicing describing symptoms to a doctor. You play the doctor. Correct errors naturally.',
      },
      {
        'id': 'date',
        'name': 'On a Date',
        'description': 'Casual conversation and getting to know someone',
        'icon': '💕',
        'difficulty': 'intermediate',
        'category': 'social',
        'system_prompt': 'You are a friendly English tutor. The student is practicing casual English conversation on a date. Be warm and engaging. Correct errors naturally.',
      },
    ];

    for (final scenario in scenarios) {
      await db.insert('scenarios', scenario);
    }
  }
}
