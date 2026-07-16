import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/project_models.dart';

class ActivityTile extends StatelessWidget {
  final ProjectActivity activity;
  const ActivityTile({super.key, required this.activity});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final icon = _iconFor(activity.type);
    final color = _colorFor(activity.type);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.t('projects.activity.${activity.type.name}'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 2),
              Text(
                _summary(activity),
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColors.textMuted),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Text(
          _relativeTime(activity.createdAt),
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: AppColors.textMuted),
        ),
      ],
    );
  }

  String _summary(ProjectActivity a) {
    switch (a.type) {
      case ProjectActivityType.projectCreated:
        return a.payload['name']?.toString() ?? '';
      case ProjectActivityType.projectEdited:
        return a.payload['name']?.toString() ?? '';
      case ProjectActivityType.statusChanged:
        return '${a.payload['from'] ?? ''} → ${a.payload['to'] ?? ''}';
      case ProjectActivityType.linkAdded:
      case ProjectActivityType.linkRemoved:
        return '${a.payload['content_type'] ?? ''} · ${a.payload['content_id'] ?? ''}';
    }
  }

  IconData _iconFor(ProjectActivityType t) => switch (t) {
        ProjectActivityType.projectCreated => Icons.add_circle_outline,
        ProjectActivityType.projectEdited => Icons.edit_outlined,
        ProjectActivityType.statusChanged => Icons.swap_vert,
        ProjectActivityType.linkAdded => Icons.link,
        ProjectActivityType.linkRemoved => Icons.link_off,
      };

  Color _colorFor(ProjectActivityType t) => switch (t) {
        ProjectActivityType.projectCreated => AppColors.success,
        ProjectActivityType.projectEdited => AppColors.accentPrimary,
        ProjectActivityType.statusChanged => AppColors.warning,
        ProjectActivityType.linkAdded => AppColors.accentSecondary,
        ProjectActivityType.linkRemoved => AppColors.error,
      };

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dt.month}/${dt.day}';
  }
}
