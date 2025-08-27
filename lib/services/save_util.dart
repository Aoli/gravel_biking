// Cross-platform byte saving with conditional imports
// On web: use FileSaver
// On mobile/desktop: write to app documents directory

import 'save_util_io.dart' if (dart.library.html) 'save_util_web.dart' as impl;
import 'package:flutter/foundation.dart';

Future<String> saveBytes(
  String suggestedName,
  Uint8List bytes, {
  required String ext,
  required String mimeType,
}) async {
  // Additional web check for Android WebView compatibility
  if (kIsWeb) {
    // Ensure we use web implementation
    try {
      return await impl.saveBytes(
        suggestedName,
        bytes,
        ext: ext,
        mimeType: mimeType,
      );
    } catch (e) {
      // If web implementation fails, rethrow with context
      throw Exception('Web file save failed: $e');
    }
  } else {
    // Use mobile implementation
    return impl.saveBytes(suggestedName, bytes, ext: ext, mimeType: mimeType);
  }
}
