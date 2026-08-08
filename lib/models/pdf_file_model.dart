import 'dart:io';
import 'package:path/path.dart' as p;

/// Model representing a PDF file in the app
class PdfFileModel {
  final String id;
  final String path;
  final String name;
  final int sizeBytes;
  final DateTime? addedAt;

  PdfFileModel({
    required this.id,
    required this.path,
    String? name,
    this.sizeBytes = 0,
    DateTime? addedAt,
  })  : name = name ?? p.basenameWithoutExtension(path),
        addedAt = addedAt ?? DateTime.now();

  String get fileName => p.basename(path);

  String get sizeFormatted {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static Future<PdfFileModel> fromPath(String path) async {
    final file = File(path);
    int size = 0;
    try {
      size = await file.length();
    } catch (_) {}

    return PdfFileModel(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      path: path,
      sizeBytes: size,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PdfFileModel && runtimeType == other.runtimeType && path == other.path;

  @override
  int get hashCode => path.hashCode;
}
