import '../providers/attendance_provider.dart';
import '../providers/timetable_provider.dart';
import '../models/attendance.dart';

class CalendarStats {
  int notMarked = 0;
  int cancelled = 0;
  int missed = 0;
  int attended = 0;
  int mixed = 0;
}

CalendarStats calculateMonthStats(
  DateTime focusedMonth,
  AttendanceProvider attendance,
  TimetableProvider timetable,
) {
  final stats = CalendarStats();

  final firstDay = DateTime(focusedMonth.year, focusedMonth.month, 1);
  final lastDay = DateTime(focusedMonth.year, focusedMonth.month + 1, 0);

  for (
    DateTime day = firstDay;
    !day.isAfter(lastDay);
    day = day.add(const Duration(days: 1))
  ) {
    if (day.isAfter(DateTime.now())) continue;

    final slots = timetable.getSlotsForDate(day);
    final slotIds = timetable.getSlotIdsForDate(day);

    // Days with no subjects — treat as holiday/off day
    if (slots.isEmpty) {
      stats.cancelled++;
      continue;
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

    final totalSubjects = slots.length;

    if (none == totalSubjects) {
      stats.notMarked++;
    } else if (cancelled == totalSubjects) {
      stats.cancelled++;
    } else if (present > 0 &&
        absent > 0 &&
        ((present + absent + cancelled) == totalSubjects)) {
      stats.mixed++;
    } else if (present > 0 &&
        absent == 0 &&
        ((present + absent + cancelled) == totalSubjects)) {
      stats.attended++;
    } else if (absent > 0 &&
        present == 0 &&
        ((present + absent + cancelled) == totalSubjects)) {
      stats.missed++;
    }
  }

  return stats;
}
