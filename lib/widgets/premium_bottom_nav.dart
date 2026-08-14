import 'package:flutter/material.dart';

import '../services/language_service.dart';
import '../theme/app_colors.dart';

class PremiumBottomNav extends StatelessWidget {
  const PremiumBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final items = [
      _NavItem(
        context.tr('Ana Sayfa', 'Home'),
        Icons.home_rounded,
        Icons.home_outlined,
      ),
      _NavItem(
        context.tr('Tara', 'Scan'),
        Icons.camera_alt_rounded,
        Icons.camera_alt_outlined,
      ),
      _NavItem(
        context.tr('Bitkilerim', 'My Plants'),
        Icons.local_florist_rounded,
        Icons.local_florist_outlined,
      ),
      _NavItem(
        context.tr('Takvim', 'Calendar'),
        Icons.calendar_month_rounded,
        Icons.calendar_month_outlined,
      ),
      _NavItem(
        context.tr('Profil', 'Profile'),
        Icons.person_rounded,
        Icons.person_outline,
      ),
    ];
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(18, 0, 18, 12),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .94),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white),
          boxShadow: [
            BoxShadow(
              color: AppColors.darkGreen.withValues(alpha: .16),
              blurRadius: 32,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Row(
          children: List.generate(items.length, (index) {
            final item = items[index];
            final selected = selectedIndex == index;
            return Expanded(
              child: _NavButton(
                item: item,
                selected: selected,
                onTap: () => onSelected(index),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        height: 68,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.mint, Color(0xFFCBE6D1)],
                )
              : null,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: selected ? 34 : 28,
              height: selected ? 30 : 28,
              decoration: selected
                  ? BoxDecoration(
                      color: AppColors.darkGreen,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.darkGreen.withValues(alpha: .18),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    )
                  : null,
              child: Icon(
                selected ? item.selectedIcon : item.icon,
                color: selected ? Colors.white : AppColors.muted,
                size: selected ? 20 : 22,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: selected ? AppColors.darkGreen : AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.label, this.selectedIcon, this.icon);

  final String label;
  final IconData selectedIcon;
  final IconData icon;
}
