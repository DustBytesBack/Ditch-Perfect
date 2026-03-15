import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';

class SettingsProvider extends ChangeNotifier {
  double _minAttendance = 75;

  bool _notificationsEnabled = true;
  int _notificationHour = 7;
  int _notificationMinute = 0;

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

  bool get notificationsEnabled => _notificationsEnabled;
  int get notificationHour => _notificationHour;
  int get notificationMinute => _notificationMinute;

  TimeOfDay get notificationTime =>
      TimeOfDay(hour: _notificationHour, minute: _notificationMinute);

  void loadSettings() {
    final box = DatabaseService.settingsBox;

    final stored = box.get("minAttendance");

    if (stored != null) {
      _minAttendance = (stored as num).toDouble();
    }

    // Load notification settings.
    _notificationsEnabled =
        box.get("notificationsEnabled", defaultValue: true) as bool;
    _notificationHour = box.get("notificationHour", defaultValue: 7) as int;
    _notificationMinute = box.get("notificationMinute", defaultValue: 0) as int;

    // One-time migration: force notifications on for existing users.
    final migrated = box.get("notifMigratedToOn", defaultValue: false) as bool;
    if (!migrated) {
      _notificationsEnabled = true;
      box.put("notificationsEnabled", true);
      box.put("notifMigratedToOn", true);
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

  /// Toggle daily notification on/off.
  Future<void> setNotificationsEnabled(bool enabled) async {
    _notificationsEnabled = enabled;
    DatabaseService.settingsBox.put("notificationsEnabled", enabled);

    if (enabled) {
      final granted = await NotificationService.requestPermission();
      if (!granted) {
        _notificationsEnabled = false;
        DatabaseService.settingsBox.put("notificationsEnabled", false);
        notifyListeners();
        return;
      }
      await NotificationService.scheduleDailyNotification(
        hour: _notificationHour,
        minute: _notificationMinute,
      );
    } else {
      await NotificationService.cancelDailyNotification();
    }

    notifyListeners();
  }

  /// Update the notification time and re-schedule.
  Future<void> setNotificationTime(TimeOfDay time) async {
    _notificationHour = time.hour;
    _notificationMinute = time.minute;

    DatabaseService.settingsBox.put("notificationHour", time.hour);
    DatabaseService.settingsBox.put("notificationMinute", time.minute);

    if (_notificationsEnabled) {
      await NotificationService.scheduleDailyNotification(
        hour: _notificationHour,
        minute: _notificationMinute,
      );
    }

    notifyListeners();
  }

  /// Re-schedule notification (call on app launch).
  Future<void> rescheduleNotificationIfEnabled() async {
    if (_notificationsEnabled) {
      final granted = await NotificationService.requestPermission();
      if (!granted) {
        _notificationsEnabled = false;
        DatabaseService.settingsBox.put("notificationsEnabled", false);
        notifyListeners();
        return;
      }
      await NotificationService.scheduleDailyNotification(
        hour: _notificationHour,
        minute: _notificationMinute,
      );
    }
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
