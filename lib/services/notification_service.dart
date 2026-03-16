import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/widgets.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/attendance.dart';
import '../services/database_service.dart';

/// Handles daily attendance notifications.
///
/// On each [scheduleDailyNotification] call the service:
///  1. Cancels any previously scheduled notification.
///  2. Computes whether the user can safely bunk today or needs to attend.
///  3. Schedules a one-shot notification at the user-chosen time (today or
///     tomorrow if the time has already passed).
///
/// Call this on every app launch and whenever notification settings change.
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const int _notificationIdBase = 1000;
  static const int _scheduleWindowDays = 60;

  static bool _initialized = false;
  static bool _appInForeground = false;
  static int? _lastScheduledHour;
  static int? _lastScheduledMinute;
  static final Map<int, Timer> _foregroundBridgeTimers = {};
  static final _NotificationLifecycleObserver _lifecycleObserver =
      _NotificationLifecycleObserver();

  /// Initialise the plugin and timezone data. Call once at app startup.
  /// Wrapped in try-catch so a notification init failure never prevents
  /// the app from launching.
  static Future<void> init() async {
    try {
      tz.initializeTimeZones();
      final tzName = _localTimezoneName();
      tz.setLocalLocation(tz.getLocation(tzName));
    } catch (_) {
      // Fallback — ensure timezone is at least UTC.
      try {
        tz.setLocalLocation(tz.getLocation('UTC'));
      } catch (_) {}
    }

    try {
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );

      const initSettings = InitializationSettings(android: androidSettings);

      await _plugin.initialize(settings: initSettings);
      WidgetsBinding.instance.addObserver(_lifecycleObserver);
      _appInForeground =
          WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
      _initialized = true;
    } catch (_) {
      // Plugin init failed — notifications won't work but app still runs.
      _initialized = false;
    }
  }

  /// Request notification permission (Android 13+).
  static Future<bool> requestPermission() async {
    if (!_initialized) return false;

    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      if (android != null) {
        final granted = await android.requestNotificationsPermission();
        return granted ?? false;
      }
    } catch (_) {
      return false;
    }

    return true;
  }

  /// Schedule the daily attendance notification.
  ///
  /// [hour] / [minute] — the time of day to fire the notification.
  ///
  /// Reads timetable + attendance data directly from Hive so it works
  /// without needing provider instances (can be called from main).
  static Future<void> scheduleDailyNotification({
    required int hour,
    required int minute,
  }) async {
    if (!_initialized) return;

    try {
      _lastScheduledHour = hour;
      _lastScheduledMinute = minute;

      await cancelDailyNotification();

      final now = tz.TZDateTime.now(tz.local);

      const androidDetails = AndroidNotificationDetails(
        'daily_attendance',
        'Daily Attendance',
        channelDescription: 'Daily notification about attendance status',
        importance: Importance.high,
        priority: Priority.high,
      );

      const details = NotificationDetails(android: androidDetails);

      final bridgeSchedules = <_ForegroundBridgeSchedule>[];

      for (int offset = 0; offset < _scheduleWindowDays; offset++) {
        final target = DateTime(now.year, now.month, now.day + offset);
        final message = _computeMessageForDate(target);
        if (message == null) continue;

        final scheduledDate = tz.TZDateTime(
          tz.local,
          target.year,
          target.month,
          target.day,
          hour,
          minute,
        );

        if (!scheduledDate.isAfter(now)) {
          continue;
        }

        await _plugin.zonedSchedule(
          id: _notificationIdBase + offset,
          title: message.title,
          body: message.body,
          scheduledDate: scheduledDate,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: null,
        );

        bridgeSchedules.add(
          _ForegroundBridgeSchedule(
            id: _notificationIdBase + offset,
            scheduledDate: scheduledDate,
            title: message.title,
            body: message.body,
          ),
        );
      }

      _armForegroundBridge(bridgeSchedules, details);
    } catch (_) {
      // Scheduling failed — don't crash the app.
    }
  }

  /// Cancel the daily notification (when user disables notifications).
  static Future<void> cancelDailyNotification() async {
    if (!_initialized) return;

    try {
      _clearForegroundBridgeTimers();

      for (int offset = 0; offset < _scheduleWindowDays; offset++) {
        await _plugin.cancel(id: _notificationIdBase + offset);
      }
    } catch (_) {
      // Non-critical.
    }
  }

  // ── Private helpers ────────────────────────────────────────────

  /// Compute whether the user can bunk today or needs to attend.
  ///
  /// Returns `null` if today has no timetable slots (holiday / empty).
  static _NotificationMessage? _computeMessageForDate(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final weekday = day.weekday; // 1=Mon..7=Sun

    const days = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
    final dayKey = days[weekday - 1];

    // Get today's base slots from Hive.
    final timetableBox = DatabaseService.timetableBox;
    final stored = timetableBox.get(dayKey);

    List<String> baseSlots = [];
    if (stored != null) {
      baseSlots = List<String>.from(
        List.from(stored).where((e) => e != null).map((e) => e.toString()),
      );
    }

    // Get extra date-specific slots.
    final dateKey = day.toIso8601String();
    final extraStored = timetableBox.get(dateKey);

    List<String> extraSlots = [];
    if (extraStored != null) {
      extraSlots = List<String>.from(
        List.from(extraStored).where((e) => e != null).map((e) => e.toString()),
      );
    }

    final allSlots = [...baseSlots, ...extraSlots];
    final occurrencesBySubject = <String, int>{};

    for (final subjectId in allSlots) {
      occurrencesBySubject[subjectId] =
          (occurrencesBySubject[subjectId] ?? 0) + 1;
    }

    if (occurrencesBySubject.isEmpty) return null;

    // Get min attendance from settings.
    final settingsBox = DatabaseService.settingsBox;
    final minAttendanceRaw = settingsBox.get('minAttendance', defaultValue: 75);
    final minAttendance = (minAttendanceRaw as num).toDouble();
    final p = minAttendance / 100;

    // Load attendance stats per subject.
    final attendanceBox = DatabaseService.attendanceBox;

    // Aggregate attended/total per subject.
    final Map<String, int> attended = {};
    final Map<String, int> total = {};

    for (var key in attendanceBox.keys) {
      final record = attendanceBox.get(key);
      if (record == null || record is! Attendance) continue;

      final sid = record.subjectId;
      if (!occurrencesBySubject.containsKey(sid)) continue;

      if (record.status == AttendanceStatus.present) {
        attended[sid] = (attended[sid] ?? 0) + 1;
        total[sid] = (total[sid] ?? 0) + 1;
      } else if (record.status == AttendanceStatus.absent) {
        total[sid] = (total[sid] ?? 0) + 1;
      }
      // cancelled / unmarked don't count toward total.
    }

    // Check if every subject today can be safely bunked (canBunk >= 1).
    bool allSafeToBunk = true;

    for (var sid in occurrencesBySubject.keys) {
      final a = attended[sid] ?? 0;
      final t = total[sid] ?? 0;
      final requiredBunks = occurrencesBySubject[sid] ?? 0;

      // canBunk = floor(attended / p) - total
      final bunk = t == 0 ? 0 : ((a / p) - t).floor();

      if (bunk < requiredBunks) {
        allSafeToBunk = false;
        break;
      }
    }

    if (allSafeToBunk) {
      return _NotificationMessage(
        title: 'BUNK SAFE !!!',
        body:
            'All ${allSlots.length} classes on ${_labelForDate(day)} are safe to bunk. Bunk you aah off!',
      );
    } else {
      return _NotificationMessage(
        title: 'Goofed around too much :(',
        body:
            'Sorry homie, at least one class on ${_labelForDate(day)} needs your attendance to stay above ${minAttendance.toInt()}%.',
      );
    }
  }

  static String _labelForDate(DateTime date) {
    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);
    final normalizedDate = DateTime(date.year, date.month, date.day);

    if (normalizedDate == normalizedToday) return 'today';
    if (normalizedDate == normalizedToday.add(const Duration(days: 1))) {
      return 'tomorrow';
    }

    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[normalizedDate.weekday - 1];
  }

  /// Get the local timezone name. Falls back to UTC if unavailable.
  static String _localTimezoneName() {
    try {
      final offset = DateTime.now().timeZoneOffset;
      // Find a timezone matching the current offset.
      // This is a rough heuristic; most Android devices report Asia/Kolkata etc.
      // via the native timezone plugin, but we keep it simple here.
      final hours = offset.inHours;
      final minutes = offset.inMinutes % 60;

      // Common mappings for Indian timezone (the likely user base).
      if (hours == 5 && minutes == 30) return 'Asia/Kolkata';
      if (hours == 0 && minutes == 0) return 'UTC';

      // Fallback: try to find by offset.
      for (var loc in tz.timeZoneDatabase.locations.values) {
        final tzOffset = loc.currentTimeZone.offset;
        if (tzOffset.inMilliseconds == offset.inMilliseconds) {
          return loc.name;
        }
      }
    } catch (_) {}

    return 'UTC';
  }

  static void _armForegroundBridge(
    List<_ForegroundBridgeSchedule> schedules,
    NotificationDetails details,
  ) {
    _clearForegroundBridgeTimers();

    if (!_appInForeground) return;

    final now = tz.TZDateTime.now(tz.local);

    for (final schedule in schedules) {
      final delay = schedule.scheduledDate.difference(now);
      if (delay.isNegative || delay == Duration.zero) continue;

      _foregroundBridgeTimers[schedule.id] = Timer(delay, () async {
        if (!_appInForeground) return;

        try {
          await _plugin.show(
            id: schedule.id,
            title: schedule.title,
            body: schedule.body,
            notificationDetails: details,
          );
        } catch (_) {}

        _foregroundBridgeTimers.remove(schedule.id);
      });
    }
  }

  static void _clearForegroundBridgeTimers() {
    for (final timer in _foregroundBridgeTimers.values) {
      timer.cancel();
    }
    _foregroundBridgeTimers.clear();
  }

  static void _handleLifecycleChanged(AppLifecycleState state) {
    _appInForeground = state == AppLifecycleState.resumed;

    if (_appInForeground) {
      final hour = _lastScheduledHour;
      final minute = _lastScheduledMinute;
      if (hour != null && minute != null) {
        unawaited(scheduleDailyNotification(hour: hour, minute: minute));
      }
    } else {
      _clearForegroundBridgeTimers();
    }
  }
}

class _NotificationMessage {
  final String title;
  final String body;

  const _NotificationMessage({required this.title, required this.body});
}

class _ForegroundBridgeSchedule {
  final int id;
  final tz.TZDateTime scheduledDate;
  final String title;
  final String body;

  const _ForegroundBridgeSchedule({
    required this.id,
    required this.scheduledDate,
    required this.title,
    required this.body,
  });
}

class _NotificationLifecycleObserver with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    NotificationService._handleLifecycleChanged(state);
  }
}
