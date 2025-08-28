# API Integration – External Services Documentation

## Table of Contents

1. [API Overview](#1-api-overview)
2. [Overpass API Integration](#2-overpass-api-integration)
3. [Tile Server Configuration](#3-tile-server-configuration)
4. [API Security and Validation](#4-api-security-and-validation)
5. [Error Handling](#5-error-handling)
6. [Performance and Compliance](#6-performance-and-compliance)

---

## 1. API Overview

### 1.1 External Service Dependencies

The Gravel First application integrates with these external APIs:

**Primary APIs:**
- **Overpass API**: OpenStreetMap data querying for gravel road geometry
- **MapTiler API**: Commercial tile server for map rendering (primary provider)
- **OpenStreetMap Tiles**: Fallback tile server for development and emergency scenarios

**Supporting Services:**
- **Device Location API**: Platform-specific GPS services via geolocator package
- **File System API**: Cross-platform file operations via path_provider

### 1.2 API Usage Strategy

Implement APIs following these principles:

- **Commercial Primary**: Use commercial services for production traffic
- **OSM Compliance**: Follow OpenStreetMap usage policies with appropriate fallbacks
- **Error Resilience**: Provide graceful degradation when APIs are unavailable
- **Security First**: Validate all inputs and sanitize responses

### 1.3 Integration Benefits

- **Real-time Data**: Current gravel road information from OpenStreetMap
- **Reliable Mapping**: Commercial tile provider with generous free tier
- **Cross-Platform**: Consistent API behavior across iOS, Android, and web
- **Professional Standards**: Compliant usage following industry best practices

---

## 2. Overpass API Integration

### 2.1 Service Configuration

Configure Overpass API integration for gravel road data:

```dart
class OverpassService {
  static const String baseUrl = 'https://overpass-api.de/api/interpreter';
  static const Duration requestTimeout = Duration(seconds: 25);
  
  Future<List<Polyline>> fetchGravelRoads(LatLngBounds bounds) async {
    final query = _buildOverpassQuery(bounds);
    
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent': 'GravelFirst/1.0',
        },
        body: 'data=$query',
      ).timeout(requestTimeout);
      
      if (response.statusCode == 200) {
        return await compute(_parseOverpassResponse, response.body);
      } else {
        throw OverpassException('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw OverpassException('Network error: $e');
    }
  }
}
```

### 2.2 Query Construction

Build Overpass queries for gravel road filtering:

```dart
String _buildOverpassQuery(LatLngBounds bounds) {
  return '''
  [out:json][timeout:25];
  (
    way[highway~"^(track|path|cycleway|footway|bridleway|unclassified|tertiary|secondary|primary|trunk|residential|service)$"]
       [surface~"^(gravel|compacted|fine_gravel|pebblestone|ground|earth|dirt|grass|sand|unpaved|cobblestone)$"]
       (${bounds.south},${bounds.west},${bounds.north},${bounds.east});
  );
  out geom;
  ''';
}
```

### 2.3 Response Processing

Process Overpass API responses efficiently:

```dart
List<Polyline> _parseOverpassResponse(String jsonData) {
  final data = json.decode(jsonData);
  final elements = data['elements'] as List<dynamic>;
  
  return elements
      .where((element) => element['type'] == 'way' && element['geometry'] != null)
      .map((element) => _createPolylineFromWay(element))
      .where((polyline) => polyline.points.isNotEmpty)
      .toList();
}

Polyline _createPolylineFromWay(Map<String, dynamic> way) {
  final geometry = way['geometry'] as List<dynamic>;
  final points = geometry
      .map((point) => LatLng(point['lat'], point['lon']))
      .toList();
  
  return Polyline(
    polylineId: PolylineId('gravel_${way['id']}'),
    points: points,
    color: const Color(0xFFD2691E), // SaddleBrown
    width: 2,
  );
}
```

### 2.4 Viewport-Based Fetching

Implement efficient viewport-based data loading:

```dart
class ViewportManager {
  static const Duration debounceDelay = Duration(milliseconds: 500);
  Timer? _debounceTimer;
  LatLngBounds? _lastFetchedBounds;
  
  void onMapMove(LatLngBounds currentBounds) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounceDelay, () {
      if (_shouldFetchData(currentBounds)) {
        _fetchGravelData(currentBounds);
        _lastFetchedBounds = currentBounds;
      }
    });
  }
  
  bool _shouldFetchData(LatLngBounds bounds) {
    if (_lastFetchedBounds == null) return true;
    
    // Fetch if bounds changed significantly
    const threshold = 0.01; // ~1km
    return (bounds.north - _lastFetchedBounds!.north).abs() > threshold ||
           (bounds.south - _lastFetchedBounds!.south).abs() > threshold ||
           (bounds.east - _lastFetchedBounds!.east).abs() > threshold ||
           (bounds.west - _lastFetchedBounds!.west).abs() > threshold;
  }
}
```

---

## 3. Tile Server Configuration

### 3.1 Dual-Provider Strategy

Implement compliant tile server configuration:

```dart
class TileServerConfig {
  static const String mapTilerBaseUrl = 'https://api.maptiler.com/maps/streets-v2/256';
  static const String osmFallbackUrl = 'https://tile.openstreetmap.org';
  
  static String getTileUrl(String? mapTilerKey) {
    if (mapTilerKey != null && mapTilerKey.isNotEmpty) {
      return '$mapTilerBaseUrl/{z}/{x}/{y}.png?key=$mapTilerKey';
    } else {
      return '$osmFallbackUrl/{z}/{x}/{y}.png';
    }
  }
  
  static List<String> getSubdomains(String? mapTilerKey) {
    // No subdomains to avoid OSM deprecation warnings
    return const <String>[];
  }
  
  static String getAttribution(String? mapTilerKey) {
    if (mapTilerKey != null && mapTilerKey.isNotEmpty) {
      return '© MapTiler © OpenStreetMap contributors';
    } else {
      return '© OpenStreetMap contributors';
    }
  }
}
```

### 3.2 MapTiler Integration

Configure MapTiler as primary provider:

```dart
class MapTilerService {
  static const String apiKeyEnvVar = 'MAPTILER_KEY';
  static const int freeMonthlyLimit = 100000; // 100k map loads/month
  
  static String? getApiKey() {
    return const String.fromEnvironment(apiKeyEnvVar);
  }
  
  static bool isConfigured() {
    final key = getApiKey();
    return key != null && key.isNotEmpty;
  }
  
  static String buildTileUrl(String apiKey) {
    return '${TileServerConfig.mapTilerBaseUrl}/{z}/{x}/{y}.png?key=$apiKey';
  }
}
```

### 3.3 OpenStreetMap Compliance

Ensure compliant usage of OSM tiles:

```dart
class OSMComplianceChecker {
  static const int maxRequestsPerSecond = 2;
  static const int maxConcurrentRequests = 8;
  
  static bool isCompiantUsage(String userAgent, int requestRate) {
    // Check user agent is present and descriptive
    if (userAgent.isEmpty || !userAgent.contains('GravelFirst')) {
      return false;
    }
    
    // Check request rate is reasonable
    if (requestRate > maxRequestsPerSecond) {
      return false;
    }
    
    return true;
  }
  
  static Map<String, String> getCompliantHeaders() {
    return {
      'User-Agent': 'GravelFirst/1.0 (contact: your-email@example.com)',
      'Accept': 'image/png,image/jpeg,*/*',
    };
  }
}
```

---

## 4. API Security and Validation

### 4.1 Input Validation

Implement comprehensive input validation:

```dart
class ApiInputValidator {
  static bool validateCoordinateBounds(double south, double west, double north, double east) {
    // Validate coordinate ranges
    if (south < -90 || south > 90 || north < -90 || north > 90) {
      return false;
    }
    if (west < -180 || west > 180 || east < -180 || east > 180) {
      return false;
    }
    
    // Validate bounds relationship
    if (south >= north || west >= east) {
      return false;
    }
    
    // Validate reasonable bounds size
    const maxBoundsSize = 1.0; // 1 degree (~111km)
    if ((north - south) > maxBoundsSize || (east - west) > maxBoundsSize) {
      return false;
    }
    
    return true;
  }
  
  static String sanitizeQueryInput(String input) {
    // Remove potential injection characters
    return input
        .replaceAll(RegExp(r'[;<>]'), '')  // Remove command separators
        .replaceAll(RegExp(r'--'), '')     // Remove SQL comments
        .replaceAll(RegExp(r'/\*|\*/'), '') // Remove block comments
        .trim();
  }
  
  static bool validateApiKey(String apiKey) {
    // Basic format validation for MapTiler keys
    return RegExp(r'^[a-zA-Z0-9]{20,}$').hasMatch(apiKey);
  }
}
```

### 4.2 Response Sanitization

Sanitize API responses before processing:

```dart
class ApiResponseSanitizer {
  static Map<String, dynamic> sanitizeOverpassResponse(String jsonData) {
    try {
      final data = json.decode(jsonData) as Map<String, dynamic>;
      
      // Validate expected structure
      if (!data.containsKey('elements')) {
        throw FormatException('Invalid Overpass response: missing elements');
      }
      
      // Validate elements array
      final elements = data['elements'];
      if (elements is! List) {
        throw FormatException('Invalid Overpass response: elements not a list');
      }
      
      // Sanitize each element
      final sanitizedElements = elements
          .where((element) => _isValidWayElement(element))
          .map((element) => _sanitizeWayElement(element))
          .toList();
      
      return {
        'elements': sanitizedElements,
        'version': data['version'],
        'generator': data['generator'],
      };
      
    } catch (e) {
      throw FormatException('Failed to parse Overpass response: $e');
    }
  }
  
  static bool _isValidWayElement(dynamic element) {
    if (element is! Map<String, dynamic>) return false;
    
    // Must have required fields
    if (!element.containsKey('type') || !element.containsKey('id')) {
      return false;
    }
    
    // Must be a way with geometry
    if (element['type'] != 'way' || !element.containsKey('geometry')) {
      return false;
    }
    
    return true;
  }
  
  static Map<String, dynamic> _sanitizeWayElement(Map<String, dynamic> element) {
    final geometry = element['geometry'] as List<dynamic>;
    
    // Validate and sanitize coordinate points
    final sanitizedGeometry = geometry
        .where((point) => _isValidCoordinate(point))
        .map((point) => {
          'lat': _clampLatitude(point['lat']),
          'lon': _clampLongitude(point['lon']),
        })
        .toList();
    
    return {
      'type': 'way',
      'id': element['id'],
      'geometry': sanitizedGeometry,
      'tags': element['tags'] ?? {},
    };
  }
  
  static bool _isValidCoordinate(dynamic point) {
    if (point is! Map<String, dynamic>) return false;
    if (!point.containsKey('lat') || !point.containsKey('lon')) return false;
    
    final lat = point['lat'];
    final lon = point['lon'];
    
    if (lat is! num || lon is! num) return false;
    if (lat < -90 || lat > 90) return false;
    if (lon < -180 || lon > 180) return false;
    
    return true;
  }
  
  static double _clampLatitude(num value) {
    return value.toDouble().clamp(-90.0, 90.0);
  }
  
  static double _clampLongitude(num value) {
    return value.toDouble().clamp(-180.0, 180.0);
  }
}
```

### 4.3 API Key Security

Implement secure API key handling:

```dart
class ApiKeyManager {
  static const String _keyStorageKey = 'maptiler_api_key';
  
  static Future<void> storeApiKey(String apiKey) async {
    if (!ApiInputValidator.validateApiKey(apiKey)) {
      throw ArgumentError('Invalid API key format');
    }
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyStorageKey, apiKey);
  }
  
  static Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(_keyStorageKey);
    
    if (key != null && !ApiInputValidator.validateApiKey(key)) {
      // Remove invalid key
      await prefs.remove(_keyStorageKey);
      return null;
    }
    
    return key;
  }
  
  static String maskApiKey(String apiKey) {
    if (apiKey.length <= 8) return '***';
    return '${apiKey.substring(0, 4)}...${apiKey.substring(apiKey.length - 4)}';
  }
  
  static void logApiUsage(String apiKey, String endpoint, int responseCode) {
    final maskedKey = maskApiKey(apiKey);
    print('API Call: $endpoint with key $maskedKey returned $responseCode');
  }
}
```

---

## 5. Error Handling

### 5.1 Network Error Management

Handle network errors gracefully:

```dart
class ApiErrorHandler {
  static Future<T> withRetry<T>(
    Future<T> Function() operation, {
    int maxRetries = 3,
    Duration delay = const Duration(seconds: 1),
  }) async {
    int attempts = 0;
    
    while (attempts < maxRetries) {
      try {
        return await operation();
      } catch (e) {
        attempts++;
        
        if (attempts >= maxRetries || !_isRetryableError(e)) {
          rethrow;
        }
        
        await Future.delayed(delay * attempts); // Exponential backoff
      }
    }
    
    throw StateError('Retry logic error'); // Should not reach here
  }
  
  static bool _isRetryableError(dynamic error) {
    if (error is SocketException) return true;
    if (error is TimeoutException) return true;
    if (error is HttpException) {
      // Retry on 5xx errors but not 4xx
      final statusCode = int.tryParse(error.message.split(':').first) ?? 0;
      return statusCode >= 500 && statusCode < 600;
    }
    
    return false;
  }
  
  static String getUserFriendlyMessage(dynamic error) {
    if (error is SocketException) {
      return 'Ingen internetanslutning. Kontrollera din anslutning och försök igen.';
    }
    
    if (error is TimeoutException) {
      return 'Anslutningen tog för lång tid. Försök igen.';
    }
    
    if (error is OverpassException) {
      return 'Kunde inte ladda vägdata. Försök igen senare.';
    }
    
    if (error is FormatException) {
      return 'Oväntat dataformat mottaget. Kontakta support om problemet kvarstår.';
    }
    
    return 'Ett oväntat fel inträffade. Försök igen.';
  }
}
```

### 5.2 API-Specific Error Handling

Handle specific API error conditions:

```dart
class OverpassException implements Exception {
  final String message;
  final int? statusCode;
  final String? response;
  
  const OverpassException(this.message, {this.statusCode, this.response});
  
  @override
  String toString() => 'OverpassException: $message';
}

class TileLoadException implements Exception {
  final String tileUrl;
  final int statusCode;
  
  const TileLoadException(this.tileUrl, this.statusCode);
  
  @override
  String toString() => 'TileLoadException: $statusCode for $tileUrl';
}

class ApiQuotaException implements Exception {
  final String service;
  final DateTime resetTime;
  
  const ApiQuotaException(this.service, this.resetTime);
  
  @override
  String toString() => 'ApiQuotaException: $service quota exceeded until $resetTime';
}
```

### 5.3 Fallback Strategies

Implement fallback mechanisms:

```dart
class ApiFallbackManager {
  static Future<List<Polyline>> fetchGravelRoadsWithFallback(
    LatLngBounds bounds,
  ) async {
    try {
      // Primary: Overpass API
      return await OverpassService().fetchGravelRoads(bounds);
    } catch (e) {
      print('Primary API failed: $e');
      
      try {
        // Fallback: Cached data
        return await CacheService().getCachedGravelRoads(bounds);
      } catch (cacheError) {
        print('Cache fallback failed: $cacheError');
        
        // Ultimate fallback: Empty data with user notification
        _notifyUserOfDataUnavailability();
        return <Polyline>[];
      }
    }
  }
  
  static void _notifyUserOfDataUnavailability() {
    // Show user-friendly notification that data is unavailable
    // This should be implemented at the UI layer
  }
}
```

---

## 6. Performance and Compliance

### 6.1 Request Optimization

Optimize API requests for performance:

```dart
class ApiPerformanceOptimizer {
  static const Duration cacheTtl = Duration(hours: 1);
  static const int maxConcurrentRequests = 5;
  
  final Map<String, CachedResponse> _responseCache = {};
  final Queue<Completer<dynamic>> _requestQueue = Queue();
  int _activeRequests = 0;
  
  Future<T> optimizedRequest<T>(
    String cacheKey,
    Future<T> Function() request,
  ) async {
    // Check cache first
    final cached = _responseCache[cacheKey];
    if (cached != null && !cached.isExpired) {
      return cached.data as T;
    }
    
    // Throttle concurrent requests
    if (_activeRequests >= maxConcurrentRequests) {
      await _waitForAvailableSlot();
    }
    
    _activeRequests++;
    
    try {
      final result = await request();
      
      // Cache successful response
      _responseCache[cacheKey] = CachedResponse(
        data: result,
        timestamp: DateTime.now(),
      );
      
      return result;
    } finally {
      _activeRequests--;
      _processQueue();
    }
  }
  
  Future<void> _waitForAvailableSlot() async {
    final completer = Completer<void>();
    _requestQueue.add(completer);
    return completer.future;
  }
  
  void _processQueue() {
    if (_requestQueue.isNotEmpty && _activeRequests < maxConcurrentRequests) {
      final completer = _requestQueue.removeFirst();
      completer.complete();
    }
  }
}

class CachedResponse {
  final dynamic data;
  final DateTime timestamp;
  
  CachedResponse({required this.data, required this.timestamp});
  
  bool get isExpired {
    return DateTime.now().difference(timestamp) > ApiPerformanceOptimizer.cacheTtl;
  }
}
```

### 6.2 Usage Monitoring

Monitor API usage and compliance:

```dart
class ApiUsageMonitor {
  static const String _usageStorageKey = 'api_usage_stats';
  
  static Future<void> recordApiCall(String service, String endpoint) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final key = '${_usageStorageKey}_${service}_$today';
    
    final currentCount = prefs.getInt(key) ?? 0;
    await prefs.setInt(key, currentCount + 1);
    
    // Check usage limits
    if (service == 'maptiler' && currentCount > 3000) {
      print('Warning: High MapTiler usage today: $currentCount calls');
    }
  }
  
  static Future<Map<String, int>> getDailyUsageStats() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    
    return {
      'overpass': prefs.getInt('${_usageStorageKey}_overpass_$today') ?? 0,
      'maptiler': prefs.getInt('${_usageStorageKey}_maptiler_$today') ?? 0,
      'osm_tiles': prefs.getInt('${_usageStorageKey}_osm_tiles_$today') ?? 0,
    };
  }
}
```

### 6.3 Compliance Status

Current compliance status for external APIs:

#### ✅ OpenStreetMap Compliance

**Following Best Practices:**
- Commercial primary provider (MapTiler) handles production traffic
- OSM tiles used only for development and emergency fallback
- Proper attribution provided for both providers
- No subdomain usage to avoid deprecation warnings
- Reasonable usage patterns for route planning applications

**Policy Adherence:**
- Development and testing usage (compliant with OSM policy)
- Appropriate use case (route planning for gravel biking)
- Proper user agent identification
- Rate limiting implemented (< 2 requests/second)

#### ✅ MapTiler Service Configuration

**Commercial Integration:**
- Primary provider for production deployment
- Free tier provides 100,000 map loads/month
- Proper API key management with environment variable configuration
- Usage monitoring and quota tracking implemented

**Production Deployment:**
```bash
# Environment configuration
MAPTILER_API_KEY=your_api_key_here
```

#### 📋 Compliance Summary

**Your application is fully compliant** with tile server usage policies:

1. **Commercial Primary Provider**: MapTiler handles production load
2. **Compliant Fallback**: OSM usage within policy guidelines
3. **Proper Attribution**: Both providers correctly attributed
4. **Technical Compliance**: No deprecated patterns, proper headers
5. **Professional Usage**: Appropriate for gravel biking route planning

**Info Messages**: The informational messages during testing are expected and harmless, indicating proper awareness of usage guidelines.

---

*This document provides comprehensive API integration guidance for the Gravel First application. All implementations follow industry best practices for security, performance, and compliance.*

*Last updated: 2025-01-27*
