import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../services/database_service.dart';

class SettingsProvider extends ChangeNotifier {
  double _minAttendance = 75;

  StreamSubscription<BoxEvent>? _boxSubscription;

  /// Always returns the latest value from Hive, since the settings page
  /// may write directly to Hive without going through this provider.
  double get minAttendance {
    final stored = DatabaseService.settingsBox.get("minAttendance");
    if (stored != null) {
      return (stored as num).toDouble();
    }
    return _minAttendance;
  }

  void loadSettings() {
    final box = DatabaseService.settingsBox;

    final stored = box.get("minAttendance");

    if (stored != null) {
      _minAttendance = (stored as num).toDouble();
    }

    // Watch for external writes to the settings box (e.g. from settings page
    // which writes directly to Hive without going through this provider).
    _boxSubscription?.cancel();
    _boxSubscription = box.watch().listen((event) {
      if (event.key == "minAttendance") {
        final val = event.value;
        if (val != null) {
          _minAttendance = (val as num).toDouble();
        }
        notifyListeners();
      }
    });

    notifyListeners();
  }

  void updateMinAttendance(double value) {
    _minAttendance = value;

    DatabaseService.settingsBox.put("minAttendance", value);

    notifyListeners();
  }

  /// Refresh from Hive — call after settings page changes.
  void refresh() {
    loadSettings();
  }

  @override
  void dispose() {
    _boxSubscription?.cancel();
    super.dispose();
  }
}
