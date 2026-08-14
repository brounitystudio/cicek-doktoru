import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import '../services/auth_service.dart';
import '../services/language_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/logo_mark.dart';
import 'language_selection_screen.dart';
import 'onboarding_screen.dart';
import 'sign_in_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  static const routeName = '/';

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _continueAfterSplash();
  }

  Future<void> _continueAfterSplash() async {
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!LanguageService.instance.configured) {
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacementNamed(LanguageSelectionScreen.routeName);
      return;
    }
    final preferences = await SharedPreferences.getInstance();
    final seenOnboarding =
        preferences.getBool(OnboardingScreen.preferenceKey) ?? false;
    final isSignedIn = AuthService().hasSignedInUser;
    if (!mounted) return;
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
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.cream, AppColors.lightGreen],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const FullBrandLogo(width: 330),
              const SizedBox(height: 18),
              _StudioSignature(),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudioSignature extends StatelessWidget {
  const _StudioSignature();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.asset(
            'assets/brand/brounity_mark.png',
            width: 24,
            height: 24,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'by BROUNITY STUDIO',
          textAlign: TextAlign.center,
          style: AppTextStyles.muted.copyWith(
            color: AppColors.darkGreen.withValues(alpha: .62),
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
          ),
        ),
      ],
    );
  }
}
