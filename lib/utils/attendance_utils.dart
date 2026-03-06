import '../models/attendance.dart';

class AttendanceStats {
  final int attended;
  final int total;

  const AttendanceStats({
    required this.attended,
    required this.total,
  });

  double get percentage {
    if (total == 0) return 0;
    return (attended / total) * 100;
  }
}

AttendanceStats calculateStats(
  String subjectId,
  Iterable<Attendance> records,
) {
  int attended = 0;
  int total = 0;

  for (final r in records) {
    if (r.subjectId != subjectId) continue;

    if (r.status == AttendanceStatus.present) {
      attended++;
      total++;
    } else if (r.status == AttendanceStatus.absent) {
      total++;
    }
  }

  return AttendanceStats(
    attended: attended,
    total: total,
  );
}