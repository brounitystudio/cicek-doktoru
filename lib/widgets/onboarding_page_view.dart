import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'onboarding_hero_illustration.dart';

class OnboardingPageData {
  const OnboardingPageData({
    required this.title,
    required this.description,
    required this.illustration,
  });

  final String title;
  final String description;
  final OnboardingIllustrationType illustration;
}

class OnboardingPageView extends StatelessWidget {
  const OnboardingPageView({super.key, required this.data});

  final OnboardingPageData data;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 610;
        return Column(
          children: [
            Expanded(
              flex: compact ? 7 : 8,
              child: Padding(
                padding: EdgeInsets.only(
                  top: compact ? 4 : 12,
                  bottom: compact ? 8 : 16,
                ),
                child: OnboardingHeroIllustration(type: data.illustration),
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                children: [
                  Text(
                    data.title,
                    textAlign: TextAlign.center,
                    maxLines: compact ? 2 : 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.title.copyWith(
                      color: AppColors.ink,
                      fontSize: compact ? 23 : 27,
                      height: 1.14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    data.description,
                    textAlign: TextAlign.center,
                    maxLines: compact ? 2 : 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.muted,
                      fontSize: compact ? 14 : 15,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
