/// Phase 5 — Enhanced history screen with session continuity features.
///
/// Shows conversation history with enriched metadata (duration, message
/// count, correction count), auto-generated summaries, topic search/filter,
/// and links to the pronunciation detail screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/util/responsive.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../shared/widgets/glass_widgets.dart';
import '../../../../shared/providers.dart';
import '../../../../features/home/presentation/home_providers.dart';
import '../../data/session_continuity_service.dart';
import '../../domain/chat_models.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = true;
  List<({ChatSession session, SessionMetadata? meta})> _enrichedSessions = [];
  List<({ChatSession session, SessionMetadata? meta})> _filtered = [];

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSessions() async {
    final repo = ref.read(chatRepoProvider);
    final continuity = await _getContinuityService(ref);
    final enriched = await continuity.getEnrichedSessionHistory();
    if (mounted) {
      setState(() {
        _enrichedSessions = enriched;
        _filtered = enriched;
        _isLoading = false;
      });
    }
  }

  SessionContinuityService _getContinuityService(WidgetRef ref) {
    final repo = ref.read(chatRepoProvider);
    return SessionContinuityService(repo);
  }

  void _filter(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filtered = _enrichedSessions;
      } else {
        final q = query.toLowerCase();
        _filtered = _enrichedSessions.where((e) {
          final s = e.session;
          final meta = e.meta;
          return (s.topic?.toLowerCase().contains(q) ?? false) ||
              (meta?.summary?.toLowerCase().contains(q) ?? false) ||
              (meta?.topicTags.any((t) => t.toLowerCase().contains(q)) ?? false);
        }).toList();
      }
    });
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(dt.year, dt.month, dt.day);
    final diffDays = today.difference(that).inDays;
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    if (diffDays == 0) {
      return 'Today, $hh:$mm';
    } else if (diffDays == 1) {
      return 'Yesterday, $hh:$mm';
    } else if (diffDays < 7) {
      return '$diffDays days ago';
    } else {
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      return '$m/$d/${dt.year}';
    }
  }

  String _formatDuration(int seconds) {
    final min = seconds ~/ 60;
    if (min < 60) return '${min}m';
    return '${min ~/ 60}h ${min % 60}m';
  }

  Future<void> _confirmDelete(ChatSession session) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.t('common.delete')),
        content: Text(
          'Are you sure you want to delete "${session.topic ?? 'Free Talk'}"? '
          'This also removes its messages and corrections.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.t('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              l.t('common.delete'),
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(chatRepoProvider).deleteSession(session.id);
      if (mounted) {
        setState(() {
          _enrichedSessions.removeWhere((e) => e.session.id == session.id);
          _filtered.removeWhere((e) => e.session.id == session.id);
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.t('common.deleted'))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: ${_safeError(e)}')),
        );
      }
    }
  }

  String _safeError(Object e) {
    final raw = e.toString();
    if (raw.length > 120) return '${raw.substring(0, 120)}...';
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.pop(),
        ),
        title: Text(l.t('history.title')),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient:
              isLight ? AppColors.lightGradientBg : AppColors.gradientBg,
        ),
        child: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: Responsive.contentMaxWidth(context),
              ),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _enrichedSessions.isEmpty
                      ? _buildEmptyState(context, l)
                      : _buildList(context, l),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppLocalizations l) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.history, size: 64, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.md),
            Text(
              l.t('history.empty'),
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: () => context.go('/'),
              child: Text(l.t('history.go_home')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, AppLocalizations l) {
    return CustomScrollView(
      slivers: [
        // Search bar
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
            child: TextField(
              controller: _searchController,
              onChanged: _filter,
              decoration: InputDecoration(
                hintText: l.t('history.search_hint'),
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _filter('');
                        },
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ),
        // Count header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(
              '${_filtered.length} ${l.t('history.conversations')}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ),
        // Session list
        SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final entry = _filtered[index];
            final session = entry.session;
            final meta = entry.meta;
            return Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xs,
              ),
              child: GlassCard(
                onTap: () => context.push('/chat/${session.id}'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.accentPrimary
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: const Icon(
                            Icons.chat_bubble_outline,
                            color: AppColors.accentPrimary,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                session.topic ?? 'Free Talk',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _formatTime(session.updatedAt),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        // Pre listen button for pronunciation
                        TextButton.icon(
                          onPressed: () => context.push(
                              '/pronunciation/${session.id}'),
                          icon: const Icon(Icons.volume_up, size: 14),
                          label: const Text('Score',
                              style: TextStyle(fontSize: 11)),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        IconButton(
                          tooltip: l.t('common.delete'),
                          icon: const Icon(
                            Icons.delete_outline,
                            color: AppColors.textMuted,
                            size: 20,
                          ),
                          onPressed: () => _confirmDelete(session),
                        ),
                      ],
                    ),
                    // Metadata row
                    if (meta != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: Row(
                          children: [
                            _MetaChip(
                              icon: Icons.timer_outlined,
                              label: _formatDuration(meta.durationSeconds),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            _MetaChip(
                              icon: Icons.message_outlined,
                              label: '${meta.messageCount}',
                            ),
                            if (meta.correctionCount > 0) ...[
                              const SizedBox(width: AppSpacing.sm),
                              _MetaChip(
                                icon: Icons.check_circle_outline,
                                label: '${meta.correctionCount}',
                              ),
                            ],
                          ],
                        ),
                      ),
                    // Summary (truncated)
                    if (meta?.summary != null &&
                        meta!.summary!.isNotEmpty &&
                        meta.summary!.length > 5)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: Text(
                          meta.summary!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }, childCount: _filtered.length),
        ),
        const SliverToBoxAdapter(
          child: SizedBox(height: AppSpacing.xxl),
        ),
      ],
    );
  }
}

/// Small metadata chip for duration/count.
class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.glassBorder.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
