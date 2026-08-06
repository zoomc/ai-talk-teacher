# SpeakFlow Online Demo Review — 2026-08-06

## Scope

- Production: `https://zoomlab.top/talk/`
- Demo: `https://zoomlab.top/talk-demo/`
- Release currently online at review start: `7e3d25f` / `1.0.5+6`

## Findings and disposition

| Area | Observation | Disposition |
| --- | --- | --- |
| Production reachability | Production returned HTTP 200 and exposed `version.json`. | Passed before and after release verification. |
| Demo protection | Demo returned HTTP 401 with the expected `SpeakFlow Demo` Basic Auth challenge and `noindex` headers. The local browser session did not have demo credentials, so interactive browser assertions were not used for the protected page. | Deployment health check is the authoritative authenticated check; it validates 401 without credentials, authenticated HTML/assets, version SHA, and `noindex`. |
| Tutor identity | Home selected Emma, while Chat initially fell back to `AI Tutor`. | Chat now uses the same default tutor identity as Home. |
| Empty chat CTA | “Start conversation” did not enter a usable flow when voice was unavailable. | CTA now routes to service configuration when voice is not configured, otherwise starts recording. |
| Quick suggestions | Empty-state suggestion chips did not submit a real turn. | Suggestions now populate and send the message through the normal chat path; HP-0 regression coverage added. |
| E2E mocked LLM | Per-test LLM overrides were ignored by the simulation gateway, so emotion assertions received the generic fixture reply. | Gateway now honors the latest matching E2E override while preserving the deterministic fixture fallback. |
| 2D human tutor | Hair was drawn over the face, the default chat avatar was inconsistent, and the fallback lacked clear layered motion/viseme wiring. | Hair/face layer order, avatar identity propagation, body/skin gradients, female hair silhouette, idle motion, emotion state, and Rhubarb viseme timeline rendering were corrected. |
| Scenario labels | General/career categories and the “all levels” difficulty appeared as raw i18n keys in the Chinese scenario list. | Added the missing labels for all supported locales. |
| Review empty state | Empty review content mixed English copy into the Chinese UI; the populated review header also contained hardcoded English. | Localized empty-state, AI review, recent-count, rating guidance, and rating feedback copy. |
| Settings copy | Correction strength showed `Moderate` in Chinese; low-bandwidth/About copy still referred to a 3D tutor. | Uses localized strength labels and updated copy to describe the current 2D tutor. |
| Tutor selection | The tutor picker was entirely English in the Chinese app, including the selected snackbar. | Localized the page headings, styles, tutor descriptions, and selection feedback for Chinese/English. |
| Projects empty state | Mobile showed both an inline “new project” button and a floating “new project” button. | Hide the FAB when the list is empty; keep the centered primary CTA. |

## Verification evidence

- `flutter test`: 266 tests passed.
- `flutter analyze --no-fatal-infos`: passed; only existing info-level notices remain.
- `npm run typecheck`: passed.
- `npm run test:simulation:responsive`: 4/4 passed on Chromium and mobile Chromium.
- E2E simulation must be built with `APP_MODE=e2e` and `E2E=true`; that CI-equivalent build passed the same 4/4 responsive cases.
- Avatar emotion HP-1–HP-5: 5/5 passed.
- Avatar lip-sync HP-1–HP-5: 5/5 passed.
- Avatar idle/mobile HP-1–HP-4 and HP-26–HP-28: 14/14 passed.
- Dependency and asset license evidence check: passed.
- Production and Demo web artifact stamping/verification: passed locally with their respective base paths and modes.

## Release note

The fallback teacher remains an asset-free layered 2D renderer, with procedural breathing/blinking/body sway and timeline-driven mouth visemes. A production Live2D model would require separately licensed model assets; this review therefore validates the current deterministic renderer and its online delivery path.
