import 'package:flutter/material.dart';
import '../models/attendance.dart';
import '../services/database_service.dart';

class AttendanceProvider extends ChangeNotifier {

  final Map<String, Attendance> _records = {};

  Map<String, Attendance> get records => _records;

  String buildKey(DateTime date, int slotIndex) {

    final d = DateTime(date.year, date.month, date.day);

    return "${d.toIso8601String()}_$slotIndex";
  }

  void loadDayAttendance(DateTime date) {

    final box = DatabaseService.attendanceBox;

    _records.clear();

    for (var key in box.keys) {

      final record = box.get(key) as Attendance;

      if (record.date.year == date.year &&
          record.date.month == date.month &&
          record.date.day == date.day) {

        _records[key] = record;
      }
    }

    notifyListeners();
  }

  void markAttendance(
    DateTime date,
    String subjectId,
    int slotIndex,
    AttendanceStatus status,
  ) {

    final box = DatabaseService.attendanceBox;

    final key = buildKey(date, slotIndex);

    final record = Attendance(
      date: DateTime(date.year, date.month, date.day),
      subjectId: subjectId,
      slotIndex: slotIndex,
      status: status,
    );

    box.put(key, record);

    _records[key] = record;

    notifyListeners();
  }

  void clearAttendance(DateTime date, int slotIndex) {

    final box = DatabaseService.attendanceBox;

    final key = buildKey(date, slotIndex);

    box.delete(key);

    _records.remove(key);

    notifyListeners();
  }

  AttendanceStatus getStatus(DateTime date, int slotIndex) {

    final key = buildKey(date, slotIndex);

    if (_records.containsKey(key)) {
      return _records[key]!.status;
    }

    return AttendanceStatus.none;
  }

  void markAll(
    DateTime date,
    List<String> subjects,
    AttendanceStatus status,
  ) {

    for (int i = 0; i < subjects.length; i++) {

      final subjectId = subjects[i];

      markAttendance(date, subjectId, i, status);
    }
  }

  /// NEW — used when database is reset
  void clearAll() {

    _records.clear();

    notifyListeners();
  }
}