import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'features/profile/data/profile_repository.dart';

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
      child: SpeakFlowApp(
        hasCompletedOnboarding: hasCompletedOnboarding,
        initialThemeMode: initialThemeMode,
      ),
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

class SpeakFlowApp extends StatefulWidget {
  final bool hasCompletedOnboarding;
  final ThemeMode initialThemeMode;
  const SpeakFlowApp({
    super.key,
    required this.hasCompletedOnboarding,
    required this.initialThemeMode,
  });

  @override
  State<SpeakFlowApp> createState() => _SpeakFlowAppState();
}

class _SpeakFlowAppState extends State<SpeakFlowApp> {
  late ThemeMode _themeMode;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.initialThemeMode;
  }

  void setThemeMode(ThemeMode mode) {
    setState(() => _themeMode = mode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'SpeakFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      routerConfig: AppRouter.router,
    );
  }
}
