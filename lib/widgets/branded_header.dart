import 'package:flutter/material.dart';

import '../screens/premium_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'logo_mark.dart';

class BrandedHeader extends StatelessWidget {
  const BrandedHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
    this.showPremium = true,
  });

  final String eyebrow;
  final String title;
  final String? subtitle;
  final bool showPremium;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const LogoMark(size: 54),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow,
                  style: AppTextStyles.muted.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                _Wordmark(title: title),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!, style: AppTextStyles.muted),
                ],
              ],
            ),
          ),
          if (showPremium)
            IconButton.filledTonal(
              tooltip: 'Premium',
              onPressed: () =>
                  Navigator.of(context).pushNamed(PremiumScreen.routeName),
              icon: const Icon(Icons.workspace_premium_outlined),
            ),
        ],
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.title.copyWith(color: AppColors.darkGreen),
          ),
        ),
        const SizedBox(width: 4),
        Transform.rotate(
          angle: -.55,
          child: const Icon(Icons.eco, color: AppColors.leaf, size: 18),
        ),
      ],
    );
  }
}
