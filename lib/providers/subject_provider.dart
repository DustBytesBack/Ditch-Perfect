import 'package:flutter/material.dart';
import '../models/subject.dart';
import '../models/attendance.dart';
import '../services/database_service.dart';
import 'package:uuid/uuid.dart';
import 'attendance_provider.dart';
import 'timetable_provider.dart';

class SubjectProvider extends ChangeNotifier {
  final List<Subject> _subjects = [];

  /// Optional references to other providers for cross-cache invalidation.
  /// Set via [setProviders] after all providers are created.
  AttendanceProvider? _attendanceProvider;
  TimetableProvider? _timetableProvider;

  List<Subject> get subjects => _subjects;

  /// Inject references to other providers so deletion methods can
  /// keep their in-memory caches in sync.
  void setProviders({
    required AttendanceProvider attendanceProvider,
    required TimetableProvider timetableProvider,
  }) {
    _attendanceProvider = attendanceProvider;
    _timetableProvider = timetableProvider;
  }

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

    final subject = Subject(id: uuid.v4(), name: name, shortName: shortName);

    DatabaseService.subjectsBox.put(subject.id, subject);

    _subjects.add(subject);

    notifyListeners();
  }

  /// DELETE SUBJECT FROM FUTURE TIMETABLE ONLY
  /// Removes the subject from the weekly timetable going forward, but
  /// past dates still show the subject and its attendance is preserved.
  /// Also removes from extra date-only slots (future dates).
  void deleteSubjectFuture(String id) {
    if (_timetableProvider != null) {
      final tp = _timetableProvider!;

      // For each weekday, add a removal for every active occurrence of
      // this subject. This hides it from today onward while preserving
      // historical views.
      for (var day in tp.days) {
        final activeSlots = tp.getDaySlots(day);
        final count = activeSlots.where((s) => s == id).length;

        for (int i = 0; i < count; i++) {
          // Find the index of this subject in the current active list.
          // After each removeSubjectAt call, getDaySlots is refreshed.
          final currentActive = tp.getDaySlots(day);
          final idx = currentActive.indexOf(id);
          if (idx >= 0) {
            tp.removeSubjectAt(day, idx);
          }
        }
      }

      // Remove from extra date-only slots — these are future-specific
      // additions, so just remove them outright.
      final timetableBox = DatabaseService.timetableBox;
      for (var key in timetableBox.keys.toList()) {
        final keyStr = key.toString();
        if (tp.days.contains(keyStr)) continue; // skip weekday keys

        final stored = timetableBox.get(key);
        if (stored == null) continue;

        final daySlots = List<String>.from(
          List.from(stored).where((e) => e != null).map((e) => e.toString()),
        );

        final hadSubject = daySlots.contains(id);
        daySlots.removeWhere((s) => s == id);

        if (hadSubject) {
          if (daySlots.isEmpty) {
            timetableBox.delete(key);
            tp.extraSlots.remove(keyStr);
          } else {
            timetableBox.put(key, daySlots);
            tp.extraSlots[keyStr] = daySlots;
          }
        }
      }

      tp.notifyListeners();
    } else {
      // Fallback if TimetableProvider not wired: direct Hive modification.
      final timetableBox = DatabaseService.timetableBox;

      for (var key in timetableBox.keys.toList()) {
        final stored = timetableBox.get(key);
        if (stored == null) continue;

        final daySlots = List<String?>.from(stored);
        daySlots.removeWhere((s) => s == id);
        timetableBox.put(key, daySlots);
      }
    }

    notifyListeners();
  }

  void reload() {
    _subjects.clear();

    // Safety: also clear the Hive box in case deleteFromDisk didn't
    // fully remove persisted data.
    try {
      DatabaseService.subjectsBox.clear();
    } catch (_) {}

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

    subjectsBox.delete(id);

    _subjects.removeWhere((s) => s.id == id);

    if (_timetableProvider != null) {
      final tp = _timetableProvider!;

      // Physically remove from _week (full historical timetable).
      final timetableBox = DatabaseService.timetableBox;

      for (var day in tp.days) {
        final fullSlots = tp.week[day] ?? [];
        fullSlots.removeWhere((s) => s == id);
        timetableBox.put(day, fullSlots);
      }

      // Remove from extra date-only slots.
      for (var key in timetableBox.keys.toList()) {
        final keyStr = key.toString();
        if (tp.days.contains(keyStr)) continue;

        final stored = timetableBox.get(key);
        if (stored == null) continue;

        final daySlots = List<String>.from(
          List.from(stored).where((e) => e != null).map((e) => e.toString()),
        );

        final hadSubject = daySlots.contains(id);
        daySlots.removeWhere((s) => s == id);

        if (hadSubject) {
          if (daySlots.isEmpty) {
            timetableBox.delete(key);
            tp.extraSlots.remove(keyStr);
          } else {
            timetableBox.put(key, daySlots);
            tp.extraSlots[keyStr] = daySlots;
          }
        }
      }

      // Clean up any removal records for this subject.
      tp.removeRemovalsForSubject(id);

      tp.notifyListeners();
    } else {
      // Fallback: direct Hive modification.
      final timetableBox = DatabaseService.timetableBox;

      for (var key in timetableBox.keys.toList()) {
        final stored = timetableBox.get(key);
        if (stored == null) continue;

        final daySlots = List<String?>.from(stored);
        daySlots.removeWhere((s) => s == id);
        timetableBox.put(key, daySlots);
      }
    }

    // Purge attendance records.
    if (_attendanceProvider != null) {
      _attendanceProvider!.deleteRecordsForSubject(id);
    } else {
      final attendanceBox = DatabaseService.attendanceBox;

      final keysToDelete = [];

      for (var key in attendanceBox.keys) {
        final record = attendanceBox.get(key);

        if (record != null && record is Attendance && record.subjectId == id) {
          keysToDelete.add(key);
        }
      }

      for (var key in keysToDelete) {
        attendanceBox.delete(key);
      }
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
