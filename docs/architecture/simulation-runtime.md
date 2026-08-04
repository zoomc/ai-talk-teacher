# Simulation runtime and fixtures

Simulation is an executable runtime, not a collection of HTTP stubs. The same
`ChatScreen`, `ChatRepository`, correction parser, TTS playback/cache path, review
queue, summary route, and AvatarStage are used in Production and Simulation. Only
the gateway implementation changes at compile time.

`SimulationRuntime` supplies deterministic STT text, streamed LLM chunks, optional
corrections, timing, TTS failure, and local PCM WAV bytes. Viseme timelines are
generated from the same text so the avatar can be tested without a provider or a
checked-in third-party recording.

Available fixtures are listed in `assets/simulation/manifests/` and selectable from
the Demo banner:

`happy_path`, `grammar_correction`, `no_correction`, `multi_turn`,
`interruption`, `slow_stream`, `stt_empty`, `llm_retry`, `tts_failure`,
`avatar_failure`, `review_loop`, and `summary_loop`.

The JSON manifests are reviewable fixture contracts. The Dart fixture catalog is
the executable source used by the gateways; a manifest change is incomplete until
its corresponding business behavior and test are updated.

## Failure semantics

- `llm_retry` fails once with a transient `LlmException`; the existing retry path
  must recover without duplicating a message or advancing the turn twice.
- `interruption` and `slow_stream` keep the stream open long enough to exercise the
  one-click interrupt path and stale callback guards.
- `stt_empty` produces the same empty-transcript UI used after a real STT call.
- `tts_failure` keeps the readable assistant message and reports audio failure.
- `avatar_failure` verifies that chat remains usable when the optional renderer is
  unavailable; the layered 2D painter is the fallback.
- `review_loop` and `summary_loop` exercise persistence into review and the final
  summary route rather than returning a test-only screen.
