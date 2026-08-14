import 'package:cicek_doktoru/main.dart';
import 'package:cicek_doktoru/widgets/logo_mark.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('app starts with splash branding', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const CicekDoktoruApp());

    expect(find.byType(FullBrandLogo), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
  });
}
