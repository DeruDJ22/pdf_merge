import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppVersion {
  final List<int> semverParts; // [major, minor, patch]
  final int? buildNumber;
  final String raw;

  AppVersion({
    required this.semverParts,
    this.buildNumber,
    required this.raw,
  });

  /// Parse strings like "v1.0.9-build.27", "v1.0.9+27", "1.0.9", "v1.1.0"
  factory AppVersion.parse(String versionStr, {int? explicitBuildNumber}) {
    var clean = versionStr.trim();
    if (clean.startsWith('v') || clean.startsWith('V')) {
      clean = clean.substring(1);
    }

    int? parsedBuild = explicitBuildNumber;

    if (parsedBuild == null) {
      final buildMatch = RegExp(r'[-+]build[.-](\d+)', caseSensitive: false).firstMatch(clean);
      if (buildMatch != null) {
        parsedBuild = int.tryParse(buildMatch.group(1)!);
        clean = clean.substring(0, buildMatch.start);
      } else {
        final plusMatch = RegExp(r'\+(\d+)').firstMatch(clean);
        if (plusMatch != null) {
          parsedBuild = int.tryParse(plusMatch.group(1)!);
          clean = clean.substring(0, plusMatch.start);
        }
      }
    }

    final parts = clean
        .split('.')
        .map((e) => int.tryParse(e.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();

    // If 4 parts without explicit build (e.g. 1.0.9.27), 4th part is build number
    if (parts.length >= 4 && parsedBuild == null) {
      parsedBuild = parts[3];
      parts.removeRange(3, parts.length);
    }

    while (parts.length < 3) {
      parts.add(0);
    }

    return AppVersion(
      semverParts: parts.sublist(0, 3),
      buildNumber: parsedBuild,
      raw: versionStr,
    );
  }

  /// Returns 1 if this > other, -1 if this < other, 0 if equal
  int compareTo(AppVersion other) {
    for (var i = 0; i < 3; i++) {
      final thisPart = i < semverParts.length ? semverParts[i] : 0;
      final otherPart = i < other.semverParts.length ? other.semverParts[i] : 0;
      if (thisPart > otherPart) return 1;
      if (thisPart < otherPart) return -1;
    }

    // Semver is equal (e.g. 1.0.9 vs 1.0.9)
    if (buildNumber != null && other.buildNumber != null) {
      if (buildNumber! > other.buildNumber!) return 1;
      if (buildNumber! < other.buildNumber!) return -1;
      return 0;
    }

    return 0;
  }
}

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
  static const String fallbackVersion = '1.0.9';
  static const int fallbackBuildNumber = 10;
  static const String githubRepo = 'DeruDJ22/pdf_merge';
  static const MethodChannel _platform = MethodChannel('com.example.pdf_merge/merge');

  /// Get actual installed application version from Android PackageManager
  static Future<AppVersion> getInstalledVersion() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final result = await _platform.invokeMethod<Map<dynamic, dynamic>>('getAppVersion');
        if (result != null) {
          final vName = result['versionName'] as String? ?? fallbackVersion;
          final vCode = (result['versionCode'] as num?)?.toInt() ?? fallbackBuildNumber;
          return AppVersion.parse(vName, explicitBuildNumber: vCode);
        }
      } catch (_) {}
    }
    return AppVersion.parse(fallbackVersion, explicitBuildNumber: fallbackBuildNumber);
  }

  /// Check GitHub latest release and return AppUpdateInfo if newer
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

      if (tagName.isEmpty) return null;

      // Check against last installed tag in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final lastInstalledTag = prefs.getString('last_installed_apk_tag');

      final localVersion = await getInstalledVersion();
      final remoteVersion = AppVersion.parse(tagName);

      // If remote version is not strictly greater than local installed version, don't update
      if (remoteVersion.compareTo(localVersion) <= 0) {
        return null;
      }

      // If local app already initiated installation of this exact tag recently and version matches
      if (lastInstalledTag != null && lastInstalledTag == tagName) {
        // User already downloaded and installed this exact tag
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
        versionName: tagName,
        title: releaseName,
        changelog: body.trim(),
        apkUrl: apkDownloadUrl,
        apkName: apkFileName ?? 'PDF-Merge-Android.apk',
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
    required String tagName,
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

      // Follow redirects manually (GitHub asset downloads redirect to AWS S3)
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

      // Record this tag as installed in SharedPreferences to prevent duplicate alerts
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_installed_apk_tag', tagName);

      // Trigger native installation
      await _platform.invokeMethod('installApk', {'filePath': targetFile.path});
    } finally {
      client.close();
    }
  }
}
