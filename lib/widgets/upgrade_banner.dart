import 'package:flutter/material.dart';

import '../screens/premium_screen.dart';
import '../services/language_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'app_button.dart';
import 'app_card.dart';

class UpgradeBanner extends StatelessWidget {
  const UpgradeBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.warmCream,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.workspace_premium_outlined,
                color: AppColors.soil,
              ),
              const SizedBox(width: 8),
              Text(
                context.tr('Premium Bakım', 'Premium Care'),
                style: AppTextStyles.section.copyWith(
                  color: AppColors.darkGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            context.tr(
              'Ayda 100 detaylı AI teşhis, reklamsız kullanım ve 7 günlük bakım planları.',
              '100 detailed AI diagnoses per month, ad-free use and 7-day care plans.',
            ),
            style: AppTextStyles.body,
          ),
          const SizedBox(height: 14),
          AppButton(
            label: context.tr('Premium’a Geç', 'Upgrade to Premium'),
            icon: Icons.arrow_forward,
            onPressed: () =>
                Navigator.of(context).pushNamed(PremiumScreen.routeName),
          ),
        ],
      ),
    );
  }
}
