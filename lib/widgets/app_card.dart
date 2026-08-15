import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'botanical_card_pattern.dart';

enum AppCardVariant { elevated, flat, tinted }

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color = AppColors.card,
    this.radius = 24,
    this.pattern,
    this.showPattern = true,
    this.variant = AppCardVariant.elevated,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final double radius;
  final BotanicalPatternTone? pattern;
  final bool showPattern;
  final AppCardVariant variant;

  @override
  Widget build(BuildContext context) {
    final onDark = color.computeLuminance() < .35;
    final decoration = switch (variant) {
      AppCardVariant.elevated => BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.card.withValues(alpha: .75)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      AppCardVariant.flat => BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
      AppCardVariant.tinted => BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: .08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
    };
    final shouldShowPattern = variant != AppCardVariant.flat && showPattern;

    return DecoratedBox(
      decoration: decoration,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          children: [
            if (shouldShowPattern)
              BotanicalCardPattern(
                tone: pattern ?? _patternFor(color),
                onDark: onDark,
              ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }

  BotanicalPatternTone _patternFor(Color color) {
    final value = color.toARGB32();
    return switch (value % 3) {
      0 => BotanicalPatternTone.jasmine,
      1 => BotanicalPatternTone.vine,
      _ => BotanicalPatternTone.meadow,
    };
  }
}
