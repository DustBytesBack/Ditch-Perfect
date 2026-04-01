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

bool isHoliday(DateTime day, TimetableProvider timetable) {
  final isWeekend =
      day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
  final slots = timetable.getSlotsForDate(day);

  // A holiday is ONLY a Saturday/Sunday with no timetable slots assigned.
  // All-cancelled days are NOT holidays — they still show the normal timetable.
  return isWeekend && slots.isEmpty;
}

/// Returns true if this is a weekday with no timetable slots assigned.
bool isNoTimetable(DateTime day, TimetableProvider timetable) {
  final isWeekend =
      day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
  final slots = timetable.getSlotsForDate(day);

  return !isWeekend && slots.isEmpty;
}

Color? getDayColor(
  DateTime day,
  AttendanceProvider attendance,
  TimetableProvider timetable,
) {
  final slots = timetable.getSlotsForDate(day);
  final slotIds = timetable.getSlotIdsForDate(day);

  // Days with no subjects assigned
  if (slots.isEmpty) {
    // Sat/Sun with no slots = holiday = orange
    final isWeekend =
        day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
    if (isWeekend) return const Color(0xFFFF9800); // orange for holidays
    // Weekdays with no slots = no timetable created = no color
    return null;
  }

  int present = 0;
  int absent = 0;
  int cancelled = 0;
  int none = 0;

  for (int i = 0; i < slots.length; i++) {
    final status = attendance.getStatus(day, slotIds[i], legacySlotIndex: i);

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
  if ((present > 0) && absent == 0 && none == 0) {
    return const Color(0xFF4CAF50); // green
  }

  // All absent
  if ((absent > 0) && present == 0 && none == 0) {
    return const Color(0xFFF44336); // red
  }

  // All cancelled (or no subjects + all cancelled)
  if (cancelled == total) return const Color(0xFFFF9800); // orange

  // Mixed (combination of present, absent, cancelled, and possibly unmarked)
  if (present > 0 && absent > 0 && none == 0) {
    return const Color(0xFF9C27B0); // purple
  }

  return null;
}
