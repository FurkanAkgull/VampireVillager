import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vampir_koylu/features/splash/splash_screen.dart';
import 'package:vampir_koylu/main.dart';

void main() {
  testWidgets('App boots through the splash to the home screen',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const VampirKoyluApp());

    // Splash first (design doc §5).
    expect(find.text('VAMPİR'), findsOneWidget);
    expect(find.text('KÖYLÜ'), findsOneWidget);

    // Then the main menu, after the splash hold + session-resume check.
    await tester.pump(SplashScreen.holdDuration);
    await tester.pumpAndSettle();

    expect(find.text('VAMPİR KÖYLÜ'), findsOneWidget);
    expect(find.text('OYUN OLUŞTUR'), findsOneWidget);
    expect(find.text('OYUNA KATIL'), findsOneWidget);
  });
}
