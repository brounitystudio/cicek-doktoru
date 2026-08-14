import 'package:flutter/material.dart';

import '../services/plant_safety_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_form_controls.dart';
import '../widgets/botanical_background.dart';

class EnvironmentAnalysisScreen extends StatefulWidget {
  const EnvironmentAnalysisScreen({super.key});

  static const routeName = '/environment-analysis';

  @override
  State<EnvironmentAnalysisScreen> createState() =>
      _EnvironmentAnalysisScreenState();
}

class _EnvironmentAnalysisScreenState extends State<EnvironmentAnalysisScreen> {
  final _formKey = GlobalKey<FormState>();
  final _plantNameController = TextEditingController();

  _EnvLocation _location = _EnvLocation.home;
  _EnvTemperature _temperature = _EnvTemperature.twentyToTwentyFive;
  _EnvSunHours _sunHours = _EnvSunHours.threeToFive;
  _EnvLightType _lightType = _EnvLightType.brightIndirect;
  _EnvHumidity _humidity = _EnvHumidity.normal;
  _EnvWind _wind = _EnvWind.none;
  _WindowDirection _windowDirection = _WindowDirection.east;
  bool _usesAc = false;
  bool _nearHeater = false;
  bool _nearWindow = true;
  bool _hasCat = false;
  bool _hasDog = false;
  _EnvironmentResult? _result;

  @override
  void initState() {
    super.initState();
    _loadSafetyProfile();
  }

  @override
  void dispose() {
    _plantNameController.dispose();
    super.dispose();
  }

  Future<void> _loadSafetyProfile() async {
    final profile = await PlantSafetyService.instance.loadProfile();
    if (!mounted || !profile.configured) {
      return;
    }
    setState(() {
      _hasCat = profile.hasCat;
      _hasDog = profile.hasDog;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ortam Analizi')),
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
                      Text('Bitki ve konum', style: AppTextStyles.section),
                      const SizedBox(height: 14),
                      _TextInput(
                        controller: _plantNameController,
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
                      _DropdownInput<_EnvLocation>(
                        label: 'Konum',
                        icon: Icons.place_outlined,
                        value: _location,
                        items: _EnvLocation.values,
                        labelBuilder: (value) => value.label,
                        onChanged: (value) => setState(
                          () => _location = value ?? _EnvLocation.home,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Işık ve sıcaklık', style: AppTextStyles.section),
                      const SizedBox(height: 14),
                      _DropdownInput<_EnvTemperature>(
                        label: 'Ortam sıcaklığı',
                        icon: Icons.thermostat_outlined,
                        value: _temperature,
                        items: _EnvTemperature.values,
                        labelBuilder: (value) => value.label,
                        onChanged: (value) => setState(
                          () => _temperature =
                              value ?? _EnvTemperature.twentyToTwentyFive,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _DropdownInput<_EnvSunHours>(
                        label: 'Günlük güneş alma süresi',
                        icon: Icons.wb_sunny_outlined,
                        value: _sunHours,
                        items: _EnvSunHours.values,
                        labelBuilder: (value) => value.label,
                        onChanged: (value) => setState(
                          () => _sunHours = value ?? _EnvSunHours.threeToFive,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _DropdownInput<_EnvLightType>(
                        label: 'Işık tipi',
                        icon: Icons.light_mode_outlined,
                        value: _lightType,
                        items: _EnvLightType.values,
                        labelBuilder: (value) => value.label,
                        onChanged: (value) => setState(
                          () => _lightType =
                              value ?? _EnvLightType.brightIndirect,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _DropdownInput<_WindowDirection>(
                        label: 'Pencere yönü',
                        icon: Icons.explore_outlined,
                        value: _windowDirection,
                        items: _WindowDirection.values,
                        labelBuilder: (value) => value.label,
                        onChanged: (value) => setState(
                          () =>
                              _windowDirection = value ?? _WindowDirection.east,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Nem ve hava akımı', style: AppTextStyles.section),
                      const SizedBox(height: 14),
                      _DropdownInput<_EnvHumidity>(
                        label: 'Nem oranı',
                        icon: Icons.opacity_outlined,
                        value: _humidity,
                        items: _EnvHumidity.values,
                        labelBuilder: (value) => value.label,
                        onChanged: (value) => setState(
                          () => _humidity = value ?? _EnvHumidity.normal,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _DropdownInput<_EnvWind>(
                        label: 'Rüzgar durumu',
                        icon: Icons.air_outlined,
                        value: _wind,
                        items: _EnvWind.values,
                        labelBuilder: (value) => value.label,
                        onChanged: (value) =>
                            setState(() => _wind = value ?? _EnvWind.none),
                      ),
                      const SizedBox(height: 8),
                      _SwitchRow(
                        label: 'Klima kullanımı',
                        value: _usesAc,
                        onChanged: (value) => setState(() => _usesAc = value),
                      ),
                      _SwitchRow(
                        label: 'Kalorifer yakınında mı?',
                        value: _nearHeater,
                        onChanged: (value) =>
                            setState(() => _nearHeater = value),
                      ),
                      _SwitchRow(
                        label: 'Cam önü mü?',
                        value: _nearWindow,
                        onChanged: (value) =>
                            setState(() => _nearWindow = value),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Evcil hayvan kontrolü',
                        style: AppTextStyles.section,
                      ),
                      const SizedBox(height: 8),
                      _SwitchRow(
                        label: 'Evde kedi var mı?',
                        value: _hasCat,
                        onChanged: (value) => setState(() => _hasCat = value),
                      ),
                      _SwitchRow(
                        label: 'Evde köpek var mı?',
                        value: _hasDog,
                        onChanged: (value) => setState(() => _hasDog = value),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppButton(
                  label: 'Ortamı Analiz Et',
                  icon: Icons.analytics_outlined,
                  onPressed: _analyze,
                ),
                if (_result != null) ...[
                  const SizedBox(height: 18),
                  _EnvironmentResultView(result: _result!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _analyze() {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    final suggestions = <String>[];
    final warnings = <String>[];

    var lightScore = 78;
    lightScore += _lightType.scoreDelta;
    lightScore += _sunHours.scoreDelta;
    lightScore += _windowDirection.lightDelta;
    if (!_nearWindow && _location != _EnvLocation.garden) {
      lightScore -= 8;
      suggestions.add(
        'Bitkiyi ışık alan ama yaprak yakmayacak bir noktaya yaklaştır.',
      );
    }
    if (_lightType == _EnvLightType.directSun && _sunHours.index >= 3) {
      suggestions.add(
        'Direkt güneşte yaprak yanığına karşı öğle saatlerini filtrele.',
      );
    }

    var temperatureScore = 82 + _temperature.scoreDelta;
    if (_nearHeater) {
      temperatureScore -= 18;
      warnings.add(
        'Kalorifer yakını yaprak kuruması ve hızlı su kaybı yapabilir.',
      );
    }
    if (_location == _EnvLocation.balcony &&
        (_temperature == _EnvTemperature.zeroToFive ||
            _temperature == _EnvTemperature.fiveToTen)) {
      temperatureScore -= 18;
      warnings.add(
        'Soğuk balkon kök bölgesinde stres ve don riski oluşturabilir.',
      );
    }

    var humidityScore = 78 + _humidity.scoreDelta;
    if (_usesAc) {
      humidityScore -= 12;
      suggestions.add('Klima üflemesi doğrudan yapraklara gelmemeli.');
    }
    if (_nearHeater) {
      humidityScore -= 10;
    }
    if (_humidity == _EnvHumidity.low || _humidity == _EnvHumidity.veryLow) {
      suggestions.add(
        'Nem tepsisi veya bitkileri gruplayarak nemi artırabilirsin.',
      );
    }

    var airflowScore = 86 + _wind.scoreDelta;
    if (_usesAc) {
      airflowScore -= 8;
    }
    if (_wind == _EnvWind.strong) {
      warnings.add(
        'Kuvvetli rüzgar yaprak uçlarını kurutabilir ve saksıyı devirebilir.',
      );
    }

    final generalScore = _clampScore(
      (lightScore * .28 +
              temperatureScore * .24 +
              humidityScore * .22 +
              airflowScore * .18 +
              (_location.baseScore * .08))
          .round(),
    );
    final environmentScore = _clampScore(
      ((generalScore +
                  lightScore +
                  temperatureScore +
                  humidityScore +
                  airflowScore) /
              5)
          .round(),
    );

    suggestions.addAll(_defaultSuggestions());
    final petRecommendations = _petFriendlyRecommendations();
    final plantRecommendations = _plantRecommendations(
      hasPets: _hasCat || _hasDog,
    );
    final petWarnings = _petWarnings(_plantNameController.text.trim());

    setState(() {
      _result = _EnvironmentResult(
        plantName: _plantNameController.text.trim(),
        overallScore: generalScore,
        light: _ScoreItem('☀️ Işık', _clampScore(lightScore)),
        temperature: _ScoreItem('🌡️ Sıcaklık', _clampScore(temperatureScore)),
        humidity: _ScoreItem('💧 Nem', _clampScore(humidityScore)),
        airflow: _ScoreItem('🌬️ Hava akımı', _clampScore(airflowScore)),
        environment: _ScoreItem('🏠 Genel ortam', environmentScore),
        summary: _summaryFor(generalScore),
        suggestions: suggestions.toSet().toList(),
        warnings: warnings,
        plantRecommendations: plantRecommendations,
        petFriendlyRecommendations: petRecommendations,
        petWarnings: petWarnings,
      );
    });
  }

  List<String> _defaultSuggestions() {
    final items = <String>[];
    if (_temperature.index >= _EnvTemperature.twentyFiveToThirty.index) {
      items.add('Sıcak günlerde toprak nemini daha sık kontrol et.');
    }
    if (_sunHours == _EnvSunHours.sevenPlus) {
      items.add('Yaz aylarında sulama ihtiyacı artabilir.');
    }
    if (_lightType == _EnvLightType.shadow) {
      items.add('Gölge ortamda büyüme yavaşlayabilir; ışığı kademeli artır.');
    }
    if (items.isEmpty) {
      items.add('Mevcut ortam genel bakım için dengeli görünüyor.');
    }
    return items;
  }

  List<String> _plantRecommendations({required bool hasPets}) {
    List<String> rank(List<String> plants) {
      final profile = SafetyProfile(
        hasCat: _hasCat,
        hasDog: _hasDog,
        hasChild: false,
        configured: true,
      );
      if (!profile.hasAnyRiskGroup) {
        return plants;
      }
      final sorted = [...plants];
      sorted.sort((a, b) {
        return PlantSafetyService.instance
            .safetyRankFor(a, profile)
            .compareTo(PlantSafetyService.instance.safetyRankFor(b, profile));
      });
      return sorted;
    }

    if (hasPets) {
      return _petFriendlyRecommendations();
    }
    if (_lightType == _EnvLightType.shadow ||
        _sunHours == _EnvSunHours.zeroToOne) {
      return rank(const [
        'Paşa Kılıcı',
        'ZZ Bitkisi',
        'Salon Sarmaşığı',
        'Aspidistra',
        'Kurdele Çiçeği',
      ]);
    }
    if (_lightType == _EnvLightType.directSun ||
        _sunHours == _EnvSunHours.sevenPlus) {
      return rank(const [
        'Kaktüs',
        'Aloe Vera',
        'Lavanta',
        'Biberiye',
        'Zeytin Fidanı',
      ]);
    }
    if (_humidity == _EnvHumidity.high || _humidity == _EnvHumidity.veryHigh) {
      return rank(const [
        'Areka Palmiyesi',
        'Calathea',
        'Eğrelti',
        'Barış Çiçeği',
        'Salon Sarmaşığı',
      ]);
    }
    return rank(const [
      'Paşa Kılıcı',
      'ZZ Bitkisi',
      'Kurdele Çiçeği',
      'Areka Palmiyesi',
      'Salon Sarmaşığı',
    ]);
  }

  List<String> _petFriendlyRecommendations() {
    if (!_hasCat && !_hasDog) {
      return const [];
    }
    return const [
      'Kurdele Çiçeği',
      'Areka Palmiyesi',
      'Calathea',
      'Peperomia',
      'Dua Çiçeği',
    ];
  }

  List<String> _petWarnings(String plantName) {
    if (!_hasCat && !_hasDog) {
      return const [];
    }
    final normalized = plantName.toLowerCase();
    final risky = [
      'monstera',
      'devetaban',
      'dieffenbachia',
      'difenbahya',
      'pothos',
      'salon sarmaşığı',
      'zambak',
      'aloe',
    ];
    if (risky.any(normalized.contains)) {
      return [
        '$plantName evcil hayvanlar için riskli olabilir. Yüksek raf veya askılı saksı önerilir.',
      ];
    }
    return [
      'Evcil hayvan varsa yeni bitki almadan önce türün toksisite durumunu kontrol et.',
    ];
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
              color: AppColors.warning,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.wb_sunny_outlined, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('🌤️ Ortam Analizi', style: AppTextStyles.section),
                const SizedBox(height: 4),
                const Text(
                  'Bitkinizin bulunduğu ortamı analiz edin.',
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

class _EnvironmentResultView extends StatelessWidget {
  const _EnvironmentResultView({required this.result});

  final _EnvironmentResult result;

  @override
  Widget build(BuildContext context) {
    return Column(
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
              const SizedBox(height: 8),
              Text(
                result.summary,
                style: AppTextStyles.muted.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _ScoreCircle(score: result.overallScore),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      _overallLabel(result.overallScore),
                      style: AppTextStyles.section.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Kategori puanları', style: AppTextStyles.section),
              const SizedBox(height: 12),
              _ScoreRow(item: result.light),
              _ScoreRow(item: result.temperature),
              _ScoreRow(item: result.humidity),
              _ScoreRow(item: result.airflow),
              _ScoreRow(item: result.environment),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _ListCard(
          title: 'Öneriler',
          icon: Icons.tips_and_updates_outlined,
          items: result.suggestions,
          color: AppColors.green,
        ),
        if (result.warnings.isNotEmpty)
          _ListCard(
            title: 'Dikkat edilmesi gerekenler',
            icon: Icons.warning_amber_outlined,
            items: result.warnings,
            color: AppColors.warning,
          ),
        _ListCard(
          title: 'Bu ortam için uygun bitkiler',
          icon: Icons.eco_outlined,
          items: result.plantRecommendations,
          color: AppColors.leaf,
        ),
        if (result.petFriendlyRecommendations.isNotEmpty)
          _ListCard(
            title: 'Evcil hayvan dostu öncelikler',
            icon: Icons.pets_outlined,
            items: result.petFriendlyRecommendations,
            color: AppColors.green,
          ),
        if (result.petWarnings.isNotEmpty)
          _ListCard(
            title: 'Evcil hayvan uyarısı',
            icon: Icons.error_outline,
            items: result.petWarnings,
            color: AppColors.critical,
          ),
        const _DisclaimerCard(),
      ],
    );
  }
}

class _ScoreCircle extends StatelessWidget {
  const _ScoreCircle({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final color = _scoreColor(score);
    return Container(
      width: 92,
      height: 92,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: .22),
        border: Border.all(color: color, width: 5),
      ),
      child: Text(
        '$score',
        style: AppTextStyles.title.copyWith(color: Colors.white),
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({required this.item});

  final _ScoreItem item;

  @override
  Widget build(BuildContext context) {
    final color = _scoreColor(item.score);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(item.title, style: AppTextStyles.body)),
              Text(
                '${item.score}/100',
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: item.score / 100,
              color: color,
              backgroundColor: color.withValues(alpha: .16),
            ),
          ),
          const SizedBox(height: 4),
          Text(_levelLabel(item.score), style: AppTextStyles.muted),
        ],
      ),
    );
  }
}

class _ListCard extends StatelessWidget {
  const _ListCard({
    required this.title,
    required this.icon,
    required this.items,
    required this.color,
  });

  final String title;
  final IconData icon;
  final List<String> items;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: .14),
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
                  Icon(icon, color: color),
                  const SizedBox(width: 9),
                  Expanded(child: Text(title, style: AppTextStyles.section)),
                ],
              ),
              const SizedBox(height: 10),
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Icon(Icons.circle, size: 7, color: color),
                      ),
                      const SizedBox(width: 9),
                      Expanded(child: Text(item, style: AppTextStyles.body)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DisclaimerCard extends StatelessWidget {
  const _DisclaimerCard();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: AppCard(
        showPattern: false,
        child: Text(
          'Bu analiz öneri amaçlıdır. Bitkinin gerçek ihtiyaçları türüne, yaşına ve bulunduğu çevreye göre değişebilir.',
          style: AppTextStyles.body,
        ),
      ),
    );
  }
}

class _TextInput extends StatelessWidget {
  const _TextInput({
    required this.controller,
    required this.label,
    required this.icon,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return AppFormTextField(
      controller: controller,
      label: label,
      icon: icon,
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

class _EnvironmentResult {
  const _EnvironmentResult({
    required this.plantName,
    required this.overallScore,
    required this.light,
    required this.temperature,
    required this.humidity,
    required this.airflow,
    required this.environment,
    required this.summary,
    required this.suggestions,
    required this.warnings,
    required this.plantRecommendations,
    required this.petFriendlyRecommendations,
    required this.petWarnings,
  });

  final String plantName;
  final int overallScore;
  final _ScoreItem light;
  final _ScoreItem temperature;
  final _ScoreItem humidity;
  final _ScoreItem airflow;
  final _ScoreItem environment;
  final String summary;
  final List<String> suggestions;
  final List<String> warnings;
  final List<String> plantRecommendations;
  final List<String> petFriendlyRecommendations;
  final List<String> petWarnings;
}

class _ScoreItem {
  const _ScoreItem(this.title, this.score);

  final String title;
  final int score;
}

enum _EnvLocation {
  home('Ev', 84),
  balcony('Balkon', 76),
  garden('Bahçe', 78),
  office('Ofis', 74),
  greenhouse('Sera', 92);

  const _EnvLocation(this.label, this.baseScore);

  final String label;
  final int baseScore;
}

enum _EnvTemperature {
  zeroToFive('0-5°C', -45),
  fiveToTen('5-10°C', -30),
  tenToFifteen('10-15°C', -14),
  fifteenToTwenty('15-20°C', 2),
  twentyToTwentyFive('20-25°C', 14),
  twentyFiveToThirty('25-30°C', 6),
  thirtyToThirtyFive('30-35°C', -12),
  thirtyFivePlus('35°C+', -32);

  const _EnvTemperature(this.label, this.scoreDelta);

  final String label;
  final int scoreDelta;
}

enum _EnvSunHours {
  zeroToOne('0-1 saat', -22),
  oneToThree('1-3 saat', -6),
  threeToFive('3-5 saat', 12),
  fiveToSeven('5-7 saat', 8),
  sevenPlus('7+ saat', -8);

  const _EnvSunHours(this.label, this.scoreDelta);

  final String label;
  final int scoreDelta;
}

enum _EnvLightType {
  directSun('Direkt güneş', 2),
  brightIndirect('Parlak dolaylı ışık', 18),
  halfShade('Yarı gölge', 5),
  shadow('Gölge', -24);

  const _EnvLightType(this.label, this.scoreDelta);

  final String label;
  final int scoreDelta;
}

enum _EnvHumidity {
  veryLow('Çok düşük', -26),
  low('Düşük', -14),
  normal('Normal', 10),
  high('Yüksek', 6),
  veryHigh('Çok yüksek', -10);

  const _EnvHumidity(this.label, this.scoreDelta);

  final String label;
  final int scoreDelta;
}

enum _EnvWind {
  none('Yok', 8),
  light('Hafif', 10),
  medium('Orta', -6),
  strong('Kuvvetli', -28);

  const _EnvWind(this.label, this.scoreDelta);

  final String label;
  final int scoreDelta;
}

enum _WindowDirection {
  north('Kuzey', -10),
  south('Güney', 8),
  east('Doğu', 12),
  west('Batı', 2);

  const _WindowDirection(this.label, this.lightDelta);

  final String label;
  final int lightDelta;
}

int _clampScore(int score) => score.clamp(0, 100);

Color _scoreColor(int score) {
  if (score >= 75) {
    return AppColors.green;
  }
  if (score >= 50) {
    return AppColors.warning;
  }
  return AppColors.critical;
}

String _levelLabel(int score) {
  if (score >= 90) {
    return 'Mükemmel';
  }
  if (score >= 75) {
    return 'İyi';
  }
  if (score >= 60) {
    return 'Orta';
  }
  if (score >= 40) {
    return 'Riskli';
  }
  return 'Uygun değil';
}

String _overallLabel(int score) {
  if (score >= 90) {
    return 'Mükemmel ortam';
  }
  if (score >= 75) {
    return 'Çok uygun ortam';
  }
  if (score >= 60) {
    return 'Küçük iyileştirmeler gerekli';
  }
  if (score >= 40) {
    return 'Bitki strese girebilir';
  }
  return 'Ortam uygun değil';
}

String _summaryFor(int score) {
  if (score >= 75) {
    return 'Bitkiniz genel olarak sağlıklı gelişebileceği bir ortamda bulunuyor.';
  }
  if (score >= 60) {
    return 'Ortam kullanılabilir; birkaç küçük ayar bitkiyi rahatlatır.';
  }
  if (score >= 40) {
    return 'Bazı çevresel koşullar bitkide stres oluşturabilir.';
  }
  return 'Bu ortam bitki için zorlayıcı görünüyor; konum değişikliği düşünülmeli.';
}
