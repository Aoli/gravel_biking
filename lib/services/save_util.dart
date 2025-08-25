// Cross-platform byte saving with conditional imports
// On web: use FileSaver
// On mobile/desktop: write to app documents directory

import 'save_util_io.dart' if (dart.library.html) 'save_util_web.dart' as impl;
import 'dart:typed_data';

Future<String> saveBytes(
  String suggestedName,
  Uint8List bytes, {
  required String ext,
  required String mimeType,
}) => impl.saveBytes(suggestedName, bytes, ext: ext, mimeType: mimeType);
