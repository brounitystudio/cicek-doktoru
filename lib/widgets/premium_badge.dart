import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class PremiumBadge extends StatelessWidget {
  const PremiumBadge({
    super.key,
    required this.label,
    this.tone = AppColors.green,
  });

  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tone.withValues(alpha: .13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tone.withValues(alpha: .22)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: TextStyle(
            color: tone,
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
