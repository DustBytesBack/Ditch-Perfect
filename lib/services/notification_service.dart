import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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

  static const int _dailyNotificationId = 0;

  /// Initialise the plugin and timezone data. Call once at app startup.
  static Future<void> init() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(_localTimezoneName()));

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(initSettings);
  }

  /// Request notification permission (Android 13+).
  static Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
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
    // Cancel any previous notification first.
    await _plugin.cancel(_dailyNotificationId);

    // Compute the notification message for today.
    final message = _computeTodayMessage();

    // Nothing to notify about (weekend / no timetable).
    if (message == null) return;

    // Build the scheduled time.
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // If the time has already passed today, schedule for tomorrow.
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    const androidDetails = AndroidNotificationDetails(
      'daily_attendance',
      'Daily Attendance',
      channelDescription: 'Daily notification about attendance status',
      importance: Importance.high,
      priority: Priority.high,
    );

    const details = NotificationDetails(android: androidDetails);

    await _plugin.zonedSchedule(
      _dailyNotificationId,
      message.title,
      message.body,
      scheduledDate,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: null, // one-shot, re-scheduled on each launch
    );
  }

  /// Cancel the daily notification (when user disables notifications).
  static Future<void> cancelDailyNotification() async {
    await _plugin.cancel(_dailyNotificationId);
  }

  // ── Private helpers ────────────────────────────────────────────

  /// Compute whether the user can bunk today or needs to attend.
  ///
  /// Returns `null` if today has no timetable slots (holiday / empty).
  static _NotificationMessage? _computeTodayMessage() {
    final now = DateTime.now();
    final weekday = now.weekday; // 1=Mon..7=Sun

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
    final todayDate = DateTime(now.year, now.month, now.day);
    final dateKey = todayDate.toIso8601String();
    final extraStored = timetableBox.get(dateKey);

    List<String> extraSlots = [];
    if (extraStored != null) {
      extraSlots = List<String>.from(
        List.from(extraStored).where((e) => e != null).map((e) => e.toString()),
      );
    }

    final allSlots = [...baseSlots, ...extraSlots];

    // De-duplicate subject IDs for today (we care per-subject, not per-slot).
    final uniqueSubjectIds = allSlots.toSet();

    if (uniqueSubjectIds.isEmpty) return null;

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
      if (!uniqueSubjectIds.contains(sid)) continue;

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

    for (var sid in uniqueSubjectIds) {
      final a = attended[sid] ?? 0;
      final t = total[sid] ?? 0;

      // canBunk = floor(attended / p) - total
      final bunk = t == 0 ? 0 : ((a / p) - t).floor();

      if (bunk < 1) {
        allSafeToBunk = false;
        break;
      }
    }

    if (allSafeToBunk) {
      return _NotificationMessage(
        title: 'BUNK SAFE !!!',
        body:
            'All ${uniqueSubjectIds.length} subjects today are safe to bunk. Bunk you aah off!',
      );
    } else {
      return _NotificationMessage(
        title: 'Goofed around too much :(',
        body:
            'Sorry homie there\'s one subject that need your attendance to stay above ${minAttendance.toInt()}%.',
      );
    }
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
        if (tzOffset == offset.inMilliseconds) {
          return loc.name;
        }
      }
    } catch (_) {}

    return 'UTC';
  }
}

class _NotificationMessage {
  final String title;
  final String body;

  const _NotificationMessage({required this.title, required this.body});
}
