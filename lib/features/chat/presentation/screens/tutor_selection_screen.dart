import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/util/responsive.dart';
import '../../../../shared/widgets/glass_widgets.dart';
import '../../domain/tutor.dart';

class TutorSelectionScreen extends ConsumerWidget {
  final String? sessionId;
  const TutorSelectionScreen({super.key, this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.pop(),
        ),
        title: const Text('Choose Your Tutor'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: Responsive.contentMaxWidth(context),
          ),
          child: Container(
            decoration: const BoxDecoration(gradient: AppColors.gradientBg),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Tutors',
                    style: Theme.of(context).textTheme.displayLarge,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Choose a tutor that matches your learning style',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Tutor grid
                  ...TutorRepository.tutors.map(
                    (tutor) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _TutorCard(
                        tutor: tutor,
                        onTap: () => _selectTutor(context, tutor),
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _selectTutor(BuildContext context, Tutor tutor) {
    // Return the selected tutor ID
    context.pop(tutor.id);
  }
}

class _TutorCard extends StatelessWidget {
  final Tutor tutor;
  final VoidCallback onTap;

  const _TutorCard({required this.tutor, required this.onTap});

  Color _getStyleColor(String style) {
    switch (style) {
      case 'friendly':
        return AppColors.success;
      case 'professional':
        return AppColors.accentPrimary;
      case 'casual':
        return AppColors.accentSecondary;
      case 'strict':
        return AppColors.error;
      case 'exam':
        return AppColors.warning;
      case 'pronunciation':
        return const Color(0xFF9C27B0); // Purple
      default:
        return AppColors.textSecondary;
    }
  }

  String _getStyleLabel(String style) {
    switch (style) {
      case 'friendly':
        return 'Friendly';
      case 'professional':
        return 'Professional';
      case 'casual':
        return 'Casual';
      case 'strict':
        return 'Strict';
      case 'exam':
        return 'Exam Prep';
      case 'pronunciation':
        return 'Pronunciation';
      default:
        return style;
    }
  }

  @override
  Widget build(BuildContext context) {
    final styleColor = _getStyleColor(tutor.style);

    return GlassCard(
      onTap: onTap,
      glowColor: styleColor.withValues(alpha: 0.3),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: styleColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Center(
              child: Text(tutor.avatar, style: const TextStyle(fontSize: 36)),
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      tutor.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: styleColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        _getStyleLabel(tutor.style),
                        style: TextStyle(
                          color: styleColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  tutor.personality,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  tutor.description,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          const Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: AppColors.textMuted,
          ),
        ],
      ),
    );
  }
}
