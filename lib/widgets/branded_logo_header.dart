import 'package:flutter/material.dart';

import '../services/language_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'logo_mark.dart';

class BrandedLogoHeader extends StatelessWidget {
  const BrandedLogoHeader({super.key, required this.onSkip});

  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .78),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: .8)),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow.withValues(alpha: .22),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const LogoMark(size: 48),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.tr('Çiçek Doktoru', 'Plant Doctor'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.section.copyWith(
                  color: AppColors.darkGreen,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                context.tr(
                  'Bitkileriniz iyi, siz rahat olun',
                  'Healthy plants, peace of mind',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.muted.copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: onSkip,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.green,
            textStyle: AppTextStyles.button,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
          child: Text(context.tr('Geç', 'Skip')),
        ),
      ],
    );
  }
}
