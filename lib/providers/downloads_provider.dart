import 'package:flutter/foundation.dart';
import '../models/app_model.dart';
import '../services/download_service.dart';

enum DlStatus { downloading, paused, completed, failed, cancelled }

class DlEntry {
  final AppModel app;
  DlStatus status;
  double progress;
  String? filePath;
  String? error;
  DownloadTask? task;

  DlEntry({
    required this.app,
    this.status = DlStatus.downloading,
    this.progress = 0,
    this.filePath,
    this.error,
    this.task,
  });
}

class DownloadsProvider with ChangeNotifier {
  final List<DlEntry> _entries = [];
  List<DlEntry> get entries => _entries;

  bool isDownloading(String id) =>
      _entries.any((e) => e.app.id == id && e.status == DlStatus.downloading);

  void startDownload(AppModel app) {
    final existing = _find(app.id);
    if (existing != null &&
        (existing.status == DlStatus.downloading ||
            existing.status == DlStatus.completed)) return;

    if (existing != null) _entries.remove(existing);

    final entry = DlEntry(app: app);
    final task = DownloadTask(
      app: app,
      onProgress: (p) {
        entry.progress = p;
        notifyListeners();
      },
      onComplete: (path) {
        entry.status = DlStatus.completed;
        entry.filePath = path;
        entry.progress = 1.0;
        notifyListeners();
      },
      onError: (err) {
        entry.status = DlStatus.failed;
        entry.error = err;
        notifyListeners();
      },
    );
    entry.task = task;
    _entries.insert(0, entry);
    notifyListeners();
    task.start();
  }

  void pause(String id) {
    final e = _find(id);
    if (e == null) return;
    e.task?.pause();
    e.status = DlStatus.paused;
    notifyListeners();
  }

  void resume(String id) {
    final e = _find(id);
    if (e == null) return;
    e.status = DlStatus.downloading;
    notifyListeners();
    e.task?.resume();
  }

  void cancel(String id) {
    final e = _find(id);
    if (e == null) return;
    e.task?.cancel();
    e.status = DlStatus.cancelled;
    notifyListeners();
  }

  void remove(String id) {
    final e = _find(id);
    if (e != null) {
      e.task?.cancel();
      _entries.remove(e);
      notifyListeners();
    }
  }

  DlEntry? _find(String id) {
    try {
      return _entries.firstWhere((e) => e.app.id == id);
    } catch (_) {
      return null;
    }
  }

  DlEntry? getEntry(String id) => _find(id);
}
