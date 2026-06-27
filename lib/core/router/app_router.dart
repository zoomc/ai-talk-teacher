import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/chat/presentation/screens/home_screen.dart';
import '../../features/chat/presentation/screens/chat_screen.dart';
import '../../features/chat/presentation/screens/scenarios_screen.dart';
import '../../features/chat/presentation/screens/review_screen.dart';
import '../../features/chat/presentation/screens/progress_screen.dart';
import '../../features/chat/presentation/screens/tutor_selection_screen.dart';
import '../../features/profile/presentation/screens/service_config_screen.dart';
import '../../features/profile/presentation/screens/profile_form_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/onboarding/presentation/screens/placement_screen.dart';
import '../../features/profile/data/profile_repository.dart';

class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();
  static final _shellNavigatorKey = GlobalKey<NavigatorState>();
  static final _profileRepo = ProfileRepository();

  static final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    redirect: (context, state) async {
      final isOnboarding = state.matchedLocation == '/onboarding';
      final isPlacement = state.matchedLocation == '/placement';

      // Check if onboarding is completed
      final hasCompletedOnboarding = await _profileRepo.hasCompletedOnboarding();

      if (!hasCompletedOnboarding && !isOnboarding) {
        return '/onboarding';
      }

      if (hasCompletedOnboarding) {
        // Check if placement is completed
        final hasCompletedPlacement = await _profileRepo.hasCompletedPlacement();
        if (!hasCompletedPlacement && !isPlacement && !isOnboarding) {
          return '/placement';
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/placement',
        builder: (context, state) => const PlacementScreen(),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HomeScreen(),
            ),
          ),
          GoRoute(
            path: '/scenarios',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ScenariosScreen(),
            ),
          ),
          GoRoute(
            path: '/review',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ReviewScreen(),
            ),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SettingsScreen(),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/chat/:sessionId',
        builder: (context, state) => ChatScreen(
          sessionId: state.pathParameters['sessionId']!,
        ),
      ),
      GoRoute(
        path: '/service-config',
        builder: (context, state) => const ServiceConfigScreen(),
      ),
      GoRoute(
        path: '/progress',
        builder: (context, state) => const ProgressScreen(),
      ),
      GoRoute(
        path: '/tutor-selection',
        builder: (context, state) => const TutorSelectionScreen(),
      ),
      GoRoute(
        path: '/profile-form/:type',
        builder: (context, state) {
          final type = state.pathParameters['type']!;
          final profileId = state.uri.queryParameters['id'];
          return ProfileFormScreen(type: type, profileId: profileId);
        },
      ),
    ],
  );
}

class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _calculateSelectedIndex(context),
        onDestinationSelected: (index) => _onItemTapped(index, context),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Practice',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view),
            label: 'Scenarios',
          ),
          NavigationDestination(
            icon: Icon(Icons.refresh_outlined),
            selectedIcon: Icon(Icons.refresh),
            label: 'Review',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location == '/') return 0;
    if (location.startsWith('/scenarios')) return 1;
    if (location.startsWith('/review')) return 2;
    if (location.startsWith('/settings')) return 3;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/');
        break;
      case 1:
        context.go('/scenarios');
        break;
      case 2:
        context.go('/review');
        break;
      case 3:
        context.go('/settings');
        break;
    }
  }
}
