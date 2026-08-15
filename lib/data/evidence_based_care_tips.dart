import '../models/diagnosis_result.dart';

class EvidenceBasedCareTip {
  const EvidenceBasedCareTip({
    required this.turkish,
    required this.english,
    required this.sourceName,
    required this.sourceUrl,
  });

  final String turkish;
  final String english;
  final String sourceName;
  final String sourceUrl;
}

/// Source-backed home-care notes reviewed on 2026-08-14.
///
/// The plant library already contains species-specific tips. These notes add a
/// practical evidence layer without presenting popular kitchen remedies as
/// proven fertilizer treatments.
List<EvidenceBasedCareTip> evidenceBasedCareTipsFor(PlantCareProfile profile) {
  final category = profile.category.toLowerCase();
  final style = profile.watering.style.toLowerCase();
  final tips = <EvidenceBasedCareTip>[
    const EvidenceBasedCareTip(
      turkish:
          'Çay/kahve posasını ve yumurta kabuğunu doğrudan saksıya yığma; bunları komposta eklemek daha güvenlidir. Saksıya tuz veya Epsom tuzu dökme.',
      english:
          'Do not pile tea or coffee grounds and eggshells directly into the pot; adding them to compost is safer. Do not add table salt or Epsom salt to the pot.',
      sourceName: 'University of Minnesota Extension',
      sourceUrl:
          'https://extension.umn.edu/manage-soil-nutrients/coffee-grounds-eggshells-epsom-salts',
    ),
  ];

  if (category.contains('foliage') ||
      category.contains('large') ||
      category.contains('tree') ||
      category.contains('palm')) {
    tips.add(
      const EvidenceBasedCareTip(
        turkish:
            'Geniş yaprakları yalnızca nemli bir bezle nazikçe sil; yaprak parlatıcı ürün kullanma.',
        english:
            'Gently wipe broad leaves with a damp cloth only; do not use leaf-shine products.',
        sourceName: 'University of Minnesota Extension',
        sourceUrl:
            'https://extension.umn.edu/houseplants/spring-houseplant-care',
      ),
    );
  } else if (style == 'moist' ||
      category.contains('tropical') ||
      category.contains('fern')) {
    tips.add(
      const EvidenceBasedCareTip(
        turkish:
            'Nemi artırmak için sürekli fısfıs yerine bitkileri grupla veya nemlendirici kullan; yaprakları uzun süre ıslak bırakma.',
        english:
            'To raise humidity, group plants or use a humidifier instead of constant misting; do not leave foliage wet for long.',
        sourceName: 'Iowa State University Extension',
        sourceUrl:
            'https://yardandgarden.extension.iastate.edu/how-to/how-care-houseplants',
      ),
    );
  } else if (style == 'dry') {
    tips.add(
      const EvidenceBasedCareTip(
        turkish:
            'Sulama gününü takvimden seçme; toprağın kuruluğunu ve saksının hafifleyip hafiflemediğini birlikte kontrol et.',
        english:
            'Do not choose watering day by the calendar; check both soil dryness and whether the pot feels lighter.',
        sourceName: 'Iowa State University Extension',
        sourceUrl:
            'https://yardandgarden.extension.iastate.edu/how-to/how-care-houseplants',
      ),
    );
  } else {
    tips.add(
      const EvidenceBasedCareTip(
        turkish:
            'Aktif büyüme döneminde gerekiyorsa etiketli dengeli gübreyi düşük dozda kullan; zayıf veya susuz bitkiye hemen gübre verme.',
        english:
            'During active growth, use a labeled balanced fertilizer at low strength if needed; do not immediately fertilize a weak or thirsty plant.',
        sourceName: 'University of Minnesota Extension',
        sourceUrl:
            'https://extension.umn.edu/houseplants/spring-houseplant-care',
      ),
    );
  }

  return tips;
}
