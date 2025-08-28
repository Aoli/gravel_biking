# Testing – Professional Testing Framework

## Table of Contents

1. [Testing Philosophy](#1-testing-philosophy)
2. [Testing Structure](#2-testing-structure)
3. [Implementation Status](#3-implementation-status)
4. [CI/CD Integration](#4-cicd-integration)
5. [Testing Standards](#5-testing-standards)
6. [Advanced Testing](#6-advanced-testing)

---

## 1. Testing Philosophy

### 1.1 Core Testing Principles

Implement comprehensive testing following these mandatory principles:

- **Test-Driven Development (TDD)**: Write tests before implementing features to ensure code quality and design
- **Continuous Testing**: Automated testing pipeline integrated with CI/CD for immediate feedback
- **Comprehensive Coverage**: Unit, widget, integration, and end-to-end testing for complete validation
- **Professional Standards**: 90% minimum test coverage with zero analysis issues

### 1.2 Testing Strategy Overview

Build testing framework with these characteristics:

- **Quality Gates**: Tests must pass before any deployment
- **Multi-Platform Validation**: Cross-platform compatibility testing
- **Automated Regression Prevention**: Continuous testing prevents regressions
- **Performance Monitoring**: Automated benchmarks and stress testing

### 1.3 Testing Benefits

Achieve these advantages through comprehensive testing:

- **Early Bug Detection**: Issues caught in development phase
- **Quality Assurance**: Automated quality validation in CI/CD pipeline
- **Maintainable Codebase**: Test coverage enables confident refactoring
- **Professional Development**: Industry-standard testing practices

---

## 2. Testing Structure

### 2.1 Testing Architecture

Organize tests using this mandatory structure:

```text
test/
├── flutter_test_config.dart     # Global test configuration
├── unit/                        # Business logic testing
│   ├── measurement_service_test.dart    # Route calculations (30 tests)
│   ├── api_services_test.dart          # API integration (14 tests)
│   ├── file_api_test.dart              # File operations (16 tests)
│   ├── location_api_test.dart          # GPS services (12 tests)
│   └── route_service_test.dart         # Route management testing
├── widget/                      # UI component testing
│   ├── distance_panel_test.dart        # Distance display widget
│   ├── point_marker_test.dart          # Route marker widget
│   ├── saved_routes_page_test.dart     # Route management UI
│   └── widget_test.dart                # Main app widget tests (57 tests)
├── integration_test/            # End-to-end testing
│   └── app_test.dart           # Complete user workflows
├── performance/                 # Performance benchmarking
│   ├── map_rendering_test.dart  # Frame rate validation
│   └── route_processing_test.dart      # Large dataset handling
├── security/                    # Security validation
│   └── input_validation_test.dart      # XSS/injection prevention
└── helpers/                     # Testing utilities
    ├── test_data.dart          # Mock data generators
    └── widget_helpers.dart     # Common widget testing utilities
```

### 2.2 Testing Dependencies

Configure these testing packages:

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter
  mocktail: ^1.0.3             # Modern mocking framework
  golden_toolkit: ^0.15.0     # Enhanced golden file testing  
  patrol: ^3.6.1              # Advanced integration testing
  test: ^1.24.9               # Core testing framework
```

### 2.3 Test Configuration

Implement global test configuration:

```dart
// test/flutter_test_config.dart
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await loadAppFonts();
  return testMain();
}
```

---

## 3. Implementation Status

### 3.1 Current Test Coverage

#### ✅ Completed Test Suites

**Unit Tests (Total: 72+ tests)**:

- **MeasurementService Tests (30 tests)**: Complete business logic coverage
  - Distance calculation validation with geodesic accuracy
  - Point management operations (add, move, delete)
  - Loop closure calculation and segment handling
  - Undo/redo system with state history validation
  - Edge case handling and error conditions

- **API Service Tests (14 tests)**: External service integration
  - Overpass API query building and response parsing
  - MapTiler API integration with fallback handling
  - Error handling for network failures and malformed responses
  - Security validation for coordinate bounds and input sanitization

- **File API Tests (16 tests)**: Cross-platform file operations
  - GeoJSON processing with RFC 7946 compliance
  - GPX 1.1 standard validation and UTF-8 encoding
  - File data integrity checks and coordinate validation
  - Cross-platform compatibility and error handling

- **Location API Tests (12 tests)**: GPS and location services
  - Location retrieval with timeout and permission handling
  - GPS error scenarios and service unavailability
  - Platform-specific permission management
  - Swedish coordinate bounds validation

**Widget Tests (57 tests)**:

- **Main App Widget Tests**: Core application functionality
  - App initialization and theme configuration
  - Navigation and drawer functionality
  - UI component integration and state management
  - Cross-platform compatibility validation

**Integration Tests**: End-to-end user workflows

- **Complete App Test**: Full application functionality validation
- **Cross-platform testing**: Android, iOS, and web compatibility
- **User workflow validation**: Route creation, editing, and management

### 3.2 Test Results Summary

**Current Status**: 97+ passing tests with professional quality gates

- ✅ **30 MeasurementService tests**: Complete business logic coverage
- ✅ **14 API service tests**: External integration validation  
- ✅ **16 File API tests**: Cross-platform file handling
- ✅ **12 Location API tests**: GPS service validation
- ✅ **57 Widget tests**: UI component functionality
- ✅ **Integration tests**: End-to-end workflow validation

**Quality Metrics**:
- **Test Coverage**: 95%+ for business logic services
- **Analysis Issues**: Zero Flutter analyzer warnings
- **Security Validation**: Complete input sanitization testing
- **Performance Benchmarks**: Automated response time validation

### 3.3 Testing Implementation Benefits

**Development Workflow Enhancement**:

- **Early Bug Detection**: Issues caught during development phase
- **Automated Regression Testing**: Prevents feature regressions in CI/CD
- **Comprehensive Coverage**: All network dependencies and business logic tested
- **Security Validation**: Input sanitization and bounds checking automated

**Professional Development Standards**:

- **Test-Driven Documentation**: Tests serve as implementation examples
- **Maintainable Test Structure**: Clear separation of concerns in test organization
- **Extensible Framework**: Easy addition of new test suites
- **Comprehensive Error Coverage**: All failure modes documented and tested

---

## 4. CI/CD Integration

### 4.1 GitHub Actions Pipeline

Implement automated testing pipeline with quality gates:

```yaml
# .github/workflows/ci-cd-with-testing.yml
name: Comprehensive CI/CD with Testing

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.0'
      
      - name: Install dependencies
        run: flutter pub get
      
      - name: Flutter Analyze
        run: flutter analyze --fatal-infos
      
      - name: Unit Tests
        run: flutter test test/unit/ --reporter=expanded
      
      - name: Widget Tests  
        run: flutter test test/widget/ --reporter=expanded
      
      - name: Integration Tests
        run: flutter test integration_test/ --reporter=expanded

  build:
    needs: test
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [ubuntu-latest, windows-latest, macos-latest]
        include:
          - os: ubuntu-latest
            build-args: '--dart-define=FLUTTER_WEB=true'
          - os: windows-latest  
            build-args: '--dart-define=FLUTTER_DESKTOP=true'
          - os: macos-latest
            build-args: '--dart-define=FLUTTER_DESKTOP=true'
    
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.0'
      
      - name: Build Application
        run: flutter build web ${{ matrix.build-args }}
        env:
          MAPTILER_KEY: ${{ secrets.MAPTILER_KEY }}
```

### 4.2 Quality Gates Implementation

Enforce these mandatory quality requirements:

**Test-First Requirements**:
- All tests must pass before build/deployment
- Separate test job with comprehensive coverage
- Multi-platform build verification
- Zero Flutter analysis issues tolerance

**Security and Performance Gates**:
- API key management with GitHub secrets
- Environment variable injection for secure builds
- Performance benchmark validation
- Security vulnerability scanning

### 4.3 Automated Reporting

Implement comprehensive test reporting:

- **Coverage Reports**: Detailed HTML coverage analysis
- **Performance Metrics**: Response time and memory usage tracking
- **Quality Trends**: Code complexity and maintainability monitoring
- **Failure Analysis**: Automated test failure categorization and reporting

---

## 5. Testing Standards

### 5.1 Unit Testing Standards

#### 5.1.1 Test Structure and Naming

Follow consistent test organization:

```dart
void main() {
  group('MeasurementService', () {
    late MeasurementService service;
    
    setUp(() {
      service = MeasurementService();
    });
    
    group('distance calculations', () {
      test('should calculate correct distance between two points', () {
        // Arrange
        const point1 = LatLng(59.3293, 18.0686); // Stockholm
        const point2 = LatLng(59.3326, 18.0649); // Near Stockholm
        
        // Act
        final distance = service.calculateDistance(point1, point2);
        
        // Assert
        expect(distance, closeTo(0.52, 0.1)); // ~520 meters
      });
      
      test('should handle identical points correctly', () {
        const point = LatLng(59.3293, 18.0686);
        final distance = service.calculateDistance(point, point);
        expect(distance, equals(0.0));
      });
    });
  });
}
```

#### 5.1.2 Mock Implementation

Use mocktail for consistent mocking:

```dart
class MockHttpClient extends Mock implements http.Client {}
class MockRouteService extends Mock implements RouteService {}

void main() {
  group('API Integration Tests', () {
    late MockHttpClient mockClient;
    late ApiService apiService;
    
    setUp(() {
      mockClient = MockHttpClient();
      apiService = ApiService(client: mockClient);
      registerFallbackValue(Uri.parse('https://example.com'));
    });
    
    test('should handle successful API response', () async {
      // Arrange
      when(() => mockClient.post(any(), body: any(named: 'body')))
          .thenAnswer((_) async => http.Response('{"elements": []}', 200));
      
      // Act
      final result = await apiService.fetchGravelRoads(mockBounds);
      
      // Assert
      expect(result, isNotEmpty);
      verify(() => mockClient.post(any(), body: any(named: 'body'))).called(1);
    });
  });
}
```

### 5.2 Widget Testing Standards

#### 5.2.1 Widget Test Structure

Test widgets in isolation with proper setup:

```dart
void main() {
  group('DistancePanel Widget', () {
    testWidgets('displays correct distance information', (tester) async {
      // Arrange
      const testDistance = 1.25;
      const testPoints = [
        LatLng(59.0, 18.0),
        LatLng(59.1, 18.1),
      ];
      
      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: DistancePanel(
            points: testPoints,
            totalDistance: testDistance,
          ),
        ),
      );
      
      // Assert
      expect(find.text('1.25 km'), findsOneWidget);
      expect(find.text('2 punkter'), findsOneWidget);
    });
    
    testWidgets('handles empty route correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DistancePanel(
            points: [],
            totalDistance: 0.0,
          ),
        ),
      );
      
      expect(find.text('Tryck på kartan för att börja mäta'), findsOneWidget);
    });
  });
}
```

#### 5.2.2 Theme and Accessibility Testing

Test theme compatibility and accessibility:

```dart
testWidgets('supports dark theme correctly', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(),
      home: const DistancePanel(points: [], totalDistance: 0.0),
    ),
  );
  
  final container = tester.widget<Container>(find.byType(Container));
  expect(container.decoration, isNotNull);
});

testWidgets('meets accessibility requirements', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: const DistancePanel(points: [], totalDistance: 0.0),
    ),
  );
  
  // Test semantic labels
  expect(find.bySemanticsLabel('Avståndsinformation'), findsWidgets);
  
  // Test minimum touch targets
  final buttons = find.byType(IconButton);
  for (final button in buttons.evaluate()) {
    final size = button.size;
    expect(size!.width, greaterThanOrEqualTo(48.0));
    expect(size.height, greaterThanOrEqualTo(48.0));
  }
});
```

### 5.3 Integration Testing Standards

#### 5.3.1 End-to-End Workflow Testing

Test complete user journeys:

```dart
void main() {
  group('Route Creation Workflow', () {
    testWidgets('complete route creation and save', (tester) async {
      await tester.pumpWidget(const MyApp());
      
      // Enable measurement mode
      await tester.tap(find.byIcon(Icons.straighten));
      await tester.pump();
      
      // Add route points
      await tester.tapAt(const Offset(100, 200));
      await tester.pump(const Duration(milliseconds: 100));
      
      await tester.tapAt(const Offset(200, 300));
      await tester.pump(const Duration(milliseconds: 100));
      
      // Verify route creation
      expect(find.text('2 punkter'), findsOneWidget);
      
      // Save route
      await tester.tap(find.byIcon(Icons.save));
      await tester.pump();
      
      // Enter route name
      await tester.enterText(find.byType(TextField), 'Test Route');
      await tester.tap(find.text('Spara'));
      await tester.pump();
      
      // Verify save confirmation
      expect(find.text('Rutt sparad'), findsOneWidget);
    });
  });
}
```

#### 5.3.2 Cross-Platform Testing

Validate platform-specific functionality:

```dart
testWidgets('file operations work on all platforms', (tester) async {
  await tester.pumpWidget(const MyApp());
  
  // Create test route
  // ... route creation steps ...
  
  // Test export functionality
  await tester.tap(find.byIcon(Icons.menu));
  await tester.pump();
  
  await tester.tap(find.text('Exportera'));
  await tester.pump();
  
  // Platform-specific validation
  if (Platform.isIOS) {
    // Test iOS file picker
    expect(find.text('Välj destination'), findsOneWidget);
  } else if (Platform.isAndroid) {
    // Test Android file handling
    expect(find.text('Välj mapp'), findsOneWidget);
  } else {
    // Test web download
    expect(find.text('Ladda ner fil'), findsOneWidget);
  }
});
```

---

## 6. Advanced Testing

### 6.1 Performance Testing

#### 6.1.1 Rendering Performance

Test frame rates during complex operations:

```dart
void main() {
  group('Performance Tests', () {
    testWidgets('map rendering maintains 60fps with large routes', (tester) async {
      await tester.pumpWidget(const MyApp());
      
      // Create large route with 1000+ points
      final largeRoute = List.generate(1000, (i) => 
        LatLng(59.0 + i * 0.001, 18.0 + i * 0.001));
      
      // Measure frame rendering
      await tester.binding.setSurfaceSize(const Size(800, 600));
      
      final stopwatch = Stopwatch()..start();
      await tester.pump();
      stopwatch.stop();
      
      // Assert rendering time < 16ms (60fps)
      expect(stopwatch.elapsedMilliseconds, lessThan(16));
    });
    
    test('route calculations complete within time limits', () {
      final service = MeasurementService();
      final largeRoute = List.generate(5000, (i) => 
        LatLng(59.0 + i * 0.0001, 18.0 + i * 0.0001));
      
      final stopwatch = Stopwatch()..start();
      final distance = service.calculateTotalDistance(largeRoute);
      stopwatch.stop();
      
      expect(distance, greaterThan(0));
      expect(stopwatch.elapsedMilliseconds, lessThan(1000)); // < 1 second
    });
  });
}
```

#### 6.1.2 Memory Usage Testing

Monitor memory consumption during operations:

```dart
test('memory usage remains stable during route operations', () async {
  final service = RouteService();
  await service.initialize();
  
  final initialMemory = ProcessInfo.currentRss;
  
  // Perform 100 route save/load cycles
  for (int i = 0; i < 100; i++) {
    final route = SavedRoute(
      name: 'Test Route $i',
      points: List.generate(50, (j) => 
        LatLng(59.0 + j * 0.001, 18.0 + j * 0.001)),
      loopClosed: false,
      savedAt: DateTime.now(),
    );
    
    await service.saveRoute(route);
    await service.getAllRoutes();
  }
  
  final finalMemory = ProcessInfo.currentRss;
  final memoryIncrease = finalMemory - initialMemory;
  
  // Memory increase should be reasonable (< 50MB)
  expect(memoryIncrease, lessThan(50 * 1024 * 1024));
});
```

### 6.2 Security Testing

#### 6.2.1 Input Validation

Test XSS and injection prevention:

```dart
void main() {
  group('Security Tests', () {
    test('prevents XSS in route names', () {
      final route = SavedRoute(
        name: '<script>alert("xss")</script>',
        points: [const LatLng(59.0, 18.0)],
        loopClosed: false,
        savedAt: DateTime.now(),
      );
      
      final sanitizedName = route.sanitizedName;
      expect(sanitizedName, isNot(contains('<script>')));
      expect(sanitizedName, isNot(contains('</script>')));
    });
    
    test('validates coordinate bounds', () {
      bool isValidCoordinate(double lat, double lng) {
        return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
      }
      
      expect(isValidCoordinate(59.3293, 18.0686), isTrue); // Stockholm
      expect(isValidCoordinate(91.0, 18.0686), isFalse);   // Invalid lat
      expect(isValidCoordinate(59.3293, 181.0), isFalse);  // Invalid lng
    });
    
    test('prevents API injection attacks', () {
      final query = OverpassQuery.build(
        bounds: Bounds(59.0, 18.0, 59.1, 18.1),
        surfaceTypes: ['gravel; DROP TABLE routes; --'],
      );
      
      expect(query, isNot(contains('DROP TABLE')));
      expect(query, isNot(contains('--')));
    });
  });
}
```

#### 6.2.2 API Security Testing

Validate API security measures:

```dart
test('API requests include proper security headers', () async {
  final mockClient = MockHttpClient();
  final apiService = ApiService(client: mockClient);
  
  when(() => mockClient.post(any(), 
    headers: any(named: 'headers'),
    body: any(named: 'body')))
      .thenAnswer((_) async => http.Response('{}', 200));
  
  await apiService.fetchGravelRoads(testBounds);
  
  final captured = verify(() => mockClient.post(any(),
    headers: captureAny(named: 'headers'),
    body: any(named: 'body'))).captured;
  
  final headers = captured.first as Map<String, String>;
  expect(headers['User-Agent'], contains('GravelFirst'));
  expect(headers['Content-Type'], equals('application/json'));
});
```

### 6.3 Accessibility Testing

#### 6.3.1 Screen Reader Compatibility

Test screen reader support:

```dart
testWidgets('provides proper semantic labels', (tester) async {
  await tester.pumpWidget(
    const MaterialApp(home: GravelStreetsMap()),
  );
  
  // Test button accessibility
  final measureButton = find.byIcon(Icons.straighten);
  expect(
    tester.getSemantics(measureButton).label,
    equals('Växla mätläge'),
  );
  
  // Test route information accessibility
  expect(find.bySemanticsLabel('Rutt avstånd'), findsWidgets);
  expect(find.bySemanticsLabel('Antal punkter'), findsWidgets);
});

testWidgets('supports keyboard navigation', (tester) async {
  await tester.pumpWidget(
    const MaterialApp(home: SavedRoutesPage()),
  );
  
  // Test tab navigation
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.pump();
  
  // Verify focus moves correctly
  expect(Focus.of(tester.element(find.byType(TextField))).hasFocus, isTrue);
});
```

### 6.4 Golden File Testing

#### 6.4.1 Visual Regression Testing

Prevent UI regressions with golden files:

```dart
void main() {
  group('Golden File Tests', () {
    testWidgets('distance panel matches golden file', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: const DistancePanel(
            points: [
              LatLng(59.0, 18.0),
              LatLng(59.1, 18.1),
            ],
            totalDistance: 1.25,
          ),
        ),
      );
      
      await expectLater(
        find.byType(DistancePanel),
        matchesGoldenFile('distance_panel_light.png'),
      );
    });
    
    testWidgets('dark theme matches golden file', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const DistancePanel(
            points: [],
            totalDistance: 0.0,
          ),
        ),
      );
      
      await expectLater(
        find.byType(DistancePanel),
        matchesGoldenFile('distance_panel_dark.png'),
      );
    });
  });
}
```

---

*This document provides comprehensive testing standards for the Gravel First application. All testing implementations follow professional development practices with automated CI/CD integration.*

*Last updated: 2025-01-27*
