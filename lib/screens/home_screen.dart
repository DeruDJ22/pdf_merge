import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../models/pdf_file_model.dart';
import '../services/history_service.dart';
import '../widgets/pdf_card.dart';
import '../widgets/empty_state.dart';
import 'pdf_viewer_screen.dart';
import 'merge_screen.dart';
import '../widgets/trim_pdf_dialog.dart';
import '../services/update_service.dart';
import '../widgets/update_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  List<PdfFileModel> _openedFiles = [];
  final List<PdfFileModel> _mergeQueue = [];
  bool _isMergeMode = false;
  String _searchQuery = '';
  String _sortOrder = 'recent'; // 'recent', 'name', 'size', 'progress'
  final TextEditingController _searchController = TextEditingController();

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

    // Load saved history from persistent storage
    _loadSavedHistory();

    // Listen for incoming intents
    _setupIntentListener();
    _getInitialIntent();

    // Check for app updates on mobile
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdates(silent: true);
    });
  }

  Future<void> _checkForUpdates({bool silent = true}) async {
    try {
      final updateInfo = await UpdateService.checkUpdate();
      if (updateInfo != null && mounted) {
        await UpdateDialog.show(context, updateInfo);
      } else if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Aplikasi sudah menggunakan versi terbaru'),
            backgroundColor: const Color(0xFF1E2533),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (_) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Gagal memeriksa pembaruan. Periksa koneksi internet.'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _loadSavedHistory() async {
    final history = await HistoryService.loadHistory();
    if (mounted) {
      setState(() {
        _openedFiles = history;
      });
    }
  }

  void _setupIntentListener() {
    platform.setMethodCallHandler((call) async {
      if (call.method == 'onNewIntent') {
        final paths = (call.arguments as List?)?.cast<String>() ?? [];
        await _handleIncomingPdfPaths(paths);
      }
    });
  }

  Future<void> _getInitialIntent() async {
    try {
      final result = await platform.invokeMethod('getInitialIntent');
      if (result != null && result is List) {
        final paths = result.cast<String>();
        await _handleIncomingPdfPaths(paths);
      }
    } catch (e) {
      // No initial intent
    }
  }

  Future<void> _handleIncomingPdfPaths(List<String> paths) async {
    if (paths.isEmpty) return;
    final models = <PdfFileModel>[];
    for (final path in paths) {
      models.add(await PdfFileModel.fromPath(path));
    }
    final updated = await HistoryService.addOrUpdateMultipleFiles(models);
    if (mounted) {
      setState(() {
        _openedFiles = updated;
      });
      if (models.length == 1) {
        _showOptionModal(models.first);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${models.length} file PDF berhasil diterima dan ditambahkan'),
            backgroundColor: const Color(0xFF1E2533),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  /// Filter files based on search query
  List<PdfFileModel> get _filteredFiles {
    if (_searchQuery.trim().isEmpty) return List.from(_openedFiles);
    return _openedFiles
        .where((f) => f.name.toLowerCase().contains(_searchQuery.toLowerCase().trim()))
        .toList();
  }

  /// Sort and filter files
  List<PdfFileModel> get _sortedAndFilteredFiles {
    final list = _filteredFiles;
    if (_sortOrder == 'name') {
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } else if (_sortOrder == 'size') {
      list.sort((a, b) => b.sizeBytes.compareTo(a.sizeBytes));
    } else if (_sortOrder == 'progress') {
      list.sort((a, b) => b.progressPercentage.compareTo(a.progressPercentage));
    }
    return list;
  }

  /// Show modal sheet with choices for a file
  void _showOptionModal(PdfFileModel file) {
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
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF151B26),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF222B3D)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E2533),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.picture_as_pdf_rounded,
                          color: Color(0xFFEF4444),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              file.name,
                              style: const TextStyle(
                                color: Color(0xFFF1F5F9),
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Pilih tindakan untuk dokumen ini:',
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  _buildModalTile(
                    title: 'Baca Dokumen',
                    subtitle: 'Buka langsung dengan penampil PDF vertikal halus & mode malam',
                    icon: Icons.menu_book_rounded,
                    accentColor: const Color(0xFF4F46E5),
                    onTap: () {
                      Navigator.pop(context);
                      _openViewer(file);
                    },
                  ),
                  const SizedBox(height: 8),

                  _buildModalTile(
                    title: 'Tambahkan ke Antrean Merge',
                    subtitle: 'Gabungkan file ini dengan dokumen PDF lainnya',
                    icon: Icons.call_merge_rounded,
                    accentColor: const Color(0xFF059669),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _isMergeMode = true;
                        if (!_mergeQueue.contains(file)) {
                          _mergeQueue.add(file);
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 8),

                  _buildModalTile(
                    title: 'Potong / Ekstrak Halaman',
                    subtitle: 'Ambil rentang halaman tertentu dan simpan terpisah',
                    icon: Icons.content_cut_rounded,
                    accentColor: const Color(0xFFD97706),
                    onTap: () {
                      Navigator.pop(context);
                      showDialog(
                        context: context,
                        builder: (context) => TrimPdfDialog(
                          pdfFile: file,
                          onTrimComplete: (trimmedPath) => _loadSavedHistory(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildModalTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1B2230),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF263246)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: accentColor, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFFF1F5F9),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF64748B), size: 18),
            ],
          ),
        ),
      ),
    );
  }

  void _openViewer(PdfFileModel model) async {
    await HistoryService.addOrUpdateFile(model);
    if (mounted) {
      await Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => PdfViewerScreen(
            pdfFile: model,
            allOpenedFiles: _openedFiles,
          ),
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
      _loadSavedHistory();
    }
  }

  Future<void> _pickAndReadPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final pickedModels = <PdfFileModel>[];
        for (final file in result.files) {
          if (file.path != null) {
            final model = await PdfFileModel.fromPath(file.path!);
            pickedModels.add(model);
          }
        }

        if (pickedModels.isEmpty) return;

        final updated = await HistoryService.addOrUpdateMultipleFiles(pickedModels);
        if (mounted) {
          setState(() {
            _openedFiles = updated;
          });

          if (pickedModels.length == 1) {
            _openViewer(pickedModels.first);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${pickedModels.length} file PDF berhasil ditambahkan'),
                backgroundColor: const Color(0xFF1E2533),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
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

  Future<void> _pickAndMergePdfs() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final pickedModels = <PdfFileModel>[];
        for (final file in result.files) {
          if (file.path != null) {
            final model = await PdfFileModel.fromPath(file.path!);
            pickedModels.add(model);
          }
        }

        if (pickedModels.isNotEmpty) {
          final updated = await HistoryService.addOrUpdateMultipleFiles(pickedModels);
          if (mounted) {
            setState(() {
              _openedFiles = updated;
            });

            if (pickedModels.length >= 2) {
              setState(() {
                _isMergeMode = true;
                _mergeQueue.clear();
                _mergeQueue.addAll(pickedModels);
              });
              _openMergeScreen();
            } else if (pickedModels.length == 1) {
              setState(() {
                _isMergeMode = true;
                _mergeQueue.clear();
                _mergeQueue.addAll(pickedModels);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('File ditambahkan. Pilih minimal 1 file lagi untuk digabungkan.'),
                  backgroundColor: const Color(0xFF1E2533),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memilih file: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _pickAndTrimPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty && result.files.first.path != null) {
        final path = result.files.first.path!;
        final model = await PdfFileModel.fromPath(path);
        await HistoryService.addOrUpdateFile(model);

        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => TrimPdfDialog(
              pdfFile: model,
              onTrimComplete: (trimmedPath) => _loadSavedHistory(),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memilih file: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  void _showFabActionSheet() {
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
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF151B26),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF222B3D)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pilih Aksi Dokumen',
                    style: TextStyle(
                      color: Color(0xFFF1F5F9),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildModalTile(
                    title: 'Buka & Baca PDF',
                    subtitle: 'Buka satu atau beberapa file PDF untuk dibaca',
                    icon: Icons.menu_book_rounded,
                    accentColor: const Color(0xFF4F46E5),
                    onTap: () {
                      Navigator.pop(context);
                      _pickAndReadPdf();
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildModalTile(
                    title: 'Gabungkan PDF (Merge)',
                    subtitle: 'Pilih beberapa file untuk digabungkan menjadi satu file',
                    icon: Icons.call_merge_rounded,
                    accentColor: const Color(0xFF059669),
                    onTap: () {
                      Navigator.pop(context);
                      _pickAndMergePdfs();
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildModalTile(
                    title: 'Potong / Ekstrak Halaman PDF',
                    subtitle: 'Ambil rentang halaman spesifik dari suatu file',
                    icon: Icons.content_cut_rounded,
                    accentColor: const Color(0xFFD97706),
                    onTap: () {
                      Navigator.pop(context);
                      _pickAndTrimPdf();
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _toggleMergeMode() {
    setState(() {
      _isMergeMode = !_isMergeMode;
      _mergeQueue.clear();
    });

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

  Future<void> _removeFile(PdfFileModel file) async {
    final updated = await HistoryService.removeFile(file.path);
    if (mounted) {
      setState(() {
        _openedFiles = updated;
        _mergeQueue.remove(file);
      });
    }
  }

  Future<void> _clearAllHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF151B26),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFF222B3D)),
        ),
        title: const Text('Hapus Riwayat', style: TextStyle(color: Color(0xFFF1F5F9), fontSize: 16, fontWeight: FontWeight.w700)),
        content: const Text(
          'Daftar file riwayat akan dibersihkan. File fisik dokumen Anda tetap aman.',
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: const Text('Hapus', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await HistoryService.clearHistory();
      if (mounted) {
        setState(() {
          _openedFiles.clear();
          _mergeQueue.clear();
        });
      }
    }
  }

  Future<void> _clearAppCache() async {
    try {
      final freedBytes = await platform.invokeMethod<int>('clearCache') ?? 0;
      final freedMb = (freedBytes / (1024 * 1024)).toStringAsFixed(1);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cache dibersihkan ($freedMb MB data sementara)'),
            backgroundColor: const Color(0xFF1E2533),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (_) {}
  }

  void _reorderFiles(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final item = _openedFiles.removeAt(oldIndex);
      _openedFiles.insert(newIndex, item);
    });
    HistoryService.saveHistory(_openedFiles);
  }

  void _openMergeScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MergeScreen(
          filesToMerge: _mergeQueue,
          onMergeComplete: (mergedPath, sourceFiles) {
            setState(() {
              _isMergeMode = false;
              _mergeQueue.clear();
            });
            _loadSavedHistory();
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _fabAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F17),
      appBar: _buildAppBar(),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 768;
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isDesktop ? 960 : double.infinity),
              child: _buildBodyContent(),
            ),
          );
        },
      ),
      floatingActionButton: _buildFab(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF0B0F17),
      elevation: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PDF Merge & Reader',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFFF1F5F9),
              letterSpacing: -0.3,
            ),
          ),
          if (_isMergeMode)
            Text(
              '${_mergeQueue.length} file dipilih untuk digabung',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF94A3B8),
              ),
            )
          else if (_openedFiles.isNotEmpty)
            Text(
              '${_openedFiles.length} file riwayat',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF94A3B8),
              ),
            ),
        ],
      ),
      actions: [
        if (_isMergeMode) ...[
          if (_mergeQueue.length >= 2)
            _buildActionButton(
              icon: Icons.call_merge_rounded,
              label: 'Merge',
              color: const Color(0xFF4F46E5),
              onTap: _openMergeScreen,
            ),
          const SizedBox(width: 8),
          _buildActionButton(
            icon: Icons.close_rounded,
            label: 'Batal',
            color: const Color(0xFFEF4444),
            onTap: _toggleMergeMode,
          ),
        ] else ...[
          _buildActionButton(
            icon: Icons.content_cut_rounded,
            label: 'Potong',
            color: const Color(0xFF94A3B8),
            onTap: _pickAndTrimPdf,
          ),
          const SizedBox(width: 6),
          _buildActionButton(
            icon: Icons.call_merge_rounded,
            label: 'Merge',
            color: const Color(0xFF4F46E5),
            onTap: _toggleMergeMode,
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: () => _checkForUpdates(silent: false),
            icon: const Icon(Icons.system_update_rounded, color: Color(0xFF94A3B8), size: 19),
            tooltip: 'Cek Pembaruan',
          ),
          IconButton(
            onPressed: _clearAppCache,
            icon: const Icon(Icons.cleaning_services_rounded, color: Color(0xFF94A3B8), size: 19),
            tooltip: 'Bersihkan Cache',
          ),
          IconButton(
            onPressed: _clearAllHistory,
            icon: const Icon(Icons.delete_sweep_rounded, color: Color(0xFF94A3B8), size: 19),
            tooltip: 'Hapus Semua Riwayat',
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
      color: const Color(0xFF151B26),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF222B3D)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardStats() {
    final total = _openedFiles.length;
    final completed = _openedFiles.where((f) => f.totalPages > 0 && f.lastReadPage + 1 >= f.totalPages).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Text(
            '$total dokumen tersimpan',
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (completed > 0) ...[
            const Text('  •  ', style: TextStyle(color: Color(0xFF475569), fontSize: 12)),
            Text(
              '$completed selesai dibaca',
              style: const TextStyle(
                color: Color(0xFF10B981),
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBodyContent() {
    final sortedList = _sortedAndFilteredFiles;

    if (_openedFiles.isEmpty) {
      return EmptyState(
        onReadPdfPressed: _pickAndReadPdf,
        onMergePdfPressed: _pickAndMergePdfs,
      );
    }

    return Column(
      children: [
        _buildDashboardStats(),

        // Search Bar & Sort Dropdown
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF151B26),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF222B3D),
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                      });
                    },
                    style: const TextStyle(color: Color(0xFFF1F5F9), fontSize: 13.5),
                    decoration: InputDecoration(
                      hintText: 'Cari file PDF di riwayat...',
                      hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13.5),
                      prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 19),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, color: Color(0xFF94A3B8), size: 17),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Sort menu button
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF151B26),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF222B3D)),
                ),
                child: PopupMenuButton<String>(
                  initialValue: _sortOrder,
                  icon: const Icon(Icons.sort_rounded, color: Color(0xFF94A3B8), size: 20),
                  tooltip: 'Urutkan Riwayat',
                  color: const Color(0xFF151B26),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: Color(0xFF222B3D)),
                  ),
                  onSelected: (value) {
                    setState(() {
                      _sortOrder = value;
                    });
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'recent',
                      child: Row(
                        children: [
                          Icon(Icons.history_rounded, color: Color(0xFF94A3B8), size: 17),
                          SizedBox(width: 10),
                          Text('Terbaru Dibuka', style: TextStyle(color: Color(0xFFF1F5F9), fontSize: 13)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'name',
                      child: Row(
                        children: [
                          Icon(Icons.sort_by_alpha_rounded, color: Color(0xFF94A3B8), size: 17),
                          SizedBox(width: 10),
                          Text('Nama File (A-Z)', style: TextStyle(color: Color(0xFFF1F5F9), fontSize: 13)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'size',
                      child: Row(
                        children: [
                          Icon(Icons.data_usage_rounded, color: Color(0xFF94A3B8), size: 17),
                          SizedBox(width: 10),
                          Text('Ukuran File', style: TextStyle(color: Color(0xFFF1F5F9), fontSize: 13)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'progress',
                      child: Row(
                        children: [
                          Icon(Icons.auto_stories_rounded, color: Color(0xFF94A3B8), size: 17),
                          SizedBox(width: 10),
                          Text('Progres Membaca', style: TextStyle(color: Color(0xFFF1F5F9), fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // File List
        Expanded(
          child: sortedList.isEmpty
              ? Center(
                  child: Text(
                    'File "$_searchQuery" tidak ditemukan',
                    style: const TextStyle(color: Color(0xFF64748B)),
                  ),
                )
              : AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: ReorderableListView.builder(
                    buildDefaultDragHandles: false,
                    key: ValueKey('$_isMergeMode$_sortOrder'),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                    itemCount: sortedList.length,
                    onReorder: _reorderFiles,
                    proxyDecorator: (child, index, animation) {
                      return Material(
                        color: Colors.transparent,
                        elevation: 4,
                        borderRadius: BorderRadius.circular(12),
                        child: child,
                      );
                    },
                    itemBuilder: (context, index) {
                      final pdfFile = sortedList[index];
                      final isSelected = _mergeQueue.contains(pdfFile);
                      final mergeOrder = isSelected ? _mergeQueue.indexOf(pdfFile) + 1 : null;

                      return PdfCard(
                        key: ValueKey('card_${pdfFile.id}'),
                        pdfFile: pdfFile,
                        isMergeMode: _isMergeMode,
                        isSelected: isSelected,
                        mergeOrder: mergeOrder,
                        onTap: () {
                          if (_isMergeMode) {
                            _toggleFileInMergeQueue(pdfFile);
                          } else {
                            _showOptionModal(pdfFile);
                          }
                        },
                        onTrimTap: () {
                          showDialog(
                            context: context,
                            builder: (context) => TrimPdfDialog(
                              pdfFile: pdfFile,
                              onTrimComplete: (trimmedPath) => _loadSavedHistory(),
                            ),
                          );
                        },
                        onDismissed: () => _removeFile(pdfFile),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildFab() {
    return ScaleTransition(
      scale: _fabScaleAnimation,
      child: FloatingActionButton.extended(
        onPressed: _showFabActionSheet,
        backgroundColor: const Color(0xFF4F46E5),
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text(
          'Buka / Impor PDF',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            letterSpacing: -0.1,
          ),
        ),
      ),
    );
  }
}
