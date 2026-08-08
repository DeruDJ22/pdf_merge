import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/pdf_file_model.dart';
import '../services/intent_handler.dart';
import '../widgets/pdf_card.dart';
import '../widgets/gradient_background.dart';
import '../widgets/empty_state.dart';
import 'pdf_viewer_screen.dart';
import 'merge_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final List<PdfFileModel> _openedFiles = [];
  final List<PdfFileModel> _mergeQueue = [];
  bool _isMergeMode = false;
  late AnimationController _fabAnimController;
  late Animation<double> _fabScaleAnimation;

  // Platform channel for receiving intents
  static const platform = MethodChannel('com.example.pdf_merge/intent');

  @override
  void initState() {
    super.initState();

    _fabAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fabScaleAnimation = CurvedAnimation(
      parent: _fabAnimController,
      curve: Curves.elasticOut,
    );
    _fabAnimController.forward();

    // Listen for incoming intents
    _setupIntentListener();
    _getInitialIntent();
  }

  void _setupIntentListener() {
    platform.setMethodCallHandler((call) async {
      if (call.method == 'onNewIntent') {
        final paths = (call.arguments as List?)?.cast<String>() ?? [];
        for (final path in paths) {
          await _addPdfFile(path);
        }
      }
    });
  }

  Future<void> _getInitialIntent() async {
    try {
      final result = await platform.invokeMethod('getInitialIntent');
      if (result != null && result is List) {
        for (final path in result.cast<String>()) {
          await _addPdfFile(path);
        }
      }
    } catch (e) {
      // No initial intent or channel not set up yet
    }
  }

  Future<void> _addPdfFile(String path) async {
    // Check if file already opened
    if (_openedFiles.any((f) => f.path == path)) {
      // Navigate to existing file
      final existing = _openedFiles.firstWhere((f) => f.path == path);
      _openViewer(existing);
      return;
    }

    final model = await PdfFileModel.fromPath(path);
    setState(() {
      _openedFiles.add(model);
    });

    // Auto open the viewer
    if (mounted) {
      _openViewer(model);
    }
  }

  void _openViewer(PdfFileModel model) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => PdfViewerScreen(pdfFile: model),
        transitionsBuilder: (_, animation, __, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  Future<void> _pickPdfFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        for (final file in result.files) {
          if (file.path != null) {
            final model = await PdfFileModel.fromPath(file.path!);
            if (!_openedFiles.any((f) => f.path == model.path)) {
              setState(() {
                _openedFiles.add(model);
              });
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuka file: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  void _toggleMergeMode() {
    setState(() {
      _isMergeMode = !_isMergeMode;
      _mergeQueue.clear();
    });

    // Re-trigger fab animation
    _fabAnimController.reset();
    _fabAnimController.forward();
  }

  void _toggleFileInMergeQueue(PdfFileModel file) {
    setState(() {
      if (_mergeQueue.contains(file)) {
        _mergeQueue.remove(file);
      } else {
        _mergeQueue.add(file);
      }
    });
  }

  void _removeFile(PdfFileModel file) {
    setState(() {
      _openedFiles.remove(file);
      _mergeQueue.remove(file);
    });
  }

  void _reorderFiles(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final item = _openedFiles.removeAt(oldIndex);
      _openedFiles.insert(newIndex, item);
    });
  }

  void _openMergeScreen() {
    if (_mergeQueue.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Pilih minimal 2 file PDF untuk digabungkan'),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => MergeScreen(
          filesToMerge: List.from(_mergeQueue),
          onMergeComplete: (mergedPath) async {
            final model = await PdfFileModel.fromPath(mergedPath);
            setState(() {
              _openedFiles.add(model);
              _isMergeMode = false;
              _mergeQueue.clear();
            });
          },
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.1),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  void dispose() {
    _fabAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: _buildAppBar(),
        body: _openedFiles.isEmpty ? const EmptyState() : _buildFileList(),
        floatingActionButton: _buildFab(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isMergeMode ? 'Pilih File untuk Merge' : 'PDF Merge',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          if (_isMergeMode)
            Text(
              '${_mergeQueue.length} file dipilih',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withOpacity(0.6),
              ),
            )
          else if (_openedFiles.isNotEmpty)
            Text(
              '${_openedFiles.length} file dibuka',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withOpacity(0.6),
              ),
            ),
        ],
      ),
      actions: [
        if (_isMergeMode) ...[
          if (_mergeQueue.length >= 2)
            _buildActionButton(
              icon: Icons.merge_type_rounded,
              label: 'Merge',
              color: const Color(0xFF6C63FF),
              onTap: _openMergeScreen,
            ),
          const SizedBox(width: 8),
          _buildActionButton(
            icon: Icons.close_rounded,
            label: 'Batal',
            color: Colors.red.shade400,
            onTap: _toggleMergeMode,
          ),
        ] else if (_openedFiles.isNotEmpty) ...[
          _buildActionButton(
            icon: Icons.merge_type_rounded,
            label: 'Merge',
            color: const Color(0xFF6C63FF),
            onTap: _toggleMergeMode,
          ),
        ],
        const SizedBox(width: 12),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withOpacity(0.15),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileList() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: ReorderableListView.builder(
        key: ValueKey(_isMergeMode),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: _openedFiles.length,
        onReorder: _reorderFiles,
        proxyDecorator: (child, index, animation) {
          return AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              final scale = Tween<double>(begin: 1.0, end: 1.05)
                  .animate(CurvedAnimation(parent: animation, curve: Curves.easeOut));
              return Transform.scale(
                scale: scale.value,
                child: Material(
                  color: Colors.transparent,
                  elevation: 8,
                  borderRadius: BorderRadius.circular(16),
                  child: child,
                ),
              );
            },
            child: child,
          );
        },
        itemBuilder: (context, index) {
          final file = _openedFiles[index];
          final isSelected = _mergeQueue.contains(file);
          final mergeIndex = _mergeQueue.indexOf(file);

          return PdfCard(
            key: ValueKey(file.id),
            pdfFile: file,
            isMergeMode: _isMergeMode,
            isSelected: isSelected,
            mergeOrder: mergeIndex >= 0 ? mergeIndex + 1 : null,
            onTap: () {
              if (_isMergeMode) {
                _toggleFileInMergeQueue(file);
              } else {
                _openViewer(file);
              }
            },
            onDismissed: () => _removeFile(file),
          );
        },
      ),
    );
  }

  Widget _buildFab() {
    return ScaleTransition(
      scale: _fabScaleAnimation,
      child: FloatingActionButton.extended(
        onPressed: _pickPdfFiles,
        icon: const Icon(Icons.add_rounded, size: 24),
        label: const Text(
          'Tambah PDF',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF6C63FF),
        foregroundColor: Colors.white,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}


