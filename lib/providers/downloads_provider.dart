import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_model.dart';
import '../models/download_task.dart';

class DownloadsProvider with ChangeNotifier {
  final List<DownloadTask> _tasks = [];
  List<DownloadTask> get tasks => List.unmodifiable(_tasks);

  int get activeCount =>
      _tasks.where((t) => t.status == DlStatus.downloading).length;

  Future<void> init() async {
    await _loadCompleted();
  }

  DownloadTask? getTask(String appId) {
    try {
      return _tasks.firstWhere((t) => t.app.id == appId);
    } catch (_) {
      return null;
    }
  }

  void startDownload(AppModel app) {
    final existing = getTask(app.id);
    if (existing != null) {
      if (existing.status == DlStatus.downloading) return;
      if (existing.status == DlStatus.completed) return;
      _tasks.remove(existing);
    }

    final task = DownloadTask(app: app);
    task.onUpdate = (_) {
      notifyListeners();
      if (task.status == DlStatus.completed) _saveCompleted();
    };
    _tasks.insert(0, task);
    notifyListeners();
    task.start();
  }

  void pause(String appId) {
    getTask(appId)?.pause();
    notifyListeners();
  }

  Future<void> resume(String appId) async {
    final task = getTask(appId);
    if (task == null) return;
    // resume continues from receivedBytes offset — does NOT reset to 0
    await task.resume();
  }

  void cancel(String appId) {
    getTask(appId)?.cancel();
    notifyListeners();
    _saveCompleted();
  }

  void remove(String appId) {
    final t = getTask(appId);
    if (t == null) return;
    t.dispose();
    _tasks.remove(t);
    notifyListeners();
    _saveCompleted();
  }

  // Persist completed download paths so they survive app restart
  Future<void> _saveCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    final completed = _tasks
        .where((t) => t.status == DlStatus.completed && t.filePath != null)
        .map((t) => json.encode({
              'app': t.app.toJson(),
              'filePath': t.filePath,
            }))
        .toList();
    await prefs.setStringList('completed_downloads_v1', completed);
  }

  Future<void> _loadCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('completed_downloads_v1') ?? [];
    for (final raw in list) {
      try {
        final map = json.decode(raw) as Map<String, dynamic>;
        final app = AppModel.fromJson(map['app'] as Map<String, dynamic>);
        if (getTask(app.id) != null) continue;
        final task = DownloadTask(
          app: app,
          status: DlStatus.completed,
          progress: 1.0,
          filePath: map['filePath']?.toString(),
        );
        task.onUpdate = (_) => notifyListeners();
        _tasks.add(task);
      } catch (_) {}
    }
    notifyListeners();
  }
}
