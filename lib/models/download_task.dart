import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'app_model.dart';

enum DlStatus { queued, downloading, paused, completed, failed, cancelled }

class DownloadTask {
  final AppModel app;
  DlStatus status;
  double progress; // 0.0–1.0
  int receivedBytes;
  int totalBytes;
  String? filePath;
  String? errorMessage;

  CancelToken? _cancelToken;
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(minutes: 10),
  ));

  void Function(DownloadTask)? onUpdate;

  DownloadTask({
    required this.app,
    this.status = DlStatus.queued,
    this.progress = 0.0,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.filePath,
  });

  Future<void> start() async {
    if (status == DlStatus.downloading) return;
    status = DlStatus.downloading;
    _cancelToken = CancelToken();
    onUpdate?.call(this);
    await _download();
  }

  Future<void> _download() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final safe = app.name.replaceAll(RegExp(r'[^\w\s]'), '').trim().replaceAll(' ', '_');
      final path = '${dir.path}/${safe}_${app.id.hashCode.abs()}.ipa';
      filePath = path;

      // Check existing file for resume
      int startByte = 0;
      final existingFile = File(path);
      if (await existingFile.exists() && receivedBytes > 0) {
        startByte = await existingFile.length();
        // Validate it matches our tracked bytes
        if (startByte != receivedBytes) startByte = 0;
      }

      final headers = <String, dynamic>{};
      if (startByte > 0) {
        headers['Range'] = 'bytes=$startByte-';
      }

      await _dio.download(
        app.downloadUrl,
        path,
        cancelToken: _cancelToken,
        deleteOnError: false,
        options: Options(
          headers: headers.isNotEmpty ? headers : null,
          receiveDataWhenStatusError: false,
        ),
        onReceiveProgress: (received, total) {
          final actualReceived = received + startByte;
          final actualTotal = total > 0 ? total + startByte : totalBytes;

          receivedBytes = actualReceived;
          if (actualTotal > 0) totalBytes = actualTotal;

          progress = actualTotal > 0
              ? (actualReceived / actualTotal).clamp(0.0, 1.0)
              : 0.0;

          onUpdate?.call(this);
        },
      );

      status = DlStatus.completed;
      progress = 1.0;
      onUpdate?.call(this);
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        // paused or cancelled — don't change status here
      } else {
        status = DlStatus.failed;
        errorMessage = e.message ?? 'Download failed';
        onUpdate?.call(this);
      }
    } catch (e) {
      status = DlStatus.failed;
      errorMessage = e.toString();
      onUpdate?.call(this);
    }
  }

  void pause() {
    if (status != DlStatus.downloading) return;
    _cancelToken?.cancel('paused');
    status = DlStatus.paused;
    onUpdate?.call(this);
  }

  Future<void> resume() async {
    if (status != DlStatus.paused) return;
    status = DlStatus.downloading;
    _cancelToken = CancelToken();
    onUpdate?.call(this);
    await _download();
  }

  void cancel() {
    _cancelToken?.cancel('cancelled');
    status = DlStatus.cancelled;
    progress = 0.0;
    receivedBytes = 0;
    // Delete partial file
    if (filePath != null) {
      File(filePath!).exists().then((exists) {
        if (exists) File(filePath!).delete().catchError((_) {});
      });
    }
    onUpdate?.call(this);
  }

  void dispose() {
    _cancelToken?.cancel('disposed');
    _dio.close();
  }
}
