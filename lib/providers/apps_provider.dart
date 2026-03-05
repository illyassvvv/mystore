import 'package:flutter/foundation.dart';
import '../models/app_model.dart';
import '../services/api_service.dart';

enum LoadingState { idle, loading, loaded, error }

class AppsProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<AppModel> _apps = [];
  List<AppModel> _filteredApps = [];
  LoadingState _state = LoadingState.idle;
  String _errorMessage = '';
  String _searchQuery = '';

  List<AppModel> get apps => _filteredApps;
  LoadingState get state => _state;
  String get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  bool get isLoading => _state == LoadingState.loading;
  bool get hasError => _state == LoadingState.error;

  Future<void> loadApps() async {
    _state = LoadingState.loading;
    _errorMessage = '';
    notifyListeners();

    try {
      _apps = await _apiService.fetchApps();
      _applySearch();
      _state = LoadingState.loaded;
    } catch (e) {
      _state = LoadingState.error;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    }

    notifyListeners();
  }

  void search(String query) {
    _searchQuery = query;
    _applySearch();
    notifyListeners();
  }

  void _applySearch() {
    if (_searchQuery.isEmpty) {
      _filteredApps = List.from(_apps);
    } else {
      final q = _searchQuery.toLowerCase();
      _filteredApps = _apps
          .where((app) =>
              app.name.toLowerCase().contains(q) ||
              app.description.toLowerCase().contains(q) ||
              (app.developer?.toLowerCase().contains(q) ?? false))
          .toList();
    }
  }

  void clearSearch() {
    _searchQuery = '';
    _filteredApps = List.from(_apps);
    notifyListeners();
  }
}
