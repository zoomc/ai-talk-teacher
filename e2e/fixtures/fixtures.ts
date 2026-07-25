/**
 * Typed fixture data for E2E tests.
 *
 * Each fixture is a named scenario (e.g., 'onboarded', 'guest', 'with-projects')
 * that bundles together the SQLite rows needed to set up that scenario.
 *
 * The actual row shapes mirror the SQLite tables defined in
 * `lib/core/database/database_helper.dart`:
 *   - llm_profiles, stt_profiles, tts_profiles
 *   - chat_sessions, messages, corrections, review_queue
 *   - scenarios, scenario_items
 *   - projects, project_links, project_activities
 *   - practice_log, skill_mastery, user_goals, scenario_review_queue
 *   - settings (key/value)
 */
import data from './mock-data.json';

// ---- Row type definitions (mirror Dart models) ----

export interface LlmProfileRow {
  id: string;
  name: string;
  provider_id: string;
  base_url: string;
  api_key: string;
  model: string;
  is_active: number;
  created_at: string;
  updated_at: string;
}

export interface SttProfileRow {
  id: string;
  name: string;
  provider_id: string;
  base_url: string;
  api_key: string;
  model: string;
  language: string;
  extra_config: string | null;
  is_active: number;
  created_at: string;
  updated_at: string;
}

export interface TtsProfileRow {
  id: string;
  name: string;
  provider_id: string;
  base_url: string;
  api_key: string;
  model: string;
  voice_id: string | null;
  voice_name: string | null;
  speed: number;
  extra_config: string | null;
  is_active: number;
  created_at: string;
  updated_at: string;
}

export interface ChatSessionRow {
  id: string;
  topic: string | null;
  scenario_id: string | null;
  status: string;
  level_tag: string | null;
  is_guest: number;
  created_at: string;
  updated_at: string;
}

export interface MessageRow {
  id: string;
  session_id: string;
  role: string;
  content: string;
  audio_path: string | null;
  created_at: string;
}

export interface CorrectionRow {
  id: string;
  session_id: string;
  message_id: string | null;
  original: string;
  corrected: string;
  type: string;
  explanation: string | null;
  skill: string | null;
  severity?: string;
  review_count: number;
  easiness_factor: number;
  interval_days: number;
  next_review_at: string | null;
  occurrence_count: number;
  last_seen_at: string;
  importance: number;
  is_favorite: number;
  favorite_at?: string | null;
  created_at: string;
  updated_at?: string;
}

export interface ReviewQueueRow {
  id: string;
  correction_id: string;
  due_at: string;
  interval_days: number;
  repetitions: number;
  ease_factor: number;
  last_reviewed_at?: string | null;
  created_at?: string;
}

export interface ScenarioRow {
  id: string;
  name: string;
  description: string;
  icon: string;
  difficulty: string;
  category: string;
  system_prompt: string;
  goal: string | null;
  tags: string | null;
}

export interface ProjectRow {
  id: string;
  name: string;
  icon: string;
  color: string;
  description: string;
  goal: string | null;
  status: string;
  topics: string;
  created_at: string;
  updated_at: string;
  last_activity_at: string;
}

// ---- Fixture bundle type ----

export interface FixtureBundle {
  /** Mark onboarding + placement as complete. */
  completeOnboarding?: boolean;
  /** Settings table key/value pairs. */
  settings?: Record<string, string>;
  /** LLM/STT/TTS profiles. */
  profiles?: Array<LlmProfileRow | SttProfileRow | TtsProfileRow>;
  /** Scenarios + scenario_items. */
  scenarios?: ScenarioRow[];
  /** Projects. */
  projects?: ProjectRow[];
  /** Chat sessions. */
  chatSessions?: ChatSessionRow[];
  /** Messages (chat bubbles). */
  messages?: MessageRow[];
  /** Corrections (SM-2 review items). */
  corrections?: CorrectionRow[];
  /** Review queue (SM-2 scheduling). */
  reviewQueue?: ReviewQueueRow[];
}

// ---- Fixture registry ----

export const FIXTURES = data as Record<FixtureName, FixtureBundle>;

export type FixtureName =
  | 'empty'
  | 'guest'
  | 'onboarded'
  | 'with-projects'
  | 'with-chat-history'
  | 'with-corrections'
  | 'with-review-queue'
  | 'full';

/** Helper: get a fixture by name (throws if missing). */
export function getFixture(name: FixtureName): FixtureBundle {
  const f = FIXTURES[name];
  if (!f) throw new Error(`Unknown fixture: ${name}`);
  return f;
}

/** All fixture names (for iteration in tests). */
export const ALL_FIXTURE_NAMES = Object.keys(FIXTURES) as FixtureName[];

// ---- Canned LLM/STT/TTS mock responses ----

/** Pre-canned LLM responses for common test scenarios. */
export const LLM_MOCKS = {
  greeting: "Hello! I'm your AI tutor. How are you today?",
  correctionDemo:
    "You said 'I goes to school' — the correct form is 'I go to school'. Let's practice!",
  long: 'This is a long mock response. '.repeat(10).trim(),
  empty: '',
  withCode: 'Here is some code:\n```dart\nvoid main() { print("hi"); }\n```',
  withEmoji: 'Great job! 🎉 Keep practicing! 🚀',
  placementResult:
    'Based on our conversation, your level is B1 (Intermediate). Continue practicing!',
};

/** Pre-canned STT transcripts. */
export const STT_MOCKS = {
  short: 'Hello.',
  long: 'I would like to practice my English speaking today.',
      withError: 'I goes to school every day.',
  empty: '',
};

/** Pre-canned TTS audio (base64-encoded silent WAV). */
export const TTS_MOCKS = {
  silent:
    'UklGRiQAAABXQVZFZm10IBAAAAABAAEARKwAAIhYAQACABAAZGF0YQAAAAA=',
};
