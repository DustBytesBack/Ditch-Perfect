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

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'shortName': shortName,
        'minAttendance': minAttendance,
      };

  factory Subject.fromJson(Map<String, dynamic> json) => Subject(
        id: json['id'],
        name: json['name'],
        shortName: json['shortName'],
        minAttendance: (json['minAttendance'] as num).toDouble(),
      );
}
