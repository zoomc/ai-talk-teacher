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
- The bundled `rocketbox-female-01.glb` is a self-hosted Microsoft Rocketbox
  female character under MIT, converted from the facial FBX with 176 facial
  targets, 15 visemes and 52 ARKit names. No Ready Player Me URL, CDN model,
  iframe evaluation, or paid avatar service is required.
- The asset pipeline is reproducible with `scripts/convert-rocketbox.py` and
  `scripts/rebind-rocketbox.mjs`; the latter normalizes the glTF armature and
  inverse bind matrices for Three.js skinning.

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

The included Rocketbox character is a materially stronger human-CG prototype
than the previous cartoon fallback, with real PBR textures, facial targets and
local audio lip sync. It is still not a MetaHuman/film-level asset: reaching
that bar requires an authorized high-resolution character with authored
hair/cloth, eyes/skin shaders and production motion capture. Generic
TalkingHead hand clips are intentionally not applied because their authored
bone axes do not match Rocketbox; the current semantic gesture timeline uses
safe gaze/emotion cues until a retargeted body-motion set is added.

## Notices

See [`assets/3d/vendor/THIRD_PARTY_NOTICES.md`](../assets/3d/vendor/THIRD_PARTY_NOTICES.md)
for licenses and asset attribution.
