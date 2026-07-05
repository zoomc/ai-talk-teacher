# SpeakFlow — Round 3 (Final) UI / Interaction / Overall-Quality Review

> Review date: 2026-07-05
> Scope: iPhone/iPad responsive edge cases, SPA/PWA code quality, Settings integration, routing/banner suppression, build configuration.
> Focus: REAL issues that affect users. Pre-existing info-level lints and stylistic preferences are intentionally excluded.
> Each finding is tagged **Regression** (from Round 1/2 work) or **Pre-existing**.

---

## HIGH severity

### H1 — `GoRouterState.of(context)` called from outside `MaterialApp.router` (route-aware banner suppression may throw)
- **File**: `lib/shared/widgets/app_banners.dart:64`
- **Regression / Pre-existing**: Pre-existing (logic was added in Round 1/2 banner-occlusion work)
- **Issue**: `AppBanners` wraps `MaterialApp.router` from the outside (`lib/main.dart:65-74`):

  ```dart
  return AppBanners(
    child: MaterialApp.router(
      routerConfig: AppRouter.router,
      ...
    ),
  );
  ```

  Inside `_AppBannersState.build`:
  ```dart
  final route = GoRouterState.of(context).uri.path;
  final hiddenRoute = _kHiddenRoutes.any(route.startsWith);
  ```

  `GoRouterState.of(context)` requires being inside the router's widget subtree (it uses `InheritedGoRouter`, which `MaterialApp.router` only provides *below* itself). Called from `AppBanners` — which is *above* `MaterialApp.router` — it should throw `GoRouterState.of must be called within a GoRouterState` (debug assert) / `NoSuchMethodError` on `null` (release).
- **Impact**: If this truly throws, the entire app crashes on first build. The fact that Round 1/2 reviews were performed suggests one of:
  1. go_router 14.8.1 silently returns a default/empty state from `of(context)` when not found (please verify),
  2. the banners never become visible in the test environment so the build path is exercised but `route` ends up empty and `route.startsWith` is called on `""` — but `GoRouterState.of` still runs unconditionally,
  3. there is a try/catch elsewhere swallowing it.
- **Suggested fix** (whichever applies):
  ```dart
  // Option A: use maybeOf (available in go_router 14.x)
  final route = GoRouterState.maybeOf(context)?.uri.path ?? '';

  // Option B: move AppBanners inside MaterialApp.router's builder
  MaterialApp.router(
    builder: (context, child) => AppBanners(child: child!),
    ...
  )
  ```
- **Action**: Verify in a real web build whether this throws. If it does, this is a startup crash.

---

### H2 — Double keyboard inset in chat input bar (text field floats ~340pt above keyboard)
- **File**: `lib/features/chat/presentation/screens/chat_screen.dart:1175-1185` (and `:214`)
- **Regression / Pre-existing**: Likely regression or incomplete fix — the Round 1/2 list says "double keyboard insets" was fixed, but `chat_screen.dart` still exhibits the pattern. The fix appears to have been applied only to `onboarding_screen.dart:231-237` (which now uses plain `AppSpacing.xl`).
- **Issue**: The Scaffold has `resizeToAvoidBottomInset: true` (line 214), so the body is shrunk by `MediaQuery.viewInsets.bottom` when the soft keyboard opens. The input bar *additionally* adds the same `viewInsets.bottom` as bottom padding:

  ```dart
  final viewInsets = MediaQuery.of(context).viewInsets.bottom;
  final safeBottom = MediaQuery.of(context).padding.bottom;
  final bottomPad = viewInsets > 0 ? viewInsets : safeBottom + AppSpacing.md;
  return Container(
    padding: EdgeInsets.only(
      left: AppSpacing.md, right: AppSpacing.md,
      top: AppSpacing.sm, bottom: bottomPad,
    ),
    ...
  );
  ```

  Net effect when keyboard is open (e.g. `viewInsets.bottom = 336`):
  - Scaffold shrinks body by 336pt → input bar's bottom edge sits at top of keyboard.
  - Input bar's Container then adds 336pt of *internal* bottom padding → the actual Row (mic/text/send) is pushed ~336pt up inside the input bar.
  - Result: text field floats ~336pt above the keyboard with a large empty gap below it.
- **Suggested fix**: Let `resizeToAvoidBottomInset: true` do the work and only add safe-area padding when the keyboard is closed:
  ```dart
  // SafeArea(top:false) above already consumes padding.bottom, so this is 0
  // when keyboard is closed.
  final bottomPad = safeBottom + AppSpacing.md;
  ```
  …or set `resizeToAvoidBottomInset: false` and keep the manual `viewInsets` handling (but not both).

---

### H3 — `favicon.png` / `favicon.svg` referenced in `index.html` but not shipped
- **File**: `web/index.html:42-43`
- **Regression / Pre-existing**: Pre-existing
- **Issue**:
  ```html
  <link rel="icon" type="image/png" href="favicon.png"/>
  <link rel="icon" type="image/svg+xml" href="favicon.svg"/>
  ```
  Neither file exists in `web/` (only `web/icons/Icon-192.png`, `Icon-512.png`, `Icon-maskable-*.png` exist). Browsers will issue 404s for both, leaving the tab with no favicon.
- **Suggested fix**: Either add `web/favicon.png` and `web/favicon.svg`, or repoint to an existing asset:
  ```html
  <link rel="icon" type="image/png" href="icons/Icon-192.png"/>
  <link rel="apple-touch-icon" href="icons/Icon-192.png"/>
  ```

---

### H4 — Tutor selection does not refresh chat screen's `_tutorName` / `_tutorAvatar`
- **File**: `lib/features/chat/presentation/screens/chat_screen.dart:166` and `:91-107`
- **Regression / Pre-existing**: Incomplete P0-3 fix from Round 1/2 — persistence was added (`tutor_selection_screen.dart:41` writes `selected_tutor_id`), but the chat screen never reloads after returning.
- **Issue**:
  ```dart
  IconButton(
    tooltip: 'Pick a tutor',
    icon: const Icon(Icons.swap_horiz),
    onPressed: () => context.push('/tutor-selection'),
  ),
  ```
  `_loadTutorIdentity()` is called only from `initState` (line 61). After the user picks a new tutor and pops back, the AppBar title and `_CharacterPanel` still show the *old* tutor — the user thinks their selection didn't take effect.
- **Suggested fix**:
  ```dart
  onPressed: () async {
    await context.push('/tutor-selection');
    if (mounted) _loadTutorIdentity(); // re-read selected_tutor_id + setState
  },
  ```

---

## MEDIUM severity

### M1 — PWA manifest shortcuts use `/?action=...` but the router ignores the `action` query parameter
- **File**: `web/manifest.json:43-64` + `lib/core/router/app_router.dart:52-117`
- **Regression / Pre-existing**: Pre-existing (shortcuts were added in the SPA/PWA work)
- **Issue**: Manifest declares:
  ```json
  { "name": "Free Talk", "url": "/?action=free-talk" },
  { "name": "Review", "url": "/?action=review" },
  { "name": "Scenarios", "url": "/?action=scenarios" }
  ```
  But `AppRouter` has no `redirect`/`builder` that reads `state.uri.queryParameters['action']`. Tapping a shortcut from the installed app's launcher just opens the home screen — the "shortcut" is a no-op.
- **Suggested fix**: Add a redirect that maps the action to a real route:
  ```dart
  redirect: (context, state) async {
    final action = state.uri.queryParameters['action'];
    if (action == 'free-talk') return null; // home handles via _startNewSession
    if (action == 'review') return '/review';
    if (action == 'scenarios') return '/scenarios';
    // ...existing onboarding/placement redirects...
  },
  ```
  (For `free-talk`, the home screen would also need to detect the param and auto-start a session, or the shortcut could deep-link to a new `/chat/new` route.)

---

### M2 — `statsProvider` in ProgressScreen is never invalidated → stale stats after reviewing
- **File**: `lib/features/chat/presentation/screens/progress_screen.dart:10-12`
- **Regression / Pre-existing**: Pre-existing
- **Issue**: `statsProvider` is a `FutureProvider` created once. After the user rates corrections on `ReviewScreen` and navigates to `ProgressScreen`, the cached stats are shown (masteredCount, dueForReview don't update). The user has to manually reload.
- **Suggested fix**: Invalidate on screen entry, or convert to `AsyncNotifier`:
  ```dart
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Refresh on every entry — stats are cheap and correctness matters here.
    ref.invalidate(statsProvider);
    final statsAsync = ref.watch(statsProvider);
    ...
  }
  ```

---

### M3 — `ScenariosScreen._loadStats` runs only in `initState` → stale "Practiced N times" after returning from chat
- **File**: `lib/features/chat/presentation/screens/scenarios_screen.dart:25-41`
- **Regression / Pre-existing**: Pre-existing
- **Issue**: `_loadStats()` is called once in `initState`. After the user practices a scenario (which creates a session), returns to Scenarios, the count and "last practiced" don't update.
- **Suggested fix**: Re-run on `didChangeAppLifecycleState` (resume) or use a Riverpod provider for `scenarioStatsProvider` and invalidate it on screen entry.

---

### M4 — `ReviewScreen._loadCorrections` runs only in `initState` → stale list after new corrections are saved in chat
- **File**: `lib/features/chat/presentation/screens/review_screen.dart:19-41`
- **Regression / Pre-existing**: Pre-existing
- **Issue**: New corrections are saved during chat (`chat_screen.dart:391-398`). When the user navigates to Review, the list reflects whatever was loaded the *first* time ReviewScreen was built. If ReviewScreen was kept alive in the shell, the list is stale.
- **Suggested fix**: Convert to a Riverpod `FutureProvider` family and invalidate on entry, or call `_loadCorrections()` from `didChangeDependencies` / a `routeObserver`.

---

### M5 — Background gradient is inside `ConstrainedBox` on 5 screens → bare scaffold sides on iPad
- **Files**:
  - `lib/features/chat/presentation/screens/progress_screen.dart:36-50`
  - `lib/features/chat/presentation/screens/history_screen.dart:126-132`
  - `lib/features/chat/presentation/screens/scenarios_screen.dart:59-61`
  - `lib/features/settings/presentation/screens/settings_screen.dart:73-75`
  - `lib/features/chat/presentation/screens/tutor_selection_screen.dart:68-74`
- **Regression / Pre-existing**: Pre-existing
- **Issue**: Pattern is `Center > ConstrainedBox(maxWidth: 880/1040) > Container(decoration: gradientBg) > content`. On iPad landscape (1366pt) the gradient only spans ~1040pt in the middle, leaving ~160pt of bare `AppColors.bgPrimary` on each side. Visually inconsistent — the brand gradient reads as a centered card rather than the app background.
- **Suggested fix**: Move the gradient to the Scaffold's `backgroundDecoration` (or wrap the *whole* body in the gradient Container, then constrain the inner content):
  ```dart
  return Scaffold(
    body: Container(
      decoration: const BoxDecoration(gradient: AppColors.gradientBg),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth(context)),
            child: /* actual content */,
          ),
        ),
      ),
    ),
  );
  ```

---

### M6 — `Inter` font declared in `AppTextStyles` but not bundled → silent fallback to system sans-serif
- **Files**: `lib/core/theme/app_text_styles.dart:4` + `pubspec.yaml`
- **Regression / Pre-existing**: Pre-existing P1 from Round 2 (still not fixed)
- **Issue**: `static const String _fontFamily = 'Inter';` is applied to every text style, but `pubspec.yaml` has no `fonts:` section and no `google_fonts` dependency. Result: every text silently renders in the system sans-serif (San Francisco on iOS, Roboto on Android, etc.), and the brand's "Inter / SF Pro" spec is not actually applied.
- **Suggested fix**: Add Inter to `pubspec.yaml`:
  ```yaml
  flutter:
    fonts:
      - family: Inter
        fonts:
          - asset: assets/fonts/Inter-Regular.ttf
          - asset: assets/fonts/Inter-Medium.ttf
            weight: 500
          - asset: assets/fonts/Inter-SemiBold.ttf
            weight: 600
          - asset: assets/fonts/Inter-Bold.ttf
            weight: 700
  ```
  Or add `google_fonts: ^6.2.1` and call `GoogleFonts.config();` once at startup.

---

### M7 — All shell routes use `NoTransitionPage` → instant tab switches with no motion
- **File**: `lib/core/router/app_router.dart:67-84`
- **Regression / Pre-existing**: Pre-existing P1 from Round 2
- **Issue**: Every shell route uses `NoTransitionPage`, so switching between Practice / Scenarios / Review / Settings is a hard cut. The design spec (`docs/design-reference.md` §8.3) calls for 300ms slide/fade transitions between major destinations.
- **Suggested fix**: Replace `NoTransitionPage` with a `CustomTransitionPage` that does a 250-300ms fade + subtle slide.

---

### M8 — "Coming soon" placeholders in Settings act as fake entries
- **File**: `lib/features/settings/presentation/screens/settings_screen.dart:118-131` (Interface Language), `:154-165` (Export Learning Data)
- **Regression / Pre-existing**: Pre-existing P1 from Round 2
- **Issue**: Both tiles look like normal tappable settings but show a "coming soon" SnackBar on tap. Users perceive this as a bug, especially "Export Learning Data" which is a destructive-sounding affordance.
- **Suggested fix**: Either remove these tiles, or add a `Badge(label: 'Soon')` / `trailing: Text('Soon', style: overline)` and set `onTap: null` so they read as disabled.

---

### M9 — Raw error text shown to users (LLM/STT/TTS/load failures)
- **Files**:
  - `lib/features/chat/presentation/screens/chat_screen.dart:412` (`'Error: ${_safeError(e)}'`)
  - `lib/features/chat/presentation/screens/chat_screen.dart:797` (`Center(child: Text('Error: $e'))`)
  - `lib/features/chat/presentation/screens/scenarios_screen.dart:143` (`Center(child: Text('Error: $e'))`)
  - `lib/features/chat/presentation/screens/progress_screen.dart:46` (`Center(child: Text('Error: $e'))`)
- **Regression / Pre-existing**: Pre-existing P1 from Round 2
- **Issue**: Raw exception strings are surfaced to the user. `_safeError` truncates to 160 chars but still includes provider-specific text. The three `Center(child: Text('Error: $e'))` cases show the full exception (potentially including API keys in URL strings for some HTTP libs).
- **Suggested fix**: Replace with friendly copy + a Retry button:
  ```dart
  error: (e, _) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Something went wrong loading your data.'),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton(onPressed: () => ref.invalidate(scenariosProvider), child: const Text('Retry')),
      ],
    ),
  ),
  ```

---

### M10 — `activeSession.whenData` triggers a dialog from inside `build`
- **File**: `lib/features/chat/presentation/screens/home_screen.dart:39-50`
- **Regression / Pre-existing**: Pre-existing P1 from Round 2
- **Issue**:
  ```dart
  activeSession.whenData((session) {
    if (session != null && !_promptedForActiveSession && mounted) {
      _promptedForActiveSession = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showContinueDialog(session);
      });
    }
  });
  ```
  Side effects in `build` are a Riverpod anti-pattern — `activeSession` is watched so any provider invalidation re-runs this. The `_promptedForActiveSession` flag guards duplicate dialogs but the pattern is fragile.
- **Suggested fix**: Move to `ref.listen` in `initState` (or a `ConsumerStatefulWidget` `ref.listen` inside build with `ref.listen` semantics that only fires on change):
  ```dart
  ref.listen<AsyncValue<ChatSession?>>(activeSessionProvider, (prev, next) {
    next.whenData((session) {
      if (session != null && !_promptedForActiveSession && mounted) {
        _promptedForActiveSession = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showContinueDialog(session);
        });
      }
    });
  });
  ```

---

### M11 — `isIOSSafari()` doesn't exclude in-app browsers (Instagram, Facebook, LinkedIn)
- **File**: `web/install_prompt.js:65-81`
- **Regression / Pre-existing**: Pre-existing
- **Issue**: The detection regex `/^((?!CriOS|FxiOS|EdgiOS|OPiOS|GSA).)*Safari\//i` excludes Chrome/Firefox/Edge/Opera/GSA on iOS, but in-app browsers (Instagram `Instagram`, Facebook `FBAV`, LinkedIn `LinkedIn`) report Safari in their UA but cannot use the iOS "Add to Home Screen" flow meaningfully (they're inside a host app). The user gets the A2HS instructions sheet but tapping Share doesn't surface the host app's browser share sheet in a useful way.
- **Suggested fix**: Add in-app browser tokens to the exclusion list:
  ```js
  var isInAppBrowser = /Instagram|FBAV|LinkedIn|Snapchat|Twitter/i.test(ua);
  if (isInAppBrowser) return false;
  ```

---

### M12 — `onVisibilityChange` callback fires `checkNow()` AND creates a new polling timer that fires `checkNow()` again — redundant immediate double-check
- **File**: `lib/core/services/version_service.dart:122-135`
- **Regression / Pre-existing**: Pre-existing
- **Issue**:
  ```dart
  bridge.VersionBridge.onVisibilityChange((visible) {
    if (visible) {
      _pollTimer ??= Timer.periodic(_pollInterval, (_) => checkNow());
      // Also fire an immediate check on resume...
      checkNow();   // ← fires immediately
    } else {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  });
  ```
  Plus `onVisibilityChange` in `version_check.js:127-132` calls the callback *once with the current state* immediately on subscribe. So when the service subscribes, `checkNow()` runs from the immediate callback (line 130), and also from `_init()` line 120. On every tab refocus, the immediate callback fires `checkNow()` twice (once from line 130 in JS, once from line 130 in Dart).
- **Suggested fix**: Don't fire the callback once on subscribe in `version_check.js` — let the Dart side control cadence. Or guard in Dart with a `DateTime? _lastCheck` throttle (e.g. skip if checked within 30s).

---

## LOW severity

### L1 — Redundant `isNotEmpty` check on `serverVersion`
- **File**: `lib/shared/widgets/app_banners.dart:161-163`
- **Pre-existing**
- **Issue**: `(state.serverVersion != null && state.serverVersion!.isNotEmpty)` — but `VersionService.checkNow` already normalizes empty to null (`serverVersion: serverVersion.isEmpty ? null : serverVersion` on line 182). The `isNotEmpty` half can never be false when `!= null` is true.
- **Fix**: Collapse to `state.serverVersion != null`.

---

### L2 — Redundant `Center` + `ConstrainedBox` duplication between MainShell and individual screens
- **Files**: `lib/core/router/app_router.dart:139-147` (MainShell wraps in `Center > ConstrainedBox`) AND `lib/features/chat/presentation/screens/home_screen.dart:56-62`, `progress_screen.dart:36-41`, `history_screen.dart:126-130`, `tutor_selection_screen.dart:68-72`, `settings_screen.dart:75-77`, `service_config_screen.dart:65-73`
- **Pre-existing**
- **Issue**: MainShell already constrains body content to `contentMaxWidth`. Each screen then constrains again to the same value. Harmless (same value applied twice is a no-op), but it means changes to `contentMaxWidth` semantics must be made in two places.
- **Fix**: Pick one layer (preferably MainShell) and remove the inner constraint — or document why both are intentional.

---

### L3 — No `MediaQuery.accessibleNavigation` / reduce-motion handling anywhere
- **Files**: All animation sites — `home_screen.dart:86-88, 268`, `app_banners.dart:410-413`, `chat_screen.dart:1379 (record pulse), 855 (typing dots)`, `glass_widgets.dart (GlowButton pulse)`
- **Pre-existing** P2 from Round 2
- **Issue**: Users who enable "Reduce Motion" on iOS / macOS / Android still see full pulse, ripple, slide, and bounce animations.
- **Fix**: Read `MediaQuery.accessibleNavigation` (and/or `MediaQuery.disableAnimations`) at each animation site and either freeze the animation at its resting state or replace with a fade. A central `AnimatedSwitcher`-like helper would make this consistent.

---

### L4 — Emoji avatars use fixed font sizes that don't scale with text scaling
- **Files**: `lib/features/chat/presentation/screens/chat_screen.dart:183` (`fontSize: 20` for AppBar avatar), `lib/features/chat/presentation/screens/tutor_selection_screen.dart:209` (`fontSize: 36` for card avatar), `lib/features/chat/presentation/screens/scenarios_screen.dart:198` (`fontSize: 32` for scenario icon)
- **Pre-existing**
- **Issue**: iOS Dynamic Type / accessibility text scaling doesn't affect emoji, so a low-vision user scaling text to 200% still sees the avatars at their original size.
- **Fix**: Multiply by `MediaQuery.textScalerOf(context).scale(1.0)` (or just use `Theme.of(context).textTheme` sizes which auto-scale).

---

### L5 — Banner message `maxLines: 1` truncates long update text on iPhone SE (320pt)
- **File**: `lib/shared/widgets/app_banners.dart:386-396`
- **Pre-existing**
- **Issue**: The banner Row has icon(20) + spacing(8) + Expanded(Text maxLines:1 ellipsis) + action button(~80) + spacing(4) + dismiss(44) ≈ 156pt taken, leaving ~140pt for the message on 320pt screens. A message like "A new version of SpeakFlow is available. 1.0.0+1 → 1.0.1+2" truncates to ~20 chars.
- **Fix**: Allow 2 lines and let the banner height grow, or shorten the message (drop the version detail on small screens):
  ```dart
  Text(message, maxLines: 2, overflow: TextOverflow.ellipsis, ...)
  ```
  Note: the parent `_MeasureSize` already supports height changes, so 2-line growth is safe.

---

### L6 — Confusing shared-preferences key naming
- **File**: `lib/core/services/version_service.dart:108`
- **Pre-existing**
- **Issue**: `static const _prefLastDismissed = 'sf_install_last_version_dismissed';` — the key says `install` but stores the *version-update* dismissal. A future maintainer might think it belongs to `InstallPromptService` (which uses `sf_install_banner_dismissed_v1` in `install_prompt_service.dart:69`).
- **Fix**: Rename to `sf_version_last_dismissed`.

---

### L7 — `location.reload(true)` is non-standard; `sf_refresh=` query param lingers in URL after reload
- **File**: `web/version_check.js:100-114`
- **Pre-existing**
- **Issue**: `location.reload(true)` (the `forceReload` argument) is deprecated and ignored by most modern browsers. Additionally, after `forceReload` appends `?sf_refresh=<ts>`, that param stays in the URL bar after the reload completes (cosmetically ugly and can confuse analytics).
- **Fix**:
  ```js
  // Use history.replaceState to drop the param after reload lands.
  if (location.search.indexOf('sf_refresh=') !== -1) {
    var cleanUrl = location.pathname + location.hash;
    history.replaceState(null, '', cleanUrl);
  }
  location.reload();
  ```

---

## Summary

| Severity | Count | Regressions | Pre-existing |
|----------|-------|-------------|--------------|
| HIGH     | 4     | 1 (H2, possibly H4) | 3 |
| MEDIUM   | 12    | 0           | 12 |
| LOW      | 7     | 0           | 7 |
| **Total**| **23**| **1-2**     | **21-22** |

### Top-priority actions
1. **Verify H1 immediately** — if `GoRouterState.of(context)` truly throws from outside `MaterialApp.router`, the app crashes on startup. Either swap to `maybeOf` or move `AppBanners` into `MaterialApp.router`'s `builder`.
2. **Fix H2** — remove the manual `viewInsets` padding in `_ChatInputBar` (let `resizeToAvoidBottomInset: true` do its job). Currently the text field floats ~340pt above the keyboard on mobile web.
3. **Fix H3** — ship a favicon or repoint to `icons/Icon-192.png` (currently 404s).
4. **Fix H4** — call `_loadTutorIdentity()` after `context.push('/tutor-selection')` returns so the chat reflects the new tutor immediately.

### Things that look correct (Round 1/2 fixes verified still in place)
- Banner occlusion (MediaQuery padding injection via `_MeasureSize`) — `app_banners.dart:74-80`
- `_MeasureSize` rebuild loop (microtask + `_last` guard) — `app_banners.dart:134-149`
- Tap targets ≥44pt on banner action/dismiss, record button, send button, listen button, rating buttons — verified across `app_banners.dart`, `chat_screen.dart`, `review_screen.dart`
- iPad detection via long-edge classification — `responsive.dart:71-77`
- Version arrow direction (`→`) — `app_banners.dart:162`
- SW update race handling (waiting-SW + 8s timeout fallback) — `version_service.dart:211-229`
- version.json 404 / network-error phantom banners (clear server state) — `version_service.dart:153-199`
- Install dismissal permanence (`sf_install_banner_dismissed_v1` + version-keyed dismissal) — `install_prompt_service.dart:146-150`, `version_service.dart:240-253`
- iOS A2HS instructions sheet — `app_banners.dart:219-287`
- iPad mini portrait side-by-side (`shouldUseSideBySide` returns false for portrait < 900pt) — `responsive.dart:120-128`
- NavRail SafeArea (top+bottom) — `app_router.dart:250`
- `_StatCard` overflow (FittedBox on value) — `progress_screen.dart:269-279`
- `_QuickActionGrid` LayoutBuilder (uses `constraints.maxWidth`, not full screen width) — `home_screen.dart:346-372`
- P0-7 (input keystroke no longer rebuilds whole screen; `ValueListenableBuilder` on send button; `_correctionsByMessageProvider` cached) — `chat_screen.dart:1263-1290`, `:735`
- P0-8 (record button pulse + ripple via `_RecordButton` + `_RipplePainter`) — `chat_screen.dart:1351-1486`
- P0-2 (delete session actually deletes via `repo.deleteSession`) — `chat_screen.dart:679`, `history_screen.dart:85`

### Final note
Round 1/2 fixes are holding up well. The remaining issues are mostly pre-existing polish items (Inter font, route transitions, raw error text, reduce-motion) plus a few real bugs that slipped through (H1 to verify, H2 keyboard, H3 favicon, H4 tutor refresh). H1 and H2 are the only items that could plausibly degrade core usability for real users; the rest are quality-of-life improvements.
