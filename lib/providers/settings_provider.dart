import 'package:flutter/material.dart';
import '../services/database_service.dart';

class SettingsProvider extends ChangeNotifier {

  double _minAttendance = 75;

  double get minAttendance => _minAttendance;

  void loadSettings() {
    final box = DatabaseService.settingsBox;

    final stored = box.get("minAttendance");

    if (stored != null) {
      _minAttendance = (stored as num).toDouble();
    }

    notifyListeners();
  }

  void updateMinAttendance(double value) {

    _minAttendance = value;

    DatabaseService.settingsBox.put("minAttendance", value);

    notifyListeners();
  }
}