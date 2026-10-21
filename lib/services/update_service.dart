import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class AppUpdateInfo {
  final String tagName;
  final String versionName;
  final String title;
  final String changelog;
  final String apkUrl;
  final String apkName;
  final int apkSizeBytes;
  final String publishedAt;

  AppUpdateInfo({
    required this.tagName,
    required this.versionName,
    required this.title,
    required this.changelog,
    required this.apkUrl,
    required this.apkName,
    required this.apkSizeBytes,
    required this.publishedAt,
  });

  String get formattedSize {
    if (apkSizeBytes <= 0) return '';
    final mb = apkSizeBytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }
}

class UpdateService {
  static const String currentVersion = '1.0.9';
  static const int currentBuildNumber = 10;
  static const String githubRepo = 'DeruDJ22/pdf_merge';
  static const MethodChannel _platform = MethodChannel('com.example.pdf_merge/merge');

  /// Compare two semantic versions (e.g. "1.1.0" vs "1.0.9")
  /// Returns true if remote is strictly greater than local.
  static bool isNewerVersion(String remote, String local) {
    try {
      final cleanRemote = remote.replaceAll(RegExp(r'[^0-9.]'), '');
      final cleanLocal = local.replaceAll(RegExp(r'[^0-9.]'), '');

      final rParts = cleanRemote.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final lParts = cleanLocal.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      final maxLength = rParts.length > lParts.length ? rParts.length : lParts.length;
      while (rParts.length < maxLength) {
        rParts.add(0);
      }
      while (lParts.length < maxLength) {
        lParts.add(0);
      }

      for (var i = 0; i < maxLength; i++) {
        if (rParts[i] > lParts[i]) return true;
        if (rParts[i] < lParts[i]) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Check GitHub latest release
  static Future<AppUpdateInfo?> checkUpdate() async {
    // Only available for Android mobile
    if (kIsWeb || !Platform.isAndroid) return null;

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 10);

    try {
      final uri = Uri.parse('https://api.github.com/repos/$githubRepo/releases/latest');
      final request = await client.getUrl(uri);
      request.headers.set('Accept', 'application/vnd.github.v3+json');
      request.headers.set('User-Agent', 'PDFMerge-Mobile-App');

      final response = await request.close();
      if (response.statusCode != 200) return null;

      final responseBody = await response.transform(utf8.decoder).join();
      final Map<String, dynamic> data = json.decode(responseBody);

      final tagName = data['tag_name'] as String? ?? '';
      final releaseName = data['name'] as String? ?? 'Pembaruan Aplikasi';
      final body = data['body'] as String? ?? 'Peningkatan performa dan perbaikan bug.';
      final publishedAt = data['published_at'] as String? ?? '';

      // Clean version string
      final cleanRemoteVersion = tagName.replaceAll(RegExp(r'[^0-9.]'), '');
      if (cleanRemoteVersion.isEmpty) return null;

      // Check if remote version is newer than current app version
      if (!isNewerVersion(cleanRemoteVersion, currentVersion)) {
        return null;
      }

      // Find APK asset
      final assets = data['assets'] as List<dynamic>? ?? [];
      String? apkDownloadUrl;
      String? apkFileName;
      int apkSize = 0;

      for (final asset in assets) {
        final name = (asset['name'] as String? ?? '').toLowerCase();
        if (name.endsWith('.apk')) {
          apkDownloadUrl = asset['browser_download_url'] as String?;
          apkFileName = asset['name'] as String?;
          apkSize = (asset['size'] as num?)?.toInt() ?? 0;
          break;
        }
      }

      if (apkDownloadUrl == null || apkDownloadUrl.isEmpty) {
        return null;
      }

      return AppUpdateInfo(
        tagName: tagName,
        versionName: cleanRemoteVersion,
        title: releaseName,
        changelog: body.trim(),
        apkUrl: apkDownloadUrl,
        apkName: apkFileName ?? 'app-release.apk',
        apkSizeBytes: apkSize,
        publishedAt: publishedAt,
      );
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  /// Download APK with progress callback and trigger Android package installer
  static Future<void> downloadAndInstallApk({
    required String apkUrl,
    required String fileName,
    required Function(int received, int total, double progress) onProgress,
  }) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 30);

    try {
      final tempDir = await getTemporaryDirectory();
      final targetFile = File('${tempDir.path}/$fileName');
      if (await targetFile.exists()) {
        await targetFile.delete();
      }

      var currentUri = Uri.parse(apkUrl);
      var redirectCount = 0;
      HttpClientResponse? finalResponse;

      // Follow redirects manually if needed (GitHub asset downloads often redirect to AWS S3)
      while (redirectCount < 5) {
        final request = await client.getUrl(currentUri);
        request.headers.set('User-Agent', 'PDFMerge-Mobile-App');
        request.followRedirects = false;
        final response = await request.close();

        if (response.statusCode == 301 || response.statusCode == 302 || response.statusCode == 307 || response.statusCode == 308) {
          final location = response.headers.value(HttpHeaders.locationHeader);
          if (location != null && location.isNotEmpty) {
            currentUri = Uri.parse(location);
            redirectCount++;
            continue;
          }
        }

        if (response.statusCode == 200) {
          finalResponse = response;
          break;
        } else {
          throw Exception('Gagal mengunduh APK (HTTP ${response.statusCode})');
        }
      }

      if (finalResponse == null) {
        throw Exception('Gagal mengunduh APK: Terlalu banyak pengalihan URL');
      }

      final totalBytes = finalResponse.contentLength;
      var receivedBytes = 0;
      final sink = targetFile.openWrite();

      await for (final chunk in finalResponse) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        final progress = totalBytes > 0 ? (receivedBytes / totalBytes).clamp(0.0, 1.0) : 0.0;
        onProgress(receivedBytes, totalBytes, progress);
      }

      await sink.flush();
      await sink.close();

      // Trigger native installation
      await _platform.invokeMethod('installApk', {'filePath': targetFile.path});
    } finally {
      client.close();
    }
  }
}
