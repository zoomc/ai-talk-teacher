import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/glass_widgets.dart';
import '../../domain/project_icon_catalog.dart';
import '../../domain/project_models.dart';
import '../../domain/project_palette.dart';

class ProjectCard extends StatelessWidget {
  final Project project;
  final VoidCallback onTap;

  const ProjectCard({super.key, required this.project, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = ProjectPalette.fromHex(project.color);
    return GlassCard(
      onTap: onTap,
      borderRadius: AppRadius.xl,
      glowColor: color.withValues(alpha: 0.4),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: color.withValues(alpha: 0.4)),
                ),
                child: Icon(
                  ProjectIconCatalog.forName(project.icon),
                  color: color,
                  size: 20,
                ),
              ),
              const Spacer(),
              _StatusDot(status: project.status),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            project.name,
            style: Theme.of(context).textTheme.titleMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (project.goal.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              project.goal,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.textMuted),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const Spacer(),
          if (project.lastActivityAt != null)
            Text(
              _relativeTime(project.lastActivityAt!),
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.textMuted),
            ),
        ],
      ),
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

class _StatusDot extends StatelessWidget {
  final ProjectStatus status;
  const _StatusDot({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      ProjectStatus.active => AppColors.success,
      ProjectStatus.archived => AppColors.textMuted,
      ProjectStatus.completed => AppColors.accentSecondary,
    };
    return Tooltip(
      message: status.name,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}
