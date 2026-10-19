import 'dart:io';
import 'package:flutter/rendering.dart';
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

  }

  void _handleScrollNotification(ScrollNotification notification) {
    if (notification is UserScrollNotification && !_showGridOverview) {
      if (notification.direction == ScrollDirection.forward) {
        // Scroll up -> show controls
        if (!_showControls && mounted) setState(() => _showControls = true);
      } else if (notification.direction == ScrollDirection.reverse) {
        // Scroll down -> hide controls
        if (_showControls && mounted) setState(() => _showControls = false);
      }
    }
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
        _showControls = true;
        _currentPage = _currentFile.lastReadPage;
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
        final models = <PdfFileModel>[];
        for (final file in result.files) {
          if (file.path != null) {
            final model = await PdfFileModel.fromPath(file.path!);
            models.add(model);
          }
        }

        if (models.isNotEmpty) {
          await HistoryService.addOrUpdateMultipleFiles(models);
          if (mounted) {
            setState(() {
              for (final model in models) {
                if (!_openedTabs.any((f) => f.path == model.path)) {
                  _openedTabs.add(model);
                }
              }
              final targetIndex = _openedTabs.indexWhere((f) => f.path == models.last.path);
              if (targetIndex != -1) {
                _switchTab(targetIndex);
              }
            });
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
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _nightMode ? const Color(0xFF0B0F17) : const Color(0xFF1E2533),
      body: Stack(
        children: [
          // Main PDF View Area with Tap + Scroll Listener
          NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              _handleScrollNotification(notification);
              return false;
            },
            child: Listener(
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
          ),),

          // Top Navigation & Tab Bar Area (Animates smoothly in/out)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            top: _showControls ? 0 : -180,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F141F),
                border: const Border(
                  bottom: BorderSide(color: Color(0xFF222B3D)),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Primary Header Bar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 12, 4),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back_rounded, size: 20),
                            color: const Color(0xFFF1F5F9),
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFF1E2533),
                              padding: const EdgeInsets.all(8),
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
                                    color: Color(0xFFF1F5F9),
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${_openedTabs.length} Dokumen • ${_currentFile.sizeFormatted}',
                                  style: const TextStyle(
                                    color: Color(0xFF94A3B8),
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
                              size: 19,
                            ),
                            color: _showGridOverview ? const Color(0xFF818CF8) : const Color(0xFF94A3B8),
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFF1E2533),
                              padding: const EdgeInsets.all(8),
                            ),
                            tooltip: 'Lihat Semua Dokumen',
                          ),
                          const SizedBox(width: 4),
                          // Night mode toggle
                          IconButton(
                            onPressed: _toggleNightMode,
                            icon: Icon(
                              _nightMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                              size: 19,
                            ),
                            color: _nightMode ? const Color(0xFF818CF8) : Colors.amber,
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFF1E2533),
                              padding: const EdgeInsets.all(8),
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
                            icon: const Icon(Icons.content_cut_rounded, size: 19),
                            color: const Color(0xFF94A3B8),
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFF1E2533),
                              padding: const EdgeInsets.all(8),
                            ),
                            tooltip: 'Potong Halaman',
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
                            icon: const Icon(Icons.share_rounded, size: 19),
                            color: const Color(0xFF94A3B8),
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFF1E2533),
                              padding: const EdgeInsets.all(8),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Multi-Document Tabs Scrollview
                    Container(
                      height: 40,
                      margin: const EdgeInsets.only(bottom: 6),
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
                                avatar: const Icon(Icons.add_rounded, size: 16, color: Color(0xFF94A3B8)),
                                label: const Text('Buka PDF', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5)),
                                backgroundColor: const Color(0xFF1E2533),
                                side: const BorderSide(color: Color(0xFF2B3548)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? const Color(0xFF4F46E5)
                                        : const Color(0xFF1E2533),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isActive
                                          ? const Color(0xFF6366F1)
                                          : const Color(0xFF2B3548),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.picture_as_pdf_rounded,
                                        size: 14,
                                        color: isActive ? Colors.white : const Color(0xFFEF4444),
                                      ),
                                      const SizedBox(width: 6),
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(maxWidth: 130),
                                        child: Text(
                                          tabFile.name,
                                          style: TextStyle(
                                            color: isActive ? Colors.white : const Color(0xFF94A3B8),
                                            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                                            fontSize: 12,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      InkWell(
                                        onTap: () => _closeTab(index),
                                        borderRadius: BorderRadius.circular(6),
                                        child: Padding(
                                          padding: const EdgeInsets.all(2),
                                          child: Icon(
                                            Icons.close_rounded,
                                            size: 14,
                                            color: isActive ? Colors.white70 : const Color(0xFF64748B),
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
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOutCubic,
              bottom: _showControls ? 20 : -120,
              left: 20,
              right: 20,
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 420),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF151B26),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black38,
                        blurRadius: 16,
                        offset: Offset(0, 4),
                      ),
                    ],
                    border: Border.all(
                      color: const Color(0xFF222B3D),
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
                            color: const Color(0xFFF1F5F9),
                            iconSize: 22,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            padding: EdgeInsets.zero,
                          ),
                          Text(
                            'Halaman ${_currentPage + 1} / $_totalPages',
                            style: const TextStyle(
                              color: Color(0xFFF1F5F9),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          IconButton(
                            onPressed: _currentPage < _totalPages - 1
                                ? () => _pdfController?.setPage(_currentPage + 1)
                                : null,
                            icon: const Icon(Icons.chevron_right_rounded),
                            color: const Color(0xFFF1F5F9),
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
                            trackHeight: 3,
                            activeTrackColor: const Color(0xFF4F46E5),
                            inactiveTrackColor: const Color(0xFF222B3D),
                            thumbColor: const Color(0xFF6366F1),
                            overlayColor: const Color(0xFF4F46E5).withOpacity(0.18),
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                          ),
                          child: Slider(
                            value: _currentPage.toDouble().clamp(0.0, (_totalPages - 1).toDouble()),
                            min: 0,
                            max: (_totalPages - 1).toDouble(),
                            divisions: _totalPages > 1 ? _totalPages - 1 : 1,
                            onChanged: (value) {
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
                color: const Color(0xFF0B0F17).withOpacity(0.97),
                child: SafeArea(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 960),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            child: Row(
                              children: [
                                const Text(
                                  'Dokumen Terbuka',
                                  style: TextStyle(
                                    color: Color(0xFFF1F5F9),
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  onPressed: _toggleGridOverview,
                                  icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                                  tooltip: 'Tutup',
                                  style: IconButton.styleFrom(
                                    backgroundColor: const Color(0xFF151B26),
                                    side: const BorderSide(color: Color(0xFF222B3D)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, gridConstraints) {
                                final isDesktopGrid = gridConstraints.maxWidth >= 720;
                                final crossAxisCount = isDesktopGrid ? 4 : 2;

                                return GridView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: crossAxisCount,
                                    childAspectRatio: 0.8,
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
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF151B26).withOpacity(0.5),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: const Color(0xFF222B3D),
                                              width: 1,
                                            ),
                                          ),
                                          child: const Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.add_rounded, color: Color(0xFF6366F1), size: 32),
                                              SizedBox(height: 8),
                                              Text(
                                                'Buka PDF Lain',
                                                style: TextStyle(
                                                  color: Color(0xFFF1F5F9),
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13,
                                                ),
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
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF151B26),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isCurrent ? const Color(0xFF4F46E5) : const Color(0xFF222B3D),
                                            width: isCurrent ? 1.5 : 1,
                                          ),
                                        ),
                                        child: Column(
                                          children: [
                                            Expanded(
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF0F141F),
                                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                                                ),
                                                child: Center(
                                                  child: Icon(
                                                    Icons.picture_as_pdf_rounded,
                                                    size: 40,
                                                    color: isCurrent ? const Color(0xFFEF4444) : const Color(0xFF64748B),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          file.name,
                                                          style: const TextStyle(
                                                            color: Color(0xFFF1F5F9),
                                                            fontWeight: FontWeight.w600,
                                                            fontSize: 12,
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                        const SizedBox(height: 2),
                                                        Text(
                                                          file.sizeFormatted,
                                                          style: const TextStyle(
                                                            color: Color(0xFF64748B),
                                                            fontSize: 11,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  IconButton(
                                                    onPressed: () => _closeTab(index),
                                                    icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF64748B)),
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                                    tooltip: 'Tutup dokumen',
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
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
                    color: Color(0xFF4F46E5),
                    strokeWidth: 2.5,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Memuat Dokumen...',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 13,
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
