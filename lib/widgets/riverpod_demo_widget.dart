import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/ui_providers.dart';

/// Demo widget to test Riverpod integration
/// 
/// This widget demonstrates basic Riverpod usage by providing
/// a simple toggle for measure mode.
/// 
/// TODO: Remove this widget once full migration is complete.
class RiverpodDemoWidget extends ConsumerWidget {
  const RiverpodDemoWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the measure mode state - widget rebuilds when it changes
    final measureEnabled = ref.watch(measureModeProvider);
    
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Riverpod Demo',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('Measure Mode: ${measureEnabled ? "ON" : "OFF"}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Toggle the state using the provider's notifier
                ref.read(measureModeProvider.notifier).state = !measureEnabled;
              },
              child: Text(measureEnabled ? 'Turn Off' : 'Turn On'),
            ),
          ],
        ),
      ),
    );
  }
}
