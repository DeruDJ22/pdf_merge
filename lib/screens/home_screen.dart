import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../models/pdf_file_model.dart';
import '../services/history_service.dart';
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
        for (final path in paths) {
          await _handleIncomingPdfPath(path);
        }
      }
    });
  }

  Future<void> _getInitialIntent() async {
    try {
      final result = await platform.invokeMethod('getInitialIntent');
      if (result != null && result is List) {
        for (final path in result.cast<String>()) {
          await _handleIncomingPdfPath(path);
        }
      }
    } catch (e) {
      // No initial intent
    }
  }

  Future<void> _handleIncomingPdfPath(String path) async {
    final model = await PdfFileModel.fromPath(path);
    final updated = await HistoryService.addOrUpdateFile(model);
    if (mounted) {
      setState(() {
        _openedFiles = updated;
      });
      _showOptionModal(model);
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

  /// Show modal sheet with choice: "Baca PDF" or "Gabungkan (Merge) PDF"
  void _showOptionModal(PdfFileModel file) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A2E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C63FF).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.picture_as_pdf_rounded,
                      color: Color(0xFF6C63FF),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          file.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Pilih aksi yang ingin dilakukan:',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              InkWell(
                onTap: () {
                  Navigator.pop(context);
                  _openViewer(file);
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF6C63FF).withOpacity(0.2),
                        const Color(0xFF6C63FF).withOpacity(0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF6C63FF).withOpacity(0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          color: Color(0xFF6C63FF),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.menu_book_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '📖 Baca PDF Ini',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Buka langsung dengan scroll terus-menerus tanpa pembatas',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white54, size: 16),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              InkWell(
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _isMergeMode = true;
                    if (!_mergeQueue.contains(file)) {
                      _mergeQueue.add(file);
                    }
                  });
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.merge_type_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '🔗 Tambahkan ke Merge PDF',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Pilih file lain dan gabungkan menjadi 1 file PDF',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white54, size: 16),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        );
      },
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
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty && result.files.first.path != null) {
        final path = result.files.first.path!;
        final model = await PdfFileModel.fromPath(path);
        final updated = await HistoryService.addOrUpdateFile(model);
        if (mounted) {
          setState(() {
            _openedFiles = updated;
          });
          _openViewer(model);
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
            await HistoryService.addOrUpdateFile(model);
            pickedModels.add(model);
          }
        }

        await _loadSavedHistory();

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
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('File ditambahkan. Pilih 1 file lagi untuk digabungkan.'),
                backgroundColor: const Color(0xFF6C63FF),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
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

  Future<void> _pickPdfFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final addedList = <PdfFileModel>[];
        for (final file in result.files) {
          if (file.path != null) {
            final model = await PdfFileModel.fromPath(file.path!);
            await HistoryService.addOrUpdateFile(model);
            addedList.add(model);
          }
        }

        await _loadSavedHistory();

        if (addedList.length == 1 && mounted) {
          _showOptionModal(addedList.first);
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
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Hapus Semua Riwayat?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Daftar file riwayat akan dibersihkan. File fisik di HP kamu tidak akan terhapus.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: const Text('Hapus Semua', style: TextStyle(color: Colors.white)),
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
            content: Text('Cache dibersihkan! Menghapus $freedMb MB data sementara.'),
            backgroundColor: const Color(0xFF6C63FF),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
          onMergeComplete: (mergedPath, sourceFiles) async {
            final model = await PdfFileModel.fromPath(mergedPath);
            await HistoryService.addOrUpdateFile(model);

            for (final src in sourceFiles) {
              await HistoryService.removeFile(src.path);
            }

            final history = await HistoryService.loadHistory();

            if (mounted) {
              setState(() {
                _openedFiles = history;
                _isMergeMode = false;
                _mergeQueue.clear();
              });
              _openViewer(model);
            }
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
    _searchController.dispose();
    _fabAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: _buildAppBar(),
        body: _openedFiles.isEmpty
            ? EmptyState(
                onReadPdfPressed: _pickAndReadPdf,
                onMergePdfPressed: _pickAndMergePdfs,
              )
            : _buildBodyContent(),
        floatingActionButton: _openedFiles.isNotEmpty ? _buildFab() : null,
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
            _isMergeMode ? 'Pilih File untuk Merge' : 'PDF Merge & Reader',
            style: const TextStyle(
              fontSize: 22,
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
              '${_openedFiles.length} Riwayat Dokumen',
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
          IconButton(
            onPressed: _clearAppCache,
            icon: const Icon(Icons.cleaning_services_rounded, color: Colors.white70),
            tooltip: 'Bersihkan Cache Aplikasi',
          ),
          IconButton(
            onPressed: _clearAllHistory,
            icon: const Icon(Icons.delete_sweep_rounded, color: Colors.white70),
            tooltip: 'Hapus Semua Riwayat',
          ),
          const SizedBox(width: 4),
          _buildActionButton(
            icon: Icons.merge_type_rounded,
            label: 'Mode Merge',
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

  Widget _buildDashboardStats() {
    final total = _openedFiles.length;
    final completed = _openedFiles.where((f) => f.totalPages > 0 && f.lastReadPage + 1 >= f.totalPages).length;
    final inProgress = total - completed;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E).withOpacity(0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatChip(
              icon: Icons.library_books_rounded,
              label: '$total Dokumen',
              color: const Color(0xFF6C63FF),
            ),
            Container(width: 1, height: 18, color: Colors.white.withOpacity(0.1)),
            _buildStatChip(
              icon: Icons.check_circle_rounded,
              label: '$completed Selesai',
              color: Colors.greenAccent,
            ),
            Container(width: 1, height: 18, color: Colors.white.withOpacity(0.1)),
            _buildStatChip(
              icon: Icons.auto_stories_rounded,
              label: '$inProgress Dibaca',
              color: const Color(0xFF9C8FFF),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildBodyContent() {
    final sortedList = _sortedAndFilteredFiles;

    return Column(
      children: [
        // Dashboard Stats Bar
        _buildDashboardStats(),

        // Search Bar & Sort Dropdown
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A2E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                      });
                    },
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Cari file PDF di riwayat...',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14),
                      prefixIcon: Icon(Icons.search_rounded, color: Colors.white.withOpacity(0.5), size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, color: Colors.white54, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Sort menu button
              Container(
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: PopupMenuButton<String>(
                  initialValue: _sortOrder,
                  icon: const Icon(Icons.sort_rounded, color: Color(0xFF9C8FFF), size: 22),
                  tooltip: 'Urutkan Riwayat',
                  color: const Color(0xFF1A1A2E),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                          Icon(Icons.history_rounded, color: Colors.white70, size: 18),
                          SizedBox(width: 10),
                          Text('Terbaru Dibuka', style: TextStyle(color: Colors.white, fontSize: 13)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'name',
                      child: Row(
                        children: [
                          Icon(Icons.sort_by_alpha_rounded, color: Colors.white70, size: 18),
                          SizedBox(width: 10),
                          Text('Nama File (A-Z)', style: TextStyle(color: Colors.white, fontSize: 13)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'size',
                      child: Row(
                        children: [
                          Icon(Icons.data_usage_rounded, color: Colors.white70, size: 18),
                          SizedBox(width: 10),
                          Text('Ukuran File', style: TextStyle(color: Colors.white, fontSize: 13)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'progress',
                      child: Row(
                        children: [
                          Icon(Icons.auto_stories_rounded, color: Colors.white70, size: 18),
                          SizedBox(width: 10),
                          Text('Progres Membaca', style: TextStyle(color: Colors.white, fontSize: 13)),
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
                    style: TextStyle(color: Colors.white.withOpacity(0.5)),
                  ),
                )
              : AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: ReorderableListView.builder(
                    key: ValueKey('$_isMergeMode$_sortOrder'),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                    itemCount: sortedList.length,
                    onReorder: _reorderFiles,
                    proxyDecorator: (child, index, animation) {
                      return Material(
                        color: Colors.transparent,
                        elevation: 8,
                        borderRadius: BorderRadius.circular(16),
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
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6C63FF).withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: _pickPdfFiles,
          backgroundColor: const Color(0xFF6C63FF),
          foregroundColor: Colors.white,
          elevation: 0,
          highlightElevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          icon: const Icon(Icons.add_rounded, size: 24),
          label: const Text(
            'Buka / Impor PDF',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ),
    );
  }
}
