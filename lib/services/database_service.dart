import 'package:hive_flutter/hive_flutter.dart';
import '../models/subject.dart';

class DatabaseService {

  static const String subjectsBoxName = "subjects";
  static const String attendanceBoxName = "attendance";
  static const String timetableBoxName = "timetable";
  static const String settingsBoxName = "settings";

  static bool _initialized = false;

  static Future<void> init() async {

    if (!_initialized) {
      await Hive.initFlutter();

      if (!Hive.isAdapterRegistered(SubjectAdapter().typeId)) {
        Hive.registerAdapter(SubjectAdapter());
      }

      _initialized = true;
    }

    if (!Hive.isBoxOpen(subjectsBoxName)) {
      await Hive.openBox(subjectsBoxName);
    }

    if (!Hive.isBoxOpen(attendanceBoxName)) {
      await Hive.openBox(attendanceBoxName);
    }

    if (!Hive.isBoxOpen(timetableBoxName)) {
      await Hive.openBox(timetableBoxName);
    }

    if (!Hive.isBoxOpen(settingsBoxName)) {
      await Hive.openBox(settingsBoxName);
    }

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