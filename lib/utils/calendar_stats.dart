import '../providers/attendance_provider.dart';
import '../providers/timetable_provider.dart';
import '../models/attendance.dart';
import '../utils/holiday_utils.dart';

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

  for (DateTime day = firstDay;
      !day.isAfter(lastDay);
      day = day.add(const Duration(days: 1))) {
      
    if (day.isAfter(DateTime.now())) continue;

    /// If timetable says it's a holiday
    if (isHoliday(day, attendance, timetable)) {
      stats.cancelled++;
      continue;
    }

    final slots = timetable.getDaySlots(weekdayKey(day));

    int present = 0;
    int absent = 0;
    int cancelled = 0;
    int none = 0;

    int totalSubjects = 0;

    for (int i = 0; i < slots.length; i++) {
      final subjectId = slots[i];

      totalSubjects++;

      final status = attendance.getStatus(day, i);

      if (status == AttendanceStatus.present) {
        present++;
      } else if (status == AttendanceStatus.absent) absent++;
      else if (status == AttendanceStatus.cancelled) cancelled++;
      else none++;
    }

    if (totalSubjects == 0) {
      stats.cancelled++;
      continue;
    }

    if (none == totalSubjects) {
      stats.notMarked++;
    }
    else if (cancelled == totalSubjects) {
      stats.cancelled++;
    }
    else if (absent == totalSubjects) {
      stats.missed++;
    }
    else if (present == totalSubjects) {
      stats.attended++;
    }
    else {
      stats.mixed++;
    }
  }

  return stats;
}