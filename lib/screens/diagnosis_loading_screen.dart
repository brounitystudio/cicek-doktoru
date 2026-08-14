import 'dart:async';

import 'package:flutter/material.dart';

import '../data/plant_trivia.dart';
import '../services/diagnosis_service.dart';
import '../services/language_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/paywall_bottom_sheet.dart';
import 'diagnosis_result_screen.dart';

class DiagnosisLoadingScreen extends StatefulWidget {
  const DiagnosisLoadingScreen({super.key});

  static const routeName = '/diagnosis-loading';

  @override
  State<DiagnosisLoadingScreen> createState() => _DiagnosisLoadingScreenState();
}

class _DiagnosisLoadingScreenState extends State<DiagnosisLoadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Timer _messageTimer;
  late final Timer _factTimer;
  int _messageIndex = 0;
  int _factIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _messageTimer = Timer.periodic(const Duration(milliseconds: 900), (_) {
      if (mounted) {
        setState(() => _messageIndex = (_messageIndex + 1) % 4);
      }
    });
    _factTimer = Timer.periodic(const Duration(seconds: 7), (_) {
      if (mounted) {
        setState(
          () => _factIndex = (_factIndex + 1) % PlantTrivia.facts.length,
        );
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _diagnose());
  }

  Future<void> _diagnose() async {
    final input = ModalRoute.of(context)?.settings.arguments as PlantScanInput?;
    try {
      final result = await DiagnosisService().diagnose(
        input ??
            const PlantScanInput(
              location: 'İç mekân',
              lastWatered: '1-3 gün önce',
              sunlight: 'Aydınlık ama direkt değil',
              hasDrainage: 'Bilmiyorum',
              symptomType: 'Sararma / solma',
              symptomDuration: 'Birkaç gündür',
            ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushReplacementNamed(
        DiagnosisResultScreen.routeName,
        arguments: result,
      );
    } on DiagnosisNoCreditsException {
      if (!mounted) {
        return;
      }
      final retry = await showPaywallBottomSheet(context);
      if (!mounted) {
        return;
      }
      if (retry) {
        unawaited(_diagnose());
      } else {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      final retry = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            context.tr(
              'Fotoğrafı işleyemedik',
              'We could not process the photo',
            ),
          ),
          content: Text(
            context.tr(
              '${error.toString()}\n\nİstersen aynı fotoğrafla tekrar deneyebilir veya daha net bir çekim yapabilirsin.',
              '${error.toString()}\n\nYou can try again with the same photo or take a clearer shot.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.tr('Geri dön', 'Go back')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(context.tr('Tekrar dene', 'Try again')),
            ),
          ],
        ),
      );
      if (!mounted) {
        return;
      }
      if (retry == true) {
        unawaited(_diagnose());
      } else {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  void dispose() {
    _messageTimer.cancel();
    _factTimer.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messages = [
      context.tr('Fotoğraf inceleniyor...', 'Reviewing photos...'),
      context.tr('Bitki türü eşleştiriliyor...', 'Matching plant type...'),
      context.tr(
        'Bakım arşivi kontrol ediliyor...',
        'Checking care archive...',
      ),
      context.tr('Öneriler hazırlanıyor...', 'Preparing suggestions...'),
    ];
    final steps = [
      context.tr('Fotoğraf', 'Photo'),
      context.tr('Bitki türü', 'Plant type'),
      context.tr('Bakım arşivi', 'Care archive'),
      context.tr('Plan', 'Plan'),
    ];
    final facts = LanguageService.instance.isEnglish
        ? PlantTrivia.englishFacts
        : PlantTrivia.facts;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: Tween<double>(begin: .92, end: 1.08).animate(
                    CurvedAnimation(
                      parent: _controller,
                      curve: Curves.easeInOut,
                    ),
                  ),
                  child: const Icon(
                    Icons.eco,
                    size: 88,
                    color: AppColors.green,
                  ),
                ),
                const SizedBox(height: 24),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  child: Text(
                    messages[_messageIndex],
                    key: ValueKey(_messageIndex),
                    style: AppTextStyles.section,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 18),
                _LoadingSteps(activeIndex: _messageIndex, steps: steps),
                const SizedBox(height: 22),
                _PlantFactCard(fact: facts[_factIndex], index: _factIndex),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingSteps extends StatelessWidget {
  const _LoadingSteps({required this.activeIndex, required this.steps});

  final int activeIndex;
  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 430),
      child: Row(
        children: [
          for (var index = 0; index < steps.length; index++) ...[
            Expanded(
              child: _LoadingStep(
                label: steps[index],
                active: index == activeIndex,
                done: index < activeIndex,
              ),
            ),
            if (index != steps.length - 1)
              Container(
                width: 12,
                height: 2,
                color: index < activeIndex
                    ? AppColors.green
                    : AppColors.lightGreen.withValues(alpha: .48),
              ),
          ],
        ],
      ),
    );
  }
}

class _LoadingStep extends StatelessWidget {
  const _LoadingStep({
    required this.label,
    required this.active,
    required this.done,
  });

  final String label;
  final bool active;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final color = done || active ? AppColors.green : AppColors.muted;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: active ? 30 : 24,
          height: active ? 30 : 24,
          decoration: BoxDecoration(
            color: done || active
                ? AppColors.mint
                : Colors.white.withValues(alpha: .8),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withValues(alpha: .55)),
          ),
          child: Icon(
            done ? Icons.check_rounded : Icons.eco_outlined,
            color: color,
            size: active ? 17 : 14,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.muted.copyWith(
            color: color,
            fontSize: 11,
            fontWeight: active ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _PlantFactCard extends StatelessWidget {
  const _PlantFactCard({required this.fact, required this.index});

  final String fact;
  final int index;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420, minHeight: 132),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .94),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: AppColors.lightGreen.withValues(alpha: .42),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.green.withValues(alpha: .10),
              blurRadius: 22,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: AppColors.mint,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Icon(
                      Icons.lightbulb_outline,
                      color: AppColors.green,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    context.tr('Bitki bilgisi', 'Plant fact'),
                    style: AppTextStyles.muted.copyWith(
                      color: AppColors.darkGreen,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 360),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, .08),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: Text(
                  fact,
                  key: ValueKey(index),
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
