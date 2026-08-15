import 'package:cicek_doktoru/data/evidence_based_care_tips.dart';
import 'package:cicek_doktoru/models/diagnosis_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('evidence tips include source-backed home-care guidance', () {
    final profile = PlantCareProfile.fromJson({
      'commonNames': ['Muz bitkisi'],
      'latinName': 'Musa acuminata',
      'category': 'indoor_large',
      'watering': {
        'style': 'moist',
        'soilDryCm': [2, 4],
        'summerDays': [3, 6],
        'winterDays': [7, 12],
        'note': 'Toprak hafif kurudukça sulanır.',
      },
      'light': 'Çok aydınlık, filtreli güneş.',
      'specialTips': ['Yaprak yırtılması normal olabilir.'],
      'avoid': ['Tam kuruma'],
    });

    final tips = evidenceBasedCareTipsFor(profile);

    expect(tips, hasLength(2));
    expect(tips.first.turkish, contains('komposta'));
    expect(tips.first.turkish, contains('tuz'));
    expect(tips.last.turkish, contains('nemli bir bez'));
    expect(tips.every((tip) => tip.sourceUrl.startsWith('https://')), isTrue);
  });
}
