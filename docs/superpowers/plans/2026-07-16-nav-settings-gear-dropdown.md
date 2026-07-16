# Nav Settings Gear Dropdown Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a settings gear icon to the navigation shell that opens a dropdown menu of settings quick-links (Settings, Service Config, Voice Health).

**Architecture:** A new self-contained `SettingsMenuButton` widget renders a gear-shaped tappable row (matching the existing side-rail item style) and opens a Material `showMenu` popup on tap. It is placed at the bottom of the `_SideNavRail` (tablet/desktop layout). The 4th "Settings" `_NavItem` is removed from the rail to avoid duplication — the gear now provides that access plus quick links. The phone bottom-nav layout is unchanged: it keeps its dedicated Settings tab, since a popup off a bottom-nav destination is an awkward affordance. Default tap handling navigates via `go_router`; an injectable `onSelected` callback makes the widget unit-testable without a router in scope. All menu labels reuse existing i18n keys (`nav.settings`, `settings.service_config`, `settings.voice_health`) — no new translation keys are needed.

**Tech Stack:** Flutter 3.x + Dart, Material widgets, `go_router` 14.8.1, `flutter_test` (widget tests via `testWidgets`), `AppLocalizations` i18n, custom `AppColors`/`AppSpacing`/`AppRadius` design tokens. Package name: `speakflow`.

---

## Important codebase note

The deployment target is `https://zoomlab.top/talk/` but the project is the **Flutter app `speakflow`** (`/workspace/pubspec.yaml`), not a React/TS "zoomlab-web". There are no `.tsx`/`.jsx` files. The "Navigation component" is the `MainShell` widget plus the private `_SideNavRail` in `/workspace/lib/core/router/app_router.dart`. This plan targets that file and one new widget file.

## File Structure

- **Create:** `lib/shared/widgets/settings_menu_button.dart` — the gear dropdown widget (`SettingsMenuButton` + `SettingsMenuAction` enum). Self-contained: owns its layout, the `showMenu` popup, and default `go_router` navigation. Sits in `shared/widgets/` next to the other reusable widgets (`glass_widgets.dart`, `app_banners.dart`, `voice_status_indicator.dart`).
- **Create:** `test/settings_menu_button_test.dart` — widget tests for the gear button (renders icon, opens menu with 3 items, fires `onSelected` with the picked action). Follows the flat `test/*_test.dart` convention already used (e.g. `test/version_service_test.dart`).
- **Modify:** `lib/core/router/app_router.dart` — add an import for `SettingsMenuButton`, drop the 4th "Settings" `_NavItem` from `_SideNavRail._items`, and append a `Spacer()` + `SettingsMenuButton` at the bottom of the rail's `Column`. The phone `NavigationBar` (4 destinations incl. Settings) and the shared `_calculateSelectedIndex` / `_onItemTapped` are intentionally left untouched.

Design-token / i18n references the plan relies on (already in the codebase, do not recreate):
- `AppSpacing` (`xxs=4, xs=8, sm=12, md=16, lg=24`), `AppRadius` (`md=12`) — `lib/core/constants/app_constants.dart`.
- `AppColors.textSecondary` — `lib/core/theme/app_colors.dart`.
- `AppLocalizations.of(context).t('nav.settings')` (en: "Settings"), `.t('settings.service_config')` (en: "Service Configuration"), `.t('settings.voice_health')` (en: "Voice Health Check") — `lib/core/i18n/app_localizations.dart`. `AppLocalizations.of` falls back to `AppLocalizations(AppLocale.zh)` when no delegate is in scope, so the widget never crashes; tests inject `AppLocalizations.delegate` + `Locale('en')` to get deterministic English strings.

---

### Task 1: SettingsMenuButton widget (TDD)

**Files:**
- Create: `lib/shared/widgets/settings_menu_button.dart`
- Create: `test/settings_menu_button_test.dart`

- [ ] **Step 1: Write the failing widget test**

Create `test/settings_menu_button_test.dart` with the full contents below. It asserts the gear icon renders, the popup opens with the three expected (English) items, and tapping an item fires `onSelected` with the right enum value.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speakflow/core/i18n/app_localizations.dart';
import 'package:speakflow/shared/widgets/settings_menu_button.dart';

void main() {
  group('SettingsMenuButton', () {
    testWidgets('renders gear icon and opens menu with 3 quick links',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [AppLocalizations.delegate],
        home: const Scaffold(body: SettingsMenuButton()),
      ));

      // Gear trigger icon is rendered (before the menu opens there is
      // exactly one settings_outlined icon in the tree).
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);

      // Open the popup.
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();

      // All three quick-link labels are present (en locale strings).
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Service Configuration'), findsOneWidget);
      expect(find.text('Voice Health Check'), findsOneWidget);
    });

    testWidgets('fires onSelected with the tapped action', (tester) async {
      SettingsMenuAction? picked;
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [AppLocalizations.delegate],
        home: Scaffold(
          body: SettingsMenuButton(onSelected: (a) => picked = a),
        ),
      ));

      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Service Configuration'));
      await tester.pumpAndSettle();

      expect(picked, SettingsMenuAction.serviceConfig);
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/settings_menu_button_test.dart`
Expected: FAIL — compilation error: `Target of URI doesn't exist: 'package:speakflow/shared/widgets/settings_menu_button.dart'` (the file/class does not exist yet).

- [ ] **Step 3: Write the minimal implementation**

Create `lib/shared/widgets/settings_menu_button.dart` with the full contents below. The widget mirrors the existing `_SideNavItem` row style (same paddings, `AppRadius.md` rounded `InkWell`, `AppColors.textSecondary` icon, optional label in `extended` mode) so it reads as part of the rail. On tap it computes the trigger's rect relative to the `Navigator` overlay (the canonical `showMenu` positioning pattern) and opens a popup with the three quick links. Default handling navigates via `go_router`; `onSelected` overrides that for tests.

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_colors.dart';

/// Quick-access actions surfaced from the settings gear at the bottom
/// of the side navigation rail.
enum SettingsMenuAction { settings, serviceConfig, voiceHealth }

/// A gear-shaped nav-rail control that opens a dropdown of settings
/// quick links (Settings, Service Config, Voice Health).
///
/// Renders as a tappable row matching the side-rail item layout, so it
/// reads as part of the rail. On tap it shows a [showMenu] popup
/// anchored at the gear. Default tap handling navigates via `go_router`;
/// pass [onSelected] to override (used by tests).
///
/// Only used on the tablet/desktop side rail. Phone layouts keep the
/// dedicated bottom-nav Settings tab — a popup off a bottom-nav
/// destination is an awkward affordance.
class SettingsMenuButton extends StatelessWidget {
  /// Mirrors the rail's `extended` flag: when true a label is shown
  /// beside the gear (e.g. "Settings").
  final bool extended;

  /// Overrides the default go_router navigation. Tests inject this so
  /// they can assert which action was picked without a router in scope.
  final ValueChanged<SettingsMenuAction>? onSelected;

  const SettingsMenuButton({
    super.key,
    this.extended = false,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: () => _openMenu(context),
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Tooltip(
            message: l.t('nav.settings'),
            child: Padding(
              padding: EdgeInsets.symmetric(
                vertical: AppSpacing.sm + 2,
                horizontal: extended ? AppSpacing.md : AppSpacing.sm,
              ),
              child: Row(
                mainAxisAlignment: extended
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.settings_outlined,
                    color: AppColors.textSecondary,
                    size: 22,
                  ),
                  if (extended) ...[
                    const SizedBox(width: AppSpacing.md),
                    Text(
                      l.t('nav.settings'),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openMenu(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox? overlay =
        Navigator.of(context).overlay?.context.findRenderObject() as RenderBox?;
    if (overlay == null) return;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(
          button.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );
    final action = await showMenu<SettingsMenuAction>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      items: <PopupMenuEntry<SettingsMenuAction>>[
        PopupMenuItem(
          value: SettingsMenuAction.settings,
          child: _itemRow(Icons.settings_outlined, l.t('nav.settings')),
        ),
        PopupMenuItem(
          value: SettingsMenuAction.serviceConfig,
          child: _itemRow(
            Icons.cloud_outlined,
            l.t('settings.service_config'),
          ),
        ),
        PopupMenuItem(
          value: SettingsMenuAction.voiceHealth,
          child: _itemRow(
            Icons.surround_sound_outlined,
            l.t('settings.voice_health'),
          ),
        ),
      ],
    );
    if (action == null) return;
    if (onSelected != null) {
      onSelected!(action);
    } else {
      _navigate(context, action);
    }
  }

  Widget _itemRow(IconData icon, String label) => Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Text(label),
        ],
      );

  void _navigate(BuildContext context, SettingsMenuAction action) {
    switch (action) {
      case SettingsMenuAction.settings:
        context.go('/settings');
        break;
      case SettingsMenuAction.serviceConfig:
        context.push('/service-config');
        break;
      case SettingsMenuAction.voiceHealth:
        context.push('/voice-health');
        break;
    }
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/settings_menu_button_test.dart`
Expected: PASS — both tests pass (gear icon renders, menu opens with "Settings" / "Service Configuration" / "Voice Health Check", tapping "Service Configuration" fires `onSelected` with `SettingsMenuAction.serviceConfig`).

- [ ] **Step 5: Commit**

```bash
git add lib/shared/widgets/settings_menu_button.dart test/settings_menu_button_test.dart
git commit -m "feat(nav): add SettingsMenuButton gear dropdown widget"
```

---

### Task 2: Wire SettingsMenuButton into the side nav rail

**Files:**
- Modify: `lib/core/router/app_router.dart` (add import near the existing imports; edit `_SideNavRail._items` and `_SideNavRail.build`'s `Column` children)

`_SideNavRail` is private, so it isn't directly importable from a test file — this task is a code edit verified by `flutter analyze` + the full existing test suite + a manual smoke check. The `SettingsMenuButton` behavior itself is already covered by Task 1's tests.

- [ ] **Step 1: Add the import to `app_router.dart`**

Add this line immediately after the existing `import '../../features/profile/data/profile_repository.dart';` (line 23) so the new widget is in scope:

```dart
import '../../shared/widgets/settings_menu_button.dart';
```

- [ ] **Step 2: Drop the 4th "Settings" item from the rail**

In `lib/core/router/app_router.dart`, find the `_SideNavRail._items` static const (currently 4 entries) and delete the Settings `_NavItem` so only Practice / Scenarios / Review remain. Replace the whole `_items` declaration with:

```dart
  static const _items = <_NavItem>[
    _NavItem(
      icon: Icons.chat_bubble_outline,
      activeIcon: Icons.chat_bubble,
      label: 'Practice',
    ),
    _NavItem(
      icon: Icons.grid_view_outlined,
      activeIcon: Icons.grid_view,
      label: 'Scenarios',
    ),
    _NavItem(
      icon: Icons.refresh_outlined,
      activeIcon: Icons.refresh,
      label: 'Review',
    ),
  ];
```

- [ ] **Step 3: Append the gear at the bottom of the rail**

In `_SideNavRail.build`, the `Column` currently ends with the `List.generate(...)` spread. Add a `Spacer()` + `SettingsMenuButton` after it so the gear pins to the bottom of the rail. Replace the existing `Column` (the one whose children are the brand mark, `SizedBox(height: AppSpacing.lg)`, and the `List.generate`) with:

```dart
        child: Column(
          children: [
            // Brand mark at the top of the rail.
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: AppColors.gradientPrimary,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: const Icon(Icons.mic, color: Colors.white, size: 20),
                  ),
                  if (extended) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'SpeakFlow',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ...List.generate(_items.length, (i) {
              final item = _items[i];
              final selected = i == selectedIndex;
              return _SideNavItem(
                item: item,
                selected: selected,
                extended: extended,
                onTap: () => onItemTapped(i),
              );
            }),
            // Settings gear pinned to the bottom of the rail. Opens a
            // dropdown of settings quick links (replaces the old 4th
            // "Settings" nav item, which the gear now covers).
            const Spacer(),
            SettingsMenuButton(extended: extended),
          ],
        ),
```

Note: `const Spacer()` requires the `Column` to have bounded height. The rail's `Column` lives inside a `Container` that is stretched to full height by the parent `Row` in `MainShell.build`, so the height is bounded and `Spacer` works.

- [ ] **Step 4: Verify with `flutter analyze` and the full test suite**

Run: `flutter analyze lib/core/router/app_router.dart lib/shared/widgets/settings_menu_button.dart`
Expected: "No issues found!" (0 errors, 0 warnings).

Run: `flutter test`
Expected: All existing tests still pass (no regressions), plus the 2 new `SettingsMenuButton` tests from Task 1 pass.

- [ ] **Step 5: Manual smoke check, then commit**

Run the app on a wide viewport so the side rail shows (not the phone bottom nav): `flutter run -d chrome` (or your usual web/macOS target) and widen the browser window past 600dp.

Verify by eye:
- The side rail shows 3 nav items (Practice, Scenarios, Review) and a gear icon at the bottom.
- Tapping the gear opens a dropdown with "Settings", "Service Configuration", "Voice Health Check".
- Picking "Settings" navigates to the full Settings screen; "Service Configuration" → service-config screen; "Voice Health Check" → voice-health screen.
- Narrowing the window below 600dp switches to the phone bottom nav, which still shows all 4 destinations including Settings (unchanged).

Then commit:

```bash
git add lib/core/router/app_router.dart
git commit -m "feat(nav): surface settings gear dropdown at bottom of side nav rail"
```

---

## Self-Review

**1. Spec coverage.** The request was: add a settings gear icon and dropdown menu to the Navigation component.
- Gear icon in the navigation: covered — `SettingsMenuButton` renders `Icons.settings_outlined` and is placed inside `_SideNavRail` (the navigation shell). ✓
- Dropdown menu: covered — `showMenu` popup with 3 items. ✓
- The phone bottom-nav layout intentionally keeps its existing Settings tab; the gear is a tablet/desktop sidebar affordance. This is a documented scope decision, not a gap.

**2. Placeholder scan.** No "TBD", "TODO", "add error handling", "similar to Task N", or undescribed steps. Every code step contains the full code to write; every run step contains the exact command and expected result.

**3. Type consistency.**
- Enum `SettingsMenuAction` with values `settings`, `serviceConfig`, `voiceHealth` — used identically in the widget (Task 1) and asserted identically in the test (`SettingsMenuAction.serviceConfig`). ✓
- Widget class name `SettingsMenuButton`, constructor params `extended` (bool) and `onSelected` (`ValueChanged<SettingsMenuAction>?`) — defined in Task 1 and referenced consistently in Task 2 (`SettingsMenuButton(extended: extended)`). ✓
- `_SideNavRail` still passes `extended` to `_SideNavItem` and now also to `SettingsMenuButton`; `extended` is an existing `final bool` field on `_SideNavRail`. ✓
- i18n keys `nav.settings`, `settings.service_config`, `settings.voice_health` — confirmed to exist in all 7 locale tables (zh/en/ja/ko/es/fr/pt); en values used in test assertions ("Settings", "Service Configuration", "Voice Health Check") match the actual strings in `lib/core/i18n/app_localizations.dart`. ✓
- Import paths verified: from `lib/shared/widgets/`, `../../core/...` resolves to `lib/core/...`; from `lib/core/router/`, `../../shared/widgets/...` resolves to `lib/shared/widgets/...`. ✓
- `_calculateSelectedIndex` and `_onItemTapped` are left untouched and remain correct: the bottom nav still has 4 destinations (index 3 = Settings), and the rail's 3 items only ever invoke `onItemTapped(0..2)`. When the route is `/settings`, the rail's `selectedIndex` is 3 and no rail item matches, so none is highlighted — the gear is the entry point. ✓

No issues found; plan is complete.
