import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:roadsafe_ai/screens/blind_spot_screen.dart';
import 'package:roadsafe_ai/screens/report_screen.dart';
import 'package:roadsafe_ai/utils/routes.dart';

void main() {
  // These screens previously rendered invented sensor values as if they were
  // live readings. These tests fail if fabricated data reappears.
  group('Blind spot screen honesty', () {
    Future<void> pumpBlindSpot(WidgetTester tester) async {
      // A tall surface so the whole screen is laid out. The body is a
      // ListView, which builds lazily - on the default 800x600 test viewport
      // the lower cards and buttons would not exist in the tree at all.
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: BlindSpotScreen()),
      );
      // Let the model-load attempt and notification setup settle.
      await tester.pumpAndSettle();
    }

    testWidgets('never shows a hardcoded detection while the model is absent',
        (tester) async {
      await pumpBlindSpot(tester);

      // None of the previously hardcoded sample readings may be present.
      expect(find.text('Bike Detected'), findsNothing);
      expect(find.text('4.5 meters'), findsNothing);
      expect(find.text('2.3 sec'), findsNothing);
      expect(find.text('Left Blind Spot'), findsNothing);
    });

    testWidgets('reports that the model is unavailable', (tester) async {
      await pumpBlindSpot(tester);

      // The bundled model is a placeholder, so this is the real state.
      expect(find.text('AI model not available'), findsOneWidget);
    });

    testWidgets('shows "No detection" rather than a made-up reading',
        (tester) async {
      await pumpBlindSpot(tester);

      // All four metric cards read "No detection" instead of a fabricated
      // number.
      expect(find.text('No detection'), findsNWidgets(4));
      expect(find.textContaining('meters'), findsNothing);
      expect(find.textContaining(' sec'), findsNothing);
    });

    testWidgets('labels simulated values as simulated', (tester) async {
      await pumpBlindSpot(tester);

      await tester.tap(find.textContaining('Simulate Detection'));
      await tester.pumpAndSettle();

      // Every sample reading is explicitly marked as simulated.
      expect(find.text('3.2 m (simulated)'), findsOneWidget);
      expect(find.text('1.5 s (simulated)'), findsOneWidget);
      expect(find.text('Motorcycle (simulated)'), findsOneWidget);
    });
  });

  group('Reports screen honesty', () {
    testWidgets('shows an empty state instead of invented rows',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        const MaterialApp(home: ReportScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('No reports yet'), findsOneWidget);
      // The ten hardcoded "Pothole Report N" rows are gone.
      expect(find.textContaining('Pothole Report'), findsNothing);
      // The Export button had an empty onPressed; it is no longer offered.
      expect(find.text('Export'), findsNothing);
    });
  });

  group('Routes', () {
    test('no longer registers the removed report detail route', () {
      expect(AppRoutes.routes.containsKey('/reportDetails'), isFalse);
      expect(AppRoutes.routes.containsKey(AppRoutes.reports), isTrue);
    });
  });
}
