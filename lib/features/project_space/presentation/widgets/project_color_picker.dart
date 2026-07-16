import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/project_palette.dart';

class ProjectColorPicker extends StatelessWidget {
  final String selectedHex;
  final ValueChanged<String> onSelected;

  const ProjectColorPicker({
    super.key,
    required this.selectedHex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: ProjectPalette.presetHexes.map((hex) {
        final color = ProjectPalette.fromHex(hex);
        final selected = hex.toUpperCase() == selectedHex.toUpperCase();
        return GestureDetector(
          onTap: () => onSelected(hex),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected
                    ? AppColors.textPrimary
                    : AppColors.glassBorder,
                width: selected ? 3 : 1,
              ),
            ),
            child: selected
                ? const Icon(Icons.check,
                    color: AppColors.textOnAccent, size: 18)
                : null,
          ),
        );
      }).toList(),
    );
  }
}
