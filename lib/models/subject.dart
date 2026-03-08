import 'package:hive/hive.dart';

part 'subject.g.dart';

@HiveType(typeId: 0)
class Subject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String shortName;

  @HiveField(3)
  double minAttendance;

  Subject({
    required this.id,
    required this.name,
    required this.shortName,
    this.minAttendance = 75,
  });
}
