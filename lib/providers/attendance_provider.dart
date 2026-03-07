import 'package:flutter/material.dart';
import '../models/attendance.dart';
import '../services/database_service.dart';

class AttendanceProvider extends ChangeNotifier {
  /// All attendance records from the Hive box, keyed by "date_slotIndex".
  final Map<String, Attendance> _records = {};

  Map<String, Attendance> get records => _records;

  String buildKey(DateTime date, int slotIndex) {
    final d = DateTime(date.year, date.month, date.day);

    return "${d.toIso8601String()}_$slotIndex";
  }

  /// Load ALL attendance records from Hive into memory.
  /// Called once on app startup and after data resets.
  void loadAllAttendance() {
    final box = DatabaseService.attendanceBox;

    _records.clear();

    for (var key in box.keys) {
      final record = box.get(key);

      if (record != null && record is Attendance) {
        _records[key.toString()] = record;
      }
    }

    notifyListeners();
  }

  /// Legacy method — now just calls loadAllAttendance.
  /// Kept for backward compatibility with any code that calls it.
  void loadDayAttendance(DateTime date) {
    // If records are empty, do a full load; otherwise the in-memory
    // cache is already up to date via markAttendance/clearAttendance.
    if (_records.isEmpty) {
      loadAllAttendance();
    } else {
      notifyListeners();
    }
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

  void markAll(DateTime date, List<String> subjects, AttendanceStatus status) {
    for (int i = 0; i < subjects.length; i++) {
      final subjectId = subjects[i];

      markAttendance(date, subjectId, i, status);
    }
  }

  /// Delete all attendance records for a specific subject.
  void deleteRecordsForSubject(String subjectId) {
    final box = DatabaseService.attendanceBox;

    final keysToDelete = <String>[];

    for (var entry in _records.entries) {
      if (entry.value.subjectId == subjectId) {
        keysToDelete.add(entry.key);
      }
    }

    for (var key in keysToDelete) {
      box.delete(key);
      _records.remove(key);
    }

    notifyListeners();
  }

  /// Notify listeners externally (e.g. when TimetableProvider modifies
  /// the in-memory records map directly during extra-subject removal).
  void notifyIfChanged() {
    notifyListeners();
  }

  /// Used when database is reset
  void clearAll() {
    _records.clear();

    // Safety: also clear the Hive box in case deleteFromDisk didn't
    // fully remove persisted data.
    try {
      DatabaseService.attendanceBox.clear();
    } catch (_) {}

    notifyListeners();
  }
}
