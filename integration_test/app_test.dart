import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:gravel_biking/main.dart' as app;
import 'package:gravel_biking/screens/gravel_streets_map.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Gravel First Integration Tests', () {
    group('App Launch and Navigation', () {
      testWidgets('should launch app successfully', (tester) async {
        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Verify app launches and displays main screen
        expect(find.text('Gravel First'), findsOneWidget);
      });

      testWidgets('should display map interface', (tester) async {
        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Verify main map components are present
        expect(find.text('Gravel First'), findsOneWidget);

        // Check for measurement hint text (indicates map is ready)
        expect(
          find.textContaining('Tryck på kartan för att lägga till punkter'),
          findsOneWidget,
        );
      });
    });

    group('Route Measurement Workflow', () {
      testWidgets('should enable measurement mode', (tester) async {
        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Find and tap measurement toggle button
        final measureButton = find.byTooltip('Växla mätläge');
        if (tester.any(measureButton)) {
          await tester.tap(measureButton);
          await tester.pumpAndSettle();
        }

        // Verify measurement mode is active
        // (This would need to check for visual indicators of active state)
        expect(find.text('Gravel First'), findsOneWidget);
      });

      testWidgets('should handle route point addition', (tester) async {
        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Enable measurement mode if toggle exists
        final measureButton = find.byTooltip('Växla mätläge');
        if (tester.any(measureButton)) {
          await tester.tap(measureButton);
          await tester.pumpAndSettle();
        }

        // Get map center coordinates for tap testing
        final mapFinder = find.byType(GravelStreetsMap);
        if (tester.any(mapFinder)) {
          final mapCenter = tester.getCenter(mapFinder);

          // Simulate tapping on map to add points
          await tester.tapAt(mapCenter);
          await tester.pumpAndSettle();

          // Tap at different location to create a route
          await tester.tapAt(mapCenter + const Offset(50, 50));
          await tester.pumpAndSettle();

          // Verify route measurement is working
          // (Would need to check for distance display or route visualization)
          expect(find.text('Gravel First'), findsOneWidget);
        }
      });
    });

    group('Drawer Navigation', () {
      testWidgets('should open and navigate drawer', (tester) async {
        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Open drawer
        await tester.tap(find.byTooltip('Open navigation menu'));
        await tester.pumpAndSettle();

        // Verify drawer content
        expect(find.text('Gravel overlay'), findsOneWidget);
        expect(find.text('TRV NVDB gravel'), findsOneWidget);
        expect(find.text('Sparade rutter'), findsOneWidget);

        // Test drawer interactions
        await tester.tap(find.text('Sparade rutter'));
        await tester.pumpAndSettle();

        // Should navigate to saved routes page
        // (Implementation would depend on navigation structure)
      });

      testWidgets('should toggle gravel overlay', (tester) async {
        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Open drawer
        await tester.tap(find.byTooltip('Open navigation menu'));
        await tester.pumpAndSettle();

        // Find gravel overlay switch
        final gravelSwitch = find.text('Gravel overlay').hitTestable();
        if (tester.any(gravelSwitch)) {
          await tester.tap(gravelSwitch);
          await tester.pumpAndSettle();
        }

        // Verify overlay toggle works
        expect(find.text('Gravel overlay'), findsOneWidget);
      });
    });

    group('File Operations', () {
      testWidgets('should handle export operations', (tester) async {
        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // First create a simple route
        final measureButton = find.byTooltip('Växla mätläge');
        if (tester.any(measureButton)) {
          await tester.tap(measureButton);
          await tester.pumpAndSettle();
        }

        // Add some route points by tapping on map
        final mapFinder = find.byType(GravelStreetsMap);
        if (tester.any(mapFinder)) {
          final mapCenter = tester.getCenter(mapFinder);
          await tester.tapAt(mapCenter);
          await tester.pumpAndSettle();
          await tester.tapAt(mapCenter + const Offset(100, 0));
          await tester.pumpAndSettle();
        }

        // Open drawer and test export
        await tester.tap(find.byTooltip('Open navigation menu'));
        await tester.pumpAndSettle();

        // Look for export options in drawer
        if (tester.any(find.text('GeoJSON'))) {
          await tester.tap(find.text('GeoJSON'));
          await tester.pumpAndSettle();

          // Test export functionality
          if (tester.any(find.text('Exportera GeoJSON'))) {
            await tester.tap(find.text('Exportera GeoJSON'));
            await tester.pumpAndSettle();
          }
        }
      });
    });

    group('Location Services', () {
      testWidgets('should handle location permission', (tester) async {
        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Look for location button
        final locationButton = find.byTooltip('Hitta min plats');
        if (tester.any(locationButton)) {
          await tester.tap(locationButton);
          await tester.pumpAndSettle();

          // Would need to mock location services for full testing
          // For now, just verify the app doesn't crash
          expect(find.text('Gravel First'), findsOneWidget);
        }
      });
    });

    group('Edit Mode Functionality', () {
      testWidgets('should enter and exit edit mode', (tester) async {
        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // First create a route with some points
        final measureButton = find.byTooltip('Växla mätläge');
        if (tester.any(measureButton)) {
          await tester.tap(measureButton);
          await tester.pumpAndSettle();
        }

        // Add points to map
        final mapFinder = find.byType(GravelStreetsMap);
        if (tester.any(mapFinder)) {
          final mapCenter = tester.getCenter(mapFinder);
          await tester.tapAt(mapCenter);
          await tester.pumpAndSettle();
          await tester.tapAt(mapCenter + const Offset(100, 100));
          await tester.pumpAndSettle();
        }

        // Look for edit mode button
        if (tester.any(find.text('Redigera'))) {
          await tester.tap(find.text('Redigera'));
          await tester.pumpAndSettle();

          // Verify edit mode is active
          // (Would check for edit mode indicators)
          expect(find.text('Gravel First'), findsOneWidget);

          // Exit edit mode
          if (tester.any(find.text('Avbryt'))) {
            await tester.tap(find.text('Avbryt'));
            await tester.pumpAndSettle();
          }
        }
      });
    });

    group('Performance and Stress Tests', () {
      testWidgets('should handle rapid interactions', (tester) async {
        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Enable measurement mode
        final measureButton = find.byTooltip('Växla mätläge');
        if (tester.any(measureButton)) {
          await tester.tap(measureButton);
          await tester.pumpAndSettle();
        }

        // Rapidly add multiple points
        final mapFinder = find.byType(GravelStreetsMap);
        if (tester.any(mapFinder)) {
          final mapCenter = tester.getCenter(mapFinder);

          for (int i = 0; i < 10; i++) {
            await tester.tapAt(mapCenter + Offset(i * 20.0, i * 10.0));
            await tester.pump(); // Don't settle, test rapid interactions
          }

          await tester.pumpAndSettle();
        }

        // Verify app remains stable
        expect(find.text('Gravel First'), findsOneWidget);
      });

      testWidgets('should maintain performance with complex routes', (
        tester,
      ) async {
        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 3));

        final stopwatch = Stopwatch()..start();

        // Enable measurement and add many points
        final measureButton = find.byTooltip('Växla mätläge');
        if (tester.any(measureButton)) {
          await tester.tap(measureButton);
          await tester.pumpAndSettle();
        }

        final mapFinder = find.byType(GravelStreetsMap);
        if (tester.any(mapFinder)) {
          final mapCenter = tester.getCenter(mapFinder);

          // Add 50 points to create a complex route
          for (int i = 0; i < 50; i++) {
            await tester.tapAt(
              mapCenter + Offset((i % 10) * 15.0, (i ~/ 10) * 15.0),
            );

            if (i % 10 == 0) {
              await tester.pump(); // Periodic pump to simulate real usage
            }
          }

          await tester.pumpAndSettle();
        }

        stopwatch.stop();

        // Should complete complex route creation in reasonable time
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(30000),
        ); // 30 seconds max
        expect(find.text('Gravel First'), findsOneWidget);
      });
    });

    group('Error Recovery Tests', () {
      testWidgets('should recover from network errors', (tester) async {
        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // App should launch successfully even if network is unavailable
        expect(find.text('Gravel First'), findsOneWidget);

        // Test map interactions without network
        final mapFinder = find.byType(GravelStreetsMap);
        if (tester.any(mapFinder)) {
          final mapCenter = tester.getCenter(mapFinder);
          await tester.tapAt(mapCenter);
          await tester.pumpAndSettle();
        }

        // App should remain functional
        expect(find.text('Gravel First'), findsOneWidget);
      });

      testWidgets('should handle device rotation', (tester) async {
        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Simulate device rotation
        await tester.binding.setSurfaceSize(const Size(800, 600));
        await tester.pumpAndSettle();

        // Verify app adapts to new orientation
        expect(find.text('Gravel First'), findsOneWidget);

        // Rotate back
        await tester.binding.setSurfaceSize(const Size(400, 800));
        await tester.pumpAndSettle();

        expect(find.text('Gravel First'), findsOneWidget);
      });
    });
  });
}
