import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/util/responsive.dart';
import '../../features/chat/presentation/screens/home_screen.dart';
import '../../features/chat/presentation/screens/chat_screen.dart';
import '../../features/chat/presentation/screens/scenarios_screen.dart';
import '../../features/chat/presentation/screens/review_screen.dart';
import '../../features/chat/presentation/screens/progress_screen.dart';
import '../../features/chat/presentation/screens/history_screen.dart';
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
      final hasCompletedOnboarding = await _profileRepo
          .hasCompletedOnboarding();

      if (!hasCompletedOnboarding && !isOnboarding) {
        return '/onboarding';
      }

      if (hasCompletedOnboarding) {
        // Check if placement is completed
        final hasCompletedPlacement = await _profileRepo
            .hasCompletedPlacement();
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
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: HomeScreen()),
          ),
          GoRoute(
            path: '/scenarios',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ScenariosScreen()),
          ),
          GoRoute(
            path: '/review',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ReviewScreen()),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: SettingsScreen()),
          ),
        ],
      ),
      GoRoute(
        path: '/chat/:sessionId',
        builder: (context, state) =>
            ChatScreen(sessionId: state.pathParameters['sessionId']!),
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
        path: '/history',
        builder: (context, state) => const HistoryScreen(),
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
    if (Responsive.useNavRail(context)) {
      // Tablet / desktop / wide browser: side rail, no bottom bar.
      // Constrain the body content to a readable max width and center it
      // so lists / cards don't stretch edge-to-edge on huge monitors.
      return Scaffold(
        body: Row(
          children: [
            _SideNavRail(
              selectedIndex: _calculateSelectedIndex(context),
              onItemTapped: (i) => _onItemTapped(i, context),
              extended: Responsive.isExpanded(context),
            ),
            Container(width: 1, color: AppColors.glassBorder),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: Responsive.contentMaxWidth(context),
                  ),
                  child: child,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Phone: bottom navigation bar.
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

/// Side navigation rail used on tablet/desktop layouts.
class _SideNavRail extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemTapped;
  final bool extended;

  const _SideNavRail({
    required this.selectedIndex,
    required this.onItemTapped,
    required this.extended,
  });

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
    _NavItem(
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings,
      label: 'Settings',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      // top:true because the tablet/desktop MainShell has no AppBar —
      // without the top inset the brand mark sits under the status bar /
      // browser chrome / iPad Split-View top inset. bottom:true keeps
      // the last nav item clear of the home indicator.
      child: Container(
        color: AppColors.bgSecondary,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        width: extended ? 200 : 72,
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
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

class _SideNavItem extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final bool extended;
  final VoidCallback onTap;

  const _SideNavItem({
    required this.item,
    required this.selected,
    required this.extended,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.accentPrimary : AppColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      child: Material(
        color: selected
            ? AppColors.accentPrimary.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
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
                Icon(
                  selected ? item.activeIcon : item.icon,
                  color: color,
                  size: 22,
                ),
                if (extended) ...[
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    item.label,
                    style: TextStyle(color: color, fontWeight: FontWeight.w500),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
