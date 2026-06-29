import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/util/responsive.dart';
import '../../../../shared/widgets/glass_widgets.dart';
import '../../../../shared/providers.dart';
import '../../domain/tutor.dart';

class TutorSelectionScreen extends ConsumerStatefulWidget {
  final String? sessionId;
  const TutorSelectionScreen({super.key, this.sessionId});

  @override
  ConsumerState<TutorSelectionScreen> createState() =>
      _TutorSelectionScreenState();
}

class _TutorSelectionScreenState extends ConsumerState<TutorSelectionScreen> {
  String? _selectedTutorId;

  @override
  void initState() {
    super.initState();
    _loadCurrentTutor();
  }

  Future<void> _loadCurrentTutor() async {
    final id = await ref.read(profileRepoProvider).getSetting('selected_tutor_id');
    if (mounted) {
      setState(() => _selectedTutorId = id);
    }
  }

  Future<void> _selectTutor(Tutor tutor) async {
    // Persist the choice so ChatScreen._loadTutorIdentity picks it up.
    // The previous implementation only did context.pop(tutor.id), but the
    // caller never read the return value AND never wrote the setting — so
    // picking a tutor here had no effect on the actual chat.
    await ref.read(profileRepoProvider).setSetting('selected_tutor_id', tutor.id);
    if (mounted) {
      setState(() => _selectedTutorId = tutor.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${tutor.name} selected')),
      );
      // Small delay so the user sees the selection highlight + snackbar before
      // we pop back to the chat.
      await Future.delayed(const Duration(milliseconds: 250));
      if (mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
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
                        isSelected: _selectedTutorId == tutor.id,
                        onTap: () => _selectTutor(tutor),
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
}

class _TutorCard extends StatelessWidget {
  final Tutor tutor;
  final bool isSelected;
  final VoidCallback onTap;

  const _TutorCard({
    required this.tutor,
    required this.isSelected,
    required this.onTap,
  });

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
        return AppColors.accentPrimary;
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
      // Stronger glow on the selected card so the user can see their current
      // pick at a glance (previously there was no selected-state UI at all).
      glowColor: isSelected
          ? styleColor.withValues(alpha: 0.55)
          : styleColor.withValues(alpha: 0.3),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: styleColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: isSelected
                  ? Border.all(color: styleColor, width: 2)
                  : null,
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
                    Flexible(
                      child: Text(
                        tutor.name,
                        style: Theme.of(context).textTheme.titleLarge,
                        overflow: TextOverflow.ellipsis,
                      ),
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

          // Selected checkmark / chevron.
          isSelected
              ? Icon(Icons.check_circle, color: styleColor, size: 24)
              : const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: AppColors.textMuted,
                ),
        ],
      ),
    );
  }
}
