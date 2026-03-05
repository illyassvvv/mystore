import 'app_model.dart';

enum DownloadStatus { queued, downloading, paused, completed, failed }

class DownloadItem {
  final AppModel app;
  DownloadStatus status;
  double progress; // 0.0 to 1.0
  String? filePath;
  String? errorMessage;
  CancelToken? cancelToken;

  DownloadItem({
    required this.app,
    this.status = DownloadStatus.queued,
    this.progress = 0.0,
    this.filePath,
    this.errorMessage,
    this.cancelToken,
  });
}

// We import this for the type reference only
class CancelToken {}
