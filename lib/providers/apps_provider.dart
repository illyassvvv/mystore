import 'package:flutter/foundation.dart';
import '../models/app_model.dart';
import '../services/api_service.dart';
import '../services/persistence_service.dart';

enum LoadState { idle, loading, loaded, error }

class AppsProvider with ChangeNotifier {
  final _api = ApiService();
  final _persistence = PersistenceService();

  List<AppModel> _all = [];
  List<AppModel> _filtered = [];
  Set<String> _favorites = {};
  LoadState state = LoadState.idle;
  String errorMsg = '';
  String _query = '';

  List<AppModel> get apps => _filtered;
  List<AppModel> get allApps => _all;
  String get query => _query;
  bool get isFavoritesLoaded => _favorites.isNotEmpty || state == LoadState.loaded;

  bool isFav(String id) => _favorites.contains(id);

  List<AppModel> get favorites =>
      _all.where((a) => _favorites.contains(a.id)).toList();

  /// Called once at startup — loads cache first, then optionally fetches
  Future<void> init() async {
    _favorites = await _persistence.loadFavorites();
    final cached = await _persistence.loadCachedApps();
    if (cached.isNotEmpty) {
      _all = cached;
      _apply();
      state = LoadState.loaded;
      notifyListeners();
    }
    // If nothing cached, do a fresh fetch
    if (cached.isEmpty) await fetch();
  }

  /// Manual refresh (pull-to-refresh only)
  Future<void> fetch() async {
    state = LoadState.loading;
    errorMsg = '';
    notifyListeners();
    try {
      _all = await _api.fetchApps();
      await _persistence.cacheApps(_all);
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

  void clearSearch() {
    _query = '';
    _apply();
    notifyListeners();
  }

  Future<void> toggleFav(String id) async {
    if (_favorites.contains(id)) {
      _favorites.remove(id);
    } else {
      _favorites.add(id);
    }
    await _persistence.saveFavorites(_favorites);
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
