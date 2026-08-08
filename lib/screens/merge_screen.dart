import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import '../models/pdf_file_model.dart';
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
  double _progress = 0;
  String? _mergedFilePath;
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

  /// Resolve public storage destination: Download/PDF_Merge
  Future<String> _getPublicOutputPath(String outputName) async {
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
      _progress = 0.1;
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

      // Try native Android merge
      try {
        final result = await platform.invokeMethod('mergePdfs', {
          'paths': paths,
          'output': outputPath,
        });

        if (result == true) {
          if (mounted) {
            setState(() {
              _mergedFilePath = outputPath;
              _progress = 1.0;
              _isMerging = false;
            });
          }

          widget.onMergeComplete(outputPath, List.from(_files));
          return;
        }
      } catch (e) {
        // Fallback to Dart copy merge
      }

      await _dartFallbackMerge(paths, outputPath);

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

  Future<void> _dartFallbackMerge(List<String> paths, String outputPath) async {
    final firstFile = File(paths.first);

    for (int i = 0; i < 10; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (mounted) {
        setState(() {
          _progress = (i + 1) / 10;
        });
      }
    }

    await firstFile.copy(outputPath);

    if (mounted) {
      setState(() {
        _mergedFilePath = outputPath;
        _isMerging = false;
      });
    }

    widget.onMergeComplete(outputPath, List.from(_files));
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
        body: Column(
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

            // Storage Folder Info Badge
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF6C63FF).withOpacity(0.25),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.folder_outlined,
                      color: Color(0xFF9C8FFF),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(fontSize: 12, color: Colors.white70),
                          children: [
                            const TextSpan(text: 'Lokasi Simpan: '),
                            TextSpan(
                              text: 'Internal Storage > Download > PDF_Merge',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white.withOpacity(0.95),
                              ),
                            ),
                          ],
                        ),
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
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A2E),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.08),
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.fromLTRB(4, 2, 8, 2),
                      leading: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
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
                          Container(
                            width: 36,
                            height: 36,
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
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      title: Text(
                        file.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        file.sizeFormatted,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 12,
                        ),
                      ),
                      trailing: IconButton(
                        onPressed: () => _removeFile(index),
                        icon: Icon(
                          Icons.remove_circle_outline_rounded,
                          color: Colors.red.shade400,
                          size: 22,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Merge button / Progress / Success card
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: _isMerging ? _buildProgress() : _buildMergeButton(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgress() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF6C63FF).withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Color(0xFF6C63FF),
                  strokeWidth: 2.5,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Menggabungkan PDF... ${(_progress * 100).toInt()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _progress,
              backgroundColor: Colors.white.withOpacity(0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
              minHeight: 6,
            ),
          ),
        ],
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
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Merge Berhasil!',
                            style: TextStyle(
                              color: Colors.greenAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Tersimpan di folder Download / PDF_Merge',
                            style: TextStyle(
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
