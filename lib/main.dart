import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/i18n/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/services/browser_language_bridge_stub.dart'
    if (dart.library.js_interop) 'core/services/browser_language_bridge_web.dart';
import 'features/profile/data/profile_repository.dart';
import 'shared/providers.dart';
import 'shared/widgets/app_banners.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // D1: Global error handling — catch framework and async errors so they don't
  // silently crash the app without any user-visible feedback.
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
  };
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('PlatformDispatcher error: $error\n$stack');
    return true;
  };

  // Check onboarding status + theme/locale preference before launching.
  final profileRepo = ProfileRepository();
  final hasCompletedOnboarding = await profileRepo.hasCompletedOnboarding();
  final themeStr = await profileRepo.getSetting('theme');
  final initialThemeMode = _parseThemeMode(themeStr);
  final initialLocale = await _resolveInitialLocale(profileRepo);

  runApp(
    ProviderScope(
      overrides: [
        // Seed the global themeModeProvider with the persisted preference
        // so the first frame already uses the correct theme (P1-8).
        themeModeProvider.overrideWith((ref) => initialThemeMode),
        // Seed the locale provider the same way: persisted user pick wins,
        // otherwise the browser language (auto-detected on web) is used,
        // otherwise zh (the project default per spec).
        localeProvider.overrideWith((ref) => initialLocale),
      ],
      child: SpeakFlowApp(hasCompletedOnboarding: hasCompletedOnboarding),
    ),
  );
}

ThemeMode _parseThemeMode(String? s) {
  switch (s) {
    case 'dark':
      return ThemeMode.dark;
    case 'light':
      return ThemeMode.light;
    case 'system':
    default:
      return ThemeMode.system;
  }
}

/// Resolve the initial app locale with this priority:
///   1. Persisted `app_language` user setting (set from Settings screen)
///   2. Browser language tag (auto-detected on web; null on mobile/desktop)
///   3. `AppLocale.zh` (spec: "如果检测不到就是默认中文")
///
/// On non-web platforms the browser bridge returns null, so we fall back to
/// the platform dispatcher locale if the user hasn't picked one — this gives
/// reasonable behaviour on mobile too.
Future<AppLocale> _resolveInitialLocale(ProfileRepository repo) async {
  final persisted = await repo.getSetting('app_language');
  if (persisted != null && persisted.isNotEmpty) {
    final parsed = AppLocale.fromString(persisted);
    if (parsed != AppLocale.zh || persisted == 'zh') {
      return parsed;
    }
    // persisted was unparseable → continue to fallback chain
  }
  final browserTag = BrowserLanguageBridge.preferredLanguageTag;
  if (browserTag != null && browserTag.isNotEmpty) {
    return AppLocale.fromString(browserTag);
  }
  // Non-web + no persisted pick: use the OS locale from the platform
  // dispatcher (only available after binding init, which has happened).
  try {
    final osLocale = PlatformDispatcher.instance.locale.languageCode;
    if (osLocale.isNotEmpty) {
      return AppLocale.fromString(osLocale);
    }
  } catch (_) {
    // ignore — fall through to default
  }
  return AppLocale.zh;
}

class SpeakFlowApp extends ConsumerWidget {
  final bool hasCompletedOnboarding;

  const SpeakFlowApp({super.key, required this.hasCompletedOnboarding});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watching themeModeProvider means a state change from the settings
    // screen immediately rebuilds MaterialApp with the new themeMode —
    // no restart required (P1-8). Same applies to localeProvider —
    // picking a language in Settings rebuilds the whole tree with the
    // new translations.
    final themeMode = ref.watch(themeModeProvider);
    final appLocale = ref.watch(localeProvider);
    // AppBanners lives inside MaterialApp.router's `builder` (rather
    // than wrapping it from the outside) so its context is within the
    // GoRouter subtree — that's what lets `GoRouterState.maybeOf` work
    // for route-aware banner suppression on first-run screens.
    return MaterialApp.router(
      title: 'SpeakFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      // i18n: app strings + Material/Cupertino built-in strings
      // (toolbar back button, date picker, etc.) for all 7 locales.
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: appLocale.toLocale(),
      routerConfig: AppRouter.router,
      builder: (context, child) => AppBanners(child: child!),
    );
  }
}
