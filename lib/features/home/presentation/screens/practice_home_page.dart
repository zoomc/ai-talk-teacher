import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/util/responsive.dart';
import '../../../../shared/providers.dart';
import '../../../../shared/widgets/glass_widgets.dart';
import '../../../avatar/presentation/widgets/avatar_stage.dart';
import '../../../chat/domain/tutor.dart';
import '../../../../core/runtime/runtime_mode_banner.dart';
import '../home_providers.dart';

/// The focused practice entry point.
///
/// The dashboard remains available at `/dashboard`, but the primary product
/// loop starts here: see the tutor, pick the default topic, and begin a turn.
class PracticeHomePage extends ConsumerStatefulWidget {
  const PracticeHomePage({super.key});

  @override
  ConsumerState<PracticeHomePage> createState() => _PracticeHomePageState();
}

class _PracticeHomePageState extends ConsumerState<PracticeHomePage> {
  Tutor _tutor = TutorRepository.getDefaultTutor();
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _loadTutor();
  }

  Future<void> _loadTutor() async {
    final id = await ref
        .read(profileRepoProvider)
        .getSetting('selected_tutor_id');
    if (!mounted || id == null || id.isEmpty) return;
    setState(() => _tutor = TutorRepository.getTutorById(id));
  }

  Future<void> _startConversation() async {
    if (_starting) return;
    setState(() => _starting = true);
    try {
      final session = await ref
          .read(chatRepoProvider)
          .createSession(topic: 'Free Talk');
      if (!mounted) return;
      ref.invalidate(activeSessionProvider);
      context.go('/chat/${session.id}');
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final lowBandwidth = ref.watch(lowBandwidthProvider);
    final activeSession = ref.watch(activeSessionProvider);
    final dueCount = ref.watch(dueReviewQueueCountProvider);

    return Container(
      decoration: BoxDecoration(
        color: lowBandwidth
            ? (isLight ? AppColors.lightFlatBg : AppColors.darkFlatBg)
            : null,
        gradient: lowBandwidth
            ? null
            : (isLight ? AppColors.lightGradientBg : AppColors.gradientBg),
      ),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: Responsive.contentMaxWidth(context),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.xxl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const RuntimeModeBanner(),
                  Text(
                    l.t('chat.practice_live'),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l.t('chat.practice_subtitle'),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: isLight
                          ? AppColors.lightTextSecondary
                          : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  GlassCard(
                    padding: EdgeInsets.zero,
                    glowColor: AppColors.glowPurple,
                    child: Column(
                      children: [
                        SizedBox(
                          height: Responsive.isMobile(context) ? 300 : 360,
                          child: AvatarStage(
                            phase: AvatarPhase.idle,
                            tutorName: _tutor.name,
                            tutorAvatar: _tutor.avatar,
                            // Avatar V2 is the production renderer; the
                            // layered painter remains a debug/test fallback.
                            prefer3d: true,
                            panelHeight: Responsive.isMobile(context)
                                ? 300
                                : 360,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg,
                            0,
                            AppSpacing.lg,
                            AppSpacing.lg,
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: AppColors.accentPrimary
                                    .withValues(alpha: 0.16),
                                child: Text(
                                  _tutor.initial,
                                  style: const TextStyle(
                                    color: AppColors.accentPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _tutor.name,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    Text(
                                      _tutor.personality,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: isLight
                                                ? AppColors.lightTextSecondary
                                                : AppColors.textSecondary,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              StatusPill(
                                text: l.t('chat.ready'),
                                color: AppColors.success,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  GlassCard(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.topic_outlined,
                          color: AppColors.accentSecondary,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l.t('home.free_talk'),
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              Text(
                                l.t('home.free_talk_subtitle'),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.check_circle,
                          color: AppColors.success,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Semantics(
                    button: true,
                    label: l.t('chat.start_button'),
                    child: FilledButton.icon(
                      onPressed: _starting ? null : _startConversation,
                      icon: _starting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.mic_none_rounded),
                      label: Text(l.t('chat.start_button')),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        backgroundColor: AppColors.accentPrimary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Semantics(
                    button: true,
                    label: l.t('home.scenarios'),
                    child: OutlinedButton.icon(
                      onPressed: () => context.go('/scenarios'),
                      icon: const Icon(Icons.grid_view_outlined),
                      label: Text(l.t('home.scenarios')),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  ),
                  activeSession.when(
                    data: (session) => session == null
                        ? const SizedBox.shrink()
                        : _ActionCard(
                            icon: Icons.play_circle_outline,
                            title: l.t('home.continue_practice'),
                            subtitle: session.topic ?? l.t('home.free_talk'),
                            onTap: () => context.go('/chat/${session.id}'),
                          ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                  dueCount.when(
                    data: (count) => count == 0
                        ? const SizedBox.shrink()
                        : _ActionCard(
                            icon: Icons.refresh_rounded,
                            title: l.t('home.review'),
                            subtitle: '$count ${l.t('review.due_now')}',
                            onTap: () => context.go('/review'),
                          ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.only(top: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: AppColors.accentSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}

extension on Tutor {
  String get initial => name.isEmpty ? '?' : name.substring(0, 1);
}
