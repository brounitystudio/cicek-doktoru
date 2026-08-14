import 'package:flutter/material.dart';

import '../services/language_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'app_card.dart';

class HealthScoreCard extends StatelessWidget {
  const HealthScoreCard({super.key, required this.score, required this.status});

  final int score;
  final String status;

  Color get _color {
    if (score >= 80) return AppColors.green;
    if (score >= 50) return AppColors.warning;
    return AppColors.critical;
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          SizedBox(
            width: 76,
            height: 76,
            child: CircularProgressIndicator(
              value: score / 100,
              strokeWidth: 9,
              color: _color,
              backgroundColor: _color.withValues(alpha: .16),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Bitki Sağlığı: %$score', 'Plant Health: $score%'),
                  style: AppTextStyles.section,
                ),
                const SizedBox(height: 6),
                Text(
                  status,
                  style: AppTextStyles.title.copyWith(color: _color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
