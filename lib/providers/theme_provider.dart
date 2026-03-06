import 'package:flutter/material.dart';
import '../services/database_service.dart';

class ThemeProvider extends ChangeNotifier {

  bool _isDark = false;

  bool get isDark => _isDark;

  void loadTheme() {
    final stored = DatabaseService.settingsBox.get("darkMode");

    if (stored != null) {
      _isDark = stored;
    }
  }

  void toggleTheme(bool value) {

    _isDark = value;

    DatabaseService.settingsBox.put("darkMode", value);

    notifyListeners();
  }
}