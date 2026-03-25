import 'package:flutter/material.dart';
import '../services/database_service.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode themeMode = ThemeMode.system;
  bool isDynamicMode = false;
  bool absoluteMode = false;
  bool pookieMode = false;
  Color seedColor = Colors.indigo;

  void loadTheme() {
    final modeName = DatabaseService.settingsBox.get(
      "themeMode",
      defaultValue: "system",
    );
    themeMode = ThemeMode.values.firstWhere(
      (e) => e.name == modeName,
      orElse: () => ThemeMode.system,
    );

    isDynamicMode = DatabaseService.settingsBox.get(
      "isDynamicMode",
      defaultValue: false,
    );
    absoluteMode = DatabaseService.settingsBox.get(
      "absoluteMode",
      defaultValue: false,
    );
    pookieMode = DatabaseService.settingsBox.get(
      "pookieMode",
      defaultValue: false,
    );

    final colorValue = DatabaseService.settingsBox.get(
      "seedColor",
      defaultValue: Colors.indigo.toARGB32(),
    );
    seedColor = Color(colorValue);

    if (pookieMode) {
      // Pookie mode logic remains for backward compatibility or future use
      // but in the new UI it will likely be locked when Dynamic is on.
      seedColor = const Color(0xFFFF8AD6);
    }
  }

  void setThemeMode(ThemeMode mode) {
    themeMode = mode;
    DatabaseService.settingsBox.put("themeMode", mode.name);

    // Safety: If switching to light mode, ensure absolute mode is off
    if (mode == ThemeMode.light) {
      absoluteMode = false;
      DatabaseService.settingsBox.put("absoluteMode", false);
    }

    notifyListeners();
  }

  void toggleDynamicMode(bool value) {
    isDynamicMode = value;
    DatabaseService.settingsBox.put("isDynamicMode", value);

    if (value) {
      pookieMode = false;
      DatabaseService.settingsBox.put("pookieMode", false);
    }

    notifyListeners();
  }

  void toggleAbsoluteMode(bool value) {
    absoluteMode = value;
    DatabaseService.settingsBox.put("absoluteMode", value);
    notifyListeners();
  }

  void setSeedColor(Color color) {
    if (isDynamicMode) return;

    pookieMode = false;
    seedColor = color;
    DatabaseService.settingsBox.put("seedColor", color.toARGB32());
    DatabaseService.settingsBox.put("pookieMode", false);
    notifyListeners();
  }

  void togglePookie(bool value) {
    if (isDynamicMode && value) {
      isDynamicMode = false;
      DatabaseService.settingsBox.put("isDynamicMode", false);
    }

    pookieMode = value;
    DatabaseService.settingsBox.put("pookieMode", value);

    if (value) {
      themeMode = ThemeMode.light;
      DatabaseService.settingsBox.put("themeMode", "light");
      absoluteMode = false;
      DatabaseService.settingsBox.put("absoluteMode", false);
      seedColor = const Color(0xFFFF8AD6);
    } else {
      final colorValue = DatabaseService.settingsBox.get(
        "seedColor",
        defaultValue: Colors.indigo.toARGB32(),
      );
      seedColor = Color(colorValue);
    }

    notifyListeners();
  }
}
