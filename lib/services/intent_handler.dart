import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Handles incoming intents from Android (VIEW, SEND, SEND_MULTIPLE)
class IntentHandler {
  static const MethodChannel _channel = MethodChannel('com.example.pdf_merge/intent');

  /// Get initial intent data when app is launched via intent
  static Future<List<String>> getInitialIntent() async {
    try {
      final result = await _channel.invokeMethod('getInitialIntent');
      if (result != null && result is List) {
        return result.cast<String>();
      }
    } catch (e) {
      // Channel not available or no intent
    }
    return [];
  }

  /// Listen for new intents while app is running
  static void listenForIntents(Function(List<String>) onNewFiles) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onNewIntent') {
        final files = (call.arguments as List).cast<String>();
        onNewFiles(files);
      }
    });
  }

  /// Copy a content URI or file to local app directory
  static Future<String?> copyToLocal(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        final dir = await getTemporaryDirectory();
        final name = p.basename(filePath);
        final localPath = p.join(dir.path, name);
        await file.copy(localPath);
        return localPath;
      }
    } catch (e) {
      // Handle error
    }
    return filePath;
  }
}
