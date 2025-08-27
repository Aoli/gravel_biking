import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

Future<String> saveBytes(
  String suggestedName,
  Uint8List bytes, {
  required String ext,
  required String mimeType,
}) async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$suggestedName');
    await file.writeAsBytes(bytes);
    return file.path;
  } catch (e) {
    // If path_provider fails (e.g., in Android WebView), throw a descriptive error
    if (kIsWeb) {
      throw Exception(
        'File save failed on web platform - this should not happen. '
        'Web platform should use FileSaver implementation. Error: $e',
      );
    } else {
      throw Exception(
        'Unable to save file to device storage. This may be due to missing '
        'storage permissions or unsupported platform. Error: $e',
      );
    }
  }
}
