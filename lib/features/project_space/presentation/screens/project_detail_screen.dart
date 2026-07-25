import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/providers.dart';
import '../../../../shared/widgets/glass_widgets.dart';
import '../../domain/project_icon_catalog.dart';
import '../../domain/project_models.dart';
import '../../domain/project_palette.dart';
import '../widgets/activity_tile.dart';
import '../widgets/project_form_dialog.dart';
import 'projects_screen.dart';

final _projectProvider =
    FutureProvider.family<Project?, String>((ref, id) async {
  final repo = ref.watch(projectRepoProvider);
  return repo.getProject(id);
});

final _linksProvider =
    FutureProvider.family<List<ProjectLink>, String>((ref, id) async {
  final repo = ref.watch(projectRepoProvider);
  return repo.getLinksForProject(id);
});

final _activitiesProvider =
    FutureProvider.family<List<ProjectActivity>, String>((ref, id) async {
  final repo = ref.watch(projectRepoProvider);
  return repo.getActivitiesForProject(id);
});

class ProjectDetailScreen extends ConsumerWidget {
  final String projectId;
  const ProjectDetailScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_projectProvider(projectId));
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.light
          ? AppColors.lightBgPrimary
          : AppColors.bgPrimary,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.pop(),
        ),
        title: async.maybeWhen(
          data: (p) => Text(p?.name ?? ''),
          orElse: () => ShimmerBox(width: 120, height: 20, borderRadius: AppRadius.sm),
        ),
        actions: [
          async.maybeWhen(
            data: (p) => p == null
                ? const SizedBox.shrink()
                : IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () async {
                      final saved = await showDialog<Project>(
                        context: context,
                        builder: (_) => ProjectFormDialog(project: p),
                      );
                      if (saved != null && context.mounted) {
                        ref.invalidate(_projectProvider(projectId));
                        ref.invalidate(_linksProvider(projectId));
                        ref.invalidate(_activitiesProvider(projectId));
                      }
                    },
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: async.when(
        data: (p) {
          if (p == null) {
            return Center(child: Text(l.t('projects.not_found')));
          }
          return DefaultTabController(
            length: 4,
            child: Column(
              children: [
                TabBar(
                  tabs: [
                    Tab(text: l.t('projects.tabs.overview')),
                    Tab(text: l.t('projects.tabs.links')),
                    Tab(text: l.t('projects.tabs.activity')),
                    Tab(text: l.t('projects.tabs.settings')),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _OverviewTab(project: p),
                      _LinksTab(projectId: projectId),
                      _ActivityTab(projectId: projectId),
                      _SettingsTab(project: p),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              l.tArg('projects.error_loading', {'error': '$e'}),
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ),
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  final Project project;
  const _OverviewTab({required this.project});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final color = ProjectPalette.fromHex(project.color);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: color.withValues(alpha: 0.4)),
              ),
              child: Icon(ProjectIconCatalog.forName(project.icon),
                  color: color, size: 28),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(project.name,
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: AppSpacing.xs),
                  StatusPill(
                    text: l.t('projects.status.${project.status.name}'),
                    color: color,
                    isActive: project.status == ProjectStatus.active,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (project.description.isNotEmpty) ...[
          Text(l.t('projects.dialog.description_label'),
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(project.description),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (project.goal.isNotEmpty) ...[
          Text(l.t('projects.dialog.goal_label'),
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(project.goal),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (project.topics.isNotEmpty) ...[
          Text(l.t('projects.overview.topics'),
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: project.topics
                .map((t) => Chip(
                      label: Text(t),
                      backgroundColor: color.withValues(alpha: 0.12),
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }
}

class _LinksTab extends ConsumerWidget {
  final String projectId;
  const _LinksTab({required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_linksProvider(projectId));
    final l = AppLocalizations.of(context);
    return async.when(
      data: (links) {
        if (links.isEmpty) {
          return Center(child: Text(l.t('projects.links.empty')));
        }
        final grouped = <ProjectContentType, List<ProjectLink>>{};
        for (final link in links) {
          grouped.putIfAbsent(link.contentType, () => []).add(link);
        }
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            for (final entry in grouped.entries) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Text(
                  l.t('projects.links.type.${entry.key.name}'),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.textSecondary),
                ),
              ),
              for (final link in entry.value)
                ListTile(
                  leading: Icon(_iconFor(link.contentType)),
                  title: FutureBuilder<String>(
                    future: _resolveLinkTitle(context, ref, link),
                    builder: (ctx, snap) => Text(
                      snap.data ?? link.contentId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  subtitle: Text(_relativeTime(context, l, link.createdAt)),
                  trailing: IconButton(
                    icon: const Icon(Icons.link_off, size: 20),
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(l.t('projects.links.confirm_remove_title')),
                          content: Text(l.t('projects.links.confirm_remove_body')),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text(l.t('common.cancel')),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: Text(l.t('common.remove')),
                            ),
                          ],
                        ),
                      );
                      if (confirmed != true) return;
                      await ref
                          .read(projectRepoProvider)
                          .removeLink(link.id);
                      ref.invalidate(_linksProvider(projectId));
                      ref.invalidate(_activitiesProvider(projectId));
                    },
                  ),
                ),
            ],
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            l.tArg('projects.error_loading', {'error': '$e'}),
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.error),
          ),
        ),
      ),
    );
  }

  String _relativeTime(BuildContext context, AppLocalizations l, DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inHours < 24) return l.t('history.today').toLowerCase();
    if (diff.inDays == 1) return l.t('history.yesterday').toLowerCase();
    if (diff.inDays < 7) {
      return l.tArg('history.days_ago', {'days': '${diff.inDays}'});
    }
    return DateFormat.Md(Localizations.localeOf(context).toString()).format(dt);
  }

  Future<String> _resolveLinkTitle(BuildContext context, WidgetRef ref, ProjectLink link) async {
    final l = AppLocalizations.of(context);
    final chatRepo = ref.read(chatRepoProvider);
    switch (link.contentType) {
      case ProjectContentType.chatSession:
        final session = await chatRepo.getSession(link.contentId);
        return session?.topic ?? link.contentId;
      case ProjectContentType.scenario:
        final scenario = await chatRepo.getScenario(link.contentId);
        return scenario?.name ?? link.contentId;
      case ProjectContentType.correction:
        return '${l.t('projects.links.type.correction')} ${link.contentId.substring(0, link.contentId.length > 8 ? 8 : link.contentId.length)}';
    }
  }

  IconData _iconFor(ProjectContentType type) {
    switch (type) {
      case ProjectContentType.chatSession:
        return Icons.chat_bubble_outline;
      case ProjectContentType.scenario:
        return Icons.grid_view;
      case ProjectContentType.correction:
        return Icons.check_circle_outline;
    }
  }
}

class _ActivityTab extends ConsumerWidget {
  final String projectId;
  const _ActivityTab({required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_activitiesProvider(projectId));
    final l = AppLocalizations.of(context);
    return async.when(
      data: (acts) {
        if (acts.isEmpty) {
          return Center(child: Text(l.t('projects.activity.empty')));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: acts.length,
          separatorBuilder: (_, _) => const Divider(height: AppSpacing.md),
          itemBuilder: (ctx, i) => ActivityTile(activity: acts[i]),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            l.tArg('projects.error_loading', {'error': '$e'}),
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.error),
          ),
        ),
      ),
    );
  }
}

class _SettingsTab extends ConsumerWidget {
  final Project project;
  const _SettingsTab({required this.project});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(l.t('projects.dialog.status_label'),
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        DropdownButtonFormField<ProjectStatus>(
          initialValue: project.status,
          items: ProjectStatus.values
              .map((s) => DropdownMenuItem(
                    value: s,
                    child: Text(l.t('projects.status.${s.name}')),
                  ))
              .toList(),
          onChanged: (v) async {
            if (v == null || v == project.status) return;
            await ref.read(projectRepoProvider).updateProject(
                  project.copyWith(status: v),
                );
            ref.invalidate(_projectProvider(project.id));
            ref.invalidate(_activitiesProvider(project.id));
          },
        ),
        const SizedBox(height: AppSpacing.xl),
        FilledButton.tonalIcon(
          onPressed: () async {
            final saved = await showDialog<Project>(
              context: context,
              builder: (_) => ProjectFormDialog(project: project),
            );
            if (saved != null) {
              ref.invalidate(_projectProvider(project.id));
            }
          },
          icon: const Icon(Icons.edit_outlined),
          label: Text(l.t('projects.settings.edit')),
        ),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.error,
            minimumSize: const Size.fromHeight(44),
          ),
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(l.t('projects.settings.confirm_delete_title')),
                content: Text(l.t('projects.settings.confirm_delete_body')),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(l.t('common.cancel')),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: AppColors.textOnAccent,
                    ),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(l.t('common.delete')),
                  ),
                ],
              ),
            );
            if (confirmed == true && context.mounted) {
              await ref.read(projectRepoProvider).deleteProject(project.id);
              ref.invalidate(projectsProvider);
              ref.invalidate(_linksProvider(project.id));
              ref.invalidate(_activitiesProvider(project.id));
              if (context.mounted) context.pop();
            }
          },
          icon: const Icon(Icons.delete_outline),
          label: Text(l.t('projects.settings.delete')),
        ),
      ],
    );
  }
}
