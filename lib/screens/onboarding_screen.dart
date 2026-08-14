import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/language_service.dart';
import '../theme/app_colors.dart';
import '../widgets/branded_logo_header.dart';
import '../widgets/onboarding_cta_button.dart';
import '../widgets/onboarding_hero_illustration.dart';
import '../widgets/onboarding_indicator.dart';
import '../widgets/onboarding_page_view.dart';
import 'sign_in_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  static const routeName = '/onboarding';
  static const preferenceKey = 'has_seen_onboarding';
  static Future<SharedPreferences> preferences() =>
      SharedPreferences.getInstance();

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  List<OnboardingPageData> _pages(BuildContext context) => [
    OnboardingPageData(
      title: context.tr(
        'Bitkini fotoğraflayarak sağlık durumunu öğren',
        'Learn your plant’s health from photos',
      ),
      description: context.tr(
        'Yapay zekâ destekli analizle bitkindeki olası sorunları hızlıca keşfet.',
        'Quickly discover possible issues with AI-supported analysis.',
      ),
      illustration: OnboardingIllustrationType.camera,
    ),
    OnboardingPageData(
      title: context.tr(
        'Sulama, ışık ve bakım önerilerini adım adım gör',
        'See watering, light and care advice step by step',
      ),
      description: context.tr(
        'Bitkine uygun ilk bakım adımlarını öğren, ne yapman gerektiğini sade şekilde gör.',
        'Get clear first-care steps tailored to your plant.',
      ),
      illustration: OnboardingIllustrationType.carePlan,
    ),
    OnboardingPageData(
      title: context.tr(
        'Bitkilerini takip et, bakım günlerini kaçırma',
        'Track your plants and never miss care days',
      ),
      description: context.tr(
        'Sulama, yaprak temizliği ve kontrol tarihlerini planla; bitkilerini daha sağlıklı tut.',
        'Plan watering, leaf cleaning and checkups to keep plants healthier.',
      ),
      illustration: OnboardingIllustrationType.calendar,
    ),
  ];

  Future<void> _finish() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(OnboardingScreen.preferenceKey, true);
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(SignInScreen.routeName);
  }

  void _next() {
    if (_page == 2) {
      _finish();
      return;
    }

    _controller.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = _pages(context);
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFBF2), AppColors.cream, AppColors.mint],
          ),
        ),
        child: Stack(
          children: [
            const _OnboardingBotanicalPattern(),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
                child: Column(
                  children: [
                    BrandedLogoHeader(onSkip: _finish),
                    const SizedBox(height: 12),
                    Expanded(
                      child: PageView.builder(
                        controller: _controller,
                        onPageChanged: (value) => setState(() => _page = value),
                        itemCount: pages.length,
                        itemBuilder: (context, index) {
                          return OnboardingPageView(data: pages[index]);
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    OnboardingIndicator(
                      activeIndex: _page,
                      itemCount: pages.length,
                    ),
                    const SizedBox(height: 18),
                    OnboardingCtaButton(
                      label: _page == pages.length - 1
                          ? context.tr(
                              'Google ile Başlayalım',
                              'Start with Google',
                            )
                          : context.tr('Devam', 'Continue'),
                      onPressed: _next,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingBotanicalPattern extends StatelessWidget {
  const _OnboardingBotanicalPattern();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: 94,
          right: -28,
          child: Icon(
            Icons.eco_rounded,
            size: 150,
            color: AppColors.lightGreen.withValues(alpha: .13),
          ),
        ),
        Positioned(
          top: 345,
          left: -50,
          child: Transform.rotate(
            angle: -.5,
            child: Icon(
              Icons.local_florist_rounded,
              size: 138,
              color: AppColors.soil.withValues(alpha: .1),
            ),
          ),
        ),
        Positioned(
          bottom: 124,
          right: -34,
          child: Icon(
            Icons.spa_rounded,
            size: 150,
            color: AppColors.green.withValues(alpha: .08),
          ),
        ),
      ],
    );
  }
}
