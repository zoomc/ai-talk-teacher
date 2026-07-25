/**
 * HTTP mock layer for E2E tests.
 *
 * Intercepts all LLM / STT / TTS vendor HTTP calls via `page.route()`
 * and returns canned responses. This is the fallback safety net — the
 * primary mocking path is the Dart-side `E2eMockServices` short-circuit
 * (which never issues HTTP at all). Use both together for defense in depth.
 *
 * Vendor endpoints covered:
 *   - OpenAI-compatible: POST **/v1/chat/completions, /v1/audio/speech,
 *                       /v1/audio/transcriptions
 *   - Deepgram: POST wss://api.deepgram.com/** (WS — not intercepted
 *              here; rely on Dart-side mock)
 *   - Azure STT/TTS: POST **.cognitiveservices.azure.com/**
 *   - Google STT: POST **.googleapis.com/speech/**
 *   - Fish Audio TTS: POST api.fish.audio/**
 *   - ElevenLabs TTS: POST api.elevenlabs.io/**
 *
 * Per-test overrides: `setLlmResponse(page, promptSubstring, reply)` lets
 * a test inject a specific LLM response keyed on a substring of the prompt.
 */
import { Page, Route } from '@playwright/test';

/** Default canned LLM response (used when no per-test override matches). */
const DEFAULT_LLM_RESPONSE = {
  id: 'chatcmpl-e2e-mock',
  object: 'chat.completion',
  created: 1718928000,
  model: 'mock-model',
  choices: [
    {
      index: 0,
      message: {
        role: 'assistant',
        content: "That's interesting! Tell me more about your day.",
      },
      finish_reason: 'stop',
    },
  ],
  usage: { prompt_tokens: 10, completion_tokens: 12, total_tokens: 22 },
};

/** Default canned LLM streaming chunks (SSE format). */
function defaultLlmStreamChunks(): string {
  const chunks = [
    { choices: [{ delta: { role: 'assistant' }, index: 0 }] },
    { choices: [{ delta: { content: "That's " }, index: 0 }] },
    { choices: [{ delta: { content: 'interesting! ' }, index: 0 }] },
    { choices: [{ delta: { content: 'Tell me ' }, index: 0 }] },
    { choices: [{ delta: { content: 'more.' }, index: 0 }] },
    { choices: [{ delta: {}, index: 0, finish_reason: 'stop' }] },
  ];
  return chunks.map((c) => `data: ${JSON.stringify(c)}\n\n`).join('') + 'data: [DONE]\n\n';
}

/** Default canned STT response (OpenAI format). */
const DEFAULT_STT_RESPONSE = {
  text: 'Hello, this is a mock transcription.',
};

/** Default canned TTS audio (silent 100ms WAV — base64-encoded). */
const SILENT_WAV_BASE64 =
  'UklGRiQAAABXQVZFZm10IBAAAAABAAEARKwAAIhYAQACABAAZGF0YQAAAAA=';

/** Per-test LLM response overrides, keyed by prompt substring. */
const llmOverrides = new Map<string, string>();

/** Per-test STT transcript override. */
let sttOverride: string | null = null;

/** Per-test TTS audio override (base64). */
let ttsOverride: string | null = null;

/**
 * Inject a custom LLM response for any request whose body contains
 * `promptSubstring` (case-insensitive). The first matching override wins.
 */
export function setLlmResponse(page: Page, promptSubstring: string, reply: string): void {
  llmOverrides.set(promptSubstring.toLowerCase(), reply);
}

/** Override the STT mock transcript. */
export function setSttTranscript(page: Page, transcript: string): void {
  sttOverride = transcript;
}

/** Override the TTS mock audio (base64-encoded). */
export function setTtsAudio(page: Page, base64Audio: string): void {
  ttsOverride = base64Audio;
}

/** Reset all per-test overrides (call in afterEach). */
export function resetOverrides(): void {
  llmOverrides.clear();
  sttOverride = null;
  ttsOverride = null;
}

/**
 * Register all HTTP mocks on the page. Call once in `beforeEach`.
 *
 * Routes are matched in registration order; the first match wins.
 * All routes call `route.fulfill()` so no real network call is ever made.
 */
export async function setupHttpMocks(page: Page): Promise<void> {
  // LLM: OpenAI-compatible chat completions (covers DeepSeek, GLM, Kimi, OpenAI, custom)
  await page.route('**/v1/chat/completions*', async (route: Route) => {
    const request = route.request();
    const body = request.postData() || '';
    const isStream = body.includes('"stream":true') || body.includes('"stream": true');

    // Find a per-test override
    let reply: string | null = null;
    for (const [needle, value] of llmOverrides) {
      if (body.toLowerCase().includes(needle)) {
        reply = value;
        break;
      }
    }

    if (isStream) {
      const chunks = reply
        ? chunkReplyForStream(reply)
        : defaultLlmStreamChunks();
      await route.fulfill({
        status: 200,
        contentType: 'text/event-stream',
        body: chunks,
      });
    } else {
      const response = reply
        ? { ...DEFAULT_LLM_RESPONSE, choices: [{ ...DEFAULT_LLM_RESPONSE.choices[0], message: { role: 'assistant', content: reply } }] }
        : DEFAULT_LLM_RESPONSE;
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify(response),
      });
    }
  });

  // LLM: legacy /chat/completions (without /v1 prefix)
  await page.route('**/chat/completions*', async (route: Route) => {
    if (route.request().url().includes('/v1/')) {
      // Already handled above — skip
      await route.continue();
      return;
    }
    const reply = pickOverride(route.request().postData() || '');
    const response = reply
      ? { ...DEFAULT_LLM_RESPONSE, choices: [{ ...DEFAULT_LLM_RESPONSE.choices[0], message: { role: 'assistant', content: reply } }] }
      : DEFAULT_LLM_RESPONSE;
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify(response),
    });
  });

  // STT: OpenAI-compatible /v1/audio/transcriptions
  await page.route('**/v1/audio/transcriptions*', async (route: Route) => {
    const text = sttOverride ?? DEFAULT_STT_RESPONSE.text;
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({ text }),
    });
  });

  // STT: Deepgram (HTTPS fallback — Deepgram also uses WS but that's mocked Dart-side)
  await page.route('**/api.deepgram.com/**', async (route: Route) => {
    const text = sttOverride ?? DEFAULT_STT_RESPONSE.text;
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({ results: { channels: [{ alternatives: [{ transcript: text, confidence: 0.95 }] }] } }),
    });
  });

  // STT: Azure
  await page.route('**.cognitiveservices.azure.com/**speech**', async (route: Route) => {
    const text = sttOverride ?? DEFAULT_STT_RESPONSE.text;
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({ DisplayText: text, RecognitionStatus: 'Success' }),
    });
  });

  // STT: Google
  await page.route('**/speech.googleapis.com/**', async (route: Route) => {
    const text = sttOverride ?? DEFAULT_STT_RESPONSE.text;
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({ results: [{ alternatives: [{ transcript: text, confidence: 0.95 }] }] }),
    });
  });

  // TTS: OpenAI-compatible /v1/audio/speech
  await page.route('**/v1/audio/speech*', async (route: Route) => {
    const audio = ttsOverride ?? SILENT_WAV_BASE64;
    await route.fulfill({
      status: 200,
      contentType: 'audio/mpeg',
      body: Buffer.from(audio, 'base64'),
    });
  });

  // TTS: Fish Audio
  await page.route('**/api.fish.audio/**', async (route: Route) => {
    const audio = ttsOverride ?? SILENT_WAV_BASE64;
    await route.fulfill({
      status: 200,
      contentType: 'audio/mpeg',
      body: Buffer.from(audio, 'base64'),
    });
  });

  // TTS: ElevenLabs
  await page.route('**/api.elevenlabs.io/**', async (route: Route) => {
    const audio = ttsOverride ?? SILENT_WAV_BASE64;
    await route.fulfill({
      status: 200,
      contentType: 'audio/mpeg',
      body: Buffer.from(audio, 'base64'),
    });
  });

  // TTS: Azure
  await page.route('**.cognitiveservices.azure.com/**tts**', async (route: Route) => {
    const audio = ttsOverride ?? SILENT_WAV_BASE64;
    await route.fulfill({
      status: 200,
      contentType: 'audio/mpeg',
      body: Buffer.from(audio, 'base64'),
    });
  });
}

/** Helper: find the first matching override for a request body. */
function pickOverride(body: string): string | null {
  const lower = body.toLowerCase();
  for (const [needle, value] of llmOverrides) {
    if (lower.includes(needle)) return value;
  }
  return null;
}

/** Helper: split a reply string into SSE streaming chunks. */
function chunkReplyForStream(reply: string): string {
  const words = reply.split(/(\s+)/);
  const chunks: object[] = [{ choices: [{ delta: { role: 'assistant' }, index: 0 }] }];
  for (const word of words) {
    chunks.push({ choices: [{ delta: { content: word }, index: 0 }] });
  }
  chunks.push({ choices: [{ delta: {}, index: 0, finish_reason: 'stop' }] });
  return chunks.map((c) => `data: ${JSON.stringify(c)}\n\n`).join('') + 'data: [DONE]\n\n';
}

/** Mock a network failure for the next N requests matching a URL pattern. */
export async function mockNetworkError(
  page: Page,
  urlPattern: string,
  status: number = 500,
): Promise<void> {
  await page.route(urlPattern, async (route) => {
    await route.fulfill({
      status,
      contentType: 'application/json',
      body: JSON.stringify({ error: { message: `Mocked ${status} error` } }),
    });
  });
}

/** Mock a network timeout (abort the request). */
export async function mockNetworkTimeout(
  page: Page,
  urlPattern: string,
): Promise<void> {
  await page.route(urlPattern, async (route) => {
    await route.abort('timedout');
  });
}
