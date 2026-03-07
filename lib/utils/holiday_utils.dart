import 'package:flutter/material.dart';
import '../providers/attendance_provider.dart';
import '../providers/timetable_provider.dart';
import '../models/attendance.dart';

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

bool isHoliday(
  DateTime day,
  AttendanceProvider attendance,
  TimetableProvider timetable,
) {
  final slots = timetable.getSlotsForDate(day);

  // Only Saturday (6) and Sunday (7) with no slots are holidays.
  // Weekdays with no slots are just "no timetable created".
  // Days with slots are never holidays, even if all cancelled.
  if (slots.isEmpty) {
    return day.weekday == 6 || day.weekday == 7;
  }

  return false;
}

/// Returns true when a day has no timetable slots at all
/// (regardless of weekday). Used to show "No timetable created".
bool hasNoSlots(DateTime day, TimetableProvider timetable) {
  return timetable.getSlotsForDate(day).isEmpty;
}

Color? getDayColor(
  DateTime day,
  AttendanceProvider attendance,
  TimetableProvider timetable,
) {
  final slots = timetable.getSlotsForDate(day);

  // No slots assigned
  if (slots.isEmpty) {
    // Only Sat/Sun get orange (holiday). Weekdays get no color.
    if (day.weekday == 6 || day.weekday == 7) {
      return const Color(0xFFFF9800); // orange
    }
    return null;
  }

  int present = 0;
  int absent = 0;
  int cancelled = 0;
  int none = 0;

  for (int i = 0; i < slots.length; i++) {
    final status = attendance.getStatus(day, i);

    if (status == AttendanceStatus.present) {
      present++;
    } else if (status == AttendanceStatus.absent) {
      absent++;
    } else if (status == AttendanceStatus.cancelled) {
      cancelled++;
    } else {
      none++;
    }
  }

  final total = slots.length;

  // All unmarked — no color
  if (none == total) return null;

  // All present
  if (present == total) return const Color(0xFF4CAF50); // green

  // All absent
  if (absent == total) return const Color(0xFFF44336); // red

  // All cancelled (or no subjects + all cancelled)
  if (cancelled == total) return const Color(0xFFFF9800); // orange

  // Mixed (combination of present, absent, cancelled, and possibly unmarked)
  return const Color(0xFF9C27B0); // purple
}
