import 'package:flutter_test/flutter_test.dart';

import 'package:roadsafe_ai/app.dart';
import 'package:roadsafe_ai/screens/login_screen.dart';
import 'package:roadsafe_ai/screens/splash_screen.dart';

void main() {
  testWidgets('RoadSafe AI starts on the splash screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(const RoadSafeAI());

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text('RoadSafe AI'), findsOneWidget);
    expect(find.text('Blind Spot & Pothole Detection'), findsOneWidget);
  });

  testWidgets('splash advances to login after the delay',
      (WidgetTester tester) async {
    await tester.pumpWidget(const RoadSafeAI());
    expect(find.byType(SplashScreen), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.byType(SplashScreen), findsNothing);
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
