import 'package:cicek_doktoru/models/diagnosis_result.dart';
import 'package:cicek_doktoru/widgets/premium_care_tips.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
    'specialTips': [
      'Yaprak yırtılması normal olabilir.',
      'Yüksek nem gelişimi artırır.',
      'Kışın ışık azalınca sulamayı düşür.',
    ],
    'avoid': ['Tam kuruma'],
  });

  Widget app({required bool isPremium}) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: PremiumCareTips(
            profile: profile,
            isPremiumOverride: isPremium,
          ),
        ),
      ),
    );
  }

  testWidgets('free users see one tip and a locked preview', (tester) async {
    await tester.pumpWidget(app(isPremium: false));

    expect(find.text('Yaprak yırtılması normal olabilir.'), findsOneWidget);
    expect(find.text('4 özel ipucu daha'), findsOneWidget);
    expect(find.text('Premium ile ipuçlarını aç'), findsOneWidget);
    final blurredTip = find.text('Yüksek nem gelişimi artırır.');
    expect(blurredTip, findsOneWidget);
    expect(
      find.ancestor(of: blurredTip, matching: find.byType(ExcludeSemantics)),
      findsOneWidget,
    );
  });

  testWidgets('premium users see all species and evidence tips', (
    tester,
  ) async {
    await tester.pumpWidget(app(isPremium: true));

    expect(find.text('Yüksek nem gelişimi artırır.'), findsOneWidget);
    expect(find.text('Kışın ışık azalınca sulamayı düşür.'), findsOneWidget);
    expect(find.textContaining('Çay/kahve posasını'), findsOneWidget);
    expect(find.textContaining('University of Minnesota'), findsOneWidget);
    expect(find.text('Premium ile ipuçlarını aç'), findsNothing);
  });
}
