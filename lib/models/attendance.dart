import 'package:hive/hive.dart';

part 'attendance.g.dart';

@HiveType(typeId: 1)
enum AttendanceStatus {
  @HiveField(0)
  present,

  @HiveField(1)
  absent,

  @HiveField(2)
  cancelled,

  @HiveField(3)
  none,
}

@HiveType(typeId: 2)
class Attendance {
  @HiveField(0)
  final DateTime date;

  @HiveField(1)
  final String subjectId;

  @HiveField(2)
  int slotIndex;

  @HiveField(3)
  AttendanceStatus status;

  Attendance({
    required this.date,
    required this.subjectId,
    required this.slotIndex,
    this.status = AttendanceStatus.none,
  });
}
