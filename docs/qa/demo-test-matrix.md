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
flutter build web --release --pwa-strategy=offline-first \
  --dart-define=APP_MODE=demo --dart-define=APP_BASE_PATH=/talk-demo/ \
  --base-href=/talk-demo/
bash scripts/stamp_web_release.sh build/web "$(git rev-parse HEAD)" demo
bash scripts/verify_web_artifact.sh build/web /talk-demo/ demo "$(git rev-parse HEAD)"
flutter build web --release --pwa-strategy=none \
  --dart-define=APP_MODE=e2e --dart-define=APP_BASE_PATH=/ \
  --dart-define=E2E=true
bash scripts/stamp_web_release.sh build/web "$(git rev-parse HEAD)" e2e
bash scripts/verify_web_artifact.sh build/web / e2e "$(git rev-parse HEAD)"
cd e2e && npm ci && npm run typecheck
npm run test:simulation:responsive
```

The Simulation smoke now proves the UI → simulation gateway → repository/SQLite
message persistence → summary path, asserts no non-local provider request, and
captures Chromium/mobile Avatar Lab screenshots. The full browser suite
additionally requires a local browser and is intentionally not represented as
passing unless its command produces a real report.
