# Simulation assets

These manifests describe business events for the compile-time `APP_MODE=demo`
and `APP_MODE=e2e` builds. The Dart `Simulation*Gateway` consumes the same
fixture contract and persists its results through the normal ChatRepository,
Correction, Summary, and Review flows.

The Demo speech path generates a small, valid PCM WAV locally from the fixture
text. It is deterministic, has no external voice or API license, and is
paired with a deterministic viseme timeline and amplitude envelope. Production
never loads this directory at runtime.

Fixtures included: happy path, grammar correction, no correction, three-turn
conversation, interruption, slow stream, empty STT, retry, TTS failure,
avatar failure fallback, review loop, and summary loop.
