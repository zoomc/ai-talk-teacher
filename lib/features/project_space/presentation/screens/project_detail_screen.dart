import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/providers.dart';
import '../../domain/project_icon_catalog.dart';
import '../../domain/project_models.dart';
import '../../domain/project_palette.dart';
import '../widgets/activity_tile.dart';
import '../widgets/project_form_dialog.dart';

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
          orElse: () => const Text(''),
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
        error: (e, _) => Center(child: Text('$e')),
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
                  Text(
                    l.t('projects.status.${project.status.name}'),
                    style: TextStyle(color: color),
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
                  leading: const Icon(Icons.link),
                  title: Text(link.contentId),
                  subtitle: Text(_relativeTime(link.createdAt)),
                  trailing: IconButton(
                    icon: const Icon(Icons.link_off, size: 20),
                    onPressed: () async {
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
      error: (e, _) => Center(child: Text('$e')),
    );
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inHours < 24) return 'today';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${dt.month}/${dt.day}';
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
          separatorBuilder: (_, __) => const Divider(height: AppSpacing.lg),
          itemBuilder: (ctx, i) => ActivityTile(activity: acts[i]),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
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
          value: project.status,
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
        FilledButton.tonalIcon(
          style: FilledButton.styleFrom(
            foregroundColor: AppColors.error,
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
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(l.t('common.delete')),
                  ),
                ],
              ),
            );
            if (confirmed == true && context.mounted) {
              await ref.read(projectRepoProvider).deleteProject(project.id);
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
