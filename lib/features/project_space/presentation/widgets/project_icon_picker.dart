import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/project_icon_catalog.dart';

class ProjectIconPicker extends StatelessWidget {
  final String selectedName;
  final ValueChanged<String> onSelected;

  const ProjectIconPicker({
    super.key,
    required this.selectedName,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: GridView.builder(
        itemCount: ProjectIconCatalog.allNames.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5,
          mainAxisSpacing: AppSpacing.xs,
          crossAxisSpacing: AppSpacing.xs,
        ),
        itemBuilder: (ctx, i) {
          final name = ProjectIconCatalog.allNames[i];
          final selected = name == selectedName;
          return InkWell(
            onTap: () => onSelected(name),
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Container(
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.accentPrimary.withValues(alpha: 0.18)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: selected
                      ? AppColors.accentPrimary
                      : AppColors.glassBorder,
                ),
              ),
              child: Icon(
                ProjectIconCatalog.forName(name),
                color: selected
                    ? AppColors.accentPrimary
                    : AppColors.textSecondary,
                size: 22,
              ),
            ),
          );
        },
      ),
    );
  }
}
