import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdfrx/pdfrx.dart';
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
  final PdfViewerController _previewController = PdfViewerController();
  int _previewPage = 1;
  int _pdfTotalPages = 0;

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
      isScrollControlled: true,
      builder: (context) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFF151B26),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(
                  top: BorderSide(color: Color(0xFF222B3D)),
                  left: BorderSide(color: Color(0xFF222B3D)),
                  right: BorderSide(color: Color(0xFF222B3D)),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669).withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Color(0xFF34D399),
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'File Berhasil Dipotong',
                    style: TextStyle(
                      color: Color(0xFFF1F5F9),
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tersimpan di:\n${fileModel.path}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
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
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: const BorderSide(color: Color(0xFF222B3D)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.share_rounded, color: Color(0xFFF1F5F9), size: 18),
                          label: const Text('Bagikan', style: TextStyle(color: Color(0xFFF1F5F9), fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4F46E5),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                          label: const Text('Selesai', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
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
      backgroundColor: const Color(0xFF151B26),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF222B3D)),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2533),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.content_cut_rounded, color: Color(0xFF6366F1), size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Potong Halaman',
              style: TextStyle(color: Color(0xFFF1F5F9), fontSize: 16, fontWeight: FontWeight.w700),
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
                color: const Color(0xFF0F141F),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF222B3D)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFEF4444), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.pdfFile.name,
                          style: const TextStyle(color: Color(0xFFF1F5F9), fontWeight: FontWeight.w600, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          maxPages > 0 ? 'Total $maxPages Halaman' : widget.pdfFile.sizeFormatted,
                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Live PDF Page Preview Area
            Container(
              height: 200,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: const Color(0xFF0F141F),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF222B3D)),
              ),
              child: Stack(
                children: [
                  PdfViewer.file(
                    widget.pdfFile.path,
                    controller: _previewController,
                    params: PdfViewerParams(
                      onPageChanged: (pageNumber) {
                        if (pageNumber != null && mounted) {
                          setState(() {
                            _previewPage = pageNumber;
                          });
                        }
                      },
                      onViewerReady: (document, controller) {
                        if (mounted) {
                          setState(() {
                            _pdfTotalPages = document.pages.length;
                          });
                        }
                      },
                    ),
                  ),
                  // Page number indicator badge & quick set action overlay
                  Positioned(
                    top: 8,
                    left: 8,
                    right: 8,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF151B26).withOpacity(0.9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF222B3D)),
                          ),
                          child: Text(
                            'Hal: $_previewPage / ${maxPages > 0 ? maxPages : _pdfTotalPages}',
                            style: const TextStyle(color: Color(0xFFF1F5F9), fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Row(
                          children: [
                            InkWell(
                              onTap: () {
                                _startPageController.text = '$_previewPage';
                                setState(() {});
                              },
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4F46E5),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Set Mulai',
                                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: () {
                                _endPageController.text = '$_previewPage';
                                setState(() {});
                              },
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E2533),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFF222B3D)),
                                ),
                                child: const Text(
                                  'Set Akhir',
                                  style: TextStyle(color: Color(0xFFF1F5F9), fontSize: 10, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Page range inputs
            const Text(
              'Rentang Halaman:',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Mulai', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _startPageController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Color(0xFFF1F5F9), fontWeight: FontWeight.w600),
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: '1',
                          hintStyle: const TextStyle(color: Color(0xFF64748B)),
                          filled: true,
                          fillColor: const Color(0xFF0F141F),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF222B3D)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF222B3D)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF4F46E5)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text('s/d', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Sampai', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _endPageController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Color(0xFFF1F5F9), fontWeight: FontWeight.w600),
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: maxPages > 0 ? '$maxPages' : '100',
                          hintStyle: const TextStyle(color: Color(0xFF64748B)),
                          filled: true,
                          fillColor: const Color(0xFF0F141F),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF222B3D)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF222B3D)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF4F46E5)),
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
                color: const Color(0xFF1E2533),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Color(0xFF6366F1), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _pageCountToExtract > 0
                          ? 'Mengekstrak $_pageCountToExtract Halaman (Hal $_startPage - $_endPage)'
                          : 'Rentang halaman tidak valid',
                      style: TextStyle(
                        color: _pageCountToExtract > 0 ? const Color(0xFFF1F5F9) : const Color(0xFFEF4444),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Output filename input
            const Text('Nama File Hasil:', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
            const SizedBox(height: 4),
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Color(0xFFF1F5F9), fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Nama_File_Potongan.pdf',
                hintStyle: const TextStyle(color: Color(0xFF64748B)),
                filled: true,
                fillColor: const Color(0xFF0F141F),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF222B3D)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF222B3D)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF4F46E5)),
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
                          width: 50,
                          height: 50,
                          child: CircularProgressIndicator(
                            value: _currentProgress / 100,
                            strokeWidth: 4,
                            backgroundColor: const Color(0xFF222B3D),
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
                          ),
                        ),
                        Text(
                          '$_currentProgress%',
                          style: const TextStyle(
                            color: Color(0xFFF1F5F9),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Memotong Halaman $_processedPages / $_totalExtractPages...',
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
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
            child: const Text('Batal', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton.icon(
            onPressed: _pageCountToExtract > 0 ? _startTrimming : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              disabledBackgroundColor: const Color(0xFF1E2533),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            icon: const Icon(Icons.content_cut_rounded, color: Colors.white, size: 16),
            label: const Text('Potong', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ],
    );
  }
}
