import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfrx/pdfrx.dart' as pdfrx;

class PdfTrimService {
  static const _platform = MethodChannel('com.example.pdf_merge/merge');

  /// Trim PDF pages cross-platform (Android Native or Dart pdfrx+pdf for Windows/Web)
  static Future<bool> trimPdf({
    required String inputPath,
    required int startPage,
    required int endPage,
    required String outputPath,
    Function(int processed, int total, int percent)? onProgress,
  }) async {
    // 1. On Android, try fast native MethodChannel first
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final success = await _platform.invokeMethod<bool>('trimPdf', {
          'path': inputPath,
          'startPage': startPage,
          'endPage': endPage,
          'output': outputPath,
        });
        if (success == true) return true;
      } catch (e) {
        debugPrint('Native Android trim channel failed, falling back to Dart: $e');
      }
    }

    // 2. Cross-platform Dart implementation (Windows, Web, Linux, macOS, Android fallback)
    try {
      final doc = await pdfrx.PdfDocumentFactory.instance.openFile(inputPath);
      final totalPages = doc.pages.length;
      if (totalPages == 0) return false;

      final startIdx = (startPage - 1).clamp(0, totalPages - 1);
      final endIdx = (endPage - 1).clamp(startIdx, totalPages - 1);
      final count = (endIdx - startIdx) + 1;

      final pdfDoc = pw.Document();
      int processed = 0;

      if (onProgress != null) onProgress(0, count, 0);

      for (int i = startIdx; i <= endIdx; i++) {
        final page = doc.pages[i];
        final pageImage = await page.render(
          fullWidth: page.width * 1.5,
          fullHeight: page.height * 1.5,
        );

        if (pageImage != null) {
          // PDFium outputs pixels in BGRA order. Using ChannelOrder.bgra fixes color inversion (red/blue swap).
          final image = img.Image.fromBytes(
            width: pageImage.width,
            height: pageImage.height,
            bytes: pageImage.pixels.buffer,
            order: img.ChannelOrder.bgra,
          );
          final pngBytes = Uint8List.fromList(img.encodePng(image));
          final memoryImage = pw.MemoryImage(pngBytes);

          pdfDoc.addPage(
            pw.Page(
              pageFormat: PdfPageFormat(page.width, page.height),
              margin: pw.EdgeInsets.zero,
              build: (pw.Context context) {
                return pw.FullPage(
                  ignoreMargins: true,
                  child: pw.Image(memoryImage, fit: pw.BoxFit.fill),
                );
              },
            ),
          );
        }

        processed++;
        final percent = ((processed / count) * 100).toInt();
        if (onProgress != null) onProgress(processed, count, percent);
      }

      final bytes = await pdfDoc.save();
      final outputFile = File(outputPath);
      await outputFile.parent.create(recursive: true);
      await outputFile.writeAsBytes(bytes);
      return true;
    } catch (e) {
      debugPrint('Dart PDF trim error: $e');
      return false;
    }
  }
}
