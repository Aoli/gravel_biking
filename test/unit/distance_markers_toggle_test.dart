import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravel_biking/providers/ui_providers.dart';

void main() {
  group('Distance Markers Toggle', () {
    test('should default to enabled (true)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final distanceMarkersEnabled = container.read(distanceMarkersProvider);
      expect(distanceMarkersEnabled, isTrue,
          reason: 'Distance markers should be enabled by default');
    });

    test('should toggle distance markers visibility', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Start with default state (enabled)
      expect(container.read(distanceMarkersProvider), isTrue);

      // Toggle to disabled
      container.read(distanceMarkersProvider.notifier).state = false;
      expect(container.read(distanceMarkersProvider), isFalse);

      // Toggle back to enabled
      container.read(distanceMarkersProvider.notifier).state = true;
      expect(container.read(distanceMarkersProvider), isTrue);
    });

    test('should maintain state independence from other providers', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Verify initial states
      expect(container.read(distanceMarkersProvider), isTrue);
      expect(container.read(measureModeProvider), isFalse);

      // Change distance markers state
      container.read(distanceMarkersProvider.notifier).state = false;
      expect(container.read(distanceMarkersProvider), isFalse);

      // Verify other providers are unaffected
      expect(container.read(measureModeProvider), isFalse);

      // Change measure mode state
      container.read(measureModeProvider.notifier).state = true;
      expect(container.read(measureModeProvider), isTrue);

      // Verify distance markers state is still independent
      expect(container.read(distanceMarkersProvider), isFalse);
    });
  });
}
