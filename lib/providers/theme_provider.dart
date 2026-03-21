import 'package:flutter/material.dart';
import '../services/database_service.dart';

class ThemeProvider extends ChangeNotifier {
  bool isDark = false;

  Color seedColor = Colors.indigo;

  bool pookieMode = false;
  bool absoluteMode = false;

  void loadTheme() {
    final colorValue = DatabaseService.settingsBox.get(
      "seedColor",
      defaultValue: Colors.indigo.toARGB32(),
    );

    pookieMode = DatabaseService.settingsBox.get(
      "pookieMode",
      defaultValue: false,
    );

    absoluteMode = DatabaseService.settingsBox.get(
      "absoluteMode",
      defaultValue: false,
    );

    if (pookieMode) {
      if (isDark) {
        /// Emo Pookie (Dark Pink + Absolute Black)
        absoluteMode = true;
        seedColor = const Color(0xFFF7A5E1);
      } else {
        /// Standard Pookie (Light Pink)
        absoluteMode = false;
        seedColor = const Color(0xFFFF8AD6);
      }
    } else {
      seedColor = Color(colorValue);
    }
  }

  void toggleTheme(bool value) {
    isDark = value;

    if (pookieMode) {
      if (value) {
        /// Switch to Emo Pookie (Dark)
        seedColor = const Color(0xFFF7A5E1);
        absoluteMode = true;
      } else {
        /// Switch to Standard Pookie (Light)
        seedColor = const Color(0xFFFF8AD6);
        absoluteMode = false;
      }
    } else {
      /// Standard Absolute mode logic
      if (!value) {
        absoluteMode = false;
        DatabaseService.settingsBox.put("absoluteMode", false);
      }
    }

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
      /// Default to Light Pookie mode
      isDark = false;
      DatabaseService.settingsBox.put("darkMode", false);

      absoluteMode = false;
      DatabaseService.settingsBox.put("absoluteMode", false);

      seedColor = const Color(0xFFFF8AD6);
    } else {
      /// Restore previous settings
      final storedDark = DatabaseService.settingsBox.get(
        "darkMode",
        defaultValue: false,
      );

      isDark = storedDark;

      final storedAbsolute = DatabaseService.settingsBox.get(
        "absoluteMode",
        defaultValue: false,
      );

      absoluteMode = storedAbsolute;

      final storedColor = DatabaseService.settingsBox.get(
        "seedColor",
        defaultValue: Colors.indigo.toARGB32(),
      );

      seedColor = Color(storedColor);
    }

    notifyListeners();
  }

  void toggleAbsoluteMode(bool value) {
    if (pookieMode) {
      /// If user turns on Absolute mode while in Pookie mode,
      /// it forces Emo Pookie (Dark Mode).
      if (value) {
        isDark = true;
        DatabaseService.settingsBox.put("darkMode", true);

        seedColor = const Color(0xFFF7A5E1);
      } else {
        /// If turning off Absolute mode while in Pookie mode, 
        /// it reverts to Light Pookie.
        isDark = false;
        DatabaseService.settingsBox.put("darkMode", false);

        seedColor = const Color(0xFFFF8AD6);
      }
    }

    /// Absolute mode can be turned on only in dark mode normally
    if (!pookieMode && value && !isDark) {
      absoluteMode = false;
      DatabaseService.settingsBox.put("absoluteMode", false);
      return;
    }

    absoluteMode = value;
    DatabaseService.settingsBox.put("absoluteMode", value);

    notifyListeners();
  }
}
