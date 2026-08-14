import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class OnboardingIndicator extends StatelessWidget {
  const OnboardingIndicator({
    super.key,
    required this.activeIndex,
    required this.itemCount,
  });

  final int activeIndex;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(itemCount, (index) {
        final isActive = activeIndex == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          width: isActive ? 34 : 9,
          height: 9,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: isActive ? AppColors.darkGreen : AppColors.border,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: isActive
                  ? AppColors.green.withValues(alpha: .34)
                  : Colors.white.withValues(alpha: .78),
            ),
          ),
        );
      }),
    );
  }
}
