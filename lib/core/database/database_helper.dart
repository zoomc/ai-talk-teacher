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
  static const int _dbVersion = 8;

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
        skill TEXT,
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
        system_prompt TEXT NOT NULL,
        goal TEXT,
        tags TEXT
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

    // S5/S6 — daily practice log + streak tracking. One row per calendar
    // day the user engaged with the app (sent a message, reviewed a
    // correction, etc.). `streak` is the consecutive-day count as of that
    // day (denormalised for cheap reads on the home dashboard).
    await db.execute('''
      CREATE TABLE practice_log (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL UNIQUE,
        duration_seconds INTEGER NOT NULL DEFAULT 0,
        completed INTEGER NOT NULL DEFAULT 0,
        streak INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // S5/S6 — review queue. Mirrors each correction's next due time so the
    // home dashboard can surface "what to review next" without re-deriving
    // the SM-2 schedule. `correction_id` is unique (one queue slot per
    // correction); the row is upserted whenever the correction's
    // `next_review_at` changes.
    // S5/S6 v7 — adds `interval`, `repetitions`, `ease_factor` columns so
    // the queue carries the full SM-2 state (not just due_at). Lets the
    // dashboard order today's tasks by SM-2 progression without joining
    // back to corrections.
    await db.execute('''
      CREATE TABLE review_queue (
        id TEXT PRIMARY KEY,
        correction_id TEXT NOT NULL UNIQUE,
        due_at TEXT NOT NULL,
        interval_days INTEGER NOT NULL DEFAULT 0,
        repetitions INTEGER NOT NULL DEFAULT 0,
        ease_factor REAL NOT NULL DEFAULT 2.5,
        created_at TEXT NOT NULL,
        FOREIGN KEY (correction_id) REFERENCES corrections(id)
      )
    ''');

    // S5/S6 v7 — skill mastery. One row per skill (e.g. 'grammar/tenses',
    // 'pronunciation/th-digraph'). `score` is 0-100 produced by
    // [SkillMasteryService] from the latest 20 practice events with a
    // time-decay weight. `level` is the human-readable bucket
    // ('new' / 'learning' / 'familiar' / 'mastered' / 'expert').
    await db.execute('''
      CREATE TABLE skill_mastery (
        id TEXT PRIMARY KEY,
        skill_id TEXT NOT NULL UNIQUE,
        score INTEGER NOT NULL DEFAULT 0,
        level TEXT NOT NULL DEFAULT 'new',
        updated_at TEXT NOT NULL
      )
    ''');

    // S5/S6 v7 — user goal. The user picks one active goal
    // (interview / travel / daily / ielts) which the home dashboard uses to
    // recommend scenarios + practice content. Only the most recent row is
    // "active" (UI shows the latest by created_at).
    await db.execute('''
      CREATE TABLE user_goal (
        id TEXT PRIMARY KEY,
        goal_type TEXT NOT NULL,
        target TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL
      )
    ''');

    // S7/S8 v8 — structured scenario content. Each scenario ships 5–8
    // core expressions (the "what to say" backbone) the user can drill
    // before / during a conversation. `practice_type` controls how the
    // practice screen presents the item ('repeat' / 'read' / 'respond' /
    // 'listen'). `score` is the user's latest 0–100 mastery score; 0
    // means "not practised yet".
    await db.execute('''
      CREATE TABLE scenario_items (
        id TEXT PRIMARY KEY,
        scenario_id TEXT NOT NULL,
        expression TEXT NOT NULL,
        translation TEXT NOT NULL DEFAULT '',
        audio_url TEXT,
        practice_type TEXT NOT NULL DEFAULT 'repeat',
        score INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (scenario_id) REFERENCES scenarios(id)
      )
    ''');

    // S7/S8 v8 — teacher persona matrix. Each persona is a named
    // "AI tutor style" the user can switch between (strict / encourage /
    // humor). `temp` is the LLM sampling temperature; `prompt_template`
    // is the system-prompt skeleton with a `{scenario_prompt}` placeholder
    // replaced at chat-session build time.
    await db.execute('''
      CREATE TABLE teacher_persona (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        style TEXT NOT NULL,
        temp REAL NOT NULL DEFAULT 0.7,
        prompt_template TEXT NOT NULL
      )
    ''');

    // S7/S8 v8 — scenario review queue. Mirrors the S5/S6 `review_queue`
    // pattern but for scenarios: when the user finishes a scenario, a slot
    // is upserted with the SM-2 state so the dashboard can surface
    // "review this scenario" alongside correction reviews. Kept in a
    // separate table so the existing review_queue's NOT NULL UNIQUE on
    // correction_id stays intact (no risky table rebuild).
    await db.execute('''
      CREATE TABLE scenario_review_queue (
        id TEXT PRIMARY KEY,
        scenario_id TEXT NOT NULL UNIQUE,
        due_at TEXT NOT NULL,
        interval_days INTEGER NOT NULL DEFAULT 0,
        repetitions INTEGER NOT NULL DEFAULT 0,
        ease_factor REAL NOT NULL DEFAULT 2.5,
        last_score INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (scenario_id) REFERENCES scenarios(id)
      )
    ''');

    // Insert default scenarios
    await _insertDefaultScenarios(db);
    // S7/S8 v8 — seed teacher personas + structured scenario items.
    await _insertDefaultTeacherPersonas(db);
    await _insertDefaultScenarioItems(db);
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
        'goal': null,
        'tags': null,
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
        'goal': 'Order a meal confidently and handle common waiter interactions',
        'tags': '["daily","food","beginner"]',
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
        'goal': 'Handle airport check-in, security, and boarding in English',
        'tags': '["travel","beginner"]',
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
        'goal': 'Answer common interview questions with structured, confident responses',
        'tags': '["career","interview","intermediate"]',
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
        'goal': 'Lead and contribute to a business meeting using professional English',
        'tags': '["career","business","advanced"]',
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
        'goal': 'Shop for clothes: ask for sizes, try on, and pay confidently',
        'tags': '["daily","shopping","beginner"]',
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
        'goal': 'Describe symptoms clearly and understand medical advice',
        'tags': '["daily","health","intermediate"]',
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
        'goal': null,
        'tags': null,
      },
      // S7/S8 v8 — six new structured scenarios from the spec. The row
      // maps live in [_v8NewScenarios] so the v8 upgrade migration reuses
      // the same source of truth.
      ..._v8NewScenarios,
    ];

    for (final scenario in scenarios) {
      await db.insert('scenarios', scenario);
    }
  }

  /// S7/S8 v8 — row maps for the 6 new spec scenarios. Shared between
  /// [_insertDefaultScenarios] (fresh install) and [_insertNewV8Scenarios]
  /// (v7→v8 upgrade) so the seed data has one source of truth.
  static const List<Map<String, dynamic>> _v8NewScenarios = [
    {
      'id': 'self_intro',
      'name': 'Self-Introduction',
      'description': 'Introduce yourself in 60 seconds',
      'icon': '👋',
      'difficulty': 'beginner',
      'category': 'daily',
      'system_prompt':
          'You are a friendly English tutor. The student is practicing a self-introduction. Ask follow-up questions about their background, work, and hobbies. Correct errors naturally.',
      'goal': 'Introduce yourself confidently in 60 seconds',
      'tags': '["daily","social","beginner"]',
    },
    {
      'id': 'order_coffee',
      'name': 'Ordering Coffee',
      'description': 'Order a coffee and customize it',
      'icon': '☕',
      'difficulty': 'beginner',
      'category': 'daily',
      'system_prompt':
          'You are a friendly English tutor. The student is practicing ordering coffee at a cafe. You play the barista. Offer sizes, milk options, and ask if it is for here or to go. Correct errors naturally.',
      'goal': 'Order a coffee and customize it to your preference',
      'tags': '["daily","food","beginner"]',
    },
    {
      'id': 'book_hotel',
      'name': 'Booking a Hotel',
      'description': 'Book a room and handle check-in',
      'icon': '🏨',
      'difficulty': 'intermediate',
      'category': 'travel',
      'system_prompt':
          'You are a friendly English tutor. The student is practicing booking a hotel room. You play the front desk agent. Ask about dates, room type, and special requests. Correct errors naturally.',
      'goal': 'Book a hotel room and handle check-in confidently',
      'tags': '["travel","hotel","intermediate"]',
    },
    {
      'id': 'phone_call',
      'name': 'Phone Calls',
      'description': 'Handle a professional phone call',
      'icon': '📞',
      'difficulty': 'intermediate',
      'category': 'career',
      'system_prompt':
          'You are a friendly English tutor. The student is practicing professional phone calls. You play the other party (colleague, customer, receptionist). Encourage clear, polite phone English. Correct errors naturally.',
      'goal': 'Handle a professional phone call from greeting to closing',
      'tags': '["career","phone","intermediate"]',
    },
    {
      'id': 'ask_directions',
      'name': 'Asking Directions',
      'description': 'Ask for and understand directions',
      'icon': '🧭',
      'difficulty': 'beginner',
      'category': 'travel',
      'system_prompt':
          'You are a friendly English tutor. The student is practicing asking for directions. You play a friendly local. Give step-by-step directions using landmarks and distances. Correct errors naturally.',
      'goal': 'Ask for and understand directions to a destination',
      'tags': '["travel","directions","beginner"]',
    },
    {
      'id': 'social_icebreaker',
      'name': 'Social Icebreakers',
      'description': 'Start a conversation with a stranger',
      'icon': '🥂',
      'difficulty': 'beginner',
      'category': 'social',
      'system_prompt':
          'You are a friendly English tutor. The student is practicing social icebreakers at a party. You play a fellow guest. Respond warmly to their opener and keep the conversation going. Correct errors naturally.',
      'goal': 'Start and sustain a conversation with a stranger',
      'tags': '["social","icebreaker","beginner"]',
    },
  ];

  /// S7/S8 v8 — seed the three canonical teacher personas (strict /
  /// encourage / humor). Idempotent: uses INSERT OR IGNORE so re-running
  /// on an already-seeded database is a no-op. Stable ids so the user's
  /// `active_persona_id` setting keeps pointing at the same persona across
  /// reinstalls.
  static Future<void> _insertDefaultTeacherPersonas(Database db) async {
    const personas = [
      {
        'id': 'persona_strict',
        'name': 'Mr. Sterling',
        'style': 'strict',
        'temp': 0.4,
        'prompt_template':
            'You are Mr. Sterling, a strict but fair English tutor. You focus on accuracy: flag every grammar, vocabulary, and pronunciation error in the student\'s utterance. Praise is brief and reserved for genuinely correct sentences. Keep corrections short and specific.\n\n{scenario_prompt}\n\nAlways correct mistakes; never let them slide to "be polite". End each turn with at most one piece of constructive feedback.',
      },
      {
        'id': 'persona_encourage',
        'name': 'Ms. Lily',
        'style': 'encourage',
        'temp': 0.7,
        'prompt_template':
            'You are Ms. Lily, a warm and encouraging English tutor. You celebrate the student\'s effort before correcting. Use positive framing ("Great try! Let\'s refine..."). Keep the conversation flowing naturally; correct only one or two errors per turn so the student doesn\'t feel overwhelmed.\n\n{scenario_prompt}\n\nAlways acknowledge what the student did well before suggesting improvements.',
      },
      {
        'id': 'persona_humor',
        'name': 'Coach Max',
        'style': 'humor',
        'temp': 0.9,
        'prompt_template':
            'You are Coach Max, a playful English tutor who uses humor to lower the student\'s anxiety. You make light jokes, use cultural references, and keep the mood upbeat while still gently correcting errors.\n\n{scenario_prompt}\n\nSneak in a small joke or witty observation each turn, then refocus on the learning goal. Never let humor block the student\'s practice.',
      },
    ];
    final batch = db.batch();
    for (final p in personas) {
      batch.insert('teacher_persona', p,
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit();
  }

  /// S7/S8 v8 — seed structured scenario_items for the 10 spec scenarios.
  /// Each scenario gets 5–7 core expressions with a Chinese translation
  /// (zh is the project default; the UI surfaces translations as a study
  /// aid, not as localised UI text). Idempotent via INSERT OR IGNORE so
  /// re-running on an already-seeded database is a no-op.
  static Future<void> _insertDefaultScenarioItems(Database db) async {
    final items = <Map<String, dynamic>>[
      // 1. self_intro
      _item('self_intro', 'Hi, my name is Alex. Nice to meet you.',
          '你好，我叫 Alex。很高兴认识你。'),
      _item('self_intro', "I'm from Shanghai, China.",
          '我来自中国上海。'),
      _item('self_intro', 'I work as a software engineer at a tech company.',
          '我在一家科技公司做软件工程师。'),
      _item('self_intro', 'In my free time, I enjoy hiking and photography.',
          '业余时间我喜欢徒步和摄影。'),
      _item('self_intro',
          "I'm learning English to communicate better with my clients.",
          '我学英语是为了更好地和客户沟通。'),
      _item('self_intro', "It's great to meet you all today.",
          '今天很高兴认识大家。'),
      // 2. order_coffee
      _item('order_coffee', 'Hi, could I get a large latte, please?',
          '你好，请给我一杯大杯拿铁。'),
      _item('order_coffee', 'What sizes do you have?', '你们有什么杯型？'),
      _item('order_coffee', 'Can I have it with oat milk?',
          '可以加燕麦奶吗？'),
      _item('order_coffee', "I'd like it iced, please.", '请做成冰的。'),
      _item('order_coffee', 'How much is it?', '多少钱？'),
      _item('order_coffee', 'For here, please.', '堂食，谢谢。'),
      _item('order_coffee', 'Could I get a receipt, please?',
          '请给我小票。'),
      // 3. book_hotel
      _item('book_hotel',
          "Hi, I'd like to book a room for two nights.",
          '你好，我想订一间房，住两晚。'),
      _item('book_hotel',
          'Do you have any rooms available for March 15th?',
          '3月15日还有房吗？'),
      _item('book_hotel', "I'd like a double room, please.",
          '请给我一间双床房。'),
      _item('book_hotel', "What's the rate per night?", '每晚多少钱？'),
      _item('book_hotel', 'Does that include breakfast?', '含早餐吗？'),
      _item('book_hotel', "I'll be checking in around 6 PM.",
          '我大约下午6点入住。'),
      _item('book_hotel', 'Can I pay with a credit card?',
          '可以刷信用卡吗？'),
      // 4. doctor
      _item('doctor', "I've had a headache for the past two days.",
          '我头疼两天了。'),
      _item('doctor', "I'm feeling a bit dizzy.", '我有点头晕。'),
      _item('doctor', 'How often should I take this medicine?',
          '这个药多久吃一次？'),
      _item('doctor', 'Are there any side effects?', '有副作用吗？'),
      _item('doctor', "I'm also having trouble sleeping.",
          '我也睡不好。'),
      _item('doctor', 'Should I avoid any foods?', '需要忌口吗？'),
      _item('doctor', 'When should I come back for a follow-up?',
          '什么时候来复查？'),
      // 5. job_interview
      _item('job_interview',
          'I have five years of experience in software development.',
          '我有五年软件开发经验。'),
      _item('job_interview',
          'In my last role, I led a team of four engineers.',
          '在上一份工作中，我带过四个人。'),
      _item('job_interview',
          'My biggest strength is problem-solving.',
          '我最大的优势是解决问题。'),
      _item('job_interview',
          "One area I'm improving is public speaking.",
          '我正在提升公开演讲能力。'),
      _item('job_interview',
          "I'm excited about this role because of your team's focus on AI.",
          '我对这个岗位很感兴趣，因为你们团队专注 AI。'),
      _item('job_interview', 'When can I expect to hear back?',
          '什么时候能有结果？'),
      // 6. business_meeting
      _item('business_meeting',
          "Let's get started. Today's agenda has three items.",
          '我们开始吧。今天有三个议题。'),
      _item('business_meeting',
          'Could you walk us through the Q2 numbers?',
          '能讲一下 Q2 数据吗？'),
      _item('business_meeting',
          "I'd like to raise a point about the timeline.",
          '我想说一个关于时间线的问题。'),
      _item('business_meeting', 'Can we circle back to that later?',
          '这个我们待会儿再讨论好吗？'),
      _item('business_meeting',
          "I think we're aligned on the next steps.",
          '下一步我们应该达成一致了。'),
      _item('business_meeting',
          "Let's table this for now and revisit next week.",
          '这个先放一放，下周再议。'),
      _item('business_meeting', "Thanks everyone, let's wrap up.",
          '谢谢大家，今天就到这儿。'),
      // 7. phone_call
      _item('phone_call',
          'Hi, this is Alex calling. May I speak to Ms. Chen?',
          '你好，我是 Alex，请找一下陈女士。'),
      _item('phone_call', 'Could you take a message, please?',
          '可以帮我留言吗？'),
      _item('phone_call', "I'm returning your call about the proposal.",
          '我回你关于提案的电话。'),
      _item('phone_call',
          'Could you spell that for me, please?',
          '可以拼写一下吗？'),
      _item('phone_call',
          "I think we have a bad connection. Could you repeat that?",
          '信号不好，能再说一遍吗？'),
      _item('phone_call',
          "I'll send the details by email right after we hang up.",
          '挂电话后我把详情发邮件。'),
      _item('phone_call', 'Thanks for your help. Goodbye.',
          '谢谢帮忙，再见。'),
      // 8. ask_directions
      _item('ask_directions',
          'Excuse me, could you tell me how to get to the train station?',
          '打扰一下，去火车站怎么走？'),
      _item('ask_directions', 'Is it far from here?', '离这儿远吗？'),
      _item('ask_directions', 'How long does it take on foot?',
          '走路要多久？'),
      _item('ask_directions', 'Should I take a bus or the subway?',
          '坐公交还是地铁？'),
      _item('ask_directions',
          'Could you repeat that more slowly, please?',
          '可以慢一点再说一遍吗？'),
      _item('ask_directions',
          'Is there a landmark I should look for?',
          '有什么地标吗？'),
      _item('ask_directions', 'Thank you, that\'s very helpful.',
          '谢谢，很有帮助。'),
      // 9. shopping
      _item('shopping', "Hi, I'm looking for a winter jacket.",
          '你好，我想买件冬装外套。'),
      _item('shopping', 'Do you have this in a size medium?',
          '有 M 码吗？'),
      _item('shopping', 'Can I try it on?', '可以试穿吗？'),
      _item('shopping', 'How much is it?', '多少钱？'),
      _item('shopping', 'Is there a discount on this?', '有折扣吗？'),
      _item('shopping', 'Do you accept returns?', '可以退货吗？'),
      _item('shopping', "I'll take it. Can I pay by card?",
          '我要了，可以刷卡吗？'),
      // 10. social_icebreaker
      _item('social_icebreaker',
          "Hi, I don't think we've met. I'm Alex.",
          '你好，我们好像没见过。我是 Alex。'),
      _item('social_icebreaker', 'Great party, isn\'t it?',
          '聚会不错，是吧？'),
      _item('social_icebreaker', 'How do you know the host?',
          '你怎么认识主人的？'),
      _item('social_icebreaker', 'What do you do for a living?',
          '你做什么工作？'),
      _item('social_icebreaker',
          "Have you tried the food? It's amazing.",
          '尝了菜没？很好吃。'),
      _item('social_icebreaker', 'Where are you from originally?',
          '你老家是哪儿的？'),
      _item('social_icebreaker',
          "It was nice talking to you. See you around!",
          '聊得挺开心，回头见！'),
    ];
    final batch = db.batch();
    for (final item in items) {
      batch.insert('scenario_items', item,
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit();
  }

  /// Helper: build a scenario_items row map with a deterministic id so the
  /// seed is idempotent across reinstalls.
  static Map<String, dynamic> _item(
    String scenarioId,
    String expression,
    String translation, {
    String practiceType = 'repeat',
  }) {
    return {
      'id': '${scenarioId}_${expression.hashCode.toRadixString(36)}',
      'scenario_id': scenarioId,
      'expression': expression,
      'translation': translation,
      'audio_url': null,
      'practice_type': practiceType,
      'score': 0,
    };
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

    if (oldVersion < 6) {
      // v6 adds the S5/S6 home-dashboard tables:
      //   practice_log — one row per day the user practised, drives the
      //     streak progress bar (max 30 days, 7-day milestone badges).
      //   review_queue — one row per correction, mirrors its next due time
      //     so the dashboard can show "what to review next" sorted by the
      //     forgetting window.
      await db.execute('''
        CREATE TABLE IF NOT EXISTS practice_log (
          id TEXT PRIMARY KEY,
          date TEXT NOT NULL UNIQUE,
          duration_seconds INTEGER NOT NULL DEFAULT 0,
          completed INTEGER NOT NULL DEFAULT 0,
          streak INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS review_queue (
          id TEXT PRIMARY KEY,
          correction_id TEXT NOT NULL UNIQUE,
          due_at TEXT NOT NULL,
          created_at TEXT NOT NULL,
          FOREIGN KEY (correction_id) REFERENCES corrections(id)
        )
      ''');
      // Back-fill review_queue from existing corrections so users on a v5
      // database don't see an empty "to review" list on their first
      // dashboard load. Corrections with no next_review_at are due now
      // (due_at = created_at). SQLite has no uuid() builtin, so we derive a
      // deterministic id from the correction id.
      await db.execute('''
        INSERT OR IGNORE INTO review_queue (id, correction_id, due_at, created_at)
        SELECT id || '_rq', id, COALESCE(next_review_at, created_at), datetime('now')
        FROM corrections
      ''');
    }

    if (oldVersion < 7) {
      // v7 adds the S5/S6 "learning profile v1" schema:
      //   corrections.skill            — free-text skill tag (e.g.
      //     'grammar/subject-verb-agreement') so each error can be rolled up
      //     under a skill point in the mastery table.
      //   review_queue.interval_days / repetitions / ease_factor — mirrors
      //     the SM-2 state so the dashboard can sort today's tasks by
      //     progression without joining back to corrections.
      //   skill_mastery (new table)   — one row per skill_id with a 0-100
      //     score + level bucket, written by SkillMasteryService.
      //   user_goal (new table)       — the user's current learning goal
      //     (interview / travel / daily / ielts) used for scenario
      //     recommendations on the home dashboard.
      //
      // Per the S5/S6 spec we ONLY add migration steps here — existing
      // tables get new nullable / default columns, new tables are created
      // with `IF NOT EXISTS` so the migration is idempotent and a fresh
      // install (which runs _onCreate at v7) is consistent.
      final batch = db.batch();
      batch.execute('ALTER TABLE corrections ADD COLUMN skill TEXT');
      batch.execute(
        'ALTER TABLE review_queue ADD COLUMN interval_days INTEGER NOT NULL DEFAULT 0',
      );
      batch.execute(
        'ALTER TABLE review_queue ADD COLUMN repetitions INTEGER NOT NULL DEFAULT 0',
      );
      batch.execute(
        'ALTER TABLE review_queue ADD COLUMN ease_factor REAL NOT NULL DEFAULT 2.5',
      );
      await batch.commit();

      // Back-fill the new review_queue SM-2 columns from the joined
      // corrections so the dashboard's "today's tasks" ordering by SM-2
      // progression works immediately on upgrade.
      await db.execute('''
        UPDATE review_queue
        SET interval_days = COALESCE((
              SELECT interval_days FROM corrections
              WHERE corrections.id = review_queue.correction_id
            ), 0),
            repetitions = COALESCE((
              SELECT review_count FROM corrections
              WHERE corrections.id = review_queue.correction_id
            ), 0),
            ease_factor = COALESCE((
              SELECT easiness_factor FROM corrections
              WHERE corrections.id = review_queue.correction_id
            ), 2.5)
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS skill_mastery (
          id TEXT PRIMARY KEY,
          skill_id TEXT NOT NULL UNIQUE,
          score INTEGER NOT NULL DEFAULT 0,
          level TEXT NOT NULL DEFAULT 'new',
          updated_at TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS user_goal (
          id TEXT PRIMARY KEY,
          goal_type TEXT NOT NULL,
          target TEXT NOT NULL DEFAULT '',
          created_at TEXT NOT NULL
        )
      ''');
    }

    if (oldVersion < 8) {
      // v8 adds the S7/S8 "structured content v1" schema:
      //   scenarios.goal / tags             — free-text goal + JSON-encoded
      //     tag array so the home dashboard can surface "what you'll learn"
      //     and filter recommendations by tag.
      //   scenario_items (new table)        — 5–8 structured expressions
      //     per scenario (expression / translation / audio_url /
      //     practice_type / score).
      //   teacher_persona (new table)       — the 3 canonical personas
      //     (strict / encourage / humor) the user can switch between.
      //   scenario_review_queue (new table) — SM-2 slots for scenarios so
      //     the dashboard can surface "review this scenario" alongside
      //     correction reviews.
      //
      // All changes are additive: existing scenarios / review_queue rows
      // keep working. The 6 new spec scenarios are inserted with
      // INSERT OR IGNORE so we never clobber a user's edits. Existing
      // scenarios get their goal/tags back-filled from the same seed
      // data so the home dashboard's "what you'll learn" copy shows up
      // on upgrade.
      final batch = db.batch();
      batch.execute('ALTER TABLE scenarios ADD COLUMN goal TEXT');
      batch.execute('ALTER TABLE scenarios ADD COLUMN tags TEXT');
      batch.execute('''
        CREATE TABLE IF NOT EXISTS scenario_items (
          id TEXT PRIMARY KEY,
          scenario_id TEXT NOT NULL,
          expression TEXT NOT NULL,
          translation TEXT NOT NULL DEFAULT '',
          audio_url TEXT,
          practice_type TEXT NOT NULL DEFAULT 'repeat',
          score INTEGER NOT NULL DEFAULT 0,
          FOREIGN KEY (scenario_id) REFERENCES scenarios(id)
        )
      ''');
      batch.execute('''
        CREATE TABLE IF NOT EXISTS teacher_persona (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          style TEXT NOT NULL,
          temp REAL NOT NULL DEFAULT 0.7,
          prompt_template TEXT NOT NULL
        )
      ''');
      batch.execute('''
        CREATE TABLE IF NOT EXISTS scenario_review_queue (
          id TEXT PRIMARY KEY,
          scenario_id TEXT NOT NULL UNIQUE,
          due_at TEXT NOT NULL,
          interval_days INTEGER NOT NULL DEFAULT 0,
          repetitions INTEGER NOT NULL DEFAULT 0,
          ease_factor REAL NOT NULL DEFAULT 2.5,
          last_score INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL,
          FOREIGN KEY (scenario_id) REFERENCES scenarios(id)
        )
      ''');
      await batch.commit();

      // Back-fill goal / tags on existing scenarios so the home dashboard
      // shows the new "what you'll learn" copy on upgrade. UPDATE ... SET
      // ... WHERE goal IS NULL keeps user edits intact.
      await _backfillScenarioGoalTags(db);
      // Insert the 6 new spec scenarios (idempotent — INSERT OR IGNORE).
      await _insertNewV8Scenarios(db);
      // Seed the 3 canonical personas + the 10 spec scenarios' items.
      await _insertDefaultTeacherPersonas(db);
      await _insertDefaultScenarioItems(db);
    }
  }

  /// S7/S8 v8 — back-fill `goal` and `tags` on scenarios that already
  /// existed pre-v8. Only updates rows whose `goal` IS NULL so we never
  /// overwrite a user's manual edit. Mirrors the seed data in
  /// [_insertDefaultScenarios].
  static Future<void> _backfillScenarioGoalTags(Database db) async {
    const updates = <String, Map<String, String?>>{
      'restaurant': {
        'goal': 'Order a meal confidently and handle common waiter interactions',
        'tags': '["daily","food","beginner"]',
      },
      'airport': {
        'goal': 'Handle airport check-in, security, and boarding in English',
        'tags': '["travel","beginner"]',
      },
      'job_interview': {
        'goal': 'Answer common interview questions with structured, confident responses',
        'tags': '["career","interview","intermediate"]',
      },
      'business_meeting': {
        'goal': 'Lead and contribute to a business meeting using professional English',
        'tags': '["career","business","advanced"]',
      },
      'shopping': {
        'goal': 'Shop for clothes: ask for sizes, try on, and pay confidently',
        'tags': '["daily","shopping","beginner"]',
      },
      'doctor': {
        'goal': 'Describe symptoms clearly and understand medical advice',
        'tags': '["daily","health","intermediate"]',
      },
    };
    for (final entry in updates.entries) {
      await db.update(
        'scenarios',
        {'goal': entry.value['goal'], 'tags': entry.value['tags']},
        where: 'id = ? AND goal IS NULL',
        whereArgs: [entry.key],
      );
    }
  }

  /// S7/S8 v8 — insert the 6 new spec scenarios on upgrade. Idempotent:
  /// INSERT OR IGNORE so a re-run on an already-seeded database is a
  /// no-op. Reuses the same row maps as [_insertDefaultScenarios] for
  /// the 6 new ids so the seed data has one source of truth.
  static Future<void> _insertNewV8Scenarios(Database db) async {
    const newIds = [
      'self_intro',
      'order_coffee',
      'book_hotel',
      'phone_call',
      'ask_directions',
      'social_icebreaker',
    ];
    final existing = <String, Map<String, dynamic>>{};
    for (final s in _v8NewScenarios) {
      existing[s['id'] as String] = s;
    }
    final batch = db.batch();
    for (final id in newIds) {
      final row = existing[id];
      if (row == null) continue;
      batch.insert('scenarios', row, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit();
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
