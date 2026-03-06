import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_model.dart';

class PersistenceService {
  static const _favKey = 'favorites_v1';
  static const _appsKey = 'cached_apps_v1';
  static const _themeKey = 'dark_mode_v1';

  // ── Favorites ──────────────────────────────────────────────
  Future<Set<String>> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_favKey) ?? [];
    return list.toSet();
  }

  Future<void> saveFavorites(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favKey, ids.toList());
  }

  // ── App cache (avoid network refresh on tab switch) ─────────
  Future<List<AppModel>> loadCachedApps() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_appsKey);
    if (raw == null) return [];
    try {
      final list = json.decode(raw) as List;
      return list
          .whereType<Map<String, dynamic>>()
          .map(AppModel.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> cacheApps(List<AppModel> apps) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = json.encode(apps.map((a) => a.toJson()).toList());
    await prefs.setString(_appsKey, encoded);
  }

  // ── Theme ───────────────────────────────────────────────────
  Future<bool> loadDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_themeKey) ?? true;
  }

  Future<void> saveDarkMode(bool dark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, dark);
  }
}
