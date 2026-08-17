import 'dart:ui';

import 'package:flutter/material.dart';

import '../data/evidence_based_care_tips.dart';
import '../models/diagnosis_result.dart';
import '../screens/premium_screen.dart';
import '../services/entitlement_service.dart';
import '../services/language_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'paywall_bottom_sheet.dart';

class PremiumCareTips extends StatelessWidget {
  const PremiumCareTips({
    super.key,
    required this.profile,
    this.isPremiumOverride,
    this.showLockedPreview = true,
  });

  final PlantCareProfile profile;
  final bool? isPremiumOverride;
  final bool showLockedPreview;

  @override
  Widget build(BuildContext context) {
    final speciesTips = profile.specialTips
        .where((tip) => tip.trim().isNotEmpty)
        .toList();
    final evidenceTips = evidenceBasedCareTipsFor(profile);
    final allTips = <_VisibleCareTip>[
      ...speciesTips.map((tip) => _VisibleCareTip(turkish: tip, english: tip)),
      ...evidenceTips.map(
        (tip) => _VisibleCareTip(
          turkish: tip.turkish,
          english: tip.english,
          sourceName: tip.sourceName,
        ),
      ),
    ];
    if (allTips.isEmpty) {
      return const SizedBox.shrink();
    }
    final freeTip = allTips.first;
    final premiumTips = allTips.skip(1).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        Text(
          context.tr('Bitkiye özel ipucu', 'Plant-specific tip'),
          style: AppTextStyles.muted,
        ),
        const SizedBox(height: 8),
        _TipLine(
          text: context.tr(freeTip.turkish, freeTip.english),
          icon: Icons.lightbulb_outline,
        ),
        if (isPremiumOverride case final isPremium?)
          isPremium
              ? _PremiumTipsOpen(tips: premiumTips)
              : showLockedPreview
              ? _PremiumTipsLocked(tips: premiumTips)
              : const SizedBox.shrink()
        else
          ValueListenableBuilder<int>(
            valueListenable: EntitlementService.revision,
            builder: (context, revision, _) {
              return FutureBuilder(
                key: ValueKey(revision),
                future: EntitlementService().getCurrentPlan(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: LinearProgressIndicator(minHeight: 2),
                    );
                  }
                  if (snapshot.data?.isPremium == true) {
                    return _PremiumTipsOpen(tips: premiumTips);
                  }
                  return showLockedPreview
                      ? _PremiumTipsLocked(tips: premiumTips)
                      : const SizedBox.shrink();
                },
              );
            },
          ),
      ],
    );
  }
}

class _PremiumTipsOpen extends StatelessWidget {
  const _PremiumTipsOpen({required this.tips});

  final List<_VisibleCareTip> tips;

  @override
  Widget build(BuildContext context) {
    if (tips.isEmpty) {
      return const SizedBox.shrink();
    }
    final sources = tips
        .map((tip) => tip.sourceName)
        .whereType<String>()
        .toSet()
        .join(' • ');
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.workspace_premium_outlined,
                color: AppColors.green,
                size: 19,
              ),
              const SizedBox(width: 7),
              Text(
                context.tr('Premium bakım sırları', 'Premium care insights'),
                style: AppTextStyles.muted.copyWith(
                  color: AppColors.darkGreen,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...tips.map(
            (tip) => _TipLine(
              text: context.tr(tip.turkish, tip.english),
              icon: Icons.auto_awesome,
            ),
          ),
          if (sources.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                context.tr('Kaynak temeli: $sources', 'Source basis: $sources'),
                style: AppTextStyles.muted.copyWith(fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }
}

class _PremiumTipsLocked extends StatelessWidget {
  const _PremiumTipsLocked({required this.tips});

  final List<_VisibleCareTip> tips;

  @override
  Widget build(BuildContext context) {
    if (tips.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: InkWell(
        onTap: () => _openPremium(context),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.darkGreen.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.lock_outline,
                    color: AppColors.darkGreen,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.tr(
                        '${tips.length} özel ipucu daha',
                        '${tips.length} more special tips',
                      ),
                      style: AppTextStyles.muted.copyWith(
                        color: AppColors.darkGreen,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                context.tr(
                  'Ev tipi karışımlar, sulama ve bitkiye özel bakım ayrıntıları Premium’da.',
                  'Home-remedy guidance, watering and plant-specific care details are in Premium.',
                ),
                style: AppTextStyles.muted.copyWith(fontSize: 12),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 64,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ExcludeSemantics(
                      child: ImageFiltered(
                        imageFilter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: tips
                              .take(2)
                              .map(
                                (tip) => Text(
                                  context.tr(tip.turkish, tip.english),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.body,
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                    Center(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.darkGreen,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          child: Text(
                            context.tr(
                              'Premium ile ipuçlarını aç',
                              'Unlock tips with Premium',
                            ),
                            style: AppTextStyles.muted.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openPremium(BuildContext context) async {
    final openPremium = await showPaywallBottomSheet(context);
    if (context.mounted && openPremium) {
      await Navigator.of(context).pushNamed(PremiumScreen.routeName);
    }
  }
}

class _TipLine extends StatelessWidget {
  const _TipLine({required this.text, required this.icon});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, color: AppColors.green, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: AppTextStyles.body)),
        ],
      ),
    );
  }
}

class _VisibleCareTip {
  const _VisibleCareTip({
    required this.turkish,
    required this.english,
    this.sourceName,
  });

  final String turkish;
  final String english;
  final String? sourceName;
}
