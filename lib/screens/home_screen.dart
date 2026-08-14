import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../models/care_task.dart';
import '../models/plant.dart';
import '../screens/care_calendar_screen.dart';
import '../screens/environment_analysis_screen.dart';
import '../screens/plant_archive_screen.dart';
import '../screens/pot_calculator_screen.dart';
import '../screens/premium_screen.dart';
import '../screens/scan_plant_screen.dart';
import '../screens/water_calculator_screen.dart';
import '../services/ad_config.dart';
import '../services/ad_service.dart';
import '../services/entitlement_service.dart';
import '../services/language_service.dart';
import '../services/notification_service.dart';
import '../services/plant_safety_service.dart';
import '../services/plant_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/botanical_background.dart';
import '../widgets/branded_header.dart';
import '../widgets/decorative_hero_card.dart';
import '../widgets/safety_profile_sheet.dart';
import '../widgets/task_summary_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _maybeAskSafetyProfile(),
    );
  }

  Future<void> _maybeAskSafetyProfile() async {
    final profile = await PlantSafetyService.instance.loadProfile();
    if (!mounted || profile.configured) {
      return;
    }
    await showSafetyProfileSheet(context, initialSetup: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BotanicalBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 118),
            children: [
              BrandedHeader(
                eyebrow: context.tr(
                  'Bitkileriniz iyi, siz rahat olun',
                  'Healthy plants, peace of mind',
                ),
                title: context.tr('Çiçek Doktoru', 'Plant Doctor'),
                subtitle: context.tr(
                  'Bugün bakım için güzel bir gün.',
                  'Today is a good day for plant care.',
                ),
              ),
              const SizedBox(height: 6),
              const DecorativeHeroCard(),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _QuickActions(
                  actions: [
                    _QuickAction(
                      context.tr('Tara', 'Scan'),
                      Icons.camera_alt_outlined,
                      () => Navigator.of(
                        context,
                      ).pushNamed(ScanPlantScreen.routeName),
                    ),
                    _QuickAction(
                      context.tr('Rehber', 'Guide'),
                      Icons.menu_book_outlined,
                      () => Navigator.of(
                        context,
                      ).pushNamed(PlantArchiveScreen.routeName),
                    ),
                    _QuickAction(
                      context.tr('Saksım Uygun mu?', 'Is My Pot Right?'),
                      Icons.inventory_2_outlined,
                      () => Navigator.of(
                        context,
                      ).pushNamed(PotCalculatorScreen.routeName),
                    ),
                    _QuickAction(
                      context.tr('Su Hesaplayıcı', 'Water Calculator'),
                      Icons.water_drop_outlined,
                      () => Navigator.of(
                        context,
                      ).pushNamed(WaterCalculatorScreen.routeName),
                    ),
                    _QuickAction(
                      context.tr('Ortam Analizi', 'Environment Analysis'),
                      Icons.wb_sunny_outlined,
                      () => Navigator.of(
                        context,
                      ).pushNamed(EnvironmentAnalysisScreen.routeName),
                    ),
                    _QuickAction(
                      context.tr('Takvim', 'Calendar'),
                      Icons.calendar_month_outlined,
                      () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CareCalendarScreen(),
                        ),
                      ),
                    ),
                    _QuickAction(
                      context.tr('Premium', 'Premium'),
                      Icons.workspace_premium_outlined,
                      () => Navigator.of(
                        context,
                      ).pushNamed(PremiumScreen.routeName),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: _HomeAdBanner(),
              ),
              const SizedBox(height: 22),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text(
                      context.tr('Bugünkü bakım özeti', 'Today’s care summary'),
                      style: AppTextStyles.section.copyWith(
                        color: AppColors.darkGreen,
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.spa, color: AppColors.leaf, size: 20),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: _TodayCareSummary(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeAdBanner extends StatefulWidget {
  const _HomeAdBanner();

  @override
  State<_HomeAdBanner> createState() => _HomeAdBannerState();
}

class _HomeAdBannerState extends State<_HomeAdBanner> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  bool _shouldShow = false;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _loadIfAllowed();
  }

  Future<void> _loadIfAllowed() async {
    if (AdConfig.adsDisabled) {
      return;
    }

    try {
      final plan = await EntitlementService().getCurrentPlan();
      if (!mounted || plan.adsDisabled) {
        return;
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
    }

    setState(() => _shouldShow = true);

    if (!await AdService.instance.initialize()) {
      return;
    }
    if (!mounted) {
      return;
    }

    final banner = BannerAd(
      adUnitId: AdConfig.homeBannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _bannerAd = ad as BannerAd;
            _isLoaded = true;
            _loadFailed = false;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (!mounted) {
            return;
          }
          setState(() {
            _bannerAd = null;
            _isLoaded = false;
            _loadFailed = true;
          });
        },
      ),
    );

    await banner.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banner = _bannerAd;
    if (!_shouldShow) {
      return const SizedBox.shrink();
    }

    if (!_isLoaded || banner == null) {
      return _BannerShell(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!_loadFailed) ...[
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.green,
                ),
              ),
              const SizedBox(width: 10),
            ],
            Text(
              _loadFailed
                  ? context.tr(
                      'Sponsor alanı hazırlanıyor',
                      'Sponsor area is loading',
                    )
                  : context.tr('Reklam yükleniyor', 'Ad is loading'),
              style: AppTextStyles.muted.copyWith(
                color: AppColors.darkGreen,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    }

    return Align(
      alignment: Alignment.center,
      child: _BannerShell(
        width: banner.size.width.toDouble(),
        height: banner.size.height.toDouble(),
        child: AdWidget(ad: banner),
      ),
    );
  }
}

class _BannerShell extends StatelessWidget {
  const _BannerShell({required this.child, this.width = 320, this.height = 50});

  final Widget child;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .92),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: .84)),
          boxShadow: [
            BoxShadow(
              color: AppColors.green.withValues(alpha: .12),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}

class _TodayCareSummary extends StatefulWidget {
  const _TodayCareSummary();

  @override
  State<_TodayCareSummary> createState() => _TodayCareSummaryState();
}

class _TodayCareSummaryState extends State<_TodayCareSummary> {
  late Future<({List<CareTask> tasks, List<Plant> plants})> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<({List<CareTask> tasks, List<Plant> plants})> _load() async {
    final repository = PlantRepository();
    final tasks = await repository.getCareTasks();
    await NotificationService.instance.scheduleCareReminders(tasks);
    final plants = await repository.getPlants();
    return (tasks: tasks, plants: plants);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<({List<CareTask> tasks, List<Plant> plants})>(
      future: _future,
      builder: (context, snapshot) {
        final tasks = snapshot.data?.tasks ?? const <CareTask>[];
        final plants = snapshot.data?.plants ?? const <Plant>[];
        final todayTasks = tasks.where(_isToday).toList();
        final checkTasks = tasks
            .where((task) => task.type == CareTaskType.diseaseCheck)
            .toList();
        final latestPlant = plants.isEmpty ? null : plants.first;

        return Column(
          children: [
            TaskSummaryCard(
              icon: Icons.water_drop_outlined,
              title: context.tr(
                'Bugün bakım bekleyen bitkiler',
                'Plants needing care today',
              ),
              value: todayTasks.isEmpty
                  ? context.tr(
                      'Bugün için planlı bakım görevi yok',
                      'No planned care tasks for today',
                    )
                  : todayTasks.first.title,
              badge: todayTasks.isEmpty
                  ? context.tr('Rahat', 'Clear')
                  : context.tr('Bugün', 'Today'),
              color: AppColors.green,
            ),
            const SizedBox(height: 12),
            TaskSummaryCard(
              icon: Icons.health_and_safety_outlined,
              title: context.tr(
                'Kontrol zamanı gelen bitkiler',
                'Plants due for a checkup',
              ),
              value: checkTasks.isEmpty
                  ? context.tr(
                      'Yaklaşan kontrol görevi görünmüyor',
                      'No upcoming checkup tasks',
                    )
                  : context.tr(
                      '${checkTasks.length} görev takipte',
                      '${checkTasks.length} tasks in progress',
                    ),
              badge: context.tr('Kontrol', 'Check'),
              color: AppColors.warning,
            ),
            const SizedBox(height: 12),
            TaskSummaryCard(
              icon: Icons.history_outlined,
              title: context.tr('Son teşhisler', 'Recent diagnoses'),
              value: latestPlant == null
                  ? context.tr(
                      'İlk bitkini tarayarak teşhis geçmişi oluştur',
                      'Scan your first plant to create diagnosis history',
                    )
                  : context.tr(
                      '${latestPlant.name} görüntüye göre ${latestPlant.healthStatus.toLowerCase()} seviyede',
                      '${latestPlant.name} is rated ${latestPlant.healthStatus.toLowerCase()} from the image',
                    ),
              badge: latestPlant?.healthStatus ?? context.tr('Yeni', 'New'),
              color: AppColors.soil,
            ),
          ],
        );
      },
    );
  }

  bool _isToday(CareTask task) {
    final now = DateTime.now();
    return task.dueDate.year == now.year &&
        task.dueDate.month == now.month &&
        task.dueDate.day == now.day;
  }
}

class _QuickAction {
  const _QuickAction(this.label, this.icon, this.onTap);

  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.actions});

  final List<_QuickAction> actions;

  @override
  Widget build(BuildContext context) {
    final tools = actions.length > 1 ? actions.sublist(1) : <_QuickAction>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          title: context.tr('Akıllı Bitki Araçları', 'Smart Plant Tools'),
          subtitle: context.tr(
            'Teşhis sonrası bakım, sulama ve ortam kararlarını hızlandır.',
            'Speed up care, watering and environment decisions after diagnosis.',
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth < 460 ? 2 : 4;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: tools.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: 14,
                crossAxisSpacing: 12,
                childAspectRatio: columns == 2 ? .76 : .86,
              ),
              itemBuilder: (context, index) {
                final action = tools[index];
                final style = _styleFor(index + 1);
                return _FeatureCard(
                  action: action,
                  style: style,
                  description: _descriptionFor(context, index + 1),
                  badge: _badgeFor(context, index + 1),
                );
              },
            );
          },
        ),
      ],
    );
  }

  _FeatureStyle _styleFor(int index) {
    return switch (index) {
      1 => const _FeatureStyle(
        accent: Color(0xFF2F7D57),
        soft: Color(0xFFE9F6EE),
        icon: Icons.menu_book_rounded,
      ),
      2 => const _FeatureStyle(
        accent: Color(0xFFD48A2F),
        soft: Color(0xFFFFF2DD),
        icon: Icons.inventory_2_rounded,
      ),
      3 => const _FeatureStyle(
        accent: Color(0xFF418AE8),
        soft: Color(0xFFE8F2FF),
        icon: Icons.water_drop_rounded,
      ),
      4 => const _FeatureStyle(
        accent: Color(0xFFE4A319),
        soft: Color(0xFFFFF6D9),
        icon: Icons.wb_sunny_rounded,
      ),
      5 => const _FeatureStyle(
        accent: Color(0xFF6FA85F),
        soft: Color(0xFFEAF5E6),
        icon: Icons.calendar_month_rounded,
      ),
      _ => const _FeatureStyle(
        accent: Color(0xFF8A5CF6),
        soft: Color(0xFFF1ECFF),
        icon: Icons.workspace_premium_rounded,
      ),
    };
  }

  String _descriptionFor(BuildContext context, int index) {
    return switch (index) {
      1 => context.tr(
        '500 bitkilik bakım arşivinde ara.',
        'Search the 500-plant care archive.',
      ),
      2 => context.tr(
        'Saksı çapını ve toprak riskini hesapla.',
        'Calculate pot size and soil risk.',
      ),
      3 => context.tr(
        'Mevsime göre tahmini su miktarı al.',
        'Get estimated water amount by season.',
      ),
      4 => context.tr(
        'Işık, nem ve ortam puanını gör.',
        'See light, humidity and environment score.',
      ),
      5 => context.tr(
        'Bakım ve kontrol günlerini takip et.',
        'Track care and checkup days.',
      ),
      _ => context.tr(
        'Reklamsız ve daha güçlü analiz kilidini aç.',
        'Unlock ad-free use and stronger analysis.',
      ),
    };
  }

  String _badgeFor(BuildContext context, int index) {
    return switch (index) {
      1 => context.tr('Rehber', 'Guide'),
      2 => context.tr('Ölçer', 'Measure'),
      3 => context.tr('Tahmin', 'Estimate'),
      4 => context.tr('Puanla', 'Score'),
      5 => context.tr('Takip', 'Track'),
      _ => context.tr('Pro', 'Pro'),
    };
  }
}

// ignore: unused_element
class _PrimaryActionStrip extends StatelessWidget {
  const _PrimaryActionStrip({required this.action});

  final _QuickAction action;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: action.onTap,
      borderRadius: BorderRadius.circular(26),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0xFF0D6B49), Color(0xFF1FA36D)],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.darkGreen.withValues(alpha: .2),
              blurRadius: 26,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .18),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: .28)),
              ),
              child: Icon(action.icon, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '3 fotoğrafla detaylı teşhis',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Genel görünüm, belirti ve toprak fotoğrafını birlikte analiz et.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.muted.copyWith(
                      color: Colors.white.withValues(alpha: .78),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.arrow_forward_rounded,
                color: AppColors.darkGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.section.copyWith(
                  color: AppColors.darkGreen,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: AppTextStyles.muted.copyWith(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.mint,
            borderRadius: BorderRadius.circular(15),
          ),
          child: const Icon(Icons.auto_awesome_rounded, color: AppColors.green),
        ),
      ],
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.action,
    required this.style,
    required this.description,
    required this.badge,
  });

  final _QuickAction action;
  final _FeatureStyle style;
  final String description;
  final String badge;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: action.onTap,
      borderRadius: BorderRadius.circular(26),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: .98),
              style.soft.withValues(alpha: .9),
            ],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: .9)),
          boxShadow: [
            BoxShadow(
              color: style.accent.withValues(alpha: .17),
              blurRadius: 26,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Stack(
            children: [
              Positioned(
                right: -22,
                bottom: -26,
                child: Icon(
                  style.icon,
                  size: 104,
                  color: style.accent.withValues(alpha: .055),
                ),
              ),
              Positioned(
                right: 12,
                top: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .82),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: style.accent.withValues(alpha: .1),
                    ),
                  ),
                  child: Text(
                    badge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: style.accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: style.accent,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: style.accent.withValues(alpha: .2),
                            blurRadius: 14,
                            offset: const Offset(0, 7),
                          ),
                        ],
                      ),
                      child: Icon(style.icon, color: Colors.white, size: 30),
                    ),
                    const SizedBox(height: 42),
                    Text(
                      action.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.muted.copyWith(
                        color: AppColors.muted,
                        height: 1.14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              color: style.accent.withValues(alpha: .18),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .92),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: style.accent.withValues(alpha: .14),
                            ),
                          ),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            color: style.accent,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureStyle {
  const _FeatureStyle({
    required this.accent,
    required this.soft,
    required this.icon,
  });

  final Color accent;
  final Color soft;
  final IconData icon;
}
