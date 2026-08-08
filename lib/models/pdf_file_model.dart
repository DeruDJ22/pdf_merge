import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

/// Model representing a PDF file in the app
class PdfFileModel {
  final String id;
  final String path;
  final String name;
  final int sizeBytes;
  final DateTime? addedAt;
  int lastReadPage;
  int totalPages;

  PdfFileModel({
    required this.id,
    required this.path,
    String? name,
    this.sizeBytes = 0,
    DateTime? addedAt,
    this.lastReadPage = 0,
    this.totalPages = 0,
  })  : name = name ?? p.basenameWithoutExtension(path),
        addedAt = addedAt ?? DateTime.now();

  String get fileName => p.basename(path);

  String get sizeFormatted {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  double get progressPercentage {
    if (totalPages <= 0) return 0.0;
    return ((lastReadPage + 1) / totalPages).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'path': path,
        'name': name,
        'sizeBytes': sizeBytes,
        'addedAt': addedAt?.millisecondsSinceEpoch,
        'lastReadPage': lastReadPage,
        'totalPages': totalPages,
      };

  factory PdfFileModel.fromJson(Map<String, dynamic> json) => PdfFileModel(
        id: json['id'] as String,
        path: json['path'] as String,
        name: json['name'] as String?,
        sizeBytes: json['sizeBytes'] as int? ?? 0,
        addedAt: json['addedAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(json['addedAt'] as int)
            : null,
        lastReadPage: json['lastReadPage'] as int? ?? 0,
        totalPages: json['totalPages'] as int? ?? 0,
      );

  static String encodeList(List<PdfFileModel> files) {
    return jsonEncode(files.map((f) => f.toJson()).toList());
  }

  static List<PdfFileModel> decodeList(String jsonStr) {
    if (jsonStr.isEmpty) return [];
    try {
      final List list = jsonDecode(jsonStr);
      return list.map((item) => PdfFileModel.fromJson(item as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
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
