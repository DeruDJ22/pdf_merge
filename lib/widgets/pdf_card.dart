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
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? const Color(0xFF1E1B4B).withOpacity(0.6)
                  : const Color(0xFF151B26),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.isSelected
                    ? const Color(0xFF6366F1)
                    : const Color(0xFF222B3D),
                width: widget.isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                // PDF Cover Thumbnail or Document Badge
                Container(
                  width: 48,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C2230),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF2B3548),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(7),
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
                            color: const Color(0xFF1C2230),
                            child: const Center(
                              child: Icon(
                                Icons.picture_as_pdf_rounded,
                                color: Color(0xFFEF4444),
                                size: 24,
                              ),
                            ),
                          ),

                        // Merge mode order badge overlay
                        if (widget.isMergeMode && widget.mergeOrder != null)
                          Positioned.fill(
                            child: Container(
                              color: const Color(0xFF4F46E5),
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
                          color: Color(0xFFF1F5F9),
                          fontWeight: FontWeight.w600,
                          fontSize: 14.5,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.description_outlined,
                            size: 13,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.pdfFile.sizeFormatted,
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
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
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: widget.pdfFile.progressPercentage,
                                  backgroundColor: const Color(0xFF222B3D),
                                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
                                  minHeight: 4,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Hal ${widget.pdfFile.lastReadPage + 1}/${widget.pdfFile.totalPages}',
                              style: const TextStyle(
                                color: Color(0xFF818CF8),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
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
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: widget.isSelected
                          ? const Color(0xFF4F46E5)
                          : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.isSelected
                            ? const Color(0xFF4F46E5)
                            : const Color(0xFF475569),
                        width: 1.5,
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
                          icon: const Icon(Icons.content_cut_rounded, size: 17),
                          color: const Color(0xFF94A3B8),
                          tooltip: 'Potong / Ekstrak Halaman',
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFF1E2533),
                            padding: const EdgeInsets.all(8),
                            minimumSize: const Size(36, 36),
                          ),
                        ),
                      const SizedBox(width: 4),
                      IconButton(
                        onPressed: widget.onDismissed,
                        icon: const Icon(Icons.delete_outline_rounded, size: 17),
                        color: const Color(0xFFF87171),
                        tooltip: 'Hapus dari Riwayat',
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFF2C1E24),
                          padding: const EdgeInsets.all(8),
                          minimumSize: const Size(36, 36),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFF64748B),
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
