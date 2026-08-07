# Avatar V2 local lab

This is an independent Web playground for the Avatar V2 runtime. It does not
boot Flutter, the API gateway, an AI key, or the production chat flow.

```bash
npm install
npm run dev
```

The lab uses a self-hosted MPFB/MakeHuman GLB (CC0), TalkingHead for GLB
animation, expression, eye contact and gesture blending, and HeadAudio for
audio-driven Oculus viseme inference. The speech sample is a local WAV so the
mouth clock is the actual audio playback clock rather than a character timer.

The runtime is deliberately exercised here before the Flutter iframe bridge is
changed. Once this page passes visual and interaction review, the same runtime
boundary is integrated through the typed `postMessage` protocol.
