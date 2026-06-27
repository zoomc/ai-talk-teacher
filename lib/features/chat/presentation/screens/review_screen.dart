import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/glass_widgets.dart';
import '../../../../shared/providers.dart';
import '../../domain/chat_models.dart';

class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  List<Correction> _corrections = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCorrections();
  }

  Future<void> _loadCorrections() async {
    final repo = ref.read(chatRepoProvider);
    final corrections = await repo.getDueCorrections(limit: 50);
    setState(() {
      _corrections = corrections;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.gradientBg),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _corrections.isEmpty
                  ? _buildEmptyState(context)
                  : _buildReviewList(context),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            child: const Icon(Icons.check_circle, color: AppColors.success, size: 40),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'All caught up!',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'No errors due for review right now.\nKeep practicing!',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          ElevatedButton.icon(
            onPressed: () => context.go('/'),
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('Start Practicing'),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewList(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Review', style: Theme.of(context).textTheme.displayLarge),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '${_corrections.length} errors due for review',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _startAIReview(context),
                      icon: const Icon(Icons.auto_awesome, size: 18),
                      label: const Text('AI Review'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Tap an error to practice it in a conversation',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final correction = _corrections[index];
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.xs,
                ),
                child: _CorrectionCard(
                  correction: correction,
                  onTap: () => _practiceCorrection(context, correction),
                ),
              );
            },
            childCount: _corrections.length,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
      ],
    );
  }

  Future<void> _startAIReview(BuildContext context) async {
    final repo = ref.read(chatRepoProvider);
    final session = await repo.createSession(topic: 'AI Review Session');
    if (context.mounted) {
      context.push('/chat/${session.id}');
    }
  }

  Future<void> _practiceCorrection(BuildContext context, Correction correction) async {
    final repo = ref.read(chatRepoProvider);
    final session = await repo.createSession(
      topic: 'Practice: ${correction.original} → ${correction.corrected}',
    );
    if (context.mounted) {
      context.push('/chat/${session.id}');
    }
  }
}

class _CorrectionCard extends StatelessWidget {
  final Correction correction;
  final VoidCallback onTap;

  const _CorrectionCard({required this.correction, required this.onTap});

  Color _typeColor(CorrectionType type) {
    switch (type) {
      case CorrectionType.grammar:
        return AppColors.error;
      case CorrectionType.vocabulary:
        return AppColors.warning;
      case CorrectionType.pronunciation:
        return AppColors.accentSecondary;
    }
  }

  String _typeLabel(CorrectionType type) {
    switch (type) {
      case CorrectionType.grammar:
        return 'Grammar';
      case CorrectionType.vocabulary:
        return 'Vocabulary';
      case CorrectionType.pronunciation:
        return 'Pronunciation';
    }
  }

  @override
  Widget build(BuildContext context) {
    final typeColor = _typeColor(correction.type);

    return GlassCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 2),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  _typeLabel(correction.type),
                  style: TextStyle(color: typeColor, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
              const Spacer(),
              Text(
                'Reviewed ${correction.reviewCount}x',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Original
          Row(
            children: [
              const Icon(Icons.close, color: AppColors.error, size: 16),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  correction.original,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.error,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          // Corrected
          Row(
            children: [
              const Icon(Icons.check, color: AppColors.success, size: 16),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  correction.corrected,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          if (correction.explanation != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              correction.explanation!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
