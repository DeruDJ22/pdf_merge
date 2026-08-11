import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../models/pdf_file_model.dart';
import '../services/history_service.dart';
import '../widgets/trim_pdf_dialog.dart';

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
  Timer? _autoHideTimer;

  // Pointer tracking for tap detection on native PDF View
  DateTime? _tapDownTime;
  Offset? _tapDownPosition;

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

    _currentPage = _currentFile.lastReadPage;

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
    _animController.forward();

    _scheduleAutoHideControls();
  }

  void _scheduleAutoHideControls() {
    _autoHideTimer?.cancel();
    _autoHideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _showControls && !_showGridOverview) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _autoHideTimer?.cancel();
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
        _showControls = true;
        _currentPage = _currentFile.lastReadPage;
      });
      _scheduleAutoHideControls();
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
      _currentPage = _currentFile.lastReadPage;
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
                _showControls = true;
                _currentPage = 0;
              });
              _scheduleAutoHideControls();
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
    if (_showControls) {
      _scheduleAutoHideControls();
    } else {
      _autoHideTimer?.cancel();
    }
  }

  void _handlePointerDown(PointerDownEvent event) {
    _tapDownTime = DateTime.now();
    _tapDownPosition = event.position;
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (_tapDownTime != null && _tapDownPosition != null) {
      final duration = DateTime.now().difference(_tapDownTime!);
      final distance = (event.position - _tapDownPosition!).distance;

      // If tap lasted < 300ms and moved < 15px, treat as a single screen tap!
      if (duration.inMilliseconds < 300 && distance < 15) {
        _toggleControls();
      }
    }
  }

  void _toggleNightMode() {
    setState(() {
      _nightMode = !_nightMode;
    });
  }

  void _toggleGridOverview() {
    setState(() {
      _showGridOverview = !_showGridOverview;
      if (_showGridOverview) {
        _showControls = true;
        _autoHideTimer?.cancel();
      } else {
        _scheduleAutoHideControls();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _nightMode ? const Color(0xFF0D0D1A) : const Color(0xFF1E1E1E),
      body: Stack(
        children: [
          // Main PDF View Area with Tap Listener
          Listener(
            onPointerDown: _handlePointerDown,
            onPointerUp: _handlePointerUp,
            behavior: HitTestBehavior.translucent,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: (kIsWeb || (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)))
                  ? PdfViewer.file(
                      _currentFile.path,
                      key: ValueKey('pdfrx_view_${_currentFile.id}_${_activeTabIndex}_$_nightMode'),
                      params: PdfViewerParams(
                        onPageChanged: (pageNumber) {
                          if (pageNumber != null) {
                            setState(() {
                              _currentPage = pageNumber - 1;
                            });
                            _currentFile.lastReadPage = pageNumber - 1;
                            HistoryService.updateProgress(_currentFile.path, pageNumber - 1, _totalPages);
                          }
                        },
                        onViewerReady: (document, controller) {
                          setState(() {
                            _totalPages = document.pages.length;
                            _isReady = true;
                          });
                          _currentFile.totalPages = document.pages.length;
                          HistoryService.updateProgress(_currentFile.path, _currentPage, document.pages.length);
                        },
                      ),
                    )
                  : PDFView(
                      key: ValueKey('pdf_view_${_currentFile.id}_${_activeTabIndex}_$_nightMode'),
                      filePath: _currentFile.path,
                      defaultPage: _currentFile.lastReadPage,
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
                        _currentFile.totalPages = pages!;
                        HistoryService.updateProgress(_currentFile.path, _currentPage, pages);
                      },
                      onViewCreated: (controller) {
                        _pdfController = controller;
                        if (_currentFile.lastReadPage > 0) {
                          _pdfController?.setPage(_currentFile.lastReadPage);
                        }
                      },
                      onPageChanged: (page, total) {
                        if (page != null) {
                          setState(() {
                            _currentPage = page;
                          });
                          _currentFile.lastReadPage = page;
                          if (total != null) _currentFile.totalPages = total;
                          HistoryService.updateProgress(_currentFile.path, page, total ?? _totalPages);
                        }
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

          // Top Navigation & Tab Bar Area (Animates smoothly in/out)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            top: _showControls ? 0 : -180,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF0D0D1A),
                    const Color(0xFF0D0D1A).withOpacity(0.92),
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
                          // Trim button
                          IconButton(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => TrimPdfDialog(
                                  pdfFile: _currentFile,
                                  initialStartPage: _currentPage + 1,
                                  initialEndPage: (_currentPage + 50).clamp(1, _totalPages > 0 ? _totalPages : 1),
                                ),
                              );
                            },
                            icon: const Icon(Icons.content_cut_rounded),
                            color: Colors.white,
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.12),
                            ),
                            tooltip: 'Potong / Ekstrak Halaman',
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

          // Bottom Page Control Indicator & Fast Page Jump Slider
          if (_isReady && !_showGridOverview)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOutCubic,
              bottom: _showControls ? 20 : -120,
              left: 20,
              right: 20,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A2E).withOpacity(0.95),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6C63FF).withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 0,
                      ),
                    ],
                    border: Border.all(
                      color: const Color(0xFF6C63FF).withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Page text indicator
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                          Text(
                            'Halaman ${_currentPage + 1} / $_totalPages',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
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

                      // Fast Jump Page Slider
                      if (_totalPages > 1)
                        SliderTheme(
                          data: SliderThemeData(
                            trackHeight: 4,
                            activeTrackColor: const Color(0xFF6C63FF),
                            inactiveTrackColor: Colors.white.withOpacity(0.15),
                            thumbColor: const Color(0xFF9C8FFF),
                            overlayColor: const Color(0xFF6C63FF).withOpacity(0.2),
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                          ),
                          child: Slider(
                            value: _currentPage.toDouble().clamp(0.0, (_totalPages - 1).toDouble()),
                            min: 0,
                            max: (_totalPages - 1).toDouble(),
                            divisions: _totalPages > 1 ? _totalPages - 1 : 1,
                            onChanged: (value) {
                              _scheduleAutoHideControls();
                              final pageNum = value.round();
                              _pdfController?.setPage(pageNum);
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

          // Multi-Task Grid Overview Overlay
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
