import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfrx/pdfrx.dart' as pdfrx;

class PdfMergeService {
  static const _platform = MethodChannel('com.example.pdf_merge/merge');

  /// Merge multiple PDF files cross-platform (Android Native or Dart pdfrx+pdf for Windows/Web)
  static Future<bool> mergePdfs({
    required List<String> inputPaths,
    required String outputPath,
    Function(int processed, int total, int percent)? onProgress,
  }) async {
    if (inputPaths.length < 2) return false;

    // 1. On Android, try fast native MethodChannel first
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final success = await _platform.invokeMethod<bool>('mergePdfs', {
          'paths': inputPaths,
          'output': outputPath,
        });
        if (success == true) return true;
      } catch (e) {
        debugPrint('Native Android merge channel failed, falling back to Dart: $e');
      }
    }

    // 2. Cross-platform Dart implementation (Windows, Web, Linux, macOS, Android fallback)
    try {
      final docList = <pdfrx.PdfDocument>[];
      int totalPages = 0;

      for (final path in inputPaths) {
        final doc = await pdfrx.PdfDocumentFactory.instance.openFile(path);
        docList.add(doc);
        totalPages += doc.pages.length;
      }

      if (totalPages == 0) return false;

      final pdfDoc = pw.Document();
      int processedPages = 0;

      if (onProgress != null) onProgress(0, totalPages, 0);

      for (final doc in docList) {
        for (final page in doc.pages) {
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

          processedPages++;
          final percent = ((processedPages / totalPages) * 100).toInt();
          if (onProgress != null) onProgress(processedPages, totalPages, percent);
        }
      }

      final bytes = await pdfDoc.save();
      final outputFile = File(outputPath);
      await outputFile.parent.create(recursive: true);
      await outputFile.writeAsBytes(bytes);

      return true;
    } catch (e) {
      debugPrint('Dart PDF merge error: $e');
      return false;
    }
  }
}
