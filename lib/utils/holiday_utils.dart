import 'package:flutter/material.dart';
import '../providers/attendance_provider.dart';
import '../providers/timetable_provider.dart';
import '../models/attendance.dart';
import '../services/database_service.dart';

String weekdayKey(DateTime date) {
  const map = {
    1: "mon",
    2: "tue",
    3: "wed",
    4: "thu",
    5: "fri",
    6: "sat",
    7: "sun",
  };

  return map[date.weekday]!;
}

/// Build a key matching AttendanceProvider._key format
String _attendanceKey(DateTime date, int slotIndex) {
  final d = DateTime(date.year, date.month, date.day);
  return "${d.toIso8601String()}_$slotIndex";
}

/// Read attendance status for a specific day+slot directly from Hive,
/// so we don't depend on the provider's single-day in-memory cache.
AttendanceStatus _getStatusFromBox(DateTime day, int slotIndex) {
  final box = DatabaseService.attendanceBox;
  final key = _attendanceKey(day, slotIndex);
  final record = box.get(key);

  if (record != null && record is Attendance) {
    return record.status;
  }

  return AttendanceStatus.none;
}

/// Check if a day has no subjects assigned in the timetable
/// (all slots are null or the slot list is empty).
bool _hasNoSubjects(List<String?> slots) {
  if (slots.isEmpty) return true;

  for (final subjectId in slots) {
    if (subjectId != null) return false;
  }

  return true;
}

bool isHoliday(
  DateTime day,
  AttendanceProvider attendance,
  TimetableProvider timetable,
) {
  final slots = timetable.getDaySlots(weekdayKey(day));

  // A day with no subjects assigned is a holiday
  if (_hasNoSubjects(slots)) return true;

  // A day where every assigned slot is cancelled is also a holiday
  for (int i = 0; i < slots.length; i++) {
    final subjectId = slots[i];
    if (subjectId == null) continue;

    final status = _getStatusFromBox(day, i);

    if (status != AttendanceStatus.cancelled) {
      return false;
    }
  }

  return true;
}

Color? getDayColor(
  DateTime day,
  AttendanceProvider attendance,
  TimetableProvider timetable,
) {
  final slots = timetable.getDaySlots(weekdayKey(day));

  // Days with no subjects assigned are holidays — show orange
  if (_hasNoSubjects(slots)) {
    return const Color(0xFFFF9800); // orange for holidays
  }

  int present = 0;
  int absent = 0;
  int cancelled = 0;

  for (int i = 0; i < slots.length; i++) {
    final subjectId = slots[i];
    if (subjectId == null) continue;

    final status = _getStatusFromBox(day, i);

    if (status == AttendanceStatus.present) {
      present++;
    } else if (status == AttendanceStatus.absent) {
      absent++;
    } else if (status == AttendanceStatus.cancelled) {
      cancelled++;
    }
  }

  final total = present + absent + cancelled;

  if (total == 0) return null;

  if (present == total) return const Color(0xFF4CAF50); // green
  if (absent == total) return const Color(0xFFF44336); // red
  if (cancelled == total) return const Color(0xFFFF9800); // orange

  return const Color(0xFF9C27B0); // purple
}
