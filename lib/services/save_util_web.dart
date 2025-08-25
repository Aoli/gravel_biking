import 'dart:typed_data';
import 'package:file_saver/file_saver.dart';

Future<String> saveBytes(
  String suggestedName,
  Uint8List bytes, {
  required String ext,
  required String mimeType,
}) async {
  await FileSaver.instance.saveFile(
    name: suggestedName,
    bytes: bytes,
    ext: ext,
    mimeType: MimeType.other,
  );
  return suggestedName;
}
