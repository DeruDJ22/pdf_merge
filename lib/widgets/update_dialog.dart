import 'package:flutter/material.dart';
import '../services/update_service.dart';

class UpdateDialog extends StatefulWidget {
  final AppUpdateInfo updateInfo;

  const UpdateDialog({
    super.key,
    required this.updateInfo,
  });

  /// Static helper to show the dialog
  static Future<void> show(BuildContext context, AppUpdateInfo updateInfo) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => UpdateDialog(updateInfo: updateInfo),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _downloadedSizeText = '';
  String? _errorMessage;

  Future<void> _startDownload() async {
    setState(() {
      _isDownloading = true;
      _errorMessage = null;
      _downloadProgress = 0.0;
      _downloadedSizeText = '0.0 MB / ${widget.updateInfo.formattedSize}';
    });

    try {
      await UpdateService.downloadAndInstallApk(
        apkUrl: widget.updateInfo.apkUrl,
        fileName: widget.updateInfo.apkName,
        onProgress: (received, total, progress) {
          if (mounted) {
            final receivedMb = (received / (1024 * 1024)).toStringAsFixed(1);
            final totalMb = total > 0 ? (total / (1024 * 1024)).toStringAsFixed(1) : widget.updateInfo.formattedSize;

            setState(() {
              _downloadProgress = progress;
              _downloadedSizeText = '$receivedMb MB / $totalMb MB';
            });
          }
        },
      );

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF151B26),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF222B3D)),
      ),
      contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2533),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.system_update_rounded,
              color: Color(0xFF6366F1),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Pembaruan Tersedia',
              style: TextStyle(
                color: Color(0xFFF1F5F9),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Version info badges
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2533),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Versi ${widget.updateInfo.tagName}',
                    style: const TextStyle(
                      color: Color(0xFF6366F1),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (widget.updateInfo.formattedSize.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    '•  ${widget.updateInfo.formattedSize}',
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),

            // Release title
            if (widget.updateInfo.title.isNotEmpty && widget.updateInfo.title != widget.updateInfo.tagName)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  widget.updateInfo.title,
                  style: const TextStyle(
                    color: Color(0xFFF1F5F9),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

            // Changelog container
            const Text(
              'Apa yang baru:',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 160),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F141F),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF222B3D)),
              ),
              child: SingleChildScrollView(
                child: Text(
                  widget.updateInfo.changelog.isNotEmpty
                      ? widget.updateInfo.changelog
                      : 'Pembaruan stabilitas dan peningkatan aplikasi.',
                  style: const TextStyle(
                    color: Color(0xFFF1F5F9),
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ),
            ),

            // Downloading Progress Indicator
            if (_isDownloading) ...[
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Mengunduh pembaruan...',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                      ),
                      Text(
                        '${(_downloadProgress * 100).toInt()}%',
                        style: const TextStyle(
                          color: Color(0xFFF1F5F9),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _downloadProgress > 0 ? _downloadProgress : null,
                      backgroundColor: const Color(0xFF222B3D),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _downloadedSizeText,
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                  ),
                ],
              ),
            ],

            // Error display
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF7F1D1D).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      actions: [
        if (!_isDownloading) ...[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Nanti',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: _startDownload,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            icon: const Icon(Icons.download_rounded, size: 16),
            label: Text(
              _errorMessage != null ? 'Coba Lagi' : 'Perbarui',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ],
    );
  }
}
