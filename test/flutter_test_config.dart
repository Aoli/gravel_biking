import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:gravel_biking/models/saved_route.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Initialize Hive for testing environment
  TestWidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive with a temporary directory for testing
  final tempDir = await Directory.systemTemp.createTemp('hive_test');
  Hive.init(tempDir.path);
  
  // Register Hive adapters for testing
  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(SavedRouteAdapter());
  }
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(LatLngDataAdapter());
  }

  // Run the tests
  await testMain();

  // Clean up after tests
  await Hive.close();
  try {
    await tempDir.delete(recursive: true);
  } catch (e) {
    // Ignore cleanup errors in test environment
  }
}
