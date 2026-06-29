import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'features/profile/data/profile_repository.dart';
import 'shared/providers.dart';

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

  // Check onboarding status + theme preference before launching.
  final profileRepo = ProfileRepository();
  final hasCompletedOnboarding = await profileRepo.hasCompletedOnboarding();
  final themeStr = await profileRepo.getSetting('theme');
  final initialThemeMode = _parseThemeMode(themeStr);

  runApp(
    ProviderScope(
      overrides: [
        // Seed the global themeModeProvider with the persisted preference
        // so the first frame already uses the correct theme (P1-8).
        themeModeProvider.overrideWith((ref) => initialThemeMode),
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

class SpeakFlowApp extends ConsumerWidget {
  final bool hasCompletedOnboarding;

  const SpeakFlowApp({super.key, required this.hasCompletedOnboarding});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watching themeModeProvider means a state change from the settings
    // screen immediately rebuilds MaterialApp with the new themeMode —
    // no restart required (P1-8).
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'SpeakFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: AppRouter.router,
    );
  }
}
