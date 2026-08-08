import 'package:flutter/material.dart';
import '../models/pdf_file_model.dart';

class PdfCard extends StatefulWidget {
  final PdfFileModel pdfFile;
  final bool isMergeMode;
  final bool isSelected;
  final int? mergeOrder;
  final VoidCallback onTap;
  final VoidCallback onDismissed;

  const PdfCard({
    super.key,
    required this.pdfFile,
    required this.isMergeMode,
    required this.isSelected,
    this.mergeOrder,
    required this.onTap,
    required this.onDismissed,
  });

  @override
  State<PdfCard> createState() => _PdfCardState();
}

class _PdfCardState extends State<PdfCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

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
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? const Color(0xFF6C63FF).withOpacity(0.15)
                  : const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.isSelected
                    ? const Color(0xFF6C63FF).withOpacity(0.6)
                    : Colors.white.withOpacity(0.06),
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
                // PDF icon / merge order badge
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 48,
                  height: 48,
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
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: (widget.isSelected
                                ? const Color(0xFF6C63FF)
                                : const Color(0xFFE74C3C))
                            .withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: widget.isMergeMode && widget.mergeOrder != null
                        ? Text(
                            '${widget.mergeOrder}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          )
                        : const Icon(
                            Icons.picture_as_pdf_rounded,
                            color: Colors.white,
                            size: 24,
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
                            Icons.insert_drive_file_rounded,
                            size: 12,
                            color: Colors.white.withOpacity(0.4),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.pdfFile.fileName,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 12),
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
                    ],
                  ),
                ),

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
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white.withOpacity(0.3),
                    size: 24,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
