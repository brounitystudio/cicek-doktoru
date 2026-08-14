import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'app_card.dart';
import 'botanical_card_pattern.dart';
import 'premium_badge.dart';

class TaskSummaryCard extends StatelessWidget {
  const TaskSummaryCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.badge,
    this.color = AppColors.green,
  });

  final IconData icon;
  final String title;
  final String value;
  final String badge;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      pattern: _patternFor(color),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .13),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(value, style: AppTextStyles.muted),
              ],
            ),
          ),
          PremiumBadge(label: badge, tone: color),
        ],
      ),
    );
  }

  BotanicalPatternTone _patternFor(Color color) {
    if (color == AppColors.warning) {
      return BotanicalPatternTone.jasmine;
    }
    if (color == AppColors.soil) {
      return BotanicalPatternTone.meadow;
    }
    return BotanicalPatternTone.vine;
  }
}
