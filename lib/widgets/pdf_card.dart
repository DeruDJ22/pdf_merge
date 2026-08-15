import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/pdf_file_model.dart';

class PdfCard extends StatefulWidget {
  final PdfFileModel pdfFile;
  final bool isMergeMode;
  final bool isSelected;
  final int? mergeOrder;
  final VoidCallback onTap;
  final VoidCallback onDismissed;
  final VoidCallback? onTrimTap;

  const PdfCard({
    super.key,
    required this.pdfFile,
    required this.isMergeMode,
    required this.isSelected,
    this.mergeOrder,
    required this.onTap,
    required this.onDismissed,
    this.onTrimTap,
  });

  @override
  State<PdfCard> createState() => _PdfCardState();
}

class _PdfCardState extends State<PdfCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  String? _thumbnailPath;
  static const _platform = MethodChannel('com.example.pdf_merge/merge');

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
    _controller.forward();

    _loadThumbnail();
  }

  Future<void> _loadThumbnail() async {
    try {
      final path = await _platform.invokeMethod<String>('renderThumbnail', {
        'path': widget.pdfFile.path,
      });
      if (path != null && mounted) {
        setState(() {
          _thumbnailPath = path;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasThumbnail = _thumbnailPath != null && File(_thumbnailPath!).existsSync();

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Dismissible(
        key: ValueKey('dismiss_${widget.pdfFile.id}'),
        direction: widget.isMergeMode
            ? DismissDirection.none
            : DismissDirection.endToStart,
        onDismissed: (_) => widget.onDismissed(),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.red.shade700.withOpacity(0.3),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
              const SizedBox(width: 8),
              Text(
                'Hapus',
                style: TextStyle(
                  color: Colors.red.shade300,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? const Color(0xFF6C63FF).withOpacity(0.15)
                  : const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.isSelected
                    ? const Color(0xFF6C63FF).withOpacity(0.6)
                    : Colors.white.withOpacity(0.08),
                width: widget.isSelected ? 1.5 : 1,
              ),
              boxShadow: [
                if (widget.isSelected)
                  BoxShadow(
                    color: const Color(0xFF6C63FF).withOpacity(0.15),
                    blurRadius: 12,
                    spreadRadius: 0,
                  ),
              ],
            ),
            child: Row(
              children: [
                // PDF Cover Thumbnail or Icon / Merge order badge
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 50,
                  height: 62,
                  decoration: BoxDecoration(
                    color: const Color(0xFF161626),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (widget.isSelected
                                ? const Color(0xFF6C63FF)
                                : const Color(0xFFE74C3C))
                            .withOpacity(0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: Stack(
                      children: [
                        if (hasThumbnail)
                          Positioned.fill(
                            child: Image.file(
                              File(_thumbnailPath!),
                              fit: BoxFit.cover,
                            ),
                          )
                        else
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: widget.isSelected
                                    ? [
                                        const Color(0xFF6C63FF),
                                        const Color(0xFF9C8FFF),
                                      ]
                                    : [
                                        const Color(0xFFE74C3C).withOpacity(0.8),
                                        const Color(0xFFFF6B6B).withOpacity(0.8),
                                      ],
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.picture_as_pdf_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),

                        // Merge mode order badge overlay
                        if (widget.isMergeMode && widget.mergeOrder != null)
                          Positioned.fill(
                            child: Container(
                              color: const Color(0xFF6C63FF).withOpacity(0.85),
                              child: Center(
                                child: Text(
                                  '${widget.mergeOrder}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 14),

                // File info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.pdfFile.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.data_usage_rounded,
                            size: 12,
                            color: Colors.white.withOpacity(0.4),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.pdfFile.sizeFormatted,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      if (widget.pdfFile.totalPages > 0) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: widget.pdfFile.progressPercentage,
                                  backgroundColor: Colors.white.withOpacity(0.1),
                                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
                                  minHeight: 4,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Hal ${widget.pdfFile.lastReadPage + 1}/${widget.pdfFile.totalPages}',
                              style: const TextStyle(
                                color: Color(0xFF9C8FFF),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Action indicator
                if (widget.isMergeMode)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: widget.isSelected
                          ? const Color(0xFF6C63FF)
                          : Colors.white.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.isSelected
                            ? const Color(0xFF6C63FF)
                            : Colors.white.withOpacity(0.2),
                        width: 2,
                      ),
                    ),
                    child: widget.isSelected
                        ? const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 16,
                          )
                        : null,
                  )
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.onTrimTap != null)
                        IconButton(
                          onPressed: widget.onTrimTap,
                          icon: const Icon(Icons.content_cut_rounded, size: 18),
                          color: const Color(0xFF9C8FFF),
                          tooltip: 'Potong / Ekstrak Halaman',
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFF6C63FF).withOpacity(0.12),
                            padding: const EdgeInsets.all(6),
                            minimumSize: const Size(30, 30),
                          ),
                        ),
                      const SizedBox(width: 2),
                      IconButton(
                        onPressed: widget.onDismissed,
                        icon: const Icon(Icons.delete_outline_rounded, size: 18),
                        color: Colors.red.shade400,
                        tooltip: 'Hapus dari Riwayat',
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.red.withOpacity(0.1),
                          padding: const EdgeInsets.all(6),
                          minimumSize: const Size(30, 30),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white.withOpacity(0.3),
                        size: 20,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
