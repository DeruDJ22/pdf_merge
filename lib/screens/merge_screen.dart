import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import '../models/pdf_file_model.dart';
import '../services/pdf_merge_service.dart';
import '../widgets/gradient_background.dart';
import 'package:flutter/services.dart';

class MergeScreen extends StatefulWidget {
  final List<PdfFileModel> filesToMerge;
  final Function(String mergedPath, List<PdfFileModel> sourceFiles) onMergeComplete;

  const MergeScreen({
    super.key,
    required this.filesToMerge,
    required this.onMergeComplete,
  });

  @override
  State<MergeScreen> createState() => _MergeScreenState();
}

class _MergeScreenState extends State<MergeScreen>
    with SingleTickerProviderStateMixin {
  late List<PdfFileModel> _files;
  late TextEditingController _nameController;
  bool _isMerging = false;
  double _progress = 0.0;
  String _statusText = 'Menyiapkan file PDF...';
  String? _mergedFilePath;
  String? _customOutputDirPath;
  late AnimationController _animController;

  static const platform = MethodChannel('com.example.pdf_merge/merge');

  @override
  void initState() {
    super.initState();
    _files = List.from(widget.filesToMerge);
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(8);
    _nameController = TextEditingController(text: 'Hasil_Merge_$timestamp');

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animController.forward();

    _setupProgressListener();
  }

  void _setupProgressListener() {
    platform.setMethodCallHandler((call) async {
      if (call.method == 'onProgress') {
        final args = call.arguments as Map?;
        if (args != null) {
          final processed = args['processed'] as int? ?? 0;
          final total = args['total'] as int? ?? 1;
          final percent = args['percent'] as int? ?? 0;
          if (mounted) {
            setState(() {
              _progress = (percent / 100.0).clamp(0.0, 1.0);
              _statusText = 'Menggabungkan halaman $processed dari $total...';
            });
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _reorderFiles(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) newIndex -= 1;
      final item = _files.removeAt(oldIndex);
      _files.insert(newIndex, item);
    });
  }

  void _removeFile(int index) {
    if (_files.length <= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Minimal 2 file untuk merge'),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    setState(() {
      _files.removeAt(index);
    });
  }

  /// Pick custom storage directory
  Future<void> _pickCustomFolder() async {
    try {
      final selectedPath = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Pilih Folder Penyimpanan Hasil Merge',
      );
      if (selectedPath != null && selectedPath.isNotEmpty) {
        setState(() {
          _customOutputDirPath = selectedPath;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memilih folder: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  /// Resolve public storage destination: Download/PDF_Merge or Custom Folder
  Future<String> _getPublicOutputPath(String outputName) async {
    if (_customOutputDirPath != null && _customOutputDirPath!.isNotEmpty) {
      final customDir = Directory(_customOutputDirPath!);
      if (!await customDir.exists()) await customDir.create(recursive: true);
      return p.join(customDir.path, '$outputName.pdf');
    }

    Directory targetDir;
    if (Platform.isAndroid) {
      targetDir = Directory('/storage/emulated/0/Download/PDF_Merge');
      if (!await targetDir.exists()) {
        try {
          await targetDir.create(recursive: true);
        } catch (e) {
          final extDir = await getExternalStorageDirectory();
          targetDir = Directory(p.join(extDir?.path ?? (await getApplicationDocumentsDirectory()).path, 'PDF_Merge'));
          if (!await targetDir.exists()) await targetDir.create(recursive: true);
        }
      }
    } else {
      final docDir = await getApplicationDocumentsDirectory();
      targetDir = Directory(p.join(docDir.path, 'PDF_Merge'));
      if (!await targetDir.exists()) await targetDir.create(recursive: true);
    }

    return p.join(targetDir.path, '$outputName.pdf');
  }

  Future<void> _mergePdfs() async {
    if (_files.length < 2) return;

    setState(() {
      _isMerging = true;
      _progress = 0.0;
      _statusText = 'Membaca ${_files.length} file PDF...';
    });

    try {
      final paths = _files.map((f) => f.path).toList();
      var outputName = _nameController.text.trim();
      if (outputName.isEmpty) {
        outputName = 'Hasil_Merge_${DateTime.now().millisecondsSinceEpoch}';
      }
      if (outputName.endsWith('.pdf')) {
        outputName = outputName.substring(0, outputName.length - 4);
      }

      final outputPath = await _getPublicOutputPath(outputName);

      final success = await PdfMergeService.mergePdfs(
        inputPaths: paths,
        outputPath: outputPath,
        onProgress: (processed, total, percent) {
          if (mounted) {
            setState(() {
              _progress = (percent / 100.0).clamp(0.0, 1.0);
              _statusText = 'Menggabungkan halaman $processed dari $total ($percent%)...';
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isMerging = false;
        });

        if (success) {
          setState(() {
            _mergedFilePath = outputPath;
            _progress = 1.0;
          });

          widget.onMergeComplete(outputPath, List.from(_files));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Gagal menggabungkan PDF. Pastikan file tidak rusak.'),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isMerging = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal merge: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: const Text(
            'Gabungkan PDF',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
        ),
        body: Stack(
          children: [
            Column(
              children: [
                // Output filename input field
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A2E),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF6C63FF).withOpacity(0.4),
                        width: 1.5,
                      ),
                    ),
                    child: TextField(
                      controller: _nameController,
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        labelText: 'Nama File Hasil Merge',
                        labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                        suffixText: '.pdf',
                        suffixStyle: const TextStyle(
                          color: Color(0xFF6C63FF),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        prefixIcon: const Icon(
                          Icons.edit_document,
                          color: Color(0xFF6C63FF),
                        ),
                      ),
                    ),
                  ),
                ),

                // Storage Folder Choice & Info Badge
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C63FF).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF6C63FF).withOpacity(0.25),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6C63FF).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.folder_special_rounded,
                            color: Color(0xFF9C8FFF),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Folder Penyimpanan:',
                                style: TextStyle(fontSize: 11, color: Colors.white54, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _customOutputDirPath ?? 'Download / PDF_Merge (Default)',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: _pickCustomFolder,
                          icon: const Icon(Icons.drive_file_move_rounded, size: 16, color: Color(0xFF9C8FFF)),
                          label: const Text(
                            'Ubah',
                            style: TextStyle(color: Color(0xFF9C8FFF), fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.08),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // File list header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text(
                        '${_files.length} File Dipilih',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Seret untuk ubah urutan',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Reorderable file list
                Expanded(
                  child: ReorderableListView.builder(
                    buildDefaultDragHandles: false,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: _files.length,
                    onReorder: _reorderFiles,
                    proxyDecorator: (child, index, animation) {
                      return Material(
                        color: Colors.transparent,
                        elevation: 8,
                        borderRadius: BorderRadius.circular(14),
                        child: child,
                      );
                    },
                    itemBuilder: (context, index) {
                      final file = _files[index];
                      return Container(
                        key: ValueKey(file.id),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A2E),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.08),
                          ),
                        ),
                        child: Row(
                          children: [
                            // Drag handle
                            ReorderableDragStartListener(
                              index: index,
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Icon(
                                  Icons.drag_handle_rounded,
                                  color: Colors.white.withOpacity(0.4),
                                ),
                              ),
                            ),
                            // Order badge
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: const Color(0xFF6C63FF).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    color: Color(0xFF6C63FF),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // File info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    file.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${file.sizeFormatted} • ${file.totalPages > 0 ? "${file.totalPages} Halaman" : "PDF"}',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.5),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Remove button
                            IconButton(
                              onPressed: () => _removeFile(index),
                              icon: Icon(
                                Icons.remove_circle_outline_rounded,
                                color: Colors.red.shade400,
                                size: 22,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Bottom Action Area
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: _buildMergeButton(),
                  ),
                ),
              ],
            ),

            // Modern Progress Circular Overlay Dialog
            if (_isMerging)
              Positioned.fill(
                child: Container(
                  color: Colors.black87,
                  child: Center(
                    child: Container(
                      width: 280,
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A2E),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: const Color(0xFF6C63FF).withOpacity(0.5),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6C63FF).withOpacity(0.3),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Circular Progress with % inside
                          SizedBox(
                            width: 110,
                            height: 110,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 110,
                                  height: 110,
                                  child: CircularProgressIndicator(
                                    value: _progress,
                                    strokeWidth: 9,
                                    backgroundColor: Colors.white.withOpacity(0.1),
                                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
                                  ),
                                ),
                                Text(
                                  '${(_progress * 100).toInt()}%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Menggabungkan PDF...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _statusText,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMergeButton() {
    if (_mergedFilePath != null) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.12),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.green.withOpacity(0.4),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        color: Colors.greenAccent,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Merge Berhasil!',
                            style: TextStyle(
                              color: Colors.greenAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _customOutputDirPath != null
                                ? 'Tersimpan di folder pilihan kamu'
                                : 'Tersimpan di Download / PDF_Merge',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        Share.shareXFiles(
                          [XFile(_mergedFilePath!)],
                          text: 'Hasil Merge PDF',
                        );
                      },
                      icon: const Icon(Icons.share_rounded, color: Colors.greenAccent),
                      tooltip: 'Bagikan PDF',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _mergedFilePath!,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
              ),
              icon: const Icon(Icons.menu_book_rounded),
              label: const Text(
                'Lihat Hasil Merge',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: _files.length >= 2 ? _mergePdfs : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6C63FF),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF6C63FF).withOpacity(0.3),
          disabledForegroundColor: Colors.white.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
          shadowColor: const Color(0xFF6C63FF).withOpacity(0.4),
        ),
        icon: const Icon(Icons.merge_type_rounded, size: 22),
        label: Text(
          'Gabungkan ${_files.length} File PDF',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
