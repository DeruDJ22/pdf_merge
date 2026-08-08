import 'package:shared_preferences/shared_preferences.dart';
import '../models/pdf_file_model.dart';

class HistoryService {
  static const String _historyKey = 'pdf_merge_opened_files_history_v1';

  /// Load all saved PDF history models from SharedPreferences
  static Future<List<PdfFileModel>> loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_historyKey) ?? '';
      return PdfFileModel.decodeList(jsonStr);
    } catch (_) {
      return [];
    }
  }

  /// Save full PDF history list
  static Future<void> saveHistory(List<PdfFileModel> files) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = PdfFileModel.encodeList(files);
      await prefs.setString(_historyKey, jsonStr);
    } catch (_) {}
  }

  /// Add or update a file model in history
  static Future<List<PdfFileModel>> addOrUpdateFile(PdfFileModel file) async {
    final history = await loadHistory();
    history.removeWhere((f) => f.path == file.path);
    history.insert(0, file); // Move to top of history
    await saveHistory(history);
    return history;
  }

  /// Update reading progress (last read page & total pages) for a file
  static Future<void> updateProgress(String path, int page, int totalPages) async {
    final history = await loadHistory();
    final index = history.indexWhere((f) => f.path == path);
    if (index != -1) {
      history[index].lastReadPage = page;
      history[index].totalPages = totalPages;
      await saveHistory(history);
    }
  }

  /// Remove single file from history
  static Future<List<PdfFileModel>> removeFile(String path) async {
    final history = await loadHistory();
    history.removeWhere((f) => f.path == path);
    await saveHistory(history);
    return history;
  }

  /// Clear all history
  static Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }
}
