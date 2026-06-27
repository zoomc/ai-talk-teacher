import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'features/profile/data/profile_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Check onboarding status
  final profileRepo = ProfileRepository();
  final hasCompletedOnboarding = await profileRepo.hasCompletedOnboarding();

  runApp(
    ProviderScope(
      child: SpeakFlowApp(hasCompletedOnboarding: hasCompletedOnboarding),
    ),
  );
}

class SpeakFlowApp extends StatelessWidget {
  final bool hasCompletedOnboarding;
  const SpeakFlowApp({super.key, required this.hasCompletedOnboarding});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'SpeakFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      routerConfig: AppRouter.router,
    );
  }
}
