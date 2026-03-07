import 'package:flutter/material.dart';
import '../models/subject.dart';
import '../services/database_service.dart';
import 'package:uuid/uuid.dart';

class SubjectProvider extends ChangeNotifier {
  final List<Subject> _subjects = [];

  List<Subject> get subjects => _subjects;

  void loadSubjects() {
    final box = DatabaseService.subjectsBox;

    _subjects.clear();

    for (var item in box.values) {
      _subjects.add(item as Subject);
    }

    notifyListeners();
  }

  void addSubject(String name, String shortName) {
    final uuid = const Uuid();

    final subject = Subject(
      id: uuid.v4(),
      name: name,
      shortName: shortName,
    );

    DatabaseService.subjectsBox.put(subject.id, subject);

    _subjects.add(subject);

    notifyListeners();
  }

  /// DELETE SUBJECT FROM FUTURE TIMETABLE ONLY
  void deleteSubjectFuture(String id) {
    final timetableBox = DatabaseService.timetableBox;

    for (var key in timetableBox.keys) {
      final daySlots = List<String?>.from(timetableBox.get(key));

      for (int i = 0; i < daySlots.length; i++) {
        if (daySlots[i] == id) {
          daySlots[i] = null;
        }
      }

      timetableBox.put(key, daySlots);
    }

    notifyListeners();
  }

  void reload() {
    notifyListeners();
  }

  void updateMinAttendance(String subjectId, double value) {

    final subject = subjects.firstWhere((s) => s.id == subjectId);

    subject.minAttendance = value;

    DatabaseService.subjectsBox.put(subject.id, subject);

    notifyListeners();
  }

  /// DELETE SUBJECT COMPLETELY (PAST + FUTURE)
  void deleteSubjectCompletely(String id) {
    final subjectsBox = DatabaseService.subjectsBox;
    final timetableBox = DatabaseService.timetableBox;
    final attendanceBox = DatabaseService.attendanceBox;

    subjectsBox.delete(id);

    _subjects.removeWhere((s) => s.id == id);

    /// remove from timetable
    for (var key in timetableBox.keys) {
      final daySlots = List<String?>.from(timetableBox.get(key));

      for (int i = 0; i < daySlots.length; i++) {
        if (daySlots[i] == id) {
          daySlots[i] = null;
        }
      }

      timetableBox.put(key, daySlots);
    }

    /// remove attendance history
    final keysToDelete = [];

    for (var key in attendanceBox.keys) {
      final record = attendanceBox.get(key);

      if (record.subjectId == id) {
        keysToDelete.add(key);
      }
    }

    for (var key in keysToDelete) {
      attendanceBox.delete(key);
    }

    notifyListeners();
  }

  Subject? getSubjectById(String id) {
    try {
      return _subjects.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }
}