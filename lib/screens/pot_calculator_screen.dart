import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_form_controls.dart';
import '../widgets/botanical_background.dart';

class PotCalculatorScreen extends StatefulWidget {
  const PotCalculatorScreen({super.key});

  static const routeName = '/pot-calculator';

  @override
  State<PotCalculatorScreen> createState() => _PotCalculatorScreenState();
}

class _PotCalculatorScreenState extends State<PotCalculatorScreen> {
  final _plantNameController = TextEditingController();
  final _potDiameterController = TextEditingController();
  final _plantHeightController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  _PlantType _plantType = _PlantType.houseplant;
  _UsageArea _usageArea = _UsageArea.home;
  bool _rootsOut = false;
  bool _fastDrying = false;
  bool _hasSymptoms = false;
  bool _hasDrainage = true;
  _PotCalculationResult? _result;

  @override
  void dispose() {
    _plantNameController.dispose();
    _potDiameterController.dispose();
    _plantHeightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saksı Hesaplayıcı')),
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
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Bitki bilgileri', style: AppTextStyles.section),
                      const SizedBox(height: 14),
                      _TextInput(
                        controller: _plantNameController,
                        label: 'Bitki adı',
                        icon: Icons.local_florist_outlined,
                        validator: (value) =>
                            _required(value, 'Bitki adını yaz.'),
                      ),
                      const SizedBox(height: 12),
                      _DropdownInput<_PlantType>(
                        label: 'Bitki tipi',
                        icon: Icons.eco_outlined,
                        value: _plantType,
                        items: _PlantType.values,
                        labelBuilder: (value) => value.label,
                        onChanged: (value) => setState(() {
                          _plantType = value ?? _PlantType.houseplant;
                        }),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _TextInput(
                              controller: _potDiameterController,
                              label: 'Saksı çapı (cm)',
                              icon: Icons.radio_button_unchecked,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              validator: (value) =>
                                  _numberValidator(value, 'Saksı çapı'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _TextInput(
                              controller: _plantHeightController,
                              label: 'Bitki boyu (cm)',
                              icon: Icons.height,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              validator: (value) =>
                                  _numberValidator(value, 'Bitki boyu'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _DropdownInput<_UsageArea>(
                        label: 'Kullanım alanı',
                        icon: Icons.place_outlined,
                        value: _usageArea,
                        items: _UsageArea.values,
                        labelBuilder: (value) => value.label,
                        onChanged: (value) => setState(() {
                          _usageArea = value ?? _UsageArea.home;
                        }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Kontrol soruları', style: AppTextStyles.section),
                      const SizedBox(height: 8),
                      _YesNoRow(
                        label: 'Kökler saksının altından çıkıyor mu?',
                        value: _rootsOut,
                        onChanged: (value) => setState(() => _rootsOut = value),
                      ),
                      _YesNoRow(
                        label: 'Toprak çok hızlı kuruyor mu?',
                        value: _fastDrying,
                        onChanged: (value) =>
                            setState(() => _fastDrying = value),
                      ),
                      _YesNoRow(
                        label: 'Sararma, solma veya çürüme var mı?',
                        value: _hasSymptoms,
                        onChanged: (value) =>
                            setState(() => _hasSymptoms = value),
                      ),
                      _YesNoRow(
                        label: 'Saksıda drenaj deliği var mı?',
                        value: _hasDrainage,
                        onChanged: (value) =>
                            setState(() => _hasDrainage = value),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppButton(
                  label: 'Hesapla',
                  icon: Icons.calculate_outlined,
                  onPressed: _calculate,
                ),
                if (_result != null) ...[
                  const SizedBox(height: 18),
                  _ResultCard(result: _result!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _required(String? value, String message) {
    if (value == null || value.trim().isEmpty) {
      return message;
    }
    return null;
  }

  String? _numberValidator(String? value, String label) {
    final normalized = value?.replaceAll(',', '.').trim() ?? '';
    final number = double.tryParse(normalized);
    if (number == null || number <= 0) {
      return '$label için geçerli cm gir.';
    }
    return null;
  }

  void _calculate() {
    if (_formKey.currentState?.validate() != true) {
      return;
    }
    final currentDiameter = _parseNumber(_potDiameterController.text);
    final plantHeight = _parseNumber(_plantHeightController.text);
    final recommendedDiameter = currentDiameter + _plantType.incrementCm;
    final warnings = <_WarningMessage>[];

    if (_hasSymptoms) {
      warnings.add(
        const _WarningMessage(
          text:
              'Bitkide sararma, solma veya çürüme varsa direkt saksı büyütme. Önce kökleri, toprağın kokusunu ve çürük dokuları kontrol et.',
          severity: _WarningSeverity.critical,
        ),
      );
    }
    if (!_hasDrainage) {
      warnings.add(
        const _WarningMessage(
          text:
              'Drenaj deliği yoksa mutlaka delikli saksıya geç. Tabanda su kalması kök çürümesini hızlandırır.',
          severity: _WarningSeverity.critical,
        ),
      );
    }
    if (_rootsOut) {
      warnings.add(
        const _WarningMessage(
          text:
              'Kökler alttan çıkıyorsa bitki saksıyı doldurmuş olabilir; kontrollü saksı büyütme uygundur.',
          severity: _WarningSeverity.warning,
        ),
      );
    }
    if (_fastDrying) {
      warnings.add(
        const _WarningMessage(
          text:
              'Toprak çok hızlı kuruyorsa kök yoğunluğu artmış olabilir; yeni saksı ve taze karışım fayda sağlar.',
          severity: _WarningSeverity.warning,
        ),
      );
    }

    final shouldRepot = !_hasSymptoms && (_rootsOut || _fastDrying);
    final noUrgentChange =
        !_rootsOut && !_fastDrying && !_hasSymptoms && _hasDrainage;
    final status = noUrgentChange
        ? 'Saksı değişimi şart değil'
        : _hasSymptoms
        ? 'Önce kök ve toprak kontrolü'
        : 'Saksı değişimi önerilir';

    warnings.add(
      _WarningMessage(
        text:
            'Direkt çok büyük saksıya geçme. ${_formatCm(currentDiameter)} cm saksıdan ${_formatCm(recommendedDiameter + 6)} cm ve üstüne atlamak fazla toprağın su tutmasına ve kök çürümesine yol açabilir.',
        severity: _WarningSeverity.warning,
      ),
    );

    setState(() {
      _result = _PotCalculationResult(
        plantName: _plantNameController.text.trim(),
        plantType: _plantType,
        usageArea: _usageArea,
        currentDiameter: currentDiameter,
        plantHeight: plantHeight,
        recommendedDiameter: recommendedDiameter,
        shouldRepot: shouldRepot,
        noUrgentChange: noUrgentChange,
        hasSymptoms: _hasSymptoms,
        hasDrainage: _hasDrainage,
        status: status,
        potType: _potTypeSuggestion(_plantType, _usageArea, _hasDrainage),
        soil: _plantType.soil,
        nextCheck: _nextCheckText(
          hasSymptoms: _hasSymptoms,
          rootsOut: _rootsOut,
          fastDrying: _fastDrying,
        ),
        warnings: warnings,
      );
    });
  }

  double _parseNumber(String value) {
    return double.parse(value.replaceAll(',', '.').trim());
  }

  String _potTypeSuggestion(
    _PlantType type,
    _UsageArea area,
    bool hasDrainage,
  ) {
    final drainage = hasDrainage ? 'delikli' : 'mutlaka delikli';
    final areaText = switch (area) {
      _UsageArea.home => 'ev içinde tabaklı ve kontrollü sulamaya uygun',
      _UsageArea.balcony => 'balkonda rüzgar ve güneşe dayanıklı',
      _UsageArea.garden => 'bahçede ağırlaşmayan ama devrilmeyen',
    };
    return switch (type) {
      _PlantType.cactus =>
        '$drainage, küçük farkla büyüyen terracotta veya nefes alan saksı; $areaText.',
      _PlantType.orchid => 'şeffaf, bol delikli orkide saksısı; $areaText.',
      _PlantType.palm => '$drainage, derin ve stabil saksı; $areaText.',
      _PlantType.vegetable =>
        '$drainage, geniş hacimli fide/saksı kasası; $areaText.',
      _ =>
        '$drainage, bitki boyuna göre dengeli plastik veya seramik saksı; $areaText.',
    };
  }

  String _nextCheckText({
    required bool hasSymptoms,
    required bool rootsOut,
    required bool fastDrying,
  }) {
    if (hasSymptoms) {
      return '3-5 gün içinde kök, toprak kokusu ve yaprak durumunu tekrar kontrol et.';
    }
    if (rootsOut || fastDrying) {
      return 'Saksı değişiminden 7 gün sonra yaprak diriliği ve toprak kuruma hızını kontrol et.';
    }
    return '2-4 hafta sonra kök çıkışı ve toprak kuruma hızını tekrar kontrol et.';
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
              color: AppColors.darkGreen,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.inventory_2_outlined, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Saksım Uygun mu?', style: AppTextStyles.section),
                const SizedBox(height: 4),
                const Text(
                  'Mevcut saksıyı, kök durumunu ve bitki tipini gir; ideal yeni çapı ve uyarıları gör.',
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

class _YesNoRow extends StatelessWidget {
  const _YesNoRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTextStyles.body)),
          const SizedBox(width: 10),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Hayır')),
              ButtonSegment(value: true, label: Text('Evet')),
            ],
            selected: {value},
            showSelectedIcon: false,
            onSelectionChanged: (selected) => onChanged(selected.first),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final _PotCalculationResult result;

  @override
  Widget build(BuildContext context) {
    final tone = result.hasSymptoms
        ? AppColors.critical
        : result.noUrgentChange
        ? AppColors.green
        : AppColors.warning;
    final recommendation = result.hasSymptoms
        ? 'Hesaplanan güvenli üst hedef: ${_formatCm(result.recommendedDiameter)} cm. Ancak önce kök ve toprak kontrolü yap.'
        : result.noUrgentChange
        ? 'Şimdilik mevcut saksı uygun görünüyor. Değişim gerekirse hedef ${_formatCm(result.recommendedDiameter)} cm.'
        : '${_formatCm(result.recommendedDiameter)} cm yeni saksı uygundur.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          color: AppColors.darkGreen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                result.plantName,
                style: AppTextStyles.title.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(
                result.status,
                style: AppTextStyles.muted.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _MetricBox(
                      label: 'Mevcut',
                      value: '${_formatCm(result.currentDiameter)} cm',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricBox(
                      label: 'Önerilen',
                      value: '${_formatCm(result.recommendedDiameter)} cm',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _StatusPill(color: tone, text: recommendation),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _InfoResultBlock(
          icon: Icons.inventory_2_outlined,
          title: 'Saksı tipi önerisi',
          text: result.potType,
        ),
        _InfoResultBlock(
          icon: Icons.terrain_outlined,
          title: 'Toprak önerisi',
          text: result.soil,
        ),
        _InfoResultBlock(
          icon: Icons.event_repeat_outlined,
          title: 'Sonraki kontrol zamanı',
          text: result.nextCheck,
        ),
        if (result.warnings.isNotEmpty)
          ...result.warnings.map((warning) => _WarningBox(warning: warning)),
      ],
    );
  }
}

class _MetricBox extends StatelessWidget {
  const _MetricBox({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .12),
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: .18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: .34)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          text,
          style: AppTextStyles.body.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _InfoResultBlock extends StatelessWidget {
  const _InfoResultBlock({
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

class _PotCalculationResult {
  const _PotCalculationResult({
    required this.plantName,
    required this.plantType,
    required this.usageArea,
    required this.currentDiameter,
    required this.plantHeight,
    required this.recommendedDiameter,
    required this.shouldRepot,
    required this.noUrgentChange,
    required this.hasSymptoms,
    required this.hasDrainage,
    required this.status,
    required this.potType,
    required this.soil,
    required this.nextCheck,
    required this.warnings,
  });

  final String plantName;
  final _PlantType plantType;
  final _UsageArea usageArea;
  final double currentDiameter;
  final double plantHeight;
  final double recommendedDiameter;
  final bool shouldRepot;
  final bool noUrgentChange;
  final bool hasSymptoms;
  final bool hasDrainage;
  final String status;
  final String potType;
  final String soil;
  final String nextCheck;
  final List<_WarningMessage> warnings;
}

class _WarningMessage {
  const _WarningMessage({required this.text, required this.severity});

  final String text;
  final _WarningSeverity severity;
}

enum _WarningSeverity { warning, critical }

enum _PlantType {
  cactus('Kaktüs / Sukulent', 2, 'Kaktüs toprağı + ponza + perlit + az torf'),
  orchid(
    'Orkide',
    2,
    'Orkide kabuğu + cocopeat + az sphagnum yosunu. Şeffaf delikli saksı öner.',
  ),
  houseplant('Salon bitkisi', 4, 'Torf + perlit + orkide kabuğu + az ponza'),
  palm('Palmiye', 6, 'Torf + perlit + kum + organik madde'),
  flowering('Çiçekli bitki', 3, 'Torf + perlit + kompost'),
  vine('Sarmaşık', 4, 'Torf + perlit + cocopeat + orkide kabuğu'),
  vegetable('Sebze / fide', 8, 'Torf + kompost + perlit + bahçe toprağı');

  const _PlantType(this.label, this.incrementCm, this.soil);

  final String label;
  final double incrementCm;
  final String soil;
}

enum _UsageArea {
  home('Ev'),
  balcony('Balkon'),
  garden('Bahçe');

  const _UsageArea(this.label);

  final String label;
}

String _formatCm(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value.toStringAsFixed(1).replaceAll('.', ',');
}
