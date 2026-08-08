import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../models/pdf_file_model.dart';

class PdfViewerScreen extends StatefulWidget {
  final PdfFileModel pdfFile;
  final List<PdfFileModel> allOpenedFiles;

  const PdfViewerScreen({
    super.key,
    required this.pdfFile,
    required this.allOpenedFiles,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen>
    with TickerProviderStateMixin {
  late List<PdfFileModel> _openedTabs;
  late int _activeTabIndex;

  int _totalPages = 0;
  int _currentPage = 0;
  bool _isReady = false;
  bool _nightMode = false;
  bool _showControls = true;
  bool _showGridOverview = false;

  PDFViewController? _pdfController;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _openedTabs = widget.allOpenedFiles.isNotEmpty
        ? List.from(widget.allOpenedFiles)
        : [widget.pdfFile];

    _activeTabIndex = _openedTabs.indexWhere((f) => f.path == widget.pdfFile.path);
    if (_activeTabIndex < 0) {
      _openedTabs.insert(0, widget.pdfFile);
      _activeTabIndex = 0;
    }

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  PdfFileModel get _currentFile => _openedTabs[_activeTabIndex];

  void _switchTab(int index) {
    if (index >= 0 && index < _openedTabs.length && index != _activeTabIndex) {
      setState(() {
        _activeTabIndex = index;
        _isReady = false;
        _showGridOverview = false;
      });
    }
  }

  void _closeTab(int index) {
    if (_openedTabs.length <= 1) {
      Navigator.pop(context);
      return;
    }

    setState(() {
      _openedTabs.removeAt(index);
      if (_activeTabIndex >= _openedTabs.length) {
        _activeTabIndex = _openedTabs.length - 1;
      }
      _isReady = false;
    });
  }

  Future<void> _addNewPdfTab() async {
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
            if (!_openedTabs.any((f) => f.path == model.path)) {
              setState(() {
                _openedTabs.add(model);
                _activeTabIndex = _openedTabs.length - 1;
                _isReady = false;
              });
            } else {
              final existingIndex = _openedTabs.indexWhere((f) => f.path == model.path);
              _switchTab(existingIndex);
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuka PDF: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  void _toggleNightMode() {
    setState(() {
      _nightMode = !_nightMode;
    });
  }

  void _toggleGridOverview() {
    setState(() {
      _showGridOverview = !_showGridOverview;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _nightMode ? const Color(0xFF0D0D1A) : const Color(0xFF1E1E1E),
      body: Stack(
        children: [
          // Main PDF View Area
          GestureDetector(
            onTap: _toggleControls,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: PDFView(
                key: ValueKey('pdf_view_${_currentFile.id}_${_activeTabIndex}_$_nightMode'),
                filePath: _currentFile.path,
                enableSwipe: true,
                swipeHorizontal: false,
                autoSpacing: false,
                pageFling: false,
                pageSnap: false,
                fitPolicy: FitPolicy.WIDTH,
                nightMode: _nightMode,
                onRender: (pages) {
                  setState(() {
                    _totalPages = pages!;
                    _isReady = true;
                  });
                },
                onViewCreated: (controller) {
                  _pdfController = controller;
                },
                onPageChanged: (page, total) {
                  setState(() {
                    _currentPage = page!;
                  });
                },
                onError: (error) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $error'),
                      backgroundColor: Colors.red.shade700,
                    ),
                  );
                },
              ),
            ),
          ),

          // Top Navigation & Tab Bar Area
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            top: _showControls ? 0 : -160,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF0D0D1A),
                    const Color(0xFF0D0D1A).withOpacity(0.9),
                    Colors.transparent,
                  ],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Primary Header Bar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 16, 4),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back_rounded),
                            color: Colors.white,
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.12),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _currentFile.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${_openedTabs.length} Dokumen Terbuka • ${_currentFile.sizeFormatted}',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.6),
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Multi Window / Grid Switcher Button
                          IconButton(
                            onPressed: _toggleGridOverview,
                            icon: Icon(
                              _showGridOverview ? Icons.view_day_rounded : Icons.grid_view_rounded,
                            ),
                            color: _showGridOverview ? const Color(0xFF6C63FF) : Colors.white,
                            style: IconButton.styleFrom(
                              backgroundColor: _showGridOverview
                                  ? const Color(0xFF6C63FF).withOpacity(0.3)
                                  : Colors.white.withOpacity(0.12),
                            ),
                            tooltip: 'Lihat Semua Dokumen',
                          ),
                          const SizedBox(width: 4),
                          // Night mode toggle
                          IconButton(
                            onPressed: _toggleNightMode,
                            icon: Icon(
                              _nightMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                            ),
                            color: _nightMode ? const Color(0xFF6C63FF) : Colors.amber,
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.12),
                            ),
                            tooltip: _nightMode ? 'Mode Terang' : 'Mode Gelap',
                          ),
                          const SizedBox(width: 4),
                          // Share button
                          IconButton(
                            onPressed: () {
                              Share.shareXFiles(
                                [XFile(_currentFile.path)],
                                text: _currentFile.fileName,
                              );
                            },
                            icon: const Icon(Icons.share_rounded),
                            color: Colors.white,
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.12),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Multi-Document Tabs Scrollview
                    Container(
                      height: 44,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _openedTabs.length + 1,
                        itemBuilder: (context, index) {
                          if (index == _openedTabs.length) {
                            // Add New Tab Button
                            return Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: ActionChip(
                                onPressed: _addNewPdfTab,
                                avatar: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                                label: const Text('Buka PDF', style: TextStyle(color: Colors.white, fontSize: 12)),
                                backgroundColor: const Color(0xFF6C63FF).withOpacity(0.4),
                                side: BorderSide(color: const Color(0xFF6C63FF).withOpacity(0.6)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                            );
                          }

                          final tabFile = _openedTabs[index];
                          final isActive = index == _activeTabIndex;

                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _switchTab(index),
                                borderRadius: BorderRadius.circular(20),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? const Color(0xFF6C63FF)
                                        : Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isActive
                                          ? const Color(0xFF6C63FF)
                                          : Colors.white.withOpacity(0.15),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.picture_as_pdf_rounded,
                                        size: 14,
                                        color: isActive ? Colors.white : Colors.white70,
                                      ),
                                      const SizedBox(width: 6),
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(maxWidth: 130),
                                        child: Text(
                                          tabFile.name,
                                          style: TextStyle(
                                            color: isActive ? Colors.white : Colors.white70,
                                            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                            fontSize: 12,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      InkWell(
                                        onTap: () => _closeTab(index),
                                        borderRadius: BorderRadius.circular(10),
                                        child: Padding(
                                          padding: const EdgeInsets.all(2),
                                          child: Icon(
                                            Icons.close_rounded,
                                            size: 14,
                                            color: isActive ? Colors.white70 : Colors.white38,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Page Control Indicator
          if (_isReady && !_showGridOverview)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              bottom: _showControls ? 24 : -60,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A2E).withOpacity(0.92),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6C63FF).withOpacity(0.25),
                        blurRadius: 16,
                        spreadRadius: 0,
                      ),
                    ],
                    border: Border.all(
                      color: const Color(0xFF6C63FF).withOpacity(0.4),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: _currentPage > 0
                            ? () => _pdfController?.setPage(_currentPage - 1)
                            : null,
                        icon: const Icon(Icons.chevron_left_rounded),
                        color: Colors.white,
                        iconSize: 22,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        padding: EdgeInsets.zero,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Halaman ${_currentPage + 1} / $_totalPages',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        onPressed: _currentPage < _totalPages - 1
                            ? () => _pdfController?.setPage(_currentPage + 1)
                            : null,
                        icon: const Icon(Icons.chevron_right_rounded),
                        color: Colors.white,
                        iconSize: 22,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Multi-Task Grid Overview Screen Overlay (Visual Task Switcher like Android Recents)
          if (_showGridOverview)
            Positioned.fill(
              child: Container(
                color: const Color(0xFF0D0D1A).withOpacity(0.95),
                child: SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        child: Row(
                          children: [
                            const Text(
                              'Dokumen Terbuka',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: _toggleGridOverview,
                              icon: const Icon(Icons.close_rounded, color: Colors.white),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white.withOpacity(0.1),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.75,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                          ),
                          itemCount: _openedTabs.length + 1,
                          itemBuilder: (context, index) {
                            if (index == _openedTabs.length) {
                              // Add New PDF Card
                              return InkWell(
                                onTap: () {
                                  _toggleGridOverview();
                                  _addNewPdfTab();
                                },
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: const Color(0xFF6C63FF).withOpacity(0.3),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_circle_outline_rounded, color: Color(0xFF6C63FF), size: 40),
                                      SizedBox(height: 12),
                                      Text(
                                        'Buka PDF Lain',
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            final file = _openedTabs[index];
                            final isCurrent = index == _activeTabIndex;

                            return InkWell(
                              onTap: () => _switchTab(index),
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1A1A2E),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isCurrent ? const Color(0xFF6C63FF) : Colors.white.withOpacity(0.12),
                                    width: isCurrent ? 2 : 1,
                                  ),
                                  boxShadow: isCurrent
                                      ? [
                                          BoxShadow(
                                            color: const Color(0xFF6C63FF).withOpacity(0.4),
                                            blurRadius: 12,
                                          )
                                        ]
                                      : [],
                                ),
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.05),
                                          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                                        ),
                                        child: Center(
                                          child: Icon(
                                            Icons.picture_as_pdf_rounded,
                                            size: 48,
                                            color: isCurrent ? const Color(0xFF6C63FF) : Colors.white38,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  file.name,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                Text(
                                                  file.sizeFormatted,
                                                  style: TextStyle(
                                                    color: Colors.white.withOpacity(0.5),
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            onPressed: () => _closeTab(index),
                                            icon: const Icon(Icons.close_rounded, size: 18, color: Colors.white54),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Loading indicator
          if (!_isReady && !_showGridOverview)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    color: Color(0xFF6C63FF),
                    strokeWidth: 3,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Memuat Dokumen...',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
