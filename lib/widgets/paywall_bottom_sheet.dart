import 'package:flutter/material.dart';

import '../screens/premium_screen.dart';
import '../services/ad_config.dart';
import '../services/language_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'reward_ad_button.dart';

Future<bool> showPaywallBottomSheet(BuildContext context) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const _PaywallBottomSheet(),
  );
  return result ?? false;
}

Future<bool> showDailyPremiumOfferBottomSheet(BuildContext context) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const _DailyPremiumOfferBottomSheet(),
  );
  return result ?? false;
}

class _DailyPremiumOfferBottomSheet extends StatelessWidget {
  const _DailyPremiumOfferBottomSheet();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                context.tr(
                  'Bitkilerini düzenli takip et',
                  'Keep tracking your plants',
                ),
                style: AppTextStyles.title,
              ),
              const SizedBox(height: 8),
              Text(
                context.tr(
                  'Premium ile ayda 100 AI destekli analiz, reklamsız kullanım, sınırsız bitki kaydı ve 7 günlük detaylı bakım planları açılır.',
                  'Premium unlocks 100 AI-assisted analyses per month, ad-free use, unlimited saved plants and detailed 7-day care plans.',
                ),
                style: AppTextStyles.body,
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(true),
                icon: const Icon(Icons.workspace_premium_outlined),
                label: Text(context.tr('Premium’u İncele', 'Explore Premium')),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(context.tr('Şimdilik değil', 'Not now')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaywallBottomSheet extends StatelessWidget {
  const _PaywallBottomSheet();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                context.tr('Teşhis hakkın bitti', 'You are out of diagnoses'),
                style: AppTextStyles.title,
              ),
              const SizedBox(height: 8),
              Text(
                context.tr(
                  AdConfig.adsSupported
                      ? 'Bugün ücretsiz hakkını kullandın. Reklam izleyerek 1 ek teşhis hakkı kazanabilir veya Premium’a geçebilirsin.'
                      : 'Bugün ücretsiz hakkını kullandın. Analizlere devam etmek için Premium’a geçebilirsin.',
                  AdConfig.adsSupported
                      ? 'You used today’s free diagnosis. Watch an ad for 1 extra diagnosis or upgrade to Premium.'
                      : 'You used today’s free diagnosis. Upgrade to Premium to keep analyzing.',
                ),
                style: AppTextStyles.body,
              ),
              const SizedBox(height: 18),
              if (AdConfig.adsSupported) ...[
                RewardAdButton(
                  onRewardGranted: (_) {
                    Navigator.of(context).pop(true);
                  },
                ),
                const SizedBox(height: 10),
              ],
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop(false);
                  Navigator.of(context).pushNamed(PremiumScreen.routeName);
                },
                icon: const Icon(Icons.workspace_premium_outlined),
                label: Text(context.tr('Premium’a Geç', 'Upgrade to Premium')),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(context.tr('Vazgeç', 'Cancel')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
