# Avatar V2 runtime notices

- `vendor/talkinghead/` — TalkingHead 1.7.0, MIT, by Mika Suominen.
- `vendor/headaudio/` — HeadAudio 0.1.0, MIT, by Mika Suominen.
- `vendor/three/` — Three.js 0.180.0, MIT, by Three.js authors.
- `avatar-v2/rocketbox-female-01.glb` — derived from Microsoft Rocketbox
  `Female_Adult_01_facial.fbx`, MIT. Source: [Microsoft-Rocketbox](https://github.com/microsoft/Microsoft-Rocketbox)
  (the repository's MIT license and attribution apply); the GLB is converted
  and self-hosted by `tools/avatar-v2-lab/scripts/convert-rocketbox.py` and
  `rebind-rocketbox.mjs`.

The Avatar V2 runtime is self-hosted. It does not call Ready Player Me,
TalkingHead CDN, or any paid avatar service at runtime.
