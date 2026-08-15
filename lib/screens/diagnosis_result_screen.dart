import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/diagnosis_result.dart';
import '../services/ad_service.dart';
import '../services/entitlement_service.dart';
import '../services/language_service.dart';
import '../services/notification_service.dart';
import '../services/plant_safety_service.dart';
import '../services/plant_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/paywall_bottom_sheet.dart';
import '../widgets/premium_care_tips.dart';
import 'plant_detail_screen.dart';
import 'premium_screen.dart';
import 'scan_plant_screen.dart';

class DiagnosisResultScreen extends StatefulWidget {
  const DiagnosisResultScreen({super.key});

  static const routeName = '/diagnosis-result';

  @override
  State<DiagnosisResultScreen> createState() => _DiagnosisResultScreenState();
}

class _DiagnosisResultScreenState extends State<DiagnosisResultScreen> {
  bool _isSaving = false;
  bool _postDiagnosisAdChecked = false;
  String? _savedPlantId;
  late Future<bool> _premiumFuture;

  @override
  void initState() {
    super.initState();
    _premiumFuture = _loadPremiumStatus();
    EntitlementService.revision.addListener(_refreshPremiumStatus);
  }

  @override
  void dispose() {
    EntitlementService.revision.removeListener(_refreshPremiumStatus);
    super.dispose();
  }

  Future<bool> _loadPremiumStatus() async {
    final plan = await EntitlementService().getCurrentPlan();
    return plan.isPremium;
  }

  void _refreshPremiumStatus() {
    if (!mounted) {
      return;
    }
    setState(() => _premiumFuture = _loadPremiumStatus());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_postDiagnosisAdChecked) {
      return;
    }
    _postDiagnosisAdChecked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_handlePostDiagnosisMonetization());
    });
  }

  Future<void> _handlePostDiagnosisMonetization() async {
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted) {
      return;
    }
    try {
      await AdService.instance.showInterstitialAfterDiagnosisIfNeeded();
    } catch (_) {
      // Monetization should never block access to a completed diagnosis.
    }
  }

  @override
  Widget build(BuildContext context) {
    final result =
        ModalRoute.of(context)?.settings.arguments as DiagnosisResult? ??
        DiagnosisResult(
          plantName: 'Barış Çiçeği',
          healthScore: 74,
          visualFindings: const [
            'Yaprak uçları ve toprak yüzeyi birlikte değerlendirildi.',
          ],
          createdAt: DateTime.now(),
          symptoms: const [
            'Yaprak sararması',
            'Yaprak ucu kahverengileşmesi',
            'Toprak nemli görünüyor',
          ],
          causes: const [
            CauseProbability(title: 'Fazla sulama', percent: 68),
            CauseProbability(title: 'Düşük nem', percent: 21),
            CauseProbability(title: 'Işık dengesizliği', percent: 11),
          ],
          actions: const [
            'Sulamayı azalt.',
            'Daha aydınlık bir konuma al.',
            'Saksı drenajını kontrol et.',
          ],
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Teşhis Sonucu', 'Diagnosis Result')),
      ),
      body: FutureBuilder<bool>(
        future: _premiumFuture,
        builder: (context, snapshot) {
          final entitlementLoaded =
              snapshot.connectionState == ConnectionState.done;
          final isPremium = snapshot.data == true;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _PlantImage(result: result),
              const SizedBox(height: 14),
              _ResultSummaryCard(result: result, isPremium: isPremium),
              const SizedBox(height: 16),
              if (!result.isPlant) ...[
                _RetakePhotoCard(result: result),
                const SizedBox(height: 14),
              ] else ...[
                _TodayActionsCard(result: result),
                _DiagnosisDetailsSection(result: result, isPremium: isPremium),
                if (result.needsCloseup) _RetakePhotoCard(result: result),
                _SevenDayPlanCard(
                  result: result,
                  isPremium: isPremium,
                  entitlementLoaded: entitlementLoaded,
                  isSaving: _isSaving,
                  onSchedule: () => _scheduleReminder(context, result),
                ),
                _DiagnosisSafetyCard(plantName: result.plantName),
                _SafetyAndLimitsSection(
                  result: result,
                  avoidanceTips: _avoidanceTips(context, result),
                ),
                const SizedBox(height: 14),
              ],
              if (result.isPlant) ...[
                AppButton(
                  label: _savedPlantId == null
                      ? context.tr(
                          'Bakım Hatırlatması Kur',
                          'Set Care Reminder',
                        )
                      : context.tr(
                          'Hatırlatmaları Yenile',
                          'Refresh Reminders',
                        ),
                  icon: Icons.notifications_active_outlined,
                  onPressed: _isSaving
                      ? null
                      : () => _scheduleReminder(context, result),
                ),
                const SizedBox(height: 10),
                AppButton(
                  label: _savedPlantId != null
                      ? context.tr(
                          'Bitkilerime Kaydedildi',
                          'Saved to My Plants',
                        )
                      : _isSaving
                      ? context.tr('Kaydediliyor...', 'Saving...')
                      : context.tr('Bitkilerime Kaydet', 'Save to My Plants'),
                  icon: _savedPlantId != null
                      ? Icons.check_circle_outline
                      : _isSaving
                      ? Icons.hourglass_top_rounded
                      : Icons.bookmark_add_outlined,
                  onPressed: _isSaving || _savedPlantId != null
                      ? null
                      : () => _savePlant(context, result),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.of(context).popUntil((route) => route.isFirst),
                  icon: const Icon(Icons.event_repeat),
                  label: Text(
                    context.tr(
                      '7 Gün Sonra Tekrar Kontrol Et',
                      'Check Again in 7 Days',
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  List<String> _avoidanceTips(BuildContext context, DiagnosisResult result) {
    final tips = <String>[
      context.tr(
        'Belirti netleşmeden kimyasal ilaç kullanma.',
        'Do not use chemical treatment before the symptom is clear.',
      ),
      context.tr(
        'Toprak nemini kontrol etmeden ekstra sulama yapma.',
        'Do not add extra water before checking soil moisture.',
      ),
    ];
    if (result.needsCloseup) {
      tips.add(
        context.tr(
          'Bulanık veya uzak fotoğrafa göre kesin karar verme.',
          'Do not make a final decision from a blurry or distant photo.',
        ),
      );
    }
    if (result.healthScore < 50) {
      tips.add(
        context.tr(
          'Sorun hızla yayılıyorsa bitkiyi diğerlerinden ayrı gözlemle.',
          'If the issue spreads quickly, observe the plant separately from others.',
        ),
      );
    }
    return tips;
  }

  Future<void> _savePlant(BuildContext context, DiagnosisResult result) async {
    if (_isSaving || _savedPlantId != null) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final plan = await EntitlementService().getCurrentPlan();
      final plants = await PlantRepository().getPlants();
      if (!plan.isPremium && plants.length >= plan.maxSavedPlants) {
        if (mounted) {
          setState(() => _isSaving = false);
        }
        if (!context.mounted) {
          return;
        }
        await showPaywallBottomSheet(context);
        return;
      }

      final plant = await PlantRepository().saveDiagnosis(result);
      if (!context.mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
        _savedPlantId = plant.id;
      });
      final openPlant = await _showSavedSheet(context);
      if (!context.mounted) {
        return;
      }
      if (openPlant == true) {
        await Navigator.of(
          context,
        ).pushNamed(PlantDetailScreen.routeName, arguments: plant);
      }
      return;
    } on PlantLimitException {
      if (mounted) {
        setState(() => _isSaving = false);
      }
      if (!context.mounted) {
        return;
      }
      await showPaywallBottomSheet(context);
      return;
    } on PlantSaveException catch (error) {
      if (mounted) {
        setState(() => _isSaving = false);
      }
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      return;
    } catch (error) {
      if (mounted) {
        setState(() => _isSaving = false);
      }
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              'Bitki kaydedilemedi, lütfen tekrar deneyin.',
              'The plant could not be saved. Please try again.',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _scheduleReminder(
    BuildContext context,
    DiagnosisResult result,
  ) async {
    if (_isSaving) {
      return;
    }
    setState(() => _isSaving = true);
    try {
      if (_savedPlantId == null) {
        final plan = await EntitlementService().getCurrentPlan();
        final plants = await PlantRepository().getPlants();
        if (!plan.isPremium && plants.length >= plan.maxSavedPlants) {
          if (mounted) {
            setState(() => _isSaving = false);
          }
          if (context.mounted) {
            await showPaywallBottomSheet(context);
          }
          return;
        }
        final plant = await PlantRepository().saveDiagnosis(result);
        _savedPlantId = plant.id;
      }
      final tasks = await PlantRepository().getCareTasks();
      final scheduled = await NotificationService.instance
          .scheduleCareReminders(tasks, requestPermissionIfNeeded: true);
      if (!context.mounted) {
        return;
      }
      setState(() => _isSaving = false);
      if (!scheduled) {
        await _showNotificationPermissionDialog(context);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              'Bakım hatırlatmaları bu bitki için planlandı.',
              'Care reminders have been scheduled for this plant.',
            ),
          ),
        ),
      );
    } on PlantLimitException {
      if (mounted) {
        setState(() => _isSaving = false);
      }
      if (context.mounted) {
        await showPaywallBottomSheet(context);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _isSaving = false);
      }
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _showNotificationPermissionDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.notifications_off_outlined,
          color: AppColors.warning,
          size: 34,
        ),
        title: Text(
          context.tr('Bildirim izni kapalı', 'Notifications are disabled'),
        ),
        content: Text(
          context.tr(
            'Bakım planı kaydedildi ancak hatırlatma gösterebilmek için bildirim iznini telefon ayarlarından açmalısın.',
            'The care plan was saved, but notifications must be enabled in phone settings to show reminders.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.tr('Şimdi değil', 'Not now')),
          ),
          FilledButton.icon(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await NotificationService.instance.openNotificationSettings();
            },
            icon: const Icon(Icons.settings_outlined),
            label: Text(context.tr('Ayarlara git', 'Open settings')),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showSavedSheet(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(14),
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: AppColors.darkGreen.withValues(alpha: .16),
              blurRadius: 32,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: AppColors.mint,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  color: AppColors.green,
                  size: 34,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                context.tr('Bitkin kaydedildi', 'Your plant was saved'),
                style: AppTextStyles.title,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                context.tr(
                  'Fotoğraf ve teşhis sonucu Bitkilerim listene eklendi.',
                  'The photo and diagnosis result were added to My Plants.',
                ),
                style: AppTextStyles.muted,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              AppButton(
                label: context.tr('Bitkiye Git', 'Open Plant'),
                icon: Icons.local_florist_outlined,
                onPressed: () => Navigator.of(context).pop(true),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(context.tr('Sonuçta kal', 'Stay here')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RetakePhotoCard extends StatelessWidget {
  const _RetakePhotoCard({required this.result});

  final DiagnosisResult result;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.warmCream,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.center_focus_strong, color: AppColors.warning),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  result.isPlant
                      ? context.tr(
                          'Sonucu güçlendirelim',
                          'Let’s strengthen the result',
                        )
                      : context.tr(
                          'Bitkiyi yeniden fotoğrafla',
                          'Photograph the plant again',
                        ),
                  style: AppTextStyles.section,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            context.tr(
              'Genel bitki, belirti yakın çekimi ve toprak/saksı dibini ayrı ayrı çek. Net olmayan görüntüde yüksek güvenli sonuç gösterilmez.',
              'Take separate photos of the full plant, a symptom close-up and the soil/pot base. High-confidence results are not shown for unclear images.',
            ),
            style: AppTextStyles.body,
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () =>
                  Navigator.of(context).pushNamed(ScanPlantScreen.routeName),
              icon: const Icon(Icons.photo_camera_outlined),
              label: Text(context.tr('Yeni fotoğraf çek', 'Take new photos')),
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayActionsCard extends StatelessWidget {
  const _TodayActionsCard({required this.result});

  final DiagnosisResult result;

  @override
  Widget build(BuildContext context) {
    final urgent = result.healthScore < 50;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: AppCard(
        color: AppColors.mint.withValues(alpha: .92),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.task_alt, color: AppColors.darkGreen),
                const SizedBox(width: 10),
                Text(
                  context.tr('Bugün yap', 'Do today'),
                  style: AppTextStyles.section.copyWith(
                    color: AppColors.darkGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (result.actions.isEmpty)
              Text(
                context.tr(
                  'Bugün bitkiyi gözlemle ve belirgin değişiklikleri not et.',
                  'Observe the plant today and note any visible changes.',
                ),
                style: AppTextStyles.body,
              )
            else
              ...result.actions.map((item) => _Bullet(item)),
            const Divider(height: 24, color: AppColors.lightGreen),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  urgent ? Icons.priority_high_rounded : Icons.event_repeat,
                  color: urgent ? AppColors.critical : AppColors.green,
                  size: 21,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    _followUpTiming(context, result),
                    style: AppTextStyles.muted.copyWith(
                      color: AppColors.darkGreen,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _followUpTiming(BuildContext context, DiagnosisResult result) {
  if (result.healthScore < 50) {
    return context.tr(
      '24 saat içinde tekrar kontrol et. Hızlı yayılma, kötü koku veya gövde yumuşaması varsa uzman desteği al.',
      'Check again within 24 hours. Seek expert help if spreading, odor or stem softening develops.',
    );
  }
  if (result.healthScore < 80) {
    return context.tr(
      '3 gün sonra aynı açıdan fotoğrafla karşılaştır; belirti büyürse daha erken yeni analiz al.',
      'Compare with a same-angle photo in 3 days; run a new analysis sooner if the symptom grows.',
    );
  }
  return context.tr(
    '7 gün sonra aynı açıdan fotoğrafla karşılaştır; belirgin değişiklik yoksa mevcut bakım ritmini koru.',
    'Compare with a same-angle photo in 7 days; keep the current care rhythm if there is no clear change.',
  );
}

class _DiagnosisDetailsSection extends StatelessWidget {
  const _DiagnosisDetailsSection({
    required this.result,
    required this.isPremium,
  });

  final DiagnosisResult result;
  final bool isPremium;

  @override
  Widget build(BuildContext context) {
    final firstFinding = result.visualFindings.isEmpty
        ? context.tr(
            'Fotoğraf bulguları ve olası nedenleri incele.',
            'Review photo findings and possible causes.',
          )
        : result.visualFindings.first;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 2),
          childrenPadding: const EdgeInsets.fromLTRB(2, 4, 2, 10),
          leading: const Icon(Icons.manage_search, color: AppColors.green),
          title: Text(
            context.tr('Analiz ayrıntıları', 'Analysis details'),
            style: AppTextStyles.section,
          ),
          subtitle: Text(
            firstFinding,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.muted,
          ),
          shape: const Border(bottom: BorderSide(color: AppColors.border)),
          collapsedShape: const Border(
            bottom: BorderSide(color: AppColors.border),
          ),
          children: [
            if (result.visualFindings.isNotEmpty) ...[
              _DetailHeading(
                label: context.tr(
                  'Fotoğrafta gördüklerimiz',
                  'What we saw in the photo',
                ),
              ),
              ...result.visualFindings.map((item) => _Bullet(item)),
              const SizedBox(height: 8),
            ],
            _LikelyCausesCard(result: result, isPremium: isPremium),
            const SizedBox(height: 10),
            _RiskBadgeCard(result: result),
          ],
        ),
      ),
    );
  }
}

class _DetailHeading extends StatelessWidget {
  const _DetailHeading({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: AppTextStyles.muted.copyWith(
          color: AppColors.darkGreen,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _LikelyCausesCard extends StatelessWidget {
  const _LikelyCausesCard({required this.result, required this.isPremium});

  final DiagnosisResult result;
  final bool isPremium;

  @override
  Widget build(BuildContext context) {
    final causes = result.causes.take(isPremium ? 3 : 1).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DetailHeading(label: context.tr('Olası nedenler', 'Possible causes')),
        Text(
          context.tr(
            'Yüzdeler göreli AI olasılığıdır; doğruluk garantisi değildir.',
            'Percentages are relative AI likelihoods, not an accuracy guarantee.',
          ),
          style: AppTextStyles.muted,
        ),
        const SizedBox(height: 10),
        if (causes.isEmpty)
          Text(
            context.tr(
              'Net bir neden seçilemedi; değişimi takip et.',
              'No clear cause was identified; monitor changes.',
            ),
            style: AppTextStyles.body,
          )
        else
          ...causes.map(
            (cause) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                children: [
                  Expanded(child: Text(cause.title, style: AppTextStyles.body)),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.mint,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Text(
                        '%${cause.percent}',
                        style: AppTextStyles.muted.copyWith(
                          color: AppColors.darkGreen,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _SevenDayPlanCard extends StatelessWidget {
  const _SevenDayPlanCard({
    required this.result,
    required this.isPremium,
    required this.entitlementLoaded,
    required this.isSaving,
    required this.onSchedule,
  });

  final DiagnosisResult result;
  final bool isPremium;
  final bool entitlementLoaded;
  final bool isSaving;
  final Future<void> Function() onSchedule;

  @override
  Widget build(BuildContext context) {
    final visiblePlan = isPremium
        ? result.sevenDayPlan
        : result.sevenDayPlan.take(2).toList();
    final hiddenPlan = result.sevenDayPlan.skip(2).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: AppCard(
        color: AppColors.warmCream.withValues(alpha: .9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.calendar_month_outlined,
                  color: AppColors.green,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isPremium
                        ? context.tr('7 Günlük Bakım Planı', '7-Day Care Plan')
                        : context.tr(
                            'İlk 2 Günlük Bakım Planı',
                            'First 2-Day Care Plan',
                          ),
                    style: AppTextStyles.section,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (visiblePlan.isEmpty)
              Text(
                context.tr(
                  'Bugün için ek bir plan oluşturulmadı.',
                  'No additional plan was created for today.',
                ),
                style: AppTextStyles.body,
              )
            else
              ...visiblePlan.map((item) => _Bullet(item)),
            if (!isPremium && entitlementLoaded && result.careProfile != null)
              PremiumCareTips(
                profile: result.careProfile!,
                isPremiumOverride: false,
                showLockedPreview: false,
              ),
            if (!isPremium && entitlementLoaded)
              _PremiumPlanUnlock(hiddenItems: hiddenPlan),
            if (isPremium) ...[
              if (result.careProfile != null) ...[
                const Divider(height: 26, color: AppColors.border),
                _CareProfileCard(profile: result.careProfile!),
              ],
              const Divider(height: 26, color: AppColors.border),
              _PremiumFollowUp(
                result: result,
                isSaving: isSaving,
                onSchedule: onSchedule,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PremiumPlanUnlock extends StatelessWidget {
  const _PremiumPlanUnlock({required this.hiddenItems});

  final List<String> hiddenItems;

  @override
  Widget build(BuildContext context) {
    final hiddenCount = hiddenItems.length;
    final premiumValue = hiddenCount > 0
        ? context.tr(
            '$hiddenCount günlük devam planı • ek olası nedenler • bitkiye özel bakım profili • karşılaştırmalı takip',
            '$hiddenCount more days • additional possible causes • plant-specific care profile • comparison follow-up',
          )
        : context.tr(
            'Ek olası nedenler • bitkiye özel bakım profili • karşılaştırmalı takip',
            'Additional possible causes • plant-specific care profile • comparison follow-up',
          );
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.darkGreen, AppColors.green],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.workspace_premium_outlined, color: Colors.white),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  context.tr(
                    'Premium ayrıntılı bakım',
                    'Premium detailed care',
                  ),
                  style: AppTextStyles.section.copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            premiumValue,
            style: AppTextStyles.muted.copyWith(color: Colors.white70),
          ),
          if (hiddenItems.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 54,
              child: ClipRect(
                child: ExcludeSemantics(
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: hiddenItems
                          .take(2)
                          .map(
                            (item) => Text(
                              item,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.body.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () =>
                  Navigator.of(context).pushNamed(PremiumScreen.routeName),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.darkGreen,
              ),
              icon: const Icon(Icons.lock_open_outlined),
              label: Text(
                context.tr('Tüm bakım planını aç', 'Unlock the full care plan'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumFollowUp extends StatelessWidget {
  const _PremiumFollowUp({
    required this.result,
    required this.isSaving,
    required this.onSchedule,
  });

  final DiagnosisResult result;
  final bool isSaving;
  final Future<void> Function() onSchedule;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.compare_arrows_outlined, color: AppColors.green),
            const SizedBox(width: 9),
            Text(
              context.tr('Karşılaştırmalı takip', 'Comparison follow-up'),
              style: AppTextStyles.section,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          context.tr(
            '${result.plantName} için aynı açıdan yeni fotoğraf çekip yaprak, gövde ve toprak değişimini karşılaştır.',
            'Take a new photo of ${result.plantName} from the same angle and compare leaf, stem and soil changes.',
          ),
          style: AppTextStyles.muted,
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: isSaving ? null : () => onSchedule(),
          icon: const Icon(Icons.notifications_active_outlined),
          label: Text(
            context.tr('Takip hatırlatmasını kur', 'Set follow-up reminder'),
          ),
        ),
      ],
    );
  }
}

class _DiagnosisSafetyCard extends StatelessWidget {
  const _DiagnosisSafetyCard({required this.plantName});

  final String plantName;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: PlantSafetyService.instance.loadProfile(),
      builder: (context, snapshot) {
        final profile =
            snapshot.data ??
            const SafetyProfile(
              hasCat: false,
              hasDog: false,
              hasChild: false,
              configured: false,
            );
        final safety = PlantSafetyService.instance.safetyFor(plantName);
        final color = safety.tone;
        final showFocusedRows = profile.hasAnyRiskGroup;
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color.withValues(alpha: .13),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: color.withValues(alpha: .34)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.health_and_safety_outlined, color: color),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          context.tr('Evcil Hayvan Güvenliği', 'Pet Safety'),
                          style: AppTextStyles.section,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (!showFocusedRows || profile.hasCat)
                    _SafetyResultLine(
                      icon: '🐱',
                      label: context.tr('Kedi', 'Cat'),
                      value: _localizedSafetyValue(context, safety.catFriendly),
                    ),
                  if (!showFocusedRows || profile.hasDog)
                    _SafetyResultLine(
                      icon: '🐶',
                      label: context.tr('Köpek', 'Dog'),
                      value: _localizedSafetyValue(context, safety.dogFriendly),
                    ),
                  if (!showFocusedRows || profile.hasChild)
                    _SafetyResultLine(
                      icon: '👶',
                      label: context.tr('Çocuk', 'Child'),
                      value: _localizedSafetyValue(
                        context,
                        safety.childFriendly,
                      ),
                    ),
                  _SafetyResultLine(
                    icon: '☠️',
                    label: context.tr('Zehirlilik', 'Toxicity'),
                    value: _localizedSafetyValue(context, safety.toxicity),
                  ),
                  const SizedBox(height: 8),
                  Text(safety.warning, style: AppTextStyles.body),
                  const SizedBox(height: 6),
                  Text(
                    safety.recommendation,
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr(
                      'Bitki tüketimi veya temas sonrası ciddi belirti oluşursa veteriner veya sağlık kuruluşuna başvurulmalıdır.',
                      'If serious symptoms occur after eating or touching a plant, contact a veterinarian or healthcare provider.',
                    ),
                    style: AppTextStyles.muted,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

String _localizedSafetyValue(BuildContext context, String value) {
  return switch (value) {
    'Evet' => context.tr('Evet', 'Yes'),
    'Hayır' => context.tr('Hayır', 'No'),
    'Kısmen' => context.tr('Kısmen', 'Partly'),
    'Yok' => context.tr('Yok', 'None'),
    'Düşük' => context.tr('Düşük', 'Low'),
    'Orta' => context.tr('Orta', 'Medium'),
    'Yüksek' => context.tr('Yüksek', 'High'),
    _ => value,
  };
}

class _SafetyResultLine extends StatelessWidget {
  const _SafetyResultLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final String icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Text(icon),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: AppTextStyles.body)),
          Text(
            value,
            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _RiskBadgeCard extends StatelessWidget {
  const _RiskBadgeCard({required this.result});

  final DiagnosisResult result;

  @override
  Widget build(BuildContext context) {
    final badges = _riskBadges(context, result);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DetailHeading(label: context.tr('Risk işaretleri', 'Risk signals')),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: badges
              .map(
                (badge) => _RiskBadge(
                  icon: badge.icon,
                  label: badge.label,
                  color: badge.color,
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  List<_RiskBadgeData> _riskBadges(
    BuildContext context,
    DiagnosisResult result,
  ) {
    final items = <_RiskBadgeData>[];
    for (final cause in result.causes.take(3)) {
      items.add(switch (cause.code) {
        'overwatering' => _RiskBadgeData(
          Icons.water_drop_outlined,
          context.tr('Fazla sulama riski', 'Overwatering risk'),
          AppColors.warning,
        ),
        'underwatering' => _RiskBadgeData(
          Icons.water_drop,
          context.tr('Susuzluk riski', 'Underwatering risk'),
          AppColors.soil,
        ),
        'low_light' => _RiskBadgeData(
          Icons.light_mode_outlined,
          context.tr('Işık eksikliği', 'Low light'),
          AppColors.warning,
        ),
        'sunburn' => _RiskBadgeData(
          Icons.wb_sunny_outlined,
          context.tr('Güneş yanığı', 'Sunburn'),
          AppColors.critical,
        ),
        'pests_risk' => _RiskBadgeData(
          Icons.bug_report_outlined,
          context.tr('Zararlı kontrolü', 'Pest check'),
          AppColors.critical,
        ),
        'fungal_risk' => _RiskBadgeData(
          Icons.grain_outlined,
          context.tr('Mantar riski', 'Fungal risk'),
          AppColors.critical,
        ),
        'pot_drainage_issue' => _RiskBadgeData(
          Icons.inventory_2_outlined,
          context.tr('Drenaj kontrolü', 'Drainage check'),
          AppColors.warning,
        ),
        'healthy' => _RiskBadgeData(
          Icons.check_circle_outline,
          context.tr('Sağlıklı görünüm', 'Healthy look'),
          AppColors.green,
        ),
        _ => _RiskBadgeData(Icons.eco_outlined, cause.title, AppColors.green),
      });
    }
    if (result.needsCloseup) {
      items.add(
        _RiskBadgeData(
          Icons.center_focus_strong,
          context.tr('Yakın çekim gerekli', 'Close-up needed'),
          AppColors.warning,
        ),
      );
    }
    if (items.isEmpty) {
      items.add(
        _RiskBadgeData(
          Icons.eco_outlined,
          context.tr('Bakım kontrolü', 'Care check'),
          AppColors.green,
        ),
      );
    }
    return items;
  }
}

class _RiskBadgeData {
  const _RiskBadgeData(this.icon, this.label, this.color);

  final IconData icon;
  final String label;
  final Color color;
}

class _RiskBadge extends StatelessWidget {
  const _RiskBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: .34)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 17),
            const SizedBox(width: 7),
            Text(
              label,
              style: AppTextStyles.muted.copyWith(
                color: AppColors.darkGreen,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumAnalysisCard extends StatelessWidget {
  const _PremiumAnalysisCard({required this.isPremium});

  final bool isPremium;

  @override
  Widget build(BuildContext context) {
    if (!isPremium) {
      return const SizedBox.shrink();
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: .22)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.workspace_premium_outlined,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              context.tr('Premium analiz', 'Premium analysis'),
              style: AppTextStyles.muted.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CareProfileCard extends StatelessWidget {
  const _CareProfileCard({required this.profile});

  final PlantCareProfile profile;

  @override
  Widget build(BuildContext context) {
    final avoid = profile.avoid.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.local_florist_outlined, color: AppColors.green),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.tr('Bakım profili', 'Care Profile'),
                style: AppTextStyles.section,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _CareProfileRow(
          icon: Icons.water_drop_outlined,
          label: context.tr('Sulama', 'Watering'),
          value:
              '${profile.watering.soilTrigger} ${profile.watering.intervalText}',
        ),
        _CareProfileRow(
          icon: Icons.wb_sunny_outlined,
          label: context.tr('Işık', 'Light'),
          value: profile.light.isEmpty
              ? context.tr(
                  'Aydınlık konum önerilir.',
                  'A bright location is recommended.',
                )
              : profile.light,
        ),
        if (profile.watering.note.isNotEmpty)
          _CareProfileRow(
            icon: Icons.info_outline,
            label: context.tr('Not', 'Note'),
            value: profile.watering.note,
          ),
        PremiumCareTips(profile: profile, isPremiumOverride: true),
        if (avoid.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(context.tr('Kaçın', 'Avoid'), style: AppTextStyles.muted),
          const SizedBox(height: 8),
          ...avoid.map((item) => _Bullet(item)),
        ],
      ],
    );
  }
}

class _CareProfileRow extends StatelessWidget {
  const _CareProfileRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.green, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.muted.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(value, style: AppTextStyles.body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SafetyAndLimitsSection extends StatelessWidget {
  const _SafetyAndLimitsSection({
    required this.result,
    required this.avoidanceTips,
  });

  final DiagnosisResult result;
  final List<String> avoidanceTips;

  @override
  Widget build(BuildContext context) {
    final confidenceNote = result.confidenceNote?.trim();
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 2),
        childrenPadding: const EdgeInsets.fromLTRB(2, 2, 2, 10),
        leading: const Icon(Icons.shield_outlined, color: AppColors.green),
        title: Text(
          context.tr('Güvenlik ve analiz notları', 'Safety and analysis notes'),
          style: AppTextStyles.section,
        ),
        subtitle: Text(
          context.tr(
            'Güvenli kullanım, kaçınılacaklar ve analizin sınırları',
            'Safe use, what to avoid and analysis limits',
          ),
          style: AppTextStyles.muted,
        ),
        shape: const Border(bottom: BorderSide(color: AppColors.border)),
        collapsedShape: const Border(
          bottom: BorderSide(color: AppColors.border),
        ),
        children: [
          _DetailHeading(
            label: context.tr('Kaçınılması gerekenler', 'Avoid these'),
          ),
          ...avoidanceTips.map((item) => _Bullet(item)),
          const SizedBox(height: 6),
          _DetailHeading(
            label: context.tr('Güvenli kullanım notu', 'Safety note'),
          ),
          Text(result.safetyNote, style: AppTextStyles.body),
          if (confidenceNote != null && confidenceNote.isNotEmpty) ...[
            const SizedBox(height: 14),
            _DetailHeading(
              label: context.tr('Analizin sınırları', 'Analysis limits'),
            ),
            Text(confidenceNote, style: AppTextStyles.body),
          ],
        ],
      ),
    );
  }
}

class _ResultSummaryCard extends StatelessWidget {
  const _ResultSummaryCard({required this.result, required this.isPremium});

  final DiagnosisResult result;
  final bool isPremium;

  @override
  Widget build(BuildContext context) {
    final tone = !result.isPlant
        ? AppColors.warning
        : result.healthScore >= 80
        ? AppColors.green
        : result.healthScore >= 50
        ? AppColors.warning
        : AppColors.critical;

    return AppCard(
      color: AppColors.darkGreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.eco, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  result.isPlant
                      ? context.tr('Sağlık özeti', 'Health summary')
                      : context.tr('Fotoğraf sonucu', 'Photo result'),
                  style: AppTextStyles.title.copyWith(color: Colors.white),
                ),
              ),
              _PremiumAnalysisCard(isPremium: isPremium),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: result.isPlant
                ? [
                    _SummaryPill(
                      label: context.tr(
                        '${result.healthScore}/100 sağlık',
                        '${result.healthScore}/100 health',
                      ),
                      color: tone,
                    ),
                    _SummaryPill(label: result.status, color: tone),
                    _SummaryPill(
                      label:
                          '${context.tr('Güven', 'Confidence')}: ${_analysisConfidence(context, result)}',
                      color: AppColors.lightGreen,
                    ),
                    _SummaryPill(
                      label: result.needsCloseup
                          ? context.tr(
                              'Yakın çekim önerilir',
                              'Close-up suggested',
                            )
                          : context.tr(
                              'Görüntü yeterli',
                              'Image is sufficient',
                            ),
                      color: AppColors.lightGreen,
                    ),
                  ]
                : [
                    _SummaryPill(
                      label: context.tr(
                        'Yeni fotoğraf gerekli',
                        'New photos required',
                      ),
                      color: tone,
                    ),
                    _SummaryPill(
                      label: context.tr(
                        'Sağlık skoru oluşturulmadı',
                        'No health score generated',
                      ),
                      color: AppColors.lightGreen,
                    ),
                  ],
          ),
        ],
      ),
    );
  }
}

String _analysisConfidence(BuildContext context, DiagnosisResult result) {
  if (result.needsCloseup) {
    return context.tr('Orta', 'Medium');
  }
  final topConfidence = result.causes.isEmpty
      ? 0
      : result.causes
            .map((cause) => cause.percent)
            .reduce((a, b) => a > b ? a : b);
  if (topConfidence >= 70) {
    return context.tr('Yüksek', 'High');
  }
  if (topConfidence >= 45) {
    return context.tr('Orta', 'Medium');
  }
  return context.tr('Düşük', 'Low');
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: .18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: .35)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          label,
          style: AppTextStyles.muted.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _PlantImage extends StatelessWidget {
  const _PlantImage({required this.result});

  final DiagnosisResult result;

  @override
  Widget build(BuildContext context) {
    final path = result.imagePath;
    final imageUrl = result.imageUrl;
    Widget image;
    if (path != null && File(path).existsSync()) {
      image = Image.file(
        File(path),
        height: 260,
        width: double.infinity,
        fit: BoxFit.cover,
      );
    } else if (imageUrl != null && imageUrl.isNotEmpty) {
      image = Image.network(
        imageUrl,
        height: 260,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const _PlantFallback(),
      );
    } else {
      return const _PlantFallback();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        children: [
          image,
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: .04),
                    Colors.black.withValues(alpha: .46),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 14,
            top: 14,
            child: _PhotoPill(
              icon: Icons.photo_camera_outlined,
              label: context.tr('Analiz edilen fotoğraf', 'Analyzed photo'),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.plantName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.title.copyWith(
                    color: Colors.white,
                    fontSize: 27,
                  ),
                ),
                const SizedBox(height: 8),
                _PhotoPill(
                  icon: result.needsCloseup
                      ? Icons.center_focus_strong
                      : Icons.check_circle_outline,
                  label: result.needsCloseup
                      ? context.tr(
                          'Yakın çekim sonucu güçlendirir',
                          'Close-up strengthens the result',
                        )
                      : context.tr(
                          'Fotoğraf analiz için uygun',
                          'Photo is suitable for analysis',
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoPill extends StatelessWidget {
  const _PhotoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .88),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.darkGreen, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.muted.copyWith(
                color: AppColors.darkGreen,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlantFallback extends StatelessWidget {
  const _PlantFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 210,
      decoration: BoxDecoration(
        color: AppColors.lightGreen.withValues(alpha: .4),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Icon(Icons.local_florist, color: AppColors.green, size: 74),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Icon(Icons.circle, size: 7, color: AppColors.green),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: AppTextStyles.body)),
        ],
      ),
    );
  }
}
