import '../models/attendance.dart';

class AttendanceStats {
  final int attended;
  final int total;
  final int cancelled;

  const AttendanceStats({
    required this.attended,
    required this.total,
    this.cancelled = 0,
  });

  double get percentage {
    if (total == 0) return 0;
    return (attended / total) * 100;
  }

  int get missed => total - attended;
}

AttendanceStats calculateStats(String subjectId, Iterable<Attendance> records) {
  int attended = 0;
  int total = 0;
  int cancelled = 0;

  for (final r in records) {
    if (r.subjectId != subjectId) continue;

    if (r.status == AttendanceStatus.present) {
      attended++;
      total++;
    } else if (r.status == AttendanceStatus.absent) {
      total++;
    } else if (r.status == AttendanceStatus.cancelled) {
      cancelled++;
    }
  }

  return AttendanceStats(
    attended: attended,
    total: total,
    cancelled: cancelled,
  );
}
