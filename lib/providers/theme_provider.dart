import 'package:flutter/foundation.dart';
import '../services/persistence_service.dart';

class ThemeProvider with ChangeNotifier {
  final _persistence = PersistenceService();
  bool _dark = true;

  bool get isDark => _dark;

  Future<void> init() async {
    _dark = await _persistence.loadDarkMode();
    notifyListeners();
  }

  Future<void> toggle() async {
    _dark = !_dark;
    await _persistence.saveDarkMode(_dark);
    notifyListeners();
  }
}
