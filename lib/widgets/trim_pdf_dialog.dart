import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/pdf_file_model.dart';
import '../services/history_service.dart';
import '../services/pdf_trim_service.dart';

class TrimPdfDialog extends StatefulWidget {
  final PdfFileModel pdfFile;
  final int? initialStartPage;
  final int? initialEndPage;
  final Function(String trimmedPath)? onTrimComplete;

  const TrimPdfDialog({
    super.key,
    required this.pdfFile,
    this.initialStartPage,
    this.initialEndPage,
    this.onTrimComplete,
  });

  @override
  State<TrimPdfDialog> createState() => _TrimPdfDialogState();
}

class _TrimPdfDialogState extends State<TrimPdfDialog> {
  late TextEditingController _startPageController;
  late TextEditingController _endPageController;
  late TextEditingController _nameController;

  bool _isProcessing = false;
  int _currentProgress = 0;
  int _processedPages = 0;
  int _totalExtractPages = 0;

  static const _platform = MethodChannel('com.example.pdf_merge/merge');

  @override
  void initState() {
    super.initState();
    final start = widget.initialStartPage ?? 1;
    final end = widget.initialEndPage ?? (widget.pdfFile.totalPages > 0 ? widget.pdfFile.totalPages : 1);

    _startPageController = TextEditingController(text: start.toString());
    _endPageController = TextEditingController(text: end.toString());
    _nameController = TextEditingController(text: '${widget.pdfFile.name}_Potongan');

    _setupProgressListener();
  }

  void _setupProgressListener() {
    if (!kIsWeb && Platform.isAndroid) {
      _platform.setMethodCallHandler((call) async {
        if (call.method == 'onProgress') {
          final Map<dynamic, dynamic> args = call.arguments;
          if (mounted) {
            setState(() {
              _processedPages = args['processed'] ?? 0;
              _totalExtractPages = args['total'] ?? 0;
              _currentProgress = args['percent'] ?? 0;
            });
          }
        }
      });
    }
  }

  int get _startPage => int.tryParse(_startPageController.text.trim()) ?? 1;
  int get _endPage => int.tryParse(_endPageController.text.trim()) ?? 1;
  int get _pageCountToExtract {
    final s = _startPage;
    final e = _endPage;
    if (s > e || s < 1) return 0;
    return (e - s) + 1;
  }

  Future<String> _getOutputDirPath() async {
    if (!kIsWeb && Platform.isWindows) {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory('${docs.path}\\PDF_Merge');
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir.path;
    }
    final dir = Directory('/storage/emulated/0/Download/PDF_Merge');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir.path;
  }

  Future<void> _startTrimming() async {
    final start = _startPage;
    final end = _endPage;
    final maxPages = widget.pdfFile.totalPages;

    if (start < 1 || (maxPages > 0 && start > maxPages)) {
      _showError('Halaman mulai tidak valid (1 - $maxPages)');
      return;
    }

    if (end < start || (maxPages > 0 && end > maxPages)) {
      _showError('Halaman akhir harus >= halaman mulai (maks $maxPages)');
      return;
    }

    var outputName = _nameController.text.trim();
    if (outputName.isEmpty) {
      outputName = '${widget.pdfFile.name}_Halaman_$start-$end';
    }
    if (!outputName.toLowerCase().endsWith('.pdf')) {
      outputName += '.pdf';
    }

    final outputDirPath = await _getOutputDirPath();
    final outputPath = '$outputDirPath/$outputName';

    setState(() {
      _isProcessing = true;
      _currentProgress = 0;
    });

    try {
      final success = await PdfTrimService.trimPdf(
        inputPath: widget.pdfFile.path,
        startPage: start,
        endPage: end,
        outputPath: outputPath,
        onProgress: (processed, total, percent) {
          if (mounted) {
            setState(() {
              _processedPages = processed;
              _totalExtractPages = total;
              _currentProgress = percent;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isProcessing = false;
        });

        if (success) {
          Navigator.pop(context); // Close dialog

          final trimmedModel = await PdfFileModel.fromPath(outputPath);
          await HistoryService.addOrUpdateFile(trimmedModel);

          if (widget.onTrimComplete != null) {
            widget.onTrimComplete!(outputPath);
          }

          _showSuccessModal(trimmedModel);
        } else {
          _showError('Gagal memotong PDF. Pastikan file tidak terkunci password.');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        _showError('Terjadi kesalahan: $e');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSuccessModal(PdfFileModel fileModel) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A2E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.greenAccent,
                  size: 36,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'File Berhasil Dipotong! 🎉',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Tersimpan di:\n${fileModel.path}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Share.shareXFiles([XFile(fileModel.path)]);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.white.withOpacity(0.2)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.share_rounded, color: Colors.white),
                      label: const Text('Bagikan', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.check_rounded, color: Colors.white),
                      label: const Text('Selesai', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _startPageController.dispose();
    _endPageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxPages = widget.pdfFile.totalPages;

    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.content_cut_rounded, color: Color(0xFF6C63FF), size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Potong / Ekstrak Halaman',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Target file info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.pdfFile.name,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          maxPages > 0 ? 'Total $maxPages Halaman' : widget.pdfFile.sizeFormatted,
                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Page range inputs
            const Text(
              'Rentang Halaman yang Ingin Diambil:',
              style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Dari Hal', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _startPageController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: '1',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                          filled: true,
                          fillColor: const Color(0xFF161626),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF6C63FF)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text('s/d', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sampai Hal', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _endPageController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: maxPages > 0 ? '$maxPages' : '100',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                          filled: true,
                          fillColor: const Color(0xFF161626),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF6C63FF)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Extracted count badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Color(0xFF9C8FFF), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _pageCountToExtract > 0
                          ? 'Akan menyimpan $_pageCountToExtract Halaman (Hal $_startPage - $_endPage)'
                          : 'Rentang halaman tidak valid',
                      style: TextStyle(
                        color: _pageCountToExtract > 0 ? const Color(0xFF9C8FFF) : Colors.redAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Output filename input
            Text('Nama File Hasil Potongan:', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
            const SizedBox(height: 4),
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Nama_File_Potongan.pdf',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                filled: true,
                fillColor: const Color(0xFF161626),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF6C63FF)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),

            if (_isProcessing) ...[
              const SizedBox(height: 20),
              Center(
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 60,
                          height: 60,
                          child: CircularProgressIndicator(
                            value: _currentProgress / 100,
                            strokeWidth: 5,
                            backgroundColor: Colors.white10,
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
                          ),
                        ),
                        Text(
                          '$_currentProgress%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Memotong Halaman $_processedPages / $_totalExtractPages...',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (!_isProcessing) ...[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton.icon(
            onPressed: _pageCountToExtract > 0 ? _startTrimming : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.content_cut_rounded, color: Colors.white, size: 18),
            label: const Text('Potong Sekarang', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ],
    );
  }
}
