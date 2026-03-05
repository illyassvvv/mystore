import 'package:flutter/foundation.dart';
import '../models/app_model.dart';
import '../services/api_service.dart';

enum LoadState { idle, loading, loaded, error }

class AppsProvider with ChangeNotifier {
  final _api = ApiService();
  List<AppModel> _all = [];
  List<AppModel> _filtered = [];
  LoadState state = LoadState.idle;
  String errorMsg = '';
  String _query = '';
  final Set<String> _favorites = {};

  List<AppModel> get apps => _filtered;
  List<AppModel> get allApps => _all;
  String get query => _query;

  bool isFav(String id) => _favorites.contains(id);

  void toggleFav(String id) {
    if (_favorites.contains(id)) {
      _favorites.remove(id);
    } else {
      _favorites.add(id);
    }
    notifyListeners();
  }

  List<AppModel> get favorites =>
      _all.where((a) => _favorites.contains(a.id)).toList();

  Future<void> load() async {
    state = LoadState.loading;
    errorMsg = '';
    notifyListeners();
    try {
      _all = await _api.fetchApps();
      _apply();
      state = LoadState.loaded;
    } catch (e) {
      errorMsg = e.toString().replaceAll('Exception: ', '');
      state = LoadState.error;
    }
    notifyListeners();
  }

  void search(String q) {
    _query = q;
    _apply();
    notifyListeners();
  }

  void _apply() {
    if (_query.isEmpty) {
      _filtered = List.from(_all);
    } else {
      final q = _query.toLowerCase();
      _filtered = _all
          .where((a) =>
              a.name.toLowerCase().contains(q) ||
              a.description.toLowerCase().contains(q) ||
              a.developer.toLowerCase().contains(q))
          .toList();
    }
  }
}
