import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// A PDF chosen with the system document picker. Bytes are read only after
/// the name and size have been checked, so a huge file is never loaded.
class PickedPdf {
  const PickedPdf({required this.name, required this.sizeBytes, required this.readBytes});

  final String name;
  final int sizeBytes;
  final Future<Uint8List> Function() readBytes;
}

typedef PdfPicker = Future<PickedPdf?> Function();

/// Opens the system document picker filtered to PDFs (no extra Android or
/// iOS permissions needed). Overridden in tests.
final pdfPickerProvider = Provider<PdfPicker>((ref) => _pickWithSystemPicker);

Future<PickedPdf?> _pickWithSystemPicker() async {
  final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: const ['pdf']);
  if (file == null) return null;
  final size = await file.length();
  return PickedPdf(
    name: file.name,
    // Unknown length: read once and use the real size.
    sizeBytes: size ?? (await file.xFile.readAsBytes()).lengthInBytes,
    readBytes: file.xFile.readAsBytes,
  );
}

typedef PdfOpener = Future<bool> Function(Uri uri);

/// Opens a (signed) PDF link in the phone's PDF viewer or browser.
final pdfOpenerProvider = Provider<PdfOpener>(
  (ref) => (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);
