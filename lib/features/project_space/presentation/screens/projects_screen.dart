import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/util/responsive.dart';
import '../../../../shared/providers.dart';
import '../../../../shared/widgets/glass_widgets.dart';
import '../../domain/project_models.dart';
import '../widgets/project_card.dart';
import '../widgets/project_form_dialog.dart';

final projectsProvider = FutureProvider<List<Project>>((ref) async {
  final repo = ref.watch(projectRepoProvider);
  return repo.getAllProjects();
});

class ProjectsScreen extends ConsumerWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(projectsProvider);
    final l = AppLocalizations.of(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: Theme.of(context).brightness == Brightness.light
              ? AppColors.lightGradientBg
              : AppColors.gradientBg,
        ),
        child: SafeArea(
          child: async.when(
            data: (projects) => _ProjectsBody(
              projects: projects,
              onOpen: (p) => context.push('/project/${p.id}'),
              onNew: () => _openNewDialog(context, ref),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('${l.t('projects.load_error')}: $e')),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openNewDialog(context, ref),
        icon: const Icon(Icons.add),
        label: Text(l.t('projects.new')),
      ),
    );
  }

  Future<void> _openNewDialog(BuildContext context, WidgetRef ref) async {
    final created = await showDialog<Project>(
      context: context,
      builder: (_) => const ProjectFormDialog(),
    );
    if (created != null) {
      ref.invalidate(projectsProvider);
    }
  }
}

class _ProjectsBody extends StatelessWidget {
  final List<Project> projects;
  final ValueChanged<Project> onOpen;
  final VoidCallback onNew;

  const _ProjectsBody({
    required this.projects,
    required this.onOpen,
    required this.onNew,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (projects.isEmpty) {
      return _EmptyState(onNew: onNew, label: l.t('projects.empty.title'));
    }
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.t('projects.title'),
                    style: Theme.of(context).textTheme.displayLarge),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l.t('projects.subtitle'),
                  style: Theme.of(context).textTheme.bodyLarge
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: Responsive.isPhone(context) ? 180 : 240,
              mainAxisSpacing: AppSpacing.md,
              crossAxisSpacing: AppSpacing.md,
              childAspectRatio: 0.85,
            ),
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => ProjectCard(
                project: projects[i],
                onTap: () => onOpen(projects[i]),
              ),
              childCount: projects.length,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onNew;
  final String label;
  const _EmptyState({required this.onNew, required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open,
                size: 64, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.md),
            Text(label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: onNew,
              icon: const Icon(Icons.add),
              label: Text(AppLocalizations.of(context).t('projects.new')),
            ),
          ],
        ),
      ),
    );
  }
}
