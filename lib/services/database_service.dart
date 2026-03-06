import 'package:hive_flutter/hive_flutter.dart';
import '../models/subject.dart';

class DatabaseService {
  static const String subjectsBoxName = "subjects";
  static const String attendanceBoxName = "attendance";
  static const String timetableBoxName = "timetable";
  static const String settingsBoxName = "settings";

  static Future<void> init() async {
    await Hive.initFlutter();

    Hive.registerAdapter(SubjectAdapter());
    
    await Hive.openBox(subjectsBoxName);
    await Hive.openBox(attendanceBoxName);
    await Hive.openBox(timetableBoxName);
    await Hive.openBox(settingsBoxName);

    final settings = Hive.box(settingsBoxName);
    if (!settings.containsKey("hoursPerDay")) {
      settings.put("hoursPerDay", 8);
    }

    if (!settings.containsKey("minAttendance")) {
      settings.put("minAttendance", 75);
    }
  }

  static Box get subjectsBox => Hive.box(subjectsBoxName);
  static Box get attendanceBox => Hive.box(attendanceBoxName);
  static Box get timetableBox => Hive.box(timetableBoxName);
  static Box get settingsBox => Hive.box(settingsBoxName);
}