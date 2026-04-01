import 'package:flutter/material.dart';
import '../models/subject.dart';
import '../services/database_service.dart';
import 'package:uuid/uuid.dart';
import 'attendance_provider.dart';
import 'timetable_provider.dart';
import '../utils/ranking_utils.dart';

class SubjectProvider extends ChangeNotifier {
  final AttendanceProvider _attendanceProvider;
  final TimetableProvider _timetableProvider;

  SubjectProvider({
    required AttendanceProvider attendanceProvider,
    required TimetableProvider timetableProvider,
  }) : _attendanceProvider = attendanceProvider,
       _timetableProvider = timetableProvider;

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

    final subject = Subject(id: uuid.v4(), name: name, shortName: shortName);

    DatabaseService.subjectsBox.put(subject.id, subject);

    _subjects.add(subject);

    notifyListeners();
    RankingUtils.checkAndAutoUpload(force: true);
  }

  void renameSubject(String id, String newName, String newShortName) {
    final index = _subjects.indexWhere((s) => s.id == id);
    if (index == -1) return;

    final subject = _subjects[index];
    subject.name = newName;
    subject.shortName = newShortName;

    DatabaseService.subjectsBox.put(id, subject);

    notifyListeners();
    RankingUtils.checkAndAutoUpload(force: true);
  }

  /// DELETE SUBJECT FROM FUTURE TIMETABLE ONLY
  /// Removes the subject from the weekly timetable going forward, but
  /// past dates still show the subject and its attendance is preserved.
  /// Also removes from extra date-only slots (future dates).
  void deleteSubjectFuture(String id) {
    final tp = _timetableProvider;

    for (var day in tp.days) {
      final activeSlots = tp.getDaySlots(day);
      final count = activeSlots.where((s) => s == id).length;

      for (int i = 0; i < count; i++) {
        final currentActive = tp.getDaySlots(day);
        final idx = currentActive.indexOf(id);
        if (idx >= 0) {
          tp.removeSubjectAt(day, idx);
        }
      }
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final extraKeys = tp.extraSlots.keys.toList();

    for (final key in extraKeys) {
      final date = DateTime.tryParse(key);
      if (date == null || date.isBefore(today)) continue;

      final slots = tp.getSlotsForDate(date);
      final baseCount = tp.getBaseSlotsForDate(date).length;

      for (int i = slots.length - 1; i >= baseCount; i--) {
        if (slots[i] == id) {
          tp.removeExtraSubject(date, i - baseCount);
        }
      }
    }

    notifyListeners();
    RankingUtils.checkAndAutoUpload(force: true);
  }

  void reload() {
    _subjects.clear();

    // Safety: also clear the Hive box in case deleteFromDisk didn't
    // fully remove persisted data.
    try {
      DatabaseService.subjectsBox.clear();
    } catch (_) {}

    notifyListeners();
    RankingUtils.checkAndAutoUpload(force: true);
  }

  void updateMinAttendance(String subjectId, double value) {
    final subject = subjects.firstWhere((s) => s.id == subjectId);

    subject.minAttendance = value;

    DatabaseService.subjectsBox.put(subject.id, subject);

    notifyListeners();
    RankingUtils.checkAndAutoUpload(force: true);
  }

  /// DELETE SUBJECT COMPLETELY (PAST + FUTURE)
  void deleteSubjectCompletely(String id) {
    final subjectsBox = DatabaseService.subjectsBox;

    subjectsBox.delete(id);

    _subjects.removeWhere((s) => s.id == id);

    _timetableProvider.removeSubjectEverywhereById(id);
    _attendanceProvider.deleteRecordsForSubject(id);

    notifyListeners();
    RankingUtils.checkAndAutoUpload(force: true);
  }

  Subject? getSubjectById(String id) {
    try {
      return _subjects.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }
}
