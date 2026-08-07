# Avatar V2 local lab

This is an independent Web playground for the Avatar V2 runtime. It does not
boot Flutter, the API gateway, an AI key, or the production chat flow.

```bash
npm install
npm run dev
```

The lab uses the self-hosted Microsoft Rocketbox female GLB (MIT), TalkingHead
for GLB animation, expression and eye contact, and HeadAudio for audio-driven
Oculus viseme inference. The Rocketbox facial FBX is converted with
`scripts/convert-rocketbox.py`, then normalized with
`scripts/rebind-rocketbox.mjs`; the latter repairs inverse bind matrices for
Three.js skinning. The speech sample is a local WAV so the mouth clock is the
actual audio playback clock rather than a character timer.

Rocketbox's authored arm axes are not compatible with TalkingHead's generic
Mixamo hand clips, so semantic gesture controls currently use safe gaze and
emotion timelines instead of malformed limb motion.

The runtime is deliberately exercised here before the Flutter iframe bridge is
changed. Once this page passes visual and interaction review, the same runtime
boundary is integrated through the typed `postMessage` protocol.
