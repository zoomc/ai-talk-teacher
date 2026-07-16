/// Phase 5 — Weak area card widget.
///
/// Displays a persistent weak area with its type icon, description,
/// frequency badge, and severity colour coding.
library;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../domain/progress_models.dart';

class WeakAreaCard extends StatelessWidget {
  final WeakArea area;
  final bool isLight;

  const WeakAreaCard({super.key, required this.area, required this.isLight});

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(area.areaType);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatAreaType(area.areaType),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                Text(
                  area.description,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '×${area.frequencyCount}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'pronunciation':
        return AppColors.accentSecondary;
      case 'grammar':
        return AppColors.error;
      case 'vocabulary':
        return AppColors.warning;
      case 'fluency':
        return AppColors.info;
      default:
        return AppColors.textSecondary;
    }
  }

  String _formatAreaType(String type) {
    switch (type) {
      case 'pronunciation':
        return 'Pronunciation';
      case 'grammar':
        return 'Grammar';
      case 'vocabulary':
        return 'Vocabulary';
      case 'fluency':
        return 'Fluency';
      default:
        return type;
    }
  }
}
