# Avatar V2

Avatar V2 is a self-hosted WebGL teacher runtime. It is intentionally split
into an independently testable web lab and a thin Flutter host bridge.

## Stack

- Three.js + `GLTFLoader` render a local glTF/GLB character.
- `@met4citizen/talkinghead` provides animation blending, gaze, blink,
  breathing, emotion/mood control, and semantic gesture playback.
- `@met4citizen/headaudio` extracts audio-driven Oculus visemes in the lab and
  in the production iframe. Flutter forwards the exact encoded TTS bytes plus
  the native playback start clock; synthetic amplitude is only a fallback.
- The bundled `mpfb.glb` is the CC0 MakeHuman/MPFB character supplied by the
  TalkingHead project. No Ready Player Me URL, CDN model, iframe evaluation,
  or paid avatar service is required.

## Run the lab

```bash
cd tools/avatar-v2-lab
npm install
npm run dev
```

The lab uses a real local WAV file and exposes controls for state, emotion,
gesture timeline, interruption, camera gaze, and idle variation. Production
runtime assets are generated with:

```bash
npm run build:runtime
```

## Flutter integration

Flutter chat uses 3D as the primary renderer. `AvatarStage` forwards the
encoded TTS bytes, playback clock and optional native viseme timeline to the
WebGL host; text visemes and amplitude remain final fallbacks when audio
analysis is unavailable. The web host validates both message origin and
iframe source before accepting commands. On Flutter Web the iframe is served
from `assets/assets/3d/avatar.html`; the model and worklet are bundled under
the same asset tree.

## Quality boundary

The runtime now supports film-like motion primitives and can accept a more
cinematic authored GLB without changing the bridge. The included free CC0
character is a high-quality prototype asset, not a MetaHuman-level film asset.
Reaching true CG/3A character fidelity requires a separately authored,
optimized character with facial blendshapes, hair/cloth simulation, and
production motion capture; the runtime is ready for that asset replacement.

## Notices

See [`assets/3d/vendor/THIRD_PARTY_NOTICES.md`](../assets/3d/vendor/THIRD_PARTY_NOTICES.md)
for licenses and asset attribution.
