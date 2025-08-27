import 'dart:typed_data';
import 'package:file_saver/file_saver.dart';

Future<String> saveBytes(
  String suggestedName,
  Uint8List bytes, {
  required String ext,
  required String mimeType,
}) async {
  // Convert string MIME type to FileSaver MimeType enum
  MimeType fileTypeMime;
  switch (mimeType.toLowerCase()) {
    case 'application/json':
    case 'application/geo+json':
      fileTypeMime = MimeType.json;
      break;
    case 'application/gpx+xml':
    case 'application/xml':
    case 'text/xml':
      fileTypeMime = MimeType.custom;
      break;
    default:
      fileTypeMime = MimeType.other;
  }

  await FileSaver.instance.saveFile(
    name: suggestedName,
    bytes: bytes,
    ext: ext,
    mimeType: fileTypeMime,
  );
  return suggestedName;
}
