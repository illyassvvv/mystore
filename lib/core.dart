import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:convert';

enum DownloadState { none, downloading, paused, downloaded }

class AppModel {
  final String name; String version; String size; String icon;
  String url; String description; String age; String chart;

  final ValueNotifier<DownloadState> stateNotifier;
  final ValueNotifier<double> progressNotifier;
  final ValueNotifier<bool> isFavoriteNotifier;
  final ValueNotifier<bool> isTrashedNotifier;
  CancelToken? cancelToken;

  AppModel({required this.name, required this.version, required this.size, required this.icon, required this.url, required this.description, required this.age, required this.chart})
      : stateNotifier = ValueNotifier(DownloadState.none),
        progressNotifier = ValueNotifier(0.0),
        isFavoriteNotifier = ValueNotifier(false),
        isTrashedNotifier = ValueNotifier(false);

  factory AppModel.fromJson(Map<String, dynamic> json) => AppModel(
      name: json['name'] ?? 'App', version: json['version'] ?? '', size: json['size'] ?? '', icon: json['icon'] ?? '', url: json['url'] ?? '',
      description: json['description'] ?? '', age: json['age']?.toString() ?? '4+', chart: json['chart']?.toString() ?? '#1',
  );
}

class DownloadService {
  final Dio _dio = Dio();
  
  Future<String> _getPath(String name, bool isTrash) async {
    final dir = await getApplicationSupportDirectory();
    final d = Directory('${dir.path}/${isTrash ? 'trash' : 'apps'}');
    if (!await d.exists()) await d.create(recursive: true);
    return "${d.path}/$name.ipa";
  }

  Future<String> getReliableFilePath(String name) async => await _getPath(name, false);

  Future<void> startOrResumeDownload(AppModel app) async {
    app.cancelToken = CancelToken();
    app.stateNotifier.value = DownloadState.downloading;

    try {
      final file = File(await _getPath(app.name, false));
      int downloadedBytes = file.existsSync() ? file.lengthSync() : 0;
      if (app.progressNotifier.value == 1.0 || app.progressNotifier.value == 0.0) {
        if (file.existsSync()) file.deleteSync();
        downloadedBytes = 0; app.progressNotifier.value = 0.0;
      }

      final response = await _dio.get(app.url, options: Options(responseType: ResponseType.stream, headers: downloadedBytes > 0 ? {'range': 'bytes=$downloadedBytes-'} : {}), cancelToken: app.cancelToken);
      int totalBytes = downloadedBytes + int.parse(response.headers.value('content-length') ?? '0');
      RandomAccessFile raf = file.openSync(mode: response.statusCode == 200 ? FileMode.write : FileMode.append);
      
      int lastUpdate = 0;
      await for (List<int> chunk in response.data.stream) {
        raf.writeFromSync(chunk); downloadedBytes += chunk.length;
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - lastUpdate > 150 || downloadedBytes == totalBytes) {
          lastUpdate = now;
          app.progressNotifier.value = downloadedBytes / totalBytes;
        }
      }
      raf.closeSync();
      app.stateNotifier.value = DownloadState.downloaded;
      HapticFeedback.heavyImpact();
    } catch (e) {
      if (!(e is DioException && e.type == DioExceptionType.cancel)) {
        app.stateNotifier.value = DownloadState.none;
        app.progressNotifier.value = 0.0;
      }
    }
  }

  void pauseDownload(AppModel app) { app.cancelToken?.cancel(); app.stateNotifier.value = DownloadState.paused; }
  Future<void> cancelDownload(AppModel app) async {
    app.cancelToken?.cancel(); app.stateNotifier.value = DownloadState.none; app.progressNotifier.value = 0.0;
    final f = File(await _getPath(app.name, false)); if (f.existsSync()) f.deleteSync();
  }

  Future<void> moveToTrash(AppModel app) async {
    final appPath = await _getPath(app.name, false); final trashPath = await _getPath(app.name, true);
    if (File(appPath).existsSync()) { if (File(trashPath).existsSync()) File(trashPath).deleteSync(); File(appPath).renameSync(trashPath); }
  }

  Future<void> restoreFromTrash(AppModel app) async {
    final appPath = await _getPath(app.name, false); final trashPath = await _getPath(app.name, true);
    if (File(trashPath).existsSync()) { if (File(appPath).existsSync()) File(appPath).deleteSync(); File(trashPath).renameSync(appPath); }
  }

  Future<void> deletePermanently(AppModel app) async {
    final trashPath = await _getPath(app.name, true);
    if (File(trashPath).existsSync()) File(trashPath).deleteSync();
  }

  Future<bool> isFileExists(String name) async => File(await _getPath(name, false)).existsSync();
  Future<bool> isTrashFileExists(String name) async => File(await _getPath(name, true)).existsSync();
}

class StoreController extends ChangeNotifier {
  final DownloadService _ds = DownloadService();
  List<AppModel> allApps = [], filteredApps = [];
  String activeCategory = "All";
  bool isLoading = true;

  List<AppModel> get trendingApps => allApps.length > 3 ? allApps.sublist(0, 3) : allApps;

  Future<void> initStore({bool isRefresh = false}) async {
    if (!isRefresh) { isLoading = true; notifyListeners(); }
    try {
      final res = await Dio().get("https://raw.githubusercontent.com/illyassvvv/MyApps/main/apps.json?t=${DateTime.now().millisecondsSinceEpoch}");
      List<dynamic> data = res.data is String ? jsonDecode(res.data) : res.data;
      List<dynamic> visibleApps = data.where((e) => e['hidden'] != true).toList();
      List<AppModel> fetchedApps = visibleApps.map((e) => AppModel.fromJson(e)).toList();

      if (isRefresh) {
        for (var newApp in fetchedApps) {
          int existingIndex = allApps.indexWhere((a) => a.name == newApp.name);
          if (existingIndex >= 0) {
            allApps[existingIndex].version = newApp.version;
            allApps[existingIndex].url = newApp.url;
            allApps[existingIndex].icon = newApp.icon;
            allApps[existingIndex].size = newApp.size;
          } else allApps.add(newApp);
        }
        allApps.sort((a, b) => fetchedApps.indexWhere((e) => e.name == a.name).compareTo(fetchedApps.indexWhere((e) => e.name == b.name)));
      } else allApps = fetchedApps;

      applyFilters('');
      await _loadSavedPreferences();
      isLoading = false; notifyListeners();
    } catch (e) { isLoading = false; notifyListeners(); }
  }

  Future<void> _loadSavedPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    for (var app in allApps) {
      app.isFavoriteNotifier.value = prefs.getBool('fav_${app.name}') ?? false;
      if (app.stateNotifier.value == DownloadState.none) {
        if (await _ds.isFileExists(app.name)) app.stateNotifier.value = DownloadState.downloaded;
        else if (await _ds.isTrashFileExists(app.name)) app.isTrashedNotifier.value = true;
      }
    }
  }

  void setCategory(String category) { HapticFeedback.selectionClick(); activeCategory = category; applyFilters(''); }

  void applyFilters(String query) {
    List<AppModel> temp = allApps;
    if (activeCategory != "All") temp = temp.where((a) => a.chart.toLowerCase().contains(activeCategory.toLowerCase())).toList();
    if (query.isNotEmpty) temp = temp.where((app) => app.name.toLowerCase().contains(query.toLowerCase())).toList();
    filteredApps = temp; notifyListeners();
  }

  Future<void> toggleFavorite(AppModel app) async {
    HapticFeedback.lightImpact(); app.isFavoriteNotifier.value = !app.isFavoriteNotifier.value;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('fav_${app.name}', app.isFavoriteNotifier.value); notifyListeners();
  }

  void start(AppModel app) async { HapticFeedback.mediumImpact(); if (app.isTrashedNotifier.value) { await _ds.deletePermanently(app); app.isTrashedNotifier.value = false; } _ds.startOrResumeDownload(app); }
  void pause(AppModel app) { HapticFeedback.selectionClick(); _ds.pauseDownload(app); }
  void cancel(AppModel app) { HapticFeedback.heavyImpact(); _ds.cancelDownload(app); }
  
  Future<void> saveToFile(AppModel app) async {
    HapticFeedback.lightImpact();
    final actualPath = await _ds.getReliableFilePath(app.name);
    if (File(actualPath).existsSync()) Share.shareXFiles([XFile(actualPath)]);
  }
  
  Future<void> moveToTrash(AppModel app) async { HapticFeedback.mediumImpact(); await _ds.moveToTrash(app); app.stateNotifier.value = DownloadState.none; app.isTrashedNotifier.value = true; notifyListeners(); }
  Future<void> restoreFromTrash(AppModel app) async { HapticFeedback.lightImpact(); await _ds.restoreFromTrash(app); app.isTrashedNotifier.value = false; app.stateNotifier.value = DownloadState.downloaded; notifyListeners(); }
  Future<void> deletePermanently(AppModel app) async { HapticFeedback.heavyImpact(); await _ds.deletePermanently(app); app.isTrashedNotifier.value = false; notifyListeners(); }
}
