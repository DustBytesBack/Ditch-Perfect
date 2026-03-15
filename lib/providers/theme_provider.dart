import 'package:flutter/material.dart';
import '../services/database_service.dart';

class ThemeProvider extends ChangeNotifier {
  bool isDark = false;

  Color seedColor = Colors.indigo;

  bool pookieMode = false;

  void loadTheme() {
    final dark = DatabaseService.settingsBox.get(
      "darkMode",
      defaultValue: false,
    );

    final colorValue = DatabaseService.settingsBox.get(
      "seedColor",
      defaultValue: Colors.indigo.toARGB32(),
    );

    final pookie = DatabaseService.settingsBox.get(
      "pookieMode",
      defaultValue: false,
    );

    pookieMode = pookie;

    if (pookieMode) {
      /// Pookie mode always uses light theme
      isDark = false;

      seedColor = const Color(0xFFFF8AD6);
    } else {
      isDark = dark;
      seedColor = Color(colorValue);
    }
  }

  void toggleTheme(bool value) {
    /// Block dark mode if pookie mode is active
    if (pookieMode) return;

    isDark = value;

    DatabaseService.settingsBox.put("darkMode", value);

    notifyListeners();
  }

  void setSeedColor(Color color) {
    pookieMode = false;

    seedColor = color;

    DatabaseService.settingsBox.put("seedColor", color.toARGB32());
    DatabaseService.settingsBox.put("pookieMode", false);

    notifyListeners();
  }

  void togglePookie(bool value) {
    pookieMode = value;

    DatabaseService.settingsBox.put("pookieMode", value);

    if (value) {
      /// Force light mode
      isDark = false;

      seedColor = const Color(0xFFFF8AD6);
    } else {
      final storedDark = DatabaseService.settingsBox.get(
        "darkMode",
        defaultValue: false,
      );

      isDark = storedDark;

      final storedColor = DatabaseService.settingsBox.get(
        "seedColor",
        defaultValue: Colors.indigo.toARGB32(),
      );

      seedColor = Color(storedColor);
    }

    notifyListeners();
  }
}
