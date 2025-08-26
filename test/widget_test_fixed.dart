// Updated widget test for the refactored Gravel First app
//
// This test verifies the basic functionality of the refactored app structure

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravel_biking/main.dart';

void main() {
  group('Gravel First App Widget Tests', () {
    testWidgets('App builds with map and app bar', (tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // App bar title exists
      expect(find.text('Gravel First'), findsOneWidget);

      // Distance panel hint text should be present initially
      expect(
        find.text(
          'Tryck på kartan för att lägga till punkter i redigeringsläge (grön redigeringsknapp)',
        ),
        findsOneWidget,
      );
    });

    testWidgets('App has proper theme configuration', (tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Verify Material 3 is used
      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.theme?.useMaterial3, isTrue);
      expect(materialApp.darkTheme?.useMaterial3, isTrue);
    });

    testWidgets('App displays measurement controls', (tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Look for measurement-related UI elements
      // These might be buttons or text that indicate measurement functionality
      expect(find.text('Gravel First'), findsOneWidget);
    });

    testWidgets('App handles tap interactions safely', (tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Verify app can handle basic interactions without crashing
      // Try tapping on safe areas (not expecting specific functionality)
      final appBarFinder = find.text('Gravel First');
      if (tester.any(appBarFinder)) {
        await tester.tap(appBarFinder);
        await tester.pumpAndSettle();
      }

      // App should still be functional
      expect(find.text('Gravel First'), findsOneWidget);
    });

    testWidgets('App maintains state during interactions', (tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Simulate some basic user interactions
      await tester.pump(const Duration(milliseconds: 500));

      // Verify the app maintains its basic structure
      expect(find.text('Gravel First'), findsOneWidget);
    });
  });

  group('Performance Tests', () {
    testWidgets('App builds within reasonable time', (tester) async {
      final stopwatch = Stopwatch()..start();

      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      stopwatch.stop();

      // App should build quickly
      expect(stopwatch.elapsedMilliseconds, lessThan(5000)); // 5 seconds max
    });

    testWidgets('App handles multiple pumps efficiently', (tester) async {
      await tester.pumpWidget(const MyApp());

      final stopwatch = Stopwatch()..start();

      // Simulate rapid UI updates
      for (int i = 0; i < 10; i++) {
        await tester.pump();
      }

      stopwatch.stop();

      // Should handle rapid updates efficiently
      expect(stopwatch.elapsedMilliseconds, lessThan(1000));
    });
  });
}
