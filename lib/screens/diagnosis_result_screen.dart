import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../models/diagnosis_result.dart';
import '../services/ad_service.dart';
import '../services/entitlement_service.dart';
import '../services/language_service.dart';
import '../services/notification_service.dart';
import '../services/plant_safety_service.dart';
import '../services/plant_repository.dart';
import '../services/premium_prompt_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/health_score_card.dart';
import '../widgets/locked_feature_card.dart';
import '../widgets/paywall_bottom_sheet.dart';
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
      final shouldShowOffer = await PremiumPromptService.instance
          .shouldShowAfterSuccessfulDiagnosis();
      if (!mounted) {
        return;
      }
      if (shouldShowOffer) {
        final openPremium = await showDailyPremiumOfferBottomSheet(context);
        if (mounted && openPremium) {
          await Navigator.of(context).pushNamed(PremiumScreen.routeName);
        }
        return;
      }
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
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _PlantImage(result: result),
          const SizedBox(height: 16),
          _ResultSummaryCard(result: result),
          const SizedBox(height: 16),
          if (!result.isPlant) ...[
            _RetakePhotoCard(result: result),
            const SizedBox(height: 14),
          ] else ...[
            HealthScoreCard(score: result.healthScore, status: result.status),
            const SizedBox(height: 16),
            _TrustCard(result: result),
            const SizedBox(height: 16),
            if (result.visualFindings.isNotEmpty)
              _InfoCard(
                title: context.tr(
                  'Fotoğrafta gördüklerimiz',
                  'What we saw in the photo',
                ),
                children: result.visualFindings
                    .map((item) => _Bullet(item))
                    .toList(),
              ),
            _LikelyCausesCard(result: result),
            _RiskBadgeCard(result: result),
            _InfoCard(
              title: context.tr('Bugün yapılacaklar', 'What to do today'),
              children: result.actions.map((item) => _Bullet(item)).toList(),
            ),
            _FollowUpTimingCard(result: result),
            if (result.needsCloseup) _RetakePhotoCard(result: result),
            _SevenDayPlanCard(result: result),
            if (result.careProfile != null)
              _CareProfileCard(profile: result.careProfile!),
            _DiagnosisSafetyCard(plantName: result.plantName),
            _InfoCard(
              title: context.tr('Kaçınılması gerekenler', 'Avoid these'),
              children: _avoidanceTips(
                context,
                result,
              ).map((item) => _Bullet(item)).toList(),
            ),
            _InfoCard(
              title: context.tr('Güvenli kullanım notu', 'Safety note'),
              children: [Text(result.safetyNote, style: AppTextStyles.body)],
            ),
            if (result.confidenceNote != null &&
                result.confidenceNote!.trim().isNotEmpty)
              _InfoCard(
                title: context.tr('Analizin sınırları', 'Analysis limits'),
                children: [
                  Text(result.confidenceNote!, style: AppTextStyles.body),
                ],
              ),
            _PremiumAnalysisCard(result: result),
            const SizedBox(height: 14),
            _FollowUpComparisonCard(
              result: result,
              isSaving: _isSaving,
              onSchedule: () => _scheduleReminder(context, result),
            ),
            const SizedBox(height: 14),
          ],
          if (result.isPlant) ...[
            AppButton(
              label: _savedPlantId == null
                  ? context.tr('Bakım Hatırlatması Kur', 'Set Care Reminder')
                  : context.tr('Hatırlatmaları Yenile', 'Refresh Reminders'),
              icon: Icons.notifications_active_outlined,
              onPressed: _isSaving
                  ? null
                  : () => _scheduleReminder(context, result),
            ),
            const SizedBox(height: 10),
            AppButton(
              label: _savedPlantId != null
                  ? context.tr('Bitkilerime Kaydedildi', 'Saved to My Plants')
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

class _LikelyCausesCard extends StatelessWidget {
  const _LikelyCausesCard({required this.result});

  final DiagnosisResult result;

  @override
  Widget build(BuildContext context) {
    final causes = result.causes.take(3).toList();
    return _InfoCard(
      title: context.tr('Olası nedenler', 'Possible causes'),
      children: [
        Text(
          context.tr(
            'Yüzdeler, görünen kanıtlar içindeki göreli AI olasılığını gösterir; doğruluk garantisi değildir.',
            'Percentages show relative AI likelihood among the visible clues; they are not an accuracy guarantee.',
          ),
          style: AppTextStyles.muted,
        ),
        const SizedBox(height: 12),
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
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(child: Text(cause.title, style: AppTextStyles.body)),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.mint,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '%${cause.percent}',
                      style: AppTextStyles.muted.copyWith(
                        color: AppColors.darkGreen,
                        fontWeight: FontWeight.w900,
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

class _FollowUpTimingCard extends StatelessWidget {
  const _FollowUpTimingCard({required this.result});

  final DiagnosisResult result;

  @override
  Widget build(BuildContext context) {
    final urgent = result.healthScore < 50;
    final timing = urgent
        ? context.tr(
            '24 saat içinde aynı açıdan kontrol et. Hızlı yayılma, kötü koku veya gövde yumuşaması varsa uzman desteği al.',
            'Check again from the same angle within 24 hours. Seek expert help if spreading, odor or stem softening develops.',
          )
        : result.healthScore < 80
        ? context.tr(
            '3 gün sonra aynı açıdan fotoğrafla karşılaştır; belirti büyürse daha erken yeni analiz al.',
            'Compare with a same-angle photo in 3 days; run a new analysis sooner if the symptom grows.',
          )
        : context.tr(
            '7 gün sonra aynı açıdan fotoğrafla karşılaştır; belirgin değişiklik yoksa mevcut bakım ritmini koru.',
            'Compare with a same-angle photo in 7 days; keep the current care rhythm if there is no clear change.',
          );
    return _InfoCard(
      title: context.tr('Ne zaman tekrar kontrol edilmeli?', 'When to recheck'),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              urgent ? Icons.priority_high_rounded : Icons.event_repeat,
              color: urgent ? AppColors.critical : AppColors.green,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(timing, style: AppTextStyles.body)),
          ],
        ),
      ],
    );
  }
}

class _SevenDayPlanCard extends StatelessWidget {
  const _SevenDayPlanCard({required this.result});

  final DiagnosisResult result;

  @override
  Widget build(BuildContext context) {
    if (result.sevenDayPlan.isEmpty) {
      return LockedFeatureCard(onTap: () => showPaywallBottomSheet(context));
    }

    return FutureBuilder(
      future: EntitlementService().getCurrentPlan(),
      builder: (context, snapshot) {
        final isPremium = snapshot.data?.isPremium == true;
        final visiblePlan = isPremium
            ? result.sevenDayPlan
            : result.sevenDayPlan.take(3).toList();
        return _InfoCard(
          title: isPremium
              ? context.tr('7 Günlük Bakım Planı', '7-Day Care Plan')
              : context.tr('İlk 3 Günlük Bakım Planı', 'First 3-Day Care Plan'),
          children: [
            ...visiblePlan.map((item) => _Bullet(item)),
            if (!isPremium && result.sevenDayPlan.length > visiblePlan.length)
              _PremiumPlanUnlock(
                hiddenCount: result.sevenDayPlan.length - visiblePlan.length,
              ),
          ],
        );
      },
    );
  }
}

class _PremiumPlanUnlock extends StatelessWidget {
  const _PremiumPlanUnlock({required this.hiddenCount});

  final int hiddenCount;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => showPaywallBottomSheet(context),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.darkGreen,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            const Icon(Icons.lock_open_outlined, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.tr(
                  '$hiddenCount gün daha detay, takip ve uyarı Premium ile açılır.',
                  '$hiddenCount more days of detail, follow-up and alerts unlock with Premium.',
                ),
                style: AppTextStyles.muted.copyWith(color: Colors.white),
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

class _FollowUpComparisonCard extends StatelessWidget {
  const _FollowUpComparisonCard({
    required this.result,
    required this.isSaving,
    required this.onSchedule,
  });

  final DiagnosisResult result;
  final bool isSaving;
  final Future<void> Function() onSchedule;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: EntitlementService().getCurrentPlan(),
      builder: (context, snapshot) {
        final isPremium = snapshot.data?.isPremium == true;
        return AppCard(
          color: isPremium ? AppColors.darkGreen : AppColors.warmCream,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isPremium
                        ? Icons.compare_arrows_outlined
                        : Icons.workspace_premium_outlined,
                    color: isPremium ? Colors.white : AppColors.darkGreen,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      context.tr(
                        'Karşılaştırmalı takip',
                        'Comparison follow-up',
                      ),
                      style: AppTextStyles.section.copyWith(
                        color: isPremium ? Colors.white : AppColors.darkGreen,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                context.tr(
                  '${result.plantName} için 7 gün sonra aynı açıdan fotoğraf çekip yaprak rengi, gövde duruşu ve toprak değişimini karşılaştır.',
                  'Take another photo of ${result.plantName} from the same angle in 7 days and compare leaf color, stem posture and soil changes.',
                ),
                style: AppTextStyles.muted.copyWith(
                  color: isPremium ? Colors.white70 : AppColors.muted,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: isSaving
                      ? null
                      : isPremium
                      ? () => onSchedule()
                      : () => showPaywallBottomSheet(context),
                  icon: Icon(
                    isPremium
                        ? Icons.notifications_active_outlined
                        : Icons.lock_outline,
                  ),
                  label: Text(
                    isPremium
                        ? context.tr(
                            'Takip hatırlatmasını kur',
                            'Set follow-up reminder',
                          )
                        : context.tr(
                            'Premium takip özelliğini aç',
                            'Unlock Premium follow-up',
                          ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isPremium
                        ? Colors.white
                        : AppColors.darkGreen,
                    side: BorderSide(
                      color: isPremium ? Colors.white70 : AppColors.darkGreen,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TrustCard extends StatelessWidget {
  const _TrustCard({required this.result});

  final DiagnosisResult result;

  @override
  Widget build(BuildContext context) {
    final confidence = _confidenceLabel();
    final photoQuality = result.needsCloseup
        ? context.tr('Daha yakın çekim iyi olur', 'A closer shot would help')
        : context.tr('Görüntü okunabilir', 'Image is readable');
    final nextPhoto = _nextPhotoTip(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Analiz Kalitesi', 'Analysis Quality'),
            style: AppTextStyles.section,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _TrustMetric(
                  icon: Icons.verified_user_outlined,
                  label: context.tr('Tahmin güveni', 'Confidence'),
                  value: confidence,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TrustMetric(
                  icon: Icons.photo_camera_back_outlined,
                  label: context.tr('Fotoğraf', 'Photo'),
                  value: photoQuality,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(nextPhoto, style: AppTextStyles.muted),
        ],
      ),
    );
  }

  String _confidenceLabel() {
    if (result.needsCloseup) {
      return LanguageService.instance.text('Orta', 'Medium');
    }
    final topConfidence = result.causes.isEmpty
        ? 0
        : result.causes
              .map((cause) => cause.percent)
              .reduce((a, b) => a > b ? a : b);
    if (topConfidence >= 70) {
      return LanguageService.instance.text('Yüksek', 'High');
    }
    if (topConfidence >= 45) {
      return LanguageService.instance.text('Orta', 'Medium');
    }
    return LanguageService.instance.text('Düşük', 'Low');
  }

  String _nextPhotoTip(BuildContext context) {
    final name = result.plantName;
    if (result.needsCloseup) {
      return context.tr(
        '$name için yaprak yüzeyi, yaprak altı ve toprağı ayrı ayrı yakın çekim fotoğraflamak sonucu güçlendirir.',
        'For $name, separate close-up photos of the leaf surface, underside and soil will strengthen the result.',
      );
    }
    if (result.causes.any(
      (cause) =>
          cause.code == 'pot_drainage_issue' || cause.code == 'overwatering',
    )) {
      return context.tr(
        'Bir sonraki kontrolde saksı altı, tabak ve toprağın üst kısmını da çekersen sulama yorumu daha netleşir.',
        'At the next check, include the pot base, saucer and soil surface for a clearer watering comment.',
      );
    }
    return context.tr(
      'Aynı açıdan tekrar fotoğraf çekmek önce/sonra gelişim takibini daha güvenilir yapar.',
      'Repeating the photo from the same angle makes before/after tracking more reliable.',
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

class _TrustMetric extends StatelessWidget {
  const _TrustMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.mint.withValues(alpha: .56),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.green),
            const SizedBox(height: 8),
            Text(label, style: AppTextStyles.muted.copyWith(fontSize: 12)),
            const SizedBox(height: 3),
            Text(
              value,
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w900),
            ),
          ],
        ),
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
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Risk rozetleri', 'Risk Badges'),
            style: AppTextStyles.section,
          ),
          const SizedBox(height: 12),
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
      ),
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
  const _PremiumAnalysisCard({required this.result});

  final DiagnosisResult result;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: EntitlementService().getCurrentPlan(),
      builder: (context, snapshot) {
        final isPremium = snapshot.data?.isPremium == true;
        final proAnalysis =
            result.analysisTier == 'pro' || result.analysisTier == 'premium';
        final title = proAnalysis
            ? context.tr(
                'Premium detaylı analiz aktif',
                'Premium detailed analysis active',
              )
            : isPremium
            ? context.tr(
                'Premium bakım planın aktif',
                'Your Premium care plan is active',
              )
            : context.tr(
                'Premium ile daha fazla bakım hakkı',
                'Get more care access with Premium',
              );
        final text = proAnalysis
            ? context.tr(
                'Bu analiz görsel kanıtlar, bitkiye özel bakım arşivi ve akıllı hatırlatma planıyla hazırlandı.',
                'This analysis was prepared with visual evidence, plant-specific care archive and smart reminders.',
              )
            : isPremium
            ? context.tr(
                'Premium hesabında geniş bakım arşivi, reklamsız kullanım ve akıllı hatırlatmalar aktiftir.',
                'Your Premium account includes the extended care archive, ad-free use and smart reminders.',
              )
            : context.tr(
                'Premium kullanıcılar daha fazla analiz hakkı, reklamsız kullanım ve akıllı hatırlatmalardan yararlanır.',
                'Premium users get more analysis credits, ad-free use and smart reminders.',
              );
        return AppCard(
          color: isPremium
              ? AppColors.darkGreen
              : AppColors.warmCream.withValues(alpha: .92),
          child: Row(
            children: [
              Icon(
                isPremium
                    ? Icons.workspace_premium_outlined
                    : Icons.auto_awesome_outlined,
                color: isPremium ? Colors.white : AppColors.darkGreen,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.section.copyWith(
                        color: isPremium ? Colors.white : AppColors.darkGreen,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      text,
                      style: AppTextStyles.muted.copyWith(
                        color: isPremium ? Colors.white70 : AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CareProfileCard extends StatelessWidget {
  const _CareProfileCard({required this.profile});

  final PlantCareProfile profile;

  @override
  Widget build(BuildContext context) {
    final tips = profile.specialTips.take(3).toList();
    final avoid = profile.avoid.take(3).toList();
    return AppCard(
      color: AppColors.mint.withValues(alpha: .82),
      child: Column(
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
          if (tips.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              context.tr('Özel ipuçları', 'Special tips'),
              style: AppTextStyles.muted,
            ),
            const SizedBox(height: 8),
            ...tips.map((tip) => _Bullet(tip)),
          ],
          if (avoid.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(context.tr('Kaçın', 'Avoid'), style: AppTextStyles.muted),
            const SizedBox(height: 8),
            ...avoid.map((item) => _Bullet(item)),
          ],
        ],
      ),
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

class _ResultSummaryCard extends StatelessWidget {
  const _ResultSummaryCard({required this.result});

  final DiagnosisResult result;

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
                  result.plantName,
                  style: AppTextStyles.title.copyWith(color: Colors.white),
                ),
              ),
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

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTextStyles.section),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
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
