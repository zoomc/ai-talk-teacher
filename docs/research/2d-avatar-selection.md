# 2D avatar selection

Decision: ship a layered Flutter 2D upper-body tutor as the default renderer, keep
the existing 3D/GLB path as an experimental comparison, and do not bundle an
unlicensed Live2D model.

The 2D implementation in `layered_tutor_avatar.dart` uses independent painter
parts for body, shirt/collar, arms, neck/head, hair, eyes/iris/lids, brows, cheeks,
and mouth. `AvatarStage` merges idle, emotion, gesture, and viseme parameters before
painting. When Rhubarb data is absent, amplitude or text-driven viseme fallback
still animates the mouth. When a timeline exists, its cues are mapped through the
shared Rhubarb table.

## Comparison

| Option | Decision | Reason |
|---|---|---|
| Layered Flutter 2D | Default | deterministic, legal-by-construction local code, low memory, no CDN/GPU |
| Three.js + GLB | Experimental | already integrated, but asset license/CORS/offline/mobile evidence is incomplete |
| Live2D Cubism | Future optional | requires model/Core/binding and distribution rights not present here |
| Generated video/avatar service | Excluded | ongoing cloud/GPU cost and weaker interruption/offline behavior |

The hidden `/lab/avatar` route covers idle/listening/thinking/speaking, seven
emotions, reduce-motion behavior, 2D/3D comparison, and deterministic viseme
application. It is compiled into Demo/E2E only.
