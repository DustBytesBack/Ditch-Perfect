enum AttendanceStatus {
  present,
  absent,
  cancelled,
  none
}

class Attendance {
  final DateTime date;
  final String subjectId;
  final int slotIndex;

  AttendanceStatus status;

  Attendance({
    required this.date,
    required this.subjectId,
    required this.slotIndex,
    this.status = AttendanceStatus.none,
  });
}