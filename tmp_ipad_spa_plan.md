# SpeakFlow — iPhone/iPad Adaptation + SPA Plan

> Temporary planning doc. Will be deleted at the end of the task;
> the permanent record goes into `projects.md` and `CHANGELOG.md`.

## Part A — iPhone / iPad Responsive Audit

Breakpoints (current): compact `<600dp`, medium `600–1239dp`, expanded `≥1240dp`.
`isMobile <600`, `isWide ≥900`. No `OrientationBuilder` anywhere yet.

### A.1 Cross-cutting issues
1. **No orientation-driven layouts.** iPhone landscape (375–414pt wide, ~390pt tall)
   is treated identically to iPhone portrait. Breaks chat density + placement.
2. **No text-scaling guards.** `displayLarge` titles overflow fixed-height containers
   (scenario cards 184pt, activity chart 140pt) under iOS accessibility scaling.
3. **SafeArea missing on 5 screens** (progress, history, tutor_selection,
   service_config, profile_form) — bottom content hides behind the home indicator.
4. **iPad whitespace**: `contentMaxWidth` is 640 (medium) / 920 (expanded). On
   iPad landscape 1024pt with 72pt rail → ~311pt dead whitespace.
5. **No master-detail / split-view** anywhere — iPads render single-column.

### A.2 Per-screen must-fix items

| # | File | Issue | Fix |
|---|------|-------|-----|
| 1 | `chat_screen.dart` (157, 202–229) | iPhone landscape: character panel eats the screen (~110pt chat visible) | Use `OrientationBuilder` + height check; hide panel when `height < 480` |
| 2 | `chat_screen.dart` (976–979) | Listen button `minHeight: 36` < 44pt iOS min | `minHeight: 44` |
| 3 | `home_screen.dart` (349–364) | `_QuickActionGrid` uses full screen width → broken on tablet (collapses to fewer columns) | `LayoutBuilder` constraints.maxWidth |
| 4 | `home_screen.dart` (190–219) | Stats Row clips on iPhone SE with large numbers | Wrap/Flexible |
| 5 | `review_screen.dart` (109–136) | Header Row overflow on compact (title Column + AI Review button) | Wrap Column in Flexible |
| 6 | `review_screen.dart` (300–369) | Correction card badge Row overflow | Use Wrap for badges |
| 7 | `review_screen.dart` (455–466) | Rating bar `height: 36` ×4 buttons < 44pt min | height 44, drop shrinkWrap |
| 8 | `scenarios_screen.dart` (108–109) | Fixed `SizedBox(height: 184)` can clip with long names + stats | Responsive height 180–220 |
| 9 | `progress_screen.dart` (29–44) | No SafeArea bottom — button hides behind home indicator | `SafeArea(top: false, bottom: true)` |
| 10 | `progress_screen.dart` (67–109) | Two 2-col stat Rows clip on iPhone SE | Stack to 1-col on compact |
| 11 | `progress_screen.dart` (expanded) | iPad under-utilization — stays 2-col on 1366pt | Scale stat columns with breakpoint |
| 12 | `history_screen.dart` (121–126) | No SafeArea bottom | Add SafeArea |
| 13 | `tutor_selection_screen.dart` (64–69) | No SafeArea bottom | Add SafeArea |
| 14 | `tutor_selection_screen.dart` (expanded) | Single column on iPad — 6 tutors fit 2-col grid | 2-col grid on expanded |
| 15 | `onboarding_screen.dart` (231–338) | No `viewInsets.bottom` in scroll padding — keyboard hides Next button | Add keyboard inset |
| 16 | `placement_screen.dart` (64–162) | No max-width — stretches edge-to-edge on iPad | `Center(ConstrainedBox(maxWidth: contentMaxWidth))` |
| 17 | `placement_screen.dart` (landscape phone) | Title + 5 option cards overflow short height | Reduce title size in landscape, scrollable column |
| 18 | `service_config_screen.dart` (54–65) | No SafeArea bottom | Add SafeArea |
| 19 | `service_config_screen.dart` (expanded) | Single column on iPad | 3-col section grid on expanded |
| 20 | `profile_form_screen.dart` (186–231) | No SafeArea bottom + no keyboard inset | SafeArea + viewInsets padding |
| 21 | `app_router.dart` MainShell (140–147) | `contentMaxWidth` 640 on 1024pt tablet → ~311pt dead space | Introduce tablet-tier max width (~880) |
| 22 | `app_router.dart` MainShell (253, 259) | Nav rail no bottom SafeArea padding | `SafeArea(top: false)` around rail |

### A.3 Orientation-driven layout strategy
- **chat_screen**: 3 regimes — (a) phone portrait → stacked panel (height ~140), 
  (b) phone landscape → hide panel / 40pt status strip, (c) tablet/desktop → 
  side-by-side (current wide path). Trigger: `isWide || (landscape && width >= 700)`.
- **placement_screen**: In landscape phone, drop title from `displayLarge` to 
  `headlineMedium` and make the column scrollable.
- **home_screen stats**: In landscape phone, switch to a 4-col grid (1×4) or 2×2.
- **iPad portrait**: Lower the side-by-side threshold to `width >= 768` so all
  iPads get split-view even in portrait (768pt is enough for 280pt panel + 487pt chat).

---

## Part B — SPA / PWA Plan

### B.1 PWA manifest upgrades (`web/manifest.json`)
- Real `name` / `short_name` ("SpeakFlow" / "SpeakFlow").
- Correct `theme_color` / `background_color` to deep-space-blue (#0A0E1A) 
  matching the dark theme.
- Add `display: "standalone"`, `display_override: ["window-controls-overlay", "standalone"]`.
- `orientation: "any"` (was `portrait-primary` — the app adapts to both).
- `categories`, `lang`, `dir`, `scope`, `id`.
- Screenshots + richer icons (already have 192/512 + maskable).
- Add `shortcuts` (Free Talk, Review, Scenarios) for installed-app quick actions.

### B.2 `web/index.html` upgrades
- Real `<title>` and `<meta name="description">`.
- Apple touch icon + apple-mobile-web-app-* meta tags (already partial).
- `viewport` with `viewport-fit=cover` for notch / Dynamic Island.
- Theme-color meta that matches dark/light.
- Loading splash that matches the brand while `flutter_bootstrap.js` loads
  (so the first paint isn't a white screen — feels like a real SPA).
- Inline a tiny script that registers the service worker **before** Flutter
  boots, so the SW is in control for the very first navigation.

### B.3 Service worker / offline cache
Flutter web's default service worker (`flutter_service_worker.js`, emitted by
`flutter build web`) already does:
- App shell precache (all JS/CSS/fonts/assets) by hash.
- Cache-first for hashed assets, network-first for `index.html` + `manifest.json`.

We will:
1. Verify the SW is registered (the default `flutter_bootstrap.js` registers
   it only when `ServiceWorkerConfiguration` is enabled — we must enable it in
   `lib/main.dart` via `flutter.js` initialization with serviceWorker config).
2. Keep `flutter build web --pwa=on` semantics. The current index.html loads
   `flutter_bootstrap.js` async — this is the modern path that DOES register
   the SW. Good. We just need to make sure the build is invoked so the SW is
   generated.
3. Add a small `web/sw.dart`-side companion? No — Flutter generates the SW.
   We'll trust Flutter's SW for app-shell caching, and additionally cache the
   **manifest + version.json** (see B.4) ourselves with a 2-line inline script
   in index.html so the version check works even before Flutter boots.

### B.4 Version check + update mechanism
Approach: ship a `version.json` next to `index.html` on the server. The
client (a Dart `VersionService` + a small JS bridge for the SW update) polls
it on app start + every 5 minutes.

`web/version.json` (generated at build time, written by a build hook):
```json
{ "version": "1.0.0+1", "buildTime": "2026-07-05T10:00:00Z", "commit": "abc1234" }
```

Client flow (`lib/core/services/version_service.dart`):
1. On app start, fetch `/version.json?ts=<cache-buster>`.
2. Compare `version` with the bundled `appVersion` (from
   `pubspec.yaml`'s `version: 1.0.0+1`, exposed via
   `package_info_plus` or a hard-coded constant since we don't have
   package_info_plus in deps — we'll hard-code from pubspec at build time
   via a `--dart-define`).
3. If server version > bundled version, set
   `newVersionAvailableProvider` = true. Show a non-blocking banner
   ("A new version is available — tap to update").
4. On tap: call `window.location.reload(true)` (force reload). The SW
   will detect a new app-shell on the next load and activate.
5. As a fallback, if a new SW is waiting (the SW's `controllerchange`
   event), show the same banner — covers the case where the version
   string wasn't bumped but the SW detected new hashed assets.

We need a tiny JS bridge (`web/version_check.js`) that:
- Listens for the SW's `updatefound` / `controllerchange` events and
  posts a message to the Dart side via `js_interop`.
- Exposes `forceReload()` that does `location.reload()`.

Dart side uses `dart:js_interop` to call into the bridge. This keeps the
mechanism real (not a stub) and working in any browser that supports SWs.

### B.5 Install guidance (Add to Home Screen / install prompt)
- `web/install_prompt.js`: captures `beforeinstallprompt` (Chrome/Edge/Android),
  stashes the event, exposes `canInstall()` and `promptInstall()` to Dart.
- iOS Safari doesn't fire `beforeinstallprompt` — detect iOS Safari via UA
  and show a custom banner with "Share → Add to Home Screen" instructions
  (the standard iOS pattern).
- Dart side: `lib/core/services/install_prompt_service.dart` exposes
  `installAvailabilityProvider` and `promptInstall()`. The banner is shown
  by a top-level widget (`_InstallBanner`) inserted above `MaterialApp.router`
  in `main.dart`, gated by a `hasDismissedInstall` preference (don't nag).
- The banner shows after the user has used the app for 30 seconds AND the
  app is not already installed (`display-mode: standalone` media query).
- iOS detection: `window.navigator.standalone` (legacy) + the
  `display-mode: standalone` CSS media query (modern).

### B.6 Offline UX
- The app already works offline for cached data (SQLite, settings) — the
  only network needs are LLM/STT/TTS calls. When offline:
  - The chat input bar shows a "You're offline — voice & AI replies are
    unavailable" hint (gated by `ConnectivityResult` from a small
    `connectivity_check.dart` using `dart:html`'s `navigator.onLine` — we
    won't add a new package, just use the browser API).
  - Review / History / Progress / Settings / Scenarios all work fully
    offline (they're SQLite-only).
- This is "best-effort" offline that matches the user's "像本子一样" intent:
  everything that *can* be offline *is* offline.

---

## Part C — Implementation Order

1. **Foundation** — extend `Responsive` with orientation helpers + tablet-tier
   max widths; add `AppSpacing`/`AppRadius` token for tap-target min.
2. **Per-screen fixes** — work through table A.2 in order.
3. **PWA scaffolding** — manifest + index.html + SW verification.
4. **Version service + bridge** — `version.json`, `version_check.js`,
   `VersionService.dart`, `_UpdateBanner`.
5. **Install prompt** — `install_prompt.js`, `InstallPromptService.dart`,
   `_InstallBanner`.
6. **Offline UX** — connectivity check + chat offline hint.
7. **3 review rounds** — UI/interaction polish, each round a separate pass.
8. **Test** — `flutter analyze` + `flutter test` + `flutter build web --release`.
9. **Docs** — update `projects.md` + `CHANGELOG.md`.
10. **Cleanup** — delete all `tmp_*.md` files, commit, merge, push.

---

## Part D — Verification Checklist (run before commit)

- [ ] `flutter analyze` — 0 errors / 0 warnings
- [ ] `flutter test` — all tests pass
- [ ] `flutter build web --release` — succeeds
- [ ] Manually verify (in build/web):
  - [ ] manifest.json is valid PWA manifest
  - [ ] service worker registers
  - [ ] version.json is served
  - [ ] offline: open app, disconnect network, navigate Review/History/Settings (must work)
  - [ ] iPhone SE portrait (375×667): no overflow
  - [ ] iPhone 13 landscape (844×390): chat hides character panel
  - [ ] iPad mini portrait (768×1024): split-view chat
  - [ ] iPad Pro landscape (1366×1024): uses full width, no dead space
