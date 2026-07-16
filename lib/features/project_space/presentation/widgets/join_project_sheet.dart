import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/providers.dart';
import '../../../../shared/widgets/glass_widgets.dart';
import '../../domain/project_icon_catalog.dart';
import '../../domain/project_models.dart';
import '../../domain/project_palette.dart';
import 'project_form_dialog.dart';

/// Bottom sheet shown from a content detail screen (chat summary, review,
/// scenarios) to link that content to a project. Returns `true` if a link
/// was created. Caller passes the (contentType, contentId) it wants to link.
class JoinProjectSheet extends ConsumerStatefulWidget {
  final ProjectContentType contentType;
  final String contentId;

  const JoinProjectSheet({
    super.key,
    required this.contentType,
    required this.contentId,
  });

  /// Convenience wrapper used by the three call sites.
  static Future<bool> show(
    BuildContext context, {
    required ProjectContentType contentType,
    required String contentId,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => JoinProjectSheet(
        contentType: contentType,
        contentId: contentId,
      ),
    );
    return result ?? false;
  }

  @override
  ConsumerState<JoinProjectSheet> createState() => _JoinProjectSheetState();
}

class _JoinProjectSheetState extends ConsumerState<JoinProjectSheet> {
  List<Project>? _projects;
  Set<String> _linkedIds = <String>{};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(projectRepoProvider);
    final alreadyLinked =
        await repo.getProjectsForContent(widget.contentType, widget.contentId);
    final linkedIds = alreadyLinked.map((p) => p.id).toSet();
    final projects = await repo.getAllProjects();
    if (mounted) {
      setState(() {
        _projects = projects;
        _linkedIds = linkedIds;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return GlassBottomSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.t('projects.join.title'),
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_projects == null || _projects!.isEmpty)
            _EmptyState(onNew: _onNewProject)
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _projects!.length + 1,
                itemBuilder: (ctx, i) {
                  if (i == _projects!.length) {
                    return ListTile(
                      leading:
                          const Icon(Icons.add, color: AppColors.accentPrimary),
                      title: Text(l.t('projects.join.new_project')),
                      onTap: _onNewProject,
                    );
                  }
                  final p = _projects![i];
                  final linked = _linkedIds.contains(p.id);
                  return ListTile(
                    leading: Icon(
                      ProjectIconCatalog.forName(p.icon),
                      color: ProjectPalette.fromHex(p.color),
                    ),
                    title: Text(p.name),
                    trailing: linked
                        ? const Icon(Icons.check, color: AppColors.success)
                        : null,
                    onTap: linked
                        ? null
                        : () async {
                            await ref.read(projectRepoProvider).addLink(
                                  p.id,
                                  widget.contentType,
                                  widget.contentId,
                                );
                            if (context.mounted) Navigator.pop(context, true);
                          },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _onNewProject() async {
    final created = await showDialog<Project>(
      context: context,
      builder: (_) => const ProjectFormDialog(),
    );
    if (created == null) return;
    await ref.read(projectRepoProvider).addLink(
          created.id,
          widget.contentType,
          widget.contentId,
        );
    if (mounted) Navigator.pop(context, true);
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onNew;
  const _EmptyState({required this.onNew});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder_off_outlined,
              size: 48, color: AppColors.textMuted),
          const SizedBox(height: AppSpacing.md),
          Text(AppLocalizations.of(context).t('projects.join.empty')),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: onNew,
            icon: const Icon(Icons.add),
            label: Text(AppLocalizations.of(context).t('projects.new')),
          ),
        ],
      ),
    );
  }
}
