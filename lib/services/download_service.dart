import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../models/app_model.dart';

class DownloadTask {
  final AppModel app;
  final void Function(double progress) onProgress;
  final void Function(String filePath) onComplete;
  final void Function(String error) onError;

  CancelToken _cancelToken = CancelToken();
  bool _paused = false;
  double _lastProgress = 0;
  final Dio _dio = Dio();

  DownloadTask({
    required this.app,
    required this.onProgress,
    required this.onComplete,
    required this.onError,
  });

  bool get isPaused => _paused;

  Future<void> start() async {
    _paused = false;
    _cancelToken = CancelToken();
    await _doDownload();
  }

  Future<void> _doDownload() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final safeName = app.name.replaceAll(RegExp(r'[^\w]'), '_');
      final filePath = '${dir.path}/$safeName.ipa';

      final headers = <String, dynamic>{};
      if (_lastProgress > 0) {
        final file = File(filePath);
        if (await file.exists()) {
          final existingBytes = await file.length();
          headers['Range'] = 'bytes=$existingBytes-';
        }
      }

      await _dio.download(
        app.downloadUrl,
        filePath,
        cancelToken: _cancelToken,
        options: Options(headers: headers.isNotEmpty ? headers : null),
        onReceiveProgress: (received, total) {
          if (total <= 0) return;
          _lastProgress = received / total;
          onProgress(_lastProgress);
        },
        deleteOnError: false,
      );

      onComplete(filePath);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) return; // user cancelled/paused
      onError(e.message ?? 'Download failed');
    } catch (e) {
      onError(e.toString());
    }
  }

  void pause() {
    _paused = true;
    _cancelToken.cancel('paused');
  }

  Future<void> resume() async {
    if (!_paused) return;
    await start();
  }

  void cancel() {
    _cancelToken.cancel('cancelled');
    _lastProgress = 0;
  }
}
