import 'package:hive_flutter/hive_flutter.dart';
import '../models/subject.dart';
import '../models/attendance.dart';

class DatabaseService {
  static const String subjectsBoxName = "subjects";
  static const String attendanceBoxName = "attendance";
  static const String timetableBoxName = "timetable";
  static const String settingsBoxName = "settings";
  static const String timetableRemovalsBoxName = "timetable_removals";

  static bool _initialized = false;

  static Future<void> init() async {
    // Always call initFlutter to ensure Hive path is set,
    // even after deleteFromDisk which removes the directory.
    await Hive.initFlutter();

    if (!_initialized) {
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(SubjectAdapter());
      }

      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(AttendanceStatusAdapter());
      }

      if (!Hive.isAdapterRegistered(2)) {
        Hive.registerAdapter(AttendanceAdapter());
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

    if (!Hive.isBoxOpen(timetableRemovalsBoxName)) {
      await Hive.openBox(timetableRemovalsBoxName);
    }

    final settings = Hive.box(settingsBoxName);

    if (!settings.containsKey("hoursPerDay")) {
      await settings.put("hoursPerDay", 8);
    }

    if (!settings.containsKey("minAttendance")) {
      await settings.put("minAttendance", 75);
    }

    if (!settings.containsKey("username")) {
      final randomId = (DateTime.now().millisecondsSinceEpoch % 9000) + 1000;
      await settings.put("username", "User_$randomId");
    }

    if (!settings.containsKey("isUsernameSet")) {
      await settings.put("isUsernameSet", false);
    }
  }

  static Box get subjectsBox => Hive.box(subjectsBoxName);

  static Box get attendanceBox => Hive.box(attendanceBoxName);

  static Box get timetableBox => Hive.box(timetableBoxName);

  static Box get settingsBox => Hive.box(settingsBoxName);

  static Box get timetableRemovalsBox => Hive.box(timetableRemovalsBoxName);
}
