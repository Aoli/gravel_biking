import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravel_biking/main.dart';

void main() {
  group('MyApp Widget Tests', () {
    testWidgets('should build app with correct configuration', (tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Verify app builds and has basic structure
      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.text('Gravel First'), findsOneWidget);

      // Verify Material 3 configuration
      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.theme?.useMaterial3, isTrue);
      expect(materialApp.darkTheme?.useMaterial3, isTrue);
    });

    testWidgets('should display main screen content', (tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Verify main UI elements are present
      expect(find.text('Gravel First'), findsOneWidget);
    });

    testWidgets('should handle basic interactions', (tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Verify app responds to basic interactions
      expect(find.byType(MaterialApp), findsOneWidget);

      // Simulate frame updates
      await tester.pump();
      expect(find.text('Gravel First'), findsOneWidget);
    });
  });

  group('Performance Tests', () {
    testWidgets('should build within reasonable time', (tester) async {
      final stopwatch = Stopwatch()..start();

      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      stopwatch.stop();

      // Should build quickly
      expect(stopwatch.elapsedMilliseconds, lessThan(10000));
    });
  });
}
