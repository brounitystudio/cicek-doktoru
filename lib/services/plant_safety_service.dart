import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_colors.dart';

class SafetyProfile {
  const SafetyProfile({
    required this.hasCat,
    required this.hasDog,
    required this.hasChild,
    required this.configured,
  });

  final bool hasCat;
  final bool hasDog;
  final bool hasChild;
  final bool configured;

  bool get hasAnyRiskGroup => hasCat || hasDog || hasChild;

  SafetyProfile copyWith({
    bool? hasCat,
    bool? hasDog,
    bool? hasChild,
    bool? configured,
  }) {
    return SafetyProfile(
      hasCat: hasCat ?? this.hasCat,
      hasDog: hasDog ?? this.hasDog,
      hasChild: hasChild ?? this.hasChild,
      configured: configured ?? this.configured,
    );
  }
}

class PlantSafetyInfo {
  const PlantSafetyInfo({
    required this.catFriendly,
    required this.dogFriendly,
    required this.childFriendly,
    required this.toxicity,
    required this.riskTypes,
    required this.warning,
    required this.recommendation,
  });

  final String catFriendly;
  final String dogFriendly;
  final String childFriendly;
  final String toxicity;
  final List<String> riskTypes;
  final String warning;
  final String recommendation;

  bool get fullySafe =>
      catFriendly == 'Evet' &&
      dogFriendly == 'Evet' &&
      childFriendly == 'Evet' &&
      toxicity == 'Yok';

  bool get hasRisk =>
      catFriendly == 'Hayır' ||
      dogFriendly == 'Hayır' ||
      childFriendly == 'Hayır' ||
      toxicity == 'Orta' ||
      toxicity == 'Yüksek';

  bool get hasCaution =>
      catFriendly == 'Kısmen' ||
      dogFriendly == 'Kısmen' ||
      childFriendly == 'Kısmen' ||
      toxicity == 'Düşük';

  Color get tone {
    if (hasRisk) {
      return AppColors.critical;
    }
    if (hasCaution) {
      return AppColors.warning;
    }
    return AppColors.green;
  }
}

class PlantSafetyService {
  PlantSafetyService._();

  static final PlantSafetyService instance = PlantSafetyService._();

  static const _hasCatKey = 'safety_has_cat';
  static const _hasDogKey = 'safety_has_dog';
  static const _hasChildKey = 'safety_has_child';
  static const _configuredKey = 'safety_profile_configured';

  Future<SafetyProfile> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    return SafetyProfile(
      hasCat: prefs.getBool(_hasCatKey) ?? false,
      hasDog: prefs.getBool(_hasDogKey) ?? false,
      hasChild: prefs.getBool(_hasChildKey) ?? false,
      configured: prefs.getBool(_configuredKey) ?? false,
    );
  }

  Future<void> saveProfile(SafetyProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasCatKey, profile.hasCat);
    await prefs.setBool(_hasDogKey, profile.hasDog);
    await prefs.setBool(_hasChildKey, profile.hasChild);
    await prefs.setBool(_configuredKey, true);
  }

  PlantSafetyInfo safetyFor(String plantName) {
    final value = _normalize(plantName);

    if (_containsAny(value, _safeKeywords)) {
      return const PlantSafetyInfo(
        catFriendly: 'Evet',
        dogFriendly: 'Evet',
        childFriendly: 'Evet',
        toxicity: 'Yok',
        riskTypes: [],
        warning:
            'Bilinen yaygın bakım bilgisinde ciddi toksisite riski öne çıkmaz.',
        recommendation:
            'Evcil hayvan bulunan evlerde yine de yaprak çiğnemesini takip et.',
      );
    }

    if (_containsAny(value, _highRiskKeywords)) {
      return const PlantSafetyInfo(
        catFriendly: 'Hayır',
        dogFriendly: 'Hayır',
        childFriendly: 'Hayır',
        toxicity: 'Yüksek',
        riskTypes: ['Kusma', 'İshal', 'Toksik etki'],
        warning:
            'Bu bitki yenirse evcil hayvanlar ve küçük çocuklar için ciddi belirti riski oluşturabilir.',
        recommendation:
            'Kedi, köpek veya küçük çocuk bulunan evlerde erişilemeyecek konum ya da alternatif güvenli bitki önerilir.',
      );
    }

    if (_containsAny(value, _mediumRiskKeywords)) {
      return const PlantSafetyInfo(
        catFriendly: 'Hayır',
        dogFriendly: 'Hayır',
        childFriendly: 'Kısmen',
        toxicity: 'Orta',
        riskTypes: ['Ağız tahrişi', 'Kusma', 'Deri tahrişi'],
        warning:
            'Yaprakların yenmesi ağız tahrişi, salya artışı ve mide rahatsızlığı yapabilir.',
        recommendation:
            'Yüksek raf, askılı saksı veya kapalı bitki standı kullan.',
      );
    }

    if (_containsAny(value, _lowRiskKeywords)) {
      return const PlantSafetyInfo(
        catFriendly: 'Kısmen',
        dogFriendly: 'Kısmen',
        childFriendly: 'Kısmen',
        toxicity: 'Düşük',
        riskTypes: ['Deri tahrişi', 'Göz tahrişi'],
        warning:
            'Diken, özsu veya yoğun koku temas halinde hafif tahriş oluşturabilir.',
        recommendation:
            'Bakım sırasında eldiven kullan; küçük çocuk ve evcil hayvan erişimini sınırla.',
      );
    }

    return const PlantSafetyInfo(
      catFriendly: 'Kısmen',
      dogFriendly: 'Kısmen',
      childFriendly: 'Kısmen',
      toxicity: 'Düşük',
      riskTypes: ['Ağız tahrişi'],
      warning:
          'Bu tür için güvenlik bilgisi sınırlı olabilir; yaprak veya meyve tüketimine izin verme.',
      recommendation:
          'Evcil hayvan ve küçük çocuk varsa bitkiyi erişimi zor bir noktada konumlandır.',
    );
  }

  int safetyRankFor(String plantName, SafetyProfile profile) {
    if (!profile.hasAnyRiskGroup) {
      return 0;
    }
    final safety = safetyFor(plantName);
    var rank = 0;
    if (profile.hasCat) {
      rank += _statusRank(safety.catFriendly);
    }
    if (profile.hasDog) {
      rank += _statusRank(safety.dogFriendly);
    }
    if (profile.hasChild) {
      rank += _statusRank(safety.childFriendly);
    }
    rank += switch (safety.toxicity) {
      'Yok' => 0,
      'Düşük' => 1,
      'Orta' => 3,
      'Yüksek' => 6,
      _ => 2,
    };
    return rank;
  }

  bool matchesFilter(String plantName, SafetyFilter filter) {
    final safety = safetyFor(plantName);
    return switch (filter) {
      SafetyFilter.all => true,
      SafetyFilter.catFriendly => safety.catFriendly == 'Evet',
      SafetyFilter.dogFriendly => safety.dogFriendly == 'Evet',
      SafetyFilter.childFriendly => safety.childFriendly == 'Evet',
      SafetyFilter.fullySafe => safety.fullySafe,
    };
  }

  int _statusRank(String status) {
    return switch (status) {
      'Evet' => 0,
      'Kısmen' => 2,
      'Hayır' => 5,
      _ => 3,
    };
  }

  bool _containsAny(String value, List<String> keywords) {
    return keywords.any(value.contains);
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c');
  }
}

enum SafetyFilter {
  all('Tümü'),
  catFriendly('Sadece kedi dostu'),
  dogFriendly('Sadece köpek dostu'),
  childFriendly('Sadece çocuk dostu'),
  fullySafe('Tamamen güvenli');

  const SafetyFilter(this.label);

  final String label;
}

const _safeKeywords = [
  'kurdele',
  'areka',
  'calathea',
  'dua cicegi',
  'maranta',
  'peperomia',
  'fittonia',
  'pilea',
  'afrika meneksesi',
  'orkide',
  'phalaenopsis',
  'feslegen',
  'nane',
  'kekik',
];

const _highRiskKeywords = [
  'zambak',
  'lilyum',
  'oleander',
  'zakkum',
  'sikas',
  'cycas',
  'tesbih',
  'azalea',
  'acelya',
  'datura',
];

const _mediumRiskKeywords = [
  'monstera',
  'devetabani',
  'deve tabani',
  'difenbahya',
  'dieffenbachia',
  'pothos',
  'salon sarmasigi',
  'philodendron',
  'baris cicegi',
  'spathiphyllum',
  'alocasia',
  'caladium',
  'antoryum',
  'anthurium',
  'ficus',
  'kauçuk',
  'kaucuk',
  'dracaena',
  'yuka',
  'yucca',
  'aloe',
  'sansevieria',
  'pasa kilici',
  'paşa kılıcı',
  'euphorbia',
  'sut agaci',
  'süt ağacı',
];

const _lowRiskKeywords = [
  'kaktus',
  'kaktüs',
  'sukulent',
  'gül',
  'gul',
  'lavanta',
  'biberiye',
  'limon',
  'mandalina',
  'portakal',
];
