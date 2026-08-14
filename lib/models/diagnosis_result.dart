class CauseProbability {
  const CauseProbability({
    required this.title,
    required this.percent,
    this.code = 'unknown',
    this.confidence,
  });

  final String title;
  final int percent;
  final String code;
  final double? confidence;

  factory CauseProbability.fromJson(Map<String, dynamic> json) {
    final confidence = (json['confidence'] as num?)?.toDouble();
    return CauseProbability(
      title:
          (json['label'] as String?) ??
          (json['title'] as String?) ??
          'Belirsiz',
      percent: ((confidence ?? 0) * 100).round(),
      code: (json['code'] as String?) ?? 'unknown',
      confidence: confidence,
    );
  }
}

class PlantCareProfile {
  const PlantCareProfile({
    required this.commonNames,
    required this.latinName,
    required this.category,
    required this.watering,
    required this.light,
    required this.specialTips,
    required this.avoid,
  });

  final List<String> commonNames;
  final String latinName;
  final String category;
  final WateringProfile watering;
  final String light;
  final List<String> specialTips;
  final List<String> avoid;

  String get displayName =>
      commonNames.isNotEmpty ? commonNames.first : latinName;

  factory PlantCareProfile.fromJson(Map<String, dynamic> json) {
    return PlantCareProfile(
      commonNames: _stringList(json['commonNames']),
      latinName: (json['latinName'] as String?) ?? '',
      category: (json['category'] as String?) ?? '',
      watering: WateringProfile.fromJson(
        Map<String, dynamic>.from((json['watering'] as Map?) ?? const {}),
      ),
      light: (json['light'] as String?) ?? '',
      specialTips: _stringList(json['specialTips']),
      avoid: _stringList(json['avoid']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'commonNames': commonNames,
      'latinName': latinName,
      'category': category,
      'watering': watering.toJson(),
      'light': light,
      'specialTips': specialTips,
      'avoid': avoid,
    };
  }
}

class WateringProfile {
  const WateringProfile({
    required this.style,
    required this.soilDryCm,
    required this.summerDays,
    required this.winterDays,
    required this.note,
  });

  final String style;
  final List<int> soilDryCm;
  final List<int> summerDays;
  final List<int> winterDays;
  final String note;

  String get soilTrigger {
    if (style == 'dry') {
      return 'Toprak tamamen kuruduğunda kontrol et.';
    }
    if (style == 'aquatic') {
      return 'Su seviyesi ve temizliği kontrol edilmeli.';
    }
    if (soilDryCm.length >= 2) {
      return 'Üst ${soilDryCm[0]}-${soilDryCm[1]} cm toprak kuruduğunda kontrol et.';
    }
    return note;
  }

  String get intervalText {
    final summer = _rangeText(summerDays);
    final winter = _rangeText(winterDays);
    return 'Yazın $summer, kışın $winter kontrol.';
  }

  factory WateringProfile.fromJson(Map<String, dynamic> json) {
    return WateringProfile(
      style: (json['style'] as String?) ?? 'moderate',
      soilDryCm: _intList(json['soilDryCm']),
      summerDays: _intList(json['summerDays']),
      winterDays: _intList(json['winterDays']),
      note: (json['note'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'style': style,
      'soilDryCm': soilDryCm,
      'summerDays': summerDays,
      'winterDays': winterDays,
      'note': note,
    };
  }

  static String _rangeText(List<int> values) {
    if (values.length >= 2) {
      return '${values[0]}-${values[1]} günde bir';
    }
    if (values.length == 1) {
      return '${values.first} günde bir';
    }
    return 'toprağa göre';
  }
}

class DiagnosisResult {
  const DiagnosisResult({
    required this.plantName,
    required this.healthScore,
    required this.visualFindings,
    required this.symptoms,
    required this.causes,
    required this.actions,
    required this.createdAt,
    this.id,
    this.imagePath,
    this.imageUrl,
    this.storagePath,
    this.isPlant = true,
    this.needsCloseup = false,
    this.sevenDayPlan = const [],
    this.safetyNote =
        'Kesin teşhis değildir. Sorun yayılıyorsa uzman/çiçekçi desteği alın.',
    this.confidenceNote,
    this.source = 'mock',
    this.analysisTier = 'standard',
    this.careProfile,
    this.answers = const {},
  });

  final String? id;
  final String plantName;
  final int healthScore;
  final List<String> visualFindings;
  final List<String> symptoms;
  final List<CauseProbability> causes;
  final List<String> actions;
  final DateTime createdAt;
  final String? imagePath;
  final String? imageUrl;
  final String? storagePath;
  final bool isPlant;
  final bool needsCloseup;
  final List<String> sevenDayPlan;
  final String safetyNote;
  final String? confidenceNote;
  final String source;
  final String analysisTier;
  final PlantCareProfile? careProfile;
  final Map<String, String> answers;

  String get status {
    if (healthScore >= 80) return 'İyi';
    if (healthScore >= 50) return 'Orta';
    return 'Riskli';
  }

  factory DiagnosisResult.fromCloudFunction(
    Map<String, dynamic> json, {
    String? localImagePath,
  }) {
    return DiagnosisResult(
      id: json['id'] as String?,
      plantName: (json['plantGuess'] as String?) ?? 'Belirsiz',
      healthScore: (json['healthScore'] as num?)?.round().clamp(0, 100) ?? 60,
      visualFindings: _stringList(json['visualFindings']),
      imagePath: localImagePath,
      imageUrl: json['imageUrl'] as String?,
      storagePath: json['storagePath'] as String?,
      answers: _stringMap(json['answers']),
      isPlant: (json['isPlant'] as bool?) ?? true,
      needsCloseup: (json['needsCloseup'] as bool?) ?? false,
      symptoms: _stringList(json['symptoms']),
      causes: _mapList(
        json['possibleCauses'],
      ).map(CauseProbability.fromJson).toList(),
      actions: _stringList(json['quickActions']),
      sevenDayPlan: _stringList(json['sevenDayPlan']),
      safetyNote:
          (json['safetyNote'] as String?) ??
          'Kesin teşhis değildir. Sorun yayılıyorsa uzman/çiçekçi desteği alın.',
      confidenceNote: json['confidenceNote'] as String?,
      source: (json['source'] as String?) ?? 'gemini',
      analysisTier: (json['analysisTier'] as String?) ?? 'standard',
      careProfile: _careProfileFrom(json['careProfile']),
      createdAt:
          DateTime.tryParse((json['createdAt'] as String?) ?? '') ??
          DateTime.now(),
    );
  }
}

PlantCareProfile? _careProfileFrom(Object? value) {
  if (value is! Map) {
    return null;
  }
  return PlantCareProfile.fromJson(Map<String, dynamic>.from(value));
}

Map<String, String> _stringMap(Object? value) {
  if (value is! Map) {
    return const {};
  }
  return value.map(
    (key, item) => MapEntry(key.toString(), item?.toString() ?? ''),
  );
}

List<String> _stringList(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value.whereType<String>().toList();
}

List<int> _intList(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value.whereType<num>().map((item) => item.round()).toList();
}

List<Map<String, dynamic>> _mapList(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}
