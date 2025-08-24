// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:gravel_biking/main.dart';

void main() {
  testWidgets('App builds with map and app bar', (tester) async {
    await tester.pumpWidget(const MyApp());

    // App bar title exists
    expect(find.text('Gravel First'), findsOneWidget);

    // Wait a frame for map to layout
    await tester.pump(const Duration(milliseconds: 100));

    // Distance panel hint text should be present initially (clarified)
    expect(
      find.text(
        'Tryck på kartan för att lägga till punkter i redigeringsläge (grön redigeringsknapp)',
      ),
      findsOneWidget,
    );
  });
}
