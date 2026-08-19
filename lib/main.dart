import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/care_calendar_screen.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/diagnosis_loading_screen.dart';
import 'screens/diagnosis_result_screen.dart';
import 'screens/environment_analysis_screen.dart';
import 'screens/home_screen.dart';
import 'screens/language_selection_screen.dart';
import 'screens/legal_screen.dart';
import 'screens/multi_photo_camera_screen.dart';
import 'screens/my_plants_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/plant_archive_screen.dart';
import 'screens/plant_detail_screen.dart';
import 'screens/pot_calculator_screen.dart';
import 'screens/premium_screen.dart';
import 'screens/scan_plant_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/sign_in_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/water_calculator_screen.dart';
import 'services/ad_service.dart';
import 'services/analytics_service.dart';
import 'services/entitlement_service.dart';
import 'services/firebase_bootstrap.dart';
import 'services/language_service.dart';
import 'services/notification_service.dart';
import 'services/plant_repository.dart';
import 'services/premium_prompt_service.dart';
import 'services/purchase_service.dart';
import 'theme/app_theme.dart';
import 'widgets/paywall_bottom_sheet.dart';
import 'widgets/persistent_banner_ad.dart';
import 'widgets/premium_bottom_nav.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
FirebaseAnalyticsObserver? appAnalyticsObserver;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final firebaseReady = await FirebaseBootstrap.ensureInitialized();
  if (firebaseReady) {
    final analytics = FirebaseAnalytics.instance;
    appAnalyticsObserver = FirebaseAnalyticsObserver(
      analytics: analytics,
      nameExtractor: _cicekScreenName,
    );
    unawaited(AnalyticsService.instance.initialize(analytics));
  }
  await LanguageService.instance.initialize();
  PurchaseService.instance.initialize();
  unawaited(
    AdService.instance.initialize().catchError((Object error) {
      debugPrint('Ad initialization skipped: $error');
      return false;
    }),
  );
  runApp(const CicekDoktoruApp());
  unawaited(
    NotificationService.instance
        .initialize(onNotificationTap: _openNotificationDestination)
        .catchError((Object error) {
          debugPrint('Notification initialization skipped: $error');
        }),
  );
}

String? _cicekScreenName(RouteSettings settings) {
  final routeName = settings.name;
  if (routeName == null) {
    return null;
  }
  const knownNames = {
    '/': 'cicek_acilis',
    '/home': 'cicek_anasayfa',
    '/scan': 'cicek_tara',
    '/diagnosis-loading': 'cicek_teshis_hazirlaniyor',
    '/diagnosis-result': 'cicek_teshis_sonucu',
    '/plant-detail': 'cicek_bitki_detayi',
    '/plant-archive': 'cicek_bakim_arsivi',
    '/premium': 'cicek_premium',
    '/legal': 'cicek_yasal_bilgiler',
  };
  final knownName = knownNames[routeName];
  if (knownName != null) {
    return knownName;
  }
  final normalized = routeName
      .replaceFirst(RegExp(r'^/+'), '')
      .replaceAll('-', '_');
  return normalized.isEmpty ? 'cicek_acilis' : 'cicek_$normalized';
}

void _openNotificationDestination(NotificationNavigationIntent intent) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) {
      return;
    }
    navigator.pushNamedAndRemoveUntil(
      MainShell.routeName,
      (route) => false,
      arguments: intent,
    );
  });
}

class CicekDoktoruApp extends StatefulWidget {
  const CicekDoktoruApp({super.key});

  @override
  State<CicekDoktoruApp> createState() => _CicekDoktoruAppState();
}

class _CicekDoktoruAppState extends State<CicekDoktoruApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      AdService.instance.markAppBackgrounded();
    } else if (state == AppLifecycleState.resumed) {
      EntitlementService.notifyChanged();
      unawaited(AdService.instance.showAppOpenOnForegroundIfEligible());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: LanguageService.instance,
      builder: (context, _) => MaterialApp(
        navigatorKey: appNavigatorKey,
        navigatorObservers: [?appAnalyticsObserver],
        title: LanguageService.instance.text('Çiçek Doktoru', 'Plant Doctor'),
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        locale: LanguageService.instance.language.locale,
        supportedLocales: const [Locale('tr'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        initialRoute: SplashScreen.routeName,
        routes: {
          SplashScreen.routeName: (_) => const SplashScreen(),
          LanguageSelectionScreen.routeName: (_) =>
              const LanguageSelectionScreen(),
          OnboardingScreen.routeName: (_) => const OnboardingScreen(),
          MainShell.routeName: (_) => const MainShell(),
          AdminDashboardScreen.routeName: (_) => const AdminDashboardScreen(),
          ScanPlantScreen.routeName: (_) => const ScanPlantScreen(),
          DiagnosisLoadingScreen.routeName: (_) =>
              const DiagnosisLoadingScreen(),
          DiagnosisResultScreen.routeName: (_) => const DiagnosisResultScreen(),
          EnvironmentAnalysisScreen.routeName: (_) =>
              const EnvironmentAnalysisScreen(),
          LegalScreen.routeName: (_) => const LegalScreen(),
          MultiPhotoCameraScreen.routeName: (_) =>
              const MultiPhotoCameraScreen(),
          PlantArchiveScreen.routeName: (_) => const PlantArchiveScreen(),
          PlantDetailScreen.routeName: (_) => const PlantDetailScreen(),
          PotCalculatorScreen.routeName: (_) => const PotCalculatorScreen(),
          PremiumScreen.routeName: (_) => const PremiumScreen(),
          SignInScreen.routeName: (_) => const SignInScreen(),
          WaterCalculatorScreen.routeName: (_) => const WaterCalculatorScreen(),
        },
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  static const routeName = '/home';

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  bool _notificationArgsApplied = false;
  bool _initialAnalyticsLogged = false;
  Timer? _automaticReminderTimer;
  Timer? _premiumOfferTimer;

  List<Widget> _pages = const [];

  @override
  void initState() {
    super.initState();
    _pages = const [
      HomeScreen(),
      ScanPlantScreen(),
      MyPlantsScreen(),
      CareCalendarScreen(),
      SettingsScreen(),
    ];
    unawaited(AdService.instance.registerAuthenticatedLaunchAndScheduleAds());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduleAutomaticReminderSetup(const Duration(seconds: 8));
      _schedulePremiumOfferAttempt(const Duration(seconds: 25));
    });
  }

  void _scheduleAutomaticReminderSetup(Duration delay) {
    _automaticReminderTimer?.cancel();
    _automaticReminderTimer = Timer(
      delay,
      () => unawaited(_configureAutomaticReminders()),
    );
  }

  Future<void> _configureAutomaticReminders() async {
    if (!mounted) return;
    if (ModalRoute.of(context)?.isCurrent != true) {
      _scheduleAutomaticReminderSetup(const Duration(minutes: 1));
      return;
    }
    try {
      final tasks = await PlantRepository().getCareTasks();
      await NotificationService.instance.ensureAutomaticReminders(tasks);
    } catch (error) {
      debugPrint('Automatic reminders skipped: $error');
    }
  }

  void _schedulePremiumOfferAttempt(Duration delay) {
    _premiumOfferTimer?.cancel();
    _premiumOfferTimer = Timer(
      delay,
      () => unawaited(_maybeShowPremiumOffer()),
    );
  }

  Future<void> _maybeShowPremiumOffer() async {
    if (!mounted) return;
    if (ModalRoute.of(context)?.isCurrent != true) {
      _schedulePremiumOfferAttempt(const Duration(minutes: 1));
      return;
    }
    try {
      final shouldShow = await PremiumPromptService.instance
          .shouldShowDailyOffer();
      if (!mounted || !shouldShow) return;
      final openPremium = await showDailyPremiumOfferBottomSheet(context);
      if (mounted && openPremium) {
        await Navigator.of(context).pushNamed(PremiumScreen.routeName);
      }
    } catch (error) {
      debugPrint('Daily Premium offer skipped: $error');
    }
  }

  @override
  void dispose() {
    _automaticReminderTimer?.cancel();
    _premiumOfferTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_notificationArgsApplied) {
      return;
    }
    _notificationArgsApplied = true;
    final intent = ModalRoute.of(context)?.settings.arguments;
    if (intent is NotificationNavigationIntent) {
      _index = intent.isCareReminder ? 3 : 0;
      _pages = [
        const HomeScreen(),
        const ScanPlantScreen(),
        const MyPlantsScreen(),
        CareCalendarScreen(
          focusTaskId: intent.taskId,
          focusPlantId: intent.plantId,
        ),
        const SettingsScreen(),
      ];
    }
    if (!_initialAnalyticsLogged) {
      _initialAnalyticsLogged = true;
      unawaited(AnalyticsService.instance.logSectionOpened(_index));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const PersistentBannerAd(),
          PremiumBottomNav(
            selectedIndex: _index,
            onSelected: (value) {
              if (value == 2) {
                PlantRepository.plantsRevision.value++;
              }
              if (value == 4) {
                EntitlementService.notifyChanged();
              }
              if (value != _index) {
                unawaited(AnalyticsService.instance.logSectionOpened(value));
              }
              setState(() => _index = value);
            },
          ),
        ],
      ),
    );
  }
}
