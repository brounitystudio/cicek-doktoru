import 'package:flutter/material.dart';

import '../main.dart';
import '../services/auth_service.dart';
import '../services/language_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/logo_mark.dart';
import 'onboarding_screen.dart';
import 'sign_in_screen.dart';

class LanguageSelectionScreen extends StatelessWidget {
  const LanguageSelectionScreen({super.key});

  static const routeName = '/language';

  Future<void> _select(BuildContext context, AppLanguage language) async {
    await LanguageService.instance.setLanguage(language);
    final preferences = await OnboardingScreen.preferences();
    final seenOnboarding =
        preferences.getBool(OnboardingScreen.preferenceKey) ?? false;
    final isSignedIn = AuthService().hasSignedInUser;
    if (!context.mounted) return;
    Navigator.of(context).pushReplacementNamed(
      !seenOnboarding
          ? OnboardingScreen.routeName
          : isSignedIn
          ? MainShell.routeName
          : SignInScreen.routeName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = LanguageService.instance.isEnglish;
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.cream, AppColors.lightGreen],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
            child: Column(
              children: [
                const Spacer(),
                const FullBrandLogo(width: 280),
                const SizedBox(height: 28),
                Text(
                  isEnglish ? 'Choose your language' : 'Dilini seç',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.title.copyWith(
                    color: AppColors.darkGreen,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isEnglish
                      ? 'You can change this later from Profile.'
                      : 'Bunu daha sonra Profil ekranından değiştirebilirsin.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.muted.copyWith(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 28),
                _LanguageCard(
                  title: 'Türkçe',
                  subtitle: 'Uygulamayı Türkçe kullan',
                  selected: LanguageService.instance.language == AppLanguage.tr,
                  onTap: () => _select(context, AppLanguage.tr),
                ),
                const SizedBox(height: 12),
                _LanguageCard(
                  title: 'English',
                  subtitle: 'Use the app in English',
                  selected: LanguageService.instance.language == AppLanguage.en,
                  onTap: () => _select(context, AppLanguage.en),
                ),
                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(26),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: selected ? .98 : .84),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: selected
                ? AppColors.green
                : Colors.white.withValues(alpha: .72),
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.green.withValues(alpha: selected ? .18 : .08),
              blurRadius: 24,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: selected ? AppColors.green : AppColors.mint,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                selected ? Icons.check_rounded : Icons.language_rounded,
                color: selected ? Colors.white : AppColors.darkGreen,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.section),
                  const SizedBox(height: 3),
                  Text(subtitle, style: AppTextStyles.muted),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

Future<void> showLanguagePicker(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Dil seçimi', 'Language'),
            style: AppTextStyles.title,
          ),
          const SizedBox(height: 8),
          Text(
            context.tr(
              'Uygulama metinleri ve analiz dili bu seçime göre güncellenir.',
              'App text and diagnosis language will use this selection.',
            ),
            style: AppTextStyles.muted,
          ),
          const SizedBox(height: 18),
          _LanguageCard(
            title: 'Türkçe',
            subtitle: 'Uygulamayı Türkçe kullan',
            selected: LanguageService.instance.language == AppLanguage.tr,
            onTap: () async {
              await LanguageService.instance.setLanguage(AppLanguage.tr);
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
          const SizedBox(height: 12),
          _LanguageCard(
            title: 'English',
            subtitle: 'Use the app in English',
            selected: LanguageService.instance.language == AppLanguage.en,
            onTap: () async {
              await LanguageService.instance.setLanguage(AppLanguage.en);
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
    ),
  );
}
