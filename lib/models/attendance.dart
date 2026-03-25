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
  none;

  String toJson() => name;

  static AttendanceStatus fromJson(String json) =>
      AttendanceStatus.values.byName(json);
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

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'subjectId': subjectId,
    'slotIndex': slotIndex,
    'status': status.toJson(),
  };

  factory Attendance.fromJson(Map<String, dynamic> json) => Attendance(
    date: DateTime.parse(json['date']),
    subjectId: json['subjectId'],
    slotIndex: json['slotIndex'],
    status: AttendanceStatus.fromJson(json['status']),
  );
}
