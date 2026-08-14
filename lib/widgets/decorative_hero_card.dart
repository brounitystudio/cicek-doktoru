import 'package:flutter/material.dart';

import '../screens/scan_plant_screen.dart';
import '../services/language_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'app_button.dart';

class DecorativeHeroCard extends StatelessWidget {
  const DecorativeHeroCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.darkGreen, AppColors.green],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkGreen.withValues(alpha: .24),
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -18,
            top: -20,
            child: Icon(
              Icons.eco,
              size: 150,
              color: Colors.white.withValues(alpha: .12),
            ),
          ),
          Positioned(
            right: 10,
            bottom: 8,
            child: Icon(
              Icons.local_florist,
              size: 72,
              color: AppColors.lightGreen.withValues(alpha: .55),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PremiumBadgeLite(),
              const SizedBox(height: 18),
              Text(
                context.tr('Bitkini Tara', 'Scan Your Plant'),
                style: AppTextStyles.display.copyWith(
                  color: Colors.white,
                  fontSize: 32,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 240,
                child: Text(
                  context.tr(
                    'Fotoğraf çek, görüntüye göre muhtemel nedenleri ve bakım adımlarını öğren.',
                    'Take photos and learn likely causes plus care steps from the image.',
                  ),
                  style: AppTextStyles.body.copyWith(
                    color: Colors.white.withValues(alpha: .82),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: 215,
                child: AppButton(
                  label: context.tr(
                    'Fotoğrafla Teşhis Et',
                    'Diagnose by Photo',
                  ),
                  icon: Icons.camera_alt,
                  onPressed: () => Navigator.of(
                    context,
                  ).pushNamed(ScanPlantScreen.routeName),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PremiumBadgeLite extends StatelessWidget {
  const PremiumBadgeLite({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .13),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.spa, color: AppColors.lightGreen, size: 16),
            const SizedBox(width: 6),
            Text(
              context.tr(
                'Görüntüye göre bakım analizi',
                'Image-based care analysis',
              ),
              style: AppTextStyles.muted.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
