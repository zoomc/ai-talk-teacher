import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/util/responsive.dart';
import '../../features/chat/presentation/screens/home_screen.dart';
import '../../features/chat/presentation/screens/chat_screen.dart';
import '../../features/chat/presentation/screens/scenarios_screen.dart';
import '../../features/chat/presentation/screens/review_screen.dart';
import '../../features/chat/presentation/screens/progress_screen.dart';
import '../../features/chat/presentation/screens/history_screen.dart';
import '../../features/chat/presentation/screens/tutor_selection_screen.dart';
import '../../features/chat/presentation/screens/sentence_practice_screen.dart';
import '../../features/chat/presentation/screens/session_summary_screen.dart';
import '../../features/profile/presentation/screens/service_config_screen.dart';
import '../../features/profile/presentation/screens/profile_form_screen.dart';
import '../../features/profile/presentation/screens/voice_health_screen.dart';
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
      // Phase-1 P0 #1 — the guest trial launches straight into /chat/:id
      // before onboarding is complete, so the chat path must bypass the
      // onboarding/placement gates. The chat screen itself enforces the
      // 3-minute time box for guest sessions.
      final isGuestChat = state.matchedLocation.startsWith('/chat/');

      // PWA manifest shortcuts deep-link here with `?action=...` (see
      // web/manifest.json). Map the action to the real route so the
      // launcher shortcuts actually take the user somewhere useful
      // instead of silently landing on the home screen.
      final action = state.uri.queryParameters['action'];
      if (action != null) {
        if (action == 'review') return '/review';
        if (action == 'scenarios') return '/scenarios';
        // 'free-talk' falls through to '/' — the home screen handles
        // session creation via its "Free Talk" quick-action card, and
        // auto-starting a session from a cold launch would surprise
        // the user (no provider configured yet, etc.).
      }

      // Check if onboarding is completed
      final hasCompletedOnboarding = await _profileRepo
          .hasCompletedOnboarding();

      if (!hasCompletedOnboarding && !isOnboarding && !isGuestChat) {
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
                _fadeTransitionPage(context, const HomeScreen()),
          ),
          GoRoute(
            path: '/scenarios',
            pageBuilder: (context, state) =>
                _fadeTransitionPage(context, const ScenariosScreen()),
          ),
          GoRoute(
            path: '/review',
            pageBuilder: (context, state) =>
                _fadeTransitionPage(context, const ReviewScreen()),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) =>
                _fadeTransitionPage(context, const SettingsScreen()),
          ),
        ],
      ),
      GoRoute(
        path: '/chat/:sessionId',
        pageBuilder: (context, state) => _slideTransitionPage(
          context,
          ChatScreen(sessionId: state.pathParameters['sessionId']!),
        ),
      ),
      GoRoute(
        path: '/service-config',
        pageBuilder: (context, state) =>
            _slideTransitionPage(context, const ServiceConfigScreen()),
      ),
      GoRoute(
        path: '/voice-health',
        pageBuilder: (context, state) =>
            _slideTransitionPage(context, const VoiceHealthScreen()),
      ),
      GoRoute(
        path: '/practice',
        pageBuilder: (context, state) =>
            _slideTransitionPage(context, const SentencePracticeScreen()),
      ),
      GoRoute(
        path: '/summary/:sessionId',
        pageBuilder: (context, state) => _slideTransitionPage(
          context,
          SessionSummaryScreen(
            sessionId: state.pathParameters['sessionId']!,
          ),
        ),
      ),
      GoRoute(
        path: '/progress',
        pageBuilder: (context, state) =>
            _slideTransitionPage(context, const ProgressScreen()),
      ),
      GoRoute(
        path: '/history',
        pageBuilder: (context, state) =>
            _slideTransitionPage(context, const HistoryScreen()),
      ),
      GoRoute(
        path: '/tutor-selection',
        pageBuilder: (context, state) =>
            _slideTransitionPage(context, const TutorSelectionScreen()),
      ),
      GoRoute(
        path: '/profile-form/:type',
        pageBuilder: (context, state) {
          final type = state.pathParameters['type']!;
          final profileId = state.uri.queryParameters['id'];
          return _slideTransitionPage(
            context,
            ProfileFormScreen(type: type, profileId: profileId),
          );
        },
      ),
    ],
  );
}

/// P1 task 7 — page transition helper. When the user has enabled the
/// platform's "reduce motion" / accessible navigation setting we fall back
/// to a no-transition page (instant swap) per Flutter a11y guidance; the
/// ShellRoute bottom-nav destinations use a gentle fade so the tab content
/// doesn't feel like it "pops", while detail screens slide in from the
/// right (iOS-style push).
Page<T> _fadeTransitionPage<T>(BuildContext context, Widget child) {
  if (MediaQuery.of(context).accessibleNavigation) {
    return NoTransitionPage<T>(child: child);
  }
  return CustomTransitionPage<T>(
    child: child,
    transitionDuration: const Duration(milliseconds: 220),
    reverseTransitionDuration: const Duration(milliseconds: 180),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      );
    },
  );
}

Page<T> _slideTransitionPage<T>(BuildContext context, Widget child) {
  if (MediaQuery.of(context).accessibleNavigation) {
    return NoTransitionPage<T>(child: child);
  }
  return CustomTransitionPage<T>(
    child: child,
    transitionDuration: const Duration(milliseconds: 260),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(curved),
        child: FadeTransition(opacity: curved, child: child),
      );
    },
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
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.chat_bubble_outline),
            selectedIcon: const Icon(Icons.chat_bubble),
            label: AppLocalizations.of(context).t('nav.practice'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.grid_view_outlined),
            selectedIcon: const Icon(Icons.grid_view),
            label: AppLocalizations.of(context).t('nav.scenarios'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.refresh_outlined),
            selectedIcon: const Icon(Icons.refresh),
            label: AppLocalizations.of(context).t('nav.review'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: AppLocalizations.of(context).t('nav.settings'),
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
        color: Theme.of(context).brightness == Brightness.light
            ? AppColors.lightBgSecondary
            : AppColors.bgSecondary,
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
