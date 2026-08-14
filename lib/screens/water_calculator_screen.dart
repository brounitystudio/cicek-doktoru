import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_form_controls.dart';
import '../widgets/botanical_background.dart';

class WaterCalculatorScreen extends StatefulWidget {
  const WaterCalculatorScreen({super.key});

  static const routeName = '/water-calculator';

  @override
  State<WaterCalculatorScreen> createState() => _WaterCalculatorScreenState();
}

class _WaterCalculatorScreenState extends State<WaterCalculatorScreen> {
  static const _historyKey = 'water_calculator_history';

  final _formKey = GlobalKey<FormState>();
  final _plantNameController = TextEditingController();
  final _potDiameterController = TextEditingController();
  final _potHeightController = TextEditingController();

  _WaterPlantCategory _category = _WaterPlantCategory.houseplant;
  _PotMaterial _potMaterial = _PotMaterial.plastic;
  _WaterLocation _location = _WaterLocation.home;
  _SunHours _sunHours = _SunHours.twoToFour;
  _TemperatureRange _temperature = _TemperatureRange.twentyToTwentyFive;
  _HumidityLevel _humidity = _HumidityLevel.normal;
  _Season _season = _Season.spring;
  bool _usesAc = false;
  bool _getsWind = false;
  _WaterCalculationResult? _result;
  List<_WaterHistoryItem> _history = const [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _plantNameController.dispose();
    _potDiameterController.dispose();
    _potHeightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Su Hesaplayıcı')),
      body: BotanicalBackground(
        child: SafeArea(
          top: false,
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 118),
              children: [
                const _IntroCard(),
                const SizedBox(height: 14),
                _PlantFormCard(
                  plantNameController: _plantNameController,
                  category: _category,
                  onCategoryChanged: (value) => setState(
                    () => _category = value ?? _WaterPlantCategory.houseplant,
                  ),
                ),
                const SizedBox(height: 14),
                _PotFormCard(
                  diameterController: _potDiameterController,
                  heightController: _potHeightController,
                  potMaterial: _potMaterial,
                  onPotMaterialChanged: (value) => setState(
                    () => _potMaterial = value ?? _PotMaterial.plastic,
                  ),
                ),
                const SizedBox(height: 14),
                _EnvironmentFormCard(
                  location: _location,
                  sunHours: _sunHours,
                  temperature: _temperature,
                  humidity: _humidity,
                  season: _season,
                  usesAc: _usesAc,
                  getsWind: _getsWind,
                  onLocationChanged: (value) =>
                      setState(() => _location = value ?? _WaterLocation.home),
                  onSunHoursChanged: (value) =>
                      setState(() => _sunHours = value ?? _SunHours.twoToFour),
                  onTemperatureChanged: (value) => setState(
                    () => _temperature =
                        value ?? _TemperatureRange.twentyToTwentyFive,
                  ),
                  onHumidityChanged: (value) => setState(
                    () => _humidity = value ?? _HumidityLevel.normal,
                  ),
                  onSeasonChanged: (value) =>
                      setState(() => _season = value ?? _Season.spring),
                  onUsesAcChanged: (value) => setState(() => _usesAc = value),
                  onGetsWindChanged: (value) =>
                      setState(() => _getsWind = value),
                ),
                const SizedBox(height: 16),
                AppButton(
                  label: 'Hesapla',
                  icon: Icons.water_drop_outlined,
                  onPressed: _calculate,
                ),
                if (_result != null) ...[
                  const SizedBox(height: 18),
                  _WaterResultCard(
                    result: _result!,
                    saving: _saving,
                    onSaveWatering: _saveWateringAndReminder,
                  ),
                ],
                if (_history.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  _HistoryCard(items: _history),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _calculate() {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    final diameter = _parseNumber(_potDiameterController.text);
    final height = _parseNumber(_potHeightController.text);
    var multiplier = 1.0;
    final adjustments = <String>[];

    void apply(double percent, String label) {
      multiplier += percent;
      adjustments.add(label);
    }

    switch (_temperature) {
      case _TemperatureRange.tenToFifteen:
        apply(-.20, '15°C altı serin ortam su ihtiyacını azaltır.');
      case _TemperatureRange.twentyFiveToThirty:
        apply(.15, '25°C üzeri sıcaklık su ihtiyacını artırır.');
      case _TemperatureRange.thirtyPlus:
        apply(.25, '30°C+ sıcaklıkta buharlaşma belirgin artar.');
      default:
        break;
    }

    switch (_sunHours) {
      case _SunHours.zeroToTwo:
        apply(-.15, '0-2 saat güneş alan bitkide tüketim daha düşüktür.');
      case _SunHours.sixPlus:
        apply(.20, '6 saatten fazla güneş sulama ihtiyacını artırır.');
      default:
        break;
    }

    switch (_potMaterial) {
      case _PotMaterial.clay:
        apply(.10, 'Toprak saksı nemi daha hızlı kaybettirir.');
      case _PotMaterial.concrete:
        apply(.05, 'Beton saksıda buharlaşma biraz artabilir.');
      default:
        break;
    }

    if (_usesAc) {
      apply(.10, 'Klima havayı kurutabilir.');
    }
    if (_getsWind && _location == _WaterLocation.balcony) {
      apply(.10, 'Rüzgar alan balkonda toprak daha hızlı kurur.');
    }

    switch (_season) {
      case _Season.summer:
        apply(.20, 'Yaz aylarında sulama ihtiyacı artabilir.');
      case _Season.autumn:
        apply(-.10, 'Sonbaharda büyüme hızı yavaşlar.');
      case _Season.winter:
        apply(-.30, 'Kışın su ihtiyacı belirgin azalır.');
      case _Season.spring:
        break;
    }

    if (_humidity == _HumidityLevel.low) {
      apply(.08, 'Düşük nem yaprak ve toprak kaybını artırır.');
    } else if (_humidity == _HumidityLevel.high) {
      apply(-.08, 'Yüksek nem toprağın daha yavaş kurumasına yardım eder.');
    }

    if (height > diameter * 5) {
      adjustments.add(
        'Bitki boyu saksıya göre yüksek; devrilme ve hızlı kuruma açısından takip et.',
      );
    }

    final rawAmount = diameter * _category.coefficient * multiplier;
    final amount = rawAmount.clamp(30, 5000).round();
    final interval = _adjustedInterval(_category.interval, multiplier);
    final nextWatering = DateTime.now().add(Duration(days: interval.max));
    final warnings = _warnings(interval);

    setState(() {
      _result = _WaterCalculationResult(
        plantName: _plantNameController.text.trim(),
        category: _category,
        amountMl: amount,
        interval: interval,
        nextWatering: nextWatering,
        adjustments: adjustments,
        warnings: warnings,
        seasonalAdvice: _season.advice,
      );
    });
  }

  _DayInterval _adjustedInterval(_DayInterval base, double multiplier) {
    var factor = 1.0;
    if (multiplier >= 1.25) {
      factor = .82;
    } else if (multiplier >= 1.12) {
      factor = .90;
    } else if (multiplier <= .72) {
      factor = 1.35;
    } else if (multiplier <= .88) {
      factor = 1.18;
    }

    final min = (base.min * factor).round().clamp(1, 365);
    final max = (base.max * factor).round().clamp(min, 365);
    return _DayInterval(min, max);
  }

  List<_WarningMessage> _warnings(_DayInterval interval) {
    return [
      const _WarningMessage(
        text: 'Toprak tamamen kurumadan tekrar sulama yapma.',
        severity: _WarningSeverity.warning,
      ),
      const _WarningMessage(
        text: 'Saksı altında su biriktirme; tabakta kalan suyu boşalt.',
        severity: _WarningSeverity.warning,
      ),
      if (_season == _Season.winter)
        const _WarningMessage(
          text: 'Kışın fazla sulama kök çürümesi riskini artırır.',
          severity: _WarningSeverity.critical,
        ),
      if (interval.max <= 3)
        const _WarningMessage(
          text:
              'Sık sulama gerektiren bitkilerde drenaj ve toprak kokusunu düzenli kontrol et.',
          severity: _WarningSeverity.critical,
        ),
      const _WarningMessage(
        text:
            'Bu değerler tahmini önerilerdir. Sulama kararında her zaman toprağın nem durumu ve bitkinin görünümü dikkate alınmalıdır.',
        severity: _WarningSeverity.critical,
      ),
    ];
  }

  Future<void> _saveWateringAndReminder() async {
    final result = _result;
    if (result == null || _saving) {
      return;
    }
    setState(() => _saving = true);
    final item = _WaterHistoryItem(
      plantName: result.plantName,
      date: DateTime.now(),
      amountMl: result.amountMl,
      intervalText: result.interval.label,
      nextWatering: result.nextWatering,
    );
    final updated = [item, ..._history].take(12).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _historyKey,
      updated.map((entry) => jsonEncode(entry.toJson())).toList(),
    );
    final scheduled = await NotificationService.instance
        .scheduleWateringCalculatorReminder(
          plantName: result.plantName,
          dueDate: result.nextWatering,
          amountMl: result.amountMl,
          intervalText: result.interval.label,
        );
    if (!mounted) {
      return;
    }
    setState(() {
      _history = updated;
      _saving = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          scheduled
              ? 'Sulama tarihi kaydedildi ve bildirim kuruldu.'
              : 'Sulama tarihi kaydedildi. Hatırlatma için bildirim iznini aç.',
        ),
        action: scheduled
            ? null
            : SnackBarAction(
                label: 'AYARLAR',
                onPressed: () =>
                    NotificationService.instance.openNotificationSettings(),
              ),
      ),
    );
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_historyKey) ?? const [];
    final items = raw
        .map((item) {
          try {
            return _WaterHistoryItem.fromJson(
              Map<String, dynamic>.from(jsonDecode(item) as Map),
            );
          } catch (_) {
            return null;
          }
        })
        .whereType<_WaterHistoryItem>()
        .toList();
    if (!mounted) {
      return;
    }
    setState(() => _history = items);
  }

  double _parseNumber(String value) {
    return double.parse(value.replaceAll(',', '.').trim());
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.mint.withValues(alpha: .86),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFF2477A6),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.water_drop_outlined, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ne Kadar Su Vermeliyim?', style: AppTextStyles.section),
                const SizedBox(height: 4),
                const Text(
                  'Bitki, saksı, ortam ve mevsime göre tahmini su miktarı ve sulama aralığı hesapla.',
                  style: AppTextStyles.muted,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlantFormCard extends StatelessWidget {
  const _PlantFormCard({
    required this.plantNameController,
    required this.category,
    required this.onCategoryChanged,
  });

  final TextEditingController plantNameController;
  final _WaterPlantCategory category;
  final ValueChanged<_WaterPlantCategory?> onCategoryChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bitki bilgileri', style: AppTextStyles.section),
          const SizedBox(height: 14),
          _TextInput(
            controller: plantNameController,
            label: 'Bitki adı',
            icon: Icons.local_florist_outlined,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Bitki adını yaz.';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          _DropdownInput<_WaterPlantCategory>(
            label: 'Bitki kategorisi',
            icon: Icons.eco_outlined,
            value: category,
            items: _WaterPlantCategory.values,
            labelBuilder: (value) => value.label,
            onChanged: onCategoryChanged,
          ),
        ],
      ),
    );
  }
}

class _PotFormCard extends StatelessWidget {
  const _PotFormCard({
    required this.diameterController,
    required this.heightController,
    required this.potMaterial,
    required this.onPotMaterialChanged,
  });

  final TextEditingController diameterController;
  final TextEditingController heightController;
  final _PotMaterial potMaterial;
  final ValueChanged<_PotMaterial?> onPotMaterialChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Saksı bilgileri', style: AppTextStyles.section),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _TextInput(
                  controller: diameterController,
                  label: 'Çap (cm)',
                  icon: Icons.radio_button_unchecked,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: _numberValidator,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TextInput(
                  controller: heightController,
                  label: 'Yükseklik (cm)',
                  icon: Icons.height,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: _numberValidator,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _DropdownInput<_PotMaterial>(
            label: 'Saksı tipi',
            icon: Icons.inventory_2_outlined,
            value: potMaterial,
            items: _PotMaterial.values,
            labelBuilder: (value) => value.label,
            onChanged: onPotMaterialChanged,
          ),
        ],
      ),
    );
  }
}

class _EnvironmentFormCard extends StatelessWidget {
  const _EnvironmentFormCard({
    required this.location,
    required this.sunHours,
    required this.temperature,
    required this.humidity,
    required this.season,
    required this.usesAc,
    required this.getsWind,
    required this.onLocationChanged,
    required this.onSunHoursChanged,
    required this.onTemperatureChanged,
    required this.onHumidityChanged,
    required this.onSeasonChanged,
    required this.onUsesAcChanged,
    required this.onGetsWindChanged,
  });

  final _WaterLocation location;
  final _SunHours sunHours;
  final _TemperatureRange temperature;
  final _HumidityLevel humidity;
  final _Season season;
  final bool usesAc;
  final bool getsWind;
  final ValueChanged<_WaterLocation?> onLocationChanged;
  final ValueChanged<_SunHours?> onSunHoursChanged;
  final ValueChanged<_TemperatureRange?> onTemperatureChanged;
  final ValueChanged<_HumidityLevel?> onHumidityChanged;
  final ValueChanged<_Season?> onSeasonChanged;
  final ValueChanged<bool> onUsesAcChanged;
  final ValueChanged<bool> onGetsWindChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ortam ve mevsim', style: AppTextStyles.section),
          const SizedBox(height: 14),
          _DropdownInput<_WaterLocation>(
            label: 'Konum',
            icon: Icons.place_outlined,
            value: location,
            items: _WaterLocation.values,
            labelBuilder: (value) => value.label,
            onChanged: onLocationChanged,
          ),
          const SizedBox(height: 12),
          _DropdownInput<_SunHours>(
            label: 'Günlük güneş alma süresi',
            icon: Icons.wb_sunny_outlined,
            value: sunHours,
            items: _SunHours.values,
            labelBuilder: (value) => value.label,
            onChanged: onSunHoursChanged,
          ),
          const SizedBox(height: 12),
          _DropdownInput<_TemperatureRange>(
            label: 'Ortam sıcaklığı',
            icon: Icons.thermostat_outlined,
            value: temperature,
            items: _TemperatureRange.values,
            labelBuilder: (value) => value.label,
            onChanged: onTemperatureChanged,
          ),
          const SizedBox(height: 12),
          _DropdownInput<_HumidityLevel>(
            label: 'Nem oranı',
            icon: Icons.opacity_outlined,
            value: humidity,
            items: _HumidityLevel.values,
            labelBuilder: (value) => value.label,
            onChanged: onHumidityChanged,
          ),
          const SizedBox(height: 12),
          _DropdownInput<_Season>(
            label: 'Mevsim',
            icon: Icons.calendar_month_outlined,
            value: season,
            items: _Season.values,
            labelBuilder: (value) => value.label,
            onChanged: onSeasonChanged,
          ),
          const SizedBox(height: 8),
          _SwitchRow(
            label: 'Klima kullanılıyor mu?',
            value: usesAc,
            onChanged: onUsesAcChanged,
          ),
          _SwitchRow(
            label: 'Rüzgar alıyor mu?',
            value: getsWind,
            onChanged: onGetsWindChanged,
          ),
        ],
      ),
    );
  }
}

class _WaterResultCard extends StatelessWidget {
  const _WaterResultCard({
    required this.result,
    required this.saving,
    required this.onSaveWatering,
  });

  final _WaterCalculationResult result;
  final bool saving;
  final VoidCallback onSaveWatering;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppCard(
          color: const Color(0xFF2477A6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                result.plantName,
                style: AppTextStyles.title.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _WaterMetric(
                      label: 'Tahmini su miktarı',
                      value: '${result.amountMl} ml',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _WaterMetric(
                      label: 'Tahmini sıklık',
                      value: result.interval.label,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _BlueInfoLine(
                icon: Icons.event_available_outlined,
                text:
                    'Sonraki tahmini sulama: ${_formatDate(result.nextWatering)}',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _ResultInfoCard(
          icon: Icons.lightbulb_outline,
          title: 'Mevsime göre tavsiye',
          text: result.seasonalAdvice,
        ),
        if (result.adjustments.isNotEmpty)
          _ResultInfoCard(
            icon: Icons.tune_outlined,
            title: 'Hesaba etki eden koşullar',
            text: result.adjustments.join('\n'),
          ),
        ...result.warnings.map((warning) => _WarningBox(warning: warning)),
        const SizedBox(height: 4),
        AppButton(
          label: saving ? 'Kaydediliyor...' : 'Son sulamayı bugün kaydet',
          icon: Icons.notifications_active_outlined,
          onPressed: saving ? null : onSaveWatering,
        ),
      ],
    );
  }
}

class _WaterMetric extends StatelessWidget {
  const _WaterMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTextStyles.muted.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: AppTextStyles.section.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlueInfoLine extends StatelessWidget {
  const _BlueInfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.body.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _ResultInfoCard extends StatelessWidget {
  const _ResultInfoCard({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        showPattern: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.green),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.section),
                  const SizedBox(height: 6),
                  Text(text, style: AppTextStyles.body),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WarningBox extends StatelessWidget {
  const _WarningBox({required this.warning});

  final _WarningMessage warning;

  @override
  Widget build(BuildContext context) {
    final color = warning.severity == _WarningSeverity.critical
        ? AppColors.critical
        : AppColors.warning;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: .16),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: .45)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                warning.severity == _WarningSeverity.critical
                    ? Icons.error_outline
                    : Icons.warning_amber_outlined,
                color: color,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(warning.text, style: AppTextStyles.body)),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.items});

  final List<_WaterHistoryItem> items;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sulama geçmişi', style: AppTextStyles.section),
          const SizedBox(height: 10),
          ...items
              .take(5)
              .map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.water_drop_outlined,
                        color: AppColors.green,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${item.plantName} • ${item.amountMl} ml • ${_formatDate(item.date)}',
                          style: AppTextStyles.body,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _TextInput extends StatelessWidget {
  const _TextInput({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return AppFormTextField(
      controller: controller,
      label: label,
      icon: icon,
      keyboardType: keyboardType,
      validator: validator,
    );
  }
}

class _DropdownInput<T> extends StatelessWidget {
  const _DropdownInput({
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.labelBuilder,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final T value;
  final List<T> items;
  final String Function(T) labelBuilder;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppOptionSelector<T>(
      label: label,
      icon: icon,
      value: value,
      items: items,
      labelBuilder: labelBuilder,
      onChanged: onChanged,
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: AppTextStyles.body),
      activeThumbColor: AppColors.green,
    );
  }
}

String? _numberValidator(String? value) {
  final normalized = value?.replaceAll(',', '.').trim() ?? '';
  final number = double.tryParse(normalized);
  if (number == null || number <= 0) {
    return 'Geçerli cm gir.';
  }
  return null;
}

class _WaterCalculationResult {
  const _WaterCalculationResult({
    required this.plantName,
    required this.category,
    required this.amountMl,
    required this.interval,
    required this.nextWatering,
    required this.adjustments,
    required this.warnings,
    required this.seasonalAdvice,
  });

  final String plantName;
  final _WaterPlantCategory category;
  final int amountMl;
  final _DayInterval interval;
  final DateTime nextWatering;
  final List<String> adjustments;
  final List<_WarningMessage> warnings;
  final String seasonalAdvice;
}

class _WaterHistoryItem {
  const _WaterHistoryItem({
    required this.plantName,
    required this.date,
    required this.amountMl,
    required this.intervalText,
    required this.nextWatering,
  });

  final String plantName;
  final DateTime date;
  final int amountMl;
  final String intervalText;
  final DateTime nextWatering;

  Map<String, dynamic> toJson() => {
    'plantName': plantName,
    'date': date.toIso8601String(),
    'amountMl': amountMl,
    'intervalText': intervalText,
    'nextWatering': nextWatering.toIso8601String(),
  };

  factory _WaterHistoryItem.fromJson(Map<String, dynamic> json) {
    return _WaterHistoryItem(
      plantName: json['plantName'] as String? ?? 'Bitkim',
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      amountMl: (json['amountMl'] as num?)?.round() ?? 0,
      intervalText: json['intervalText'] as String? ?? '',
      nextWatering:
          DateTime.tryParse(json['nextWatering'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class _WarningMessage {
  const _WarningMessage({required this.text, required this.severity});

  final String text;
  final _WarningSeverity severity;
}

class _DayInterval {
  const _DayInterval(this.min, this.max);

  final int min;
  final int max;

  String get label => '$min-$max günde bir';
}

enum _WarningSeverity { warning, critical }

enum _WaterPlantCategory {
  cactus('Kaktüs', 7, _DayInterval(15, 30)),
  succulent('Sukulent', 9, _DayInterval(10, 20)),
  orchid('Orkide', 11, _DayInterval(7, 10)),
  tropical('Tropik bitki', 23, _DayInterval(4, 7)),
  houseplant('Salon bitkisi', 20, _DayInterval(5, 8)),
  flowering('Çiçekli bitki', 25, _DayInterval(3, 6)),
  palm('Palmiye', 24, _DayInterval(5, 8)),
  vegetable('Sebze', 30, _DayInterval(1, 3)),
  fruitTree('Meyve ağacı', 35, _DayInterval(3, 7)),
  aromatic('Aromatik bitki', 18, _DayInterval(3, 7));

  const _WaterPlantCategory(this.label, this.coefficient, this.interval);

  final String label;
  final double coefficient;
  final _DayInterval interval;
}

enum _PotMaterial {
  plastic('Plastik'),
  ceramic('Seramik'),
  clay('Toprak'),
  concrete('Beton'),
  wood('Ahşap');

  const _PotMaterial(this.label);

  final String label;
}

enum _WaterLocation {
  home('Ev'),
  balcony('Balkon'),
  garden('Bahçe'),
  greenhouse('Sera');

  const _WaterLocation(this.label);

  final String label;
}

enum _SunHours {
  zeroToTwo('0-2 saat'),
  twoToFour('2-4 saat'),
  fourToSix('4-6 saat'),
  sixPlus('6+ saat');

  const _SunHours(this.label);

  final String label;
}

enum _TemperatureRange {
  tenToFifteen('10-15°C'),
  fifteenToTwenty('15-20°C'),
  twentyToTwentyFive('20-25°C'),
  twentyFiveToThirty('25-30°C'),
  thirtyPlus('30°C+');

  const _TemperatureRange(this.label);

  final String label;
}

enum _HumidityLevel {
  low('Düşük'),
  normal('Normal'),
  high('Yüksek');

  const _HumidityLevel(this.label);

  final String label;
}

enum _Season {
  spring(
    'İlkbahar',
    'İlkbaharda büyüme başlar; toprağı kontrol ederek normal düzende sulama uygundur.',
  ),
  summer(
    'Yaz',
    'Yaz aylarında sıcaklık ve güneş arttığı için sulama ihtiyacı artabilir.',
  ),
  autumn(
    'Sonbahar',
    'Sonbaharda büyüme yavaşlar; sulama miktarını ve sıklığını azaltmaya başla.',
  ),
  winter(
    'Kış',
    'Kışın bitki daha az su tüketir; ıslak toprakta bekletmekten kaçın.',
  );

  const _Season(this.label, this.advice);

  final String label;
  final String advice;
}

String _formatDate(DateTime date) {
  const months = [
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];
  return '${date.day} ${months[date.month - 1]}';
}
