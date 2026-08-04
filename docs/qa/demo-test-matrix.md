# Demo/E2E test matrix

The matrix is designed to exercise real UI/repository flows with deterministic
local inputs. It is not a claim that a provider or physical microphone has been
tested.

| Fixture | Entry | Expected evidence |
|---|---|---|
| happy_path | Chat | stream, persist assistant message, synthesize local WAV |
| grammar_correction | Chat | parse correction, save correction, review item appears |
| no_correction | Chat | readable answer with no review item |
| multi_turn | Chat | three turns advance without stale state |
| interruption | Chat | one stop action invalidates stream/playback and returns to idle |
| slow_stream | Chat | loading state remains cancellable; no duplicate TTS |
| stt_empty | voice input | empty transcript hint; no empty user message is saved |
| llm_retry | Chat | first transient failure retries once and succeeds |
| tts_failure | Chat | subtitle remains visible and error is recoverable |
| avatar_failure | Avatar/Chat | renderer fallback does not block chat |
| review_loop | Chat → Review | correction is persisted and review route loads it |
| summary_loop | Chat → Summary | summary uses the simulation gateway and closes the loop |

## Commands

```bash
flutter test
flutter build web --release --dart-define=APP_MODE=demo --base-href=/talk-demo/
flutter build web --release --dart-define=APP_MODE=e2e
cd e2e && npm ci && npm run typecheck
npx playwright test specs/runtime/simulation.spec.ts --project=chromium --workers=1
```

The full browser suite additionally requires a local browser and is intentionally
not represented as passing unless its command produces a real report.
