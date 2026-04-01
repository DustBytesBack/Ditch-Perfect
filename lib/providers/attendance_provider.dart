import 'package:flutter/material.dart';
import '../models/attendance.dart';
import '../services/database_service.dart';
import '../utils/ranking_utils.dart';
import '../utils/attendance_utils.dart';

class AttendanceProvider extends ChangeNotifier {
  final Map<String, Attendance> _records = {};
  final Map<String, AttendanceStats> _subjectStatsCache = {};
  final Map<String, AttendanceStats> _subjectBaselineCache = {};

  Map<String, Attendance> get records => _records;

  String _dateKey(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.toIso8601String();
  }

  String _slotIdKey(DateTime date, String slotId) {
    return '${_dateKey(date)}_$slotId';
  }

  String _legacyIndexKey(DateTime date, int slotIndex) {
    return '${_dateKey(date)}_$slotIndex';
  }

  AttendanceStats getStatsForSubject(String subjectId) {
    return _subjectStatsCache[subjectId] ??
        _subjectBaselineCache[subjectId] ??
        const AttendanceStats(attended: 0, total: 0, cancelled: 0);
  }

  void _loadBaselines() {
    _subjectBaselineCache.clear();

    for (final key in DatabaseService.attendanceBaselinesBox.keys) {
      final subjectId = key.toString();
      final raw = DatabaseService.attendanceBaselinesBox.get(key);
      if (raw is! Map) continue;

      final attended = (raw['attended'] as num?)?.toInt() ?? 0;
      final total = (raw['total'] as num?)?.toInt() ?? 0;

      _subjectBaselineCache[subjectId] = AttendanceStats(
        attended: attended.clamp(0, total),
        total: total < 0 ? 0 : total,
      );
    }
  }

  void _migrateLegacyBaselines() {
    final legacyPerSubject = <String, AttendanceStats>{};
    final legacyKeys = <String>[];

    for (final entry in _records.entries) {
      final record = entry.value;
      final isLegacyBaseline = record.date.year == 2000 && record.slotIndex < 0;
      if (!isLegacyBaseline) continue;

      legacyKeys.add(entry.key);
      final current =
          legacyPerSubject[record.subjectId] ??
          const AttendanceStats(attended: 0, total: 0, cancelled: 0);

      int attended = current.attended;
      int total = current.total;

      if (record.status == AttendanceStatus.present) {
        attended++;
        total++;
      } else if (record.status == AttendanceStatus.absent) {
        total++;
      }

      legacyPerSubject[record.subjectId] = AttendanceStats(
        attended: attended,
        total: total,
      );
    }

    if (legacyKeys.isEmpty) return;

    for (final entry in legacyPerSubject.entries) {
      DatabaseService.attendanceBaselinesBox.put(entry.key, {
        'attended': entry.value.attended,
        'total': entry.value.total,
      });
    }

    for (final key in legacyKeys) {
      DatabaseService.attendanceBox.delete(key);
      _records.remove(key);
    }
  }

  void _rebuildStatsCache() {
    final attendedBySubject = <String, int>{};
    final totalBySubject = <String, int>{};
    final cancelledBySubject = <String, int>{};

    for (final record in _records.values) {
      final subjectId = record.subjectId;

      if (record.status == AttendanceStatus.present) {
        attendedBySubject[subjectId] = (attendedBySubject[subjectId] ?? 0) + 1;
        totalBySubject[subjectId] = (totalBySubject[subjectId] ?? 0) + 1;
      } else if (record.status == AttendanceStatus.absent) {
        totalBySubject[subjectId] = (totalBySubject[subjectId] ?? 0) + 1;
      } else if (record.status == AttendanceStatus.cancelled) {
        cancelledBySubject[subjectId] =
            (cancelledBySubject[subjectId] ?? 0) + 1;
      }
    }

    _subjectStatsCache.clear();

    final allSubjects = <String>{
      ..._subjectBaselineCache.keys,
      ...attendedBySubject.keys,
      ...totalBySubject.keys,
      ...cancelledBySubject.keys,
    };

    for (final subjectId in allSubjects) {
      final baseline =
          _subjectBaselineCache[subjectId] ??
          const AttendanceStats(attended: 0, total: 0, cancelled: 0);

      _subjectStatsCache[subjectId] = AttendanceStats(
        attended: baseline.attended + (attendedBySubject[subjectId] ?? 0),
        total: baseline.total + (totalBySubject[subjectId] ?? 0),
        cancelled: baseline.cancelled + (cancelledBySubject[subjectId] ?? 0),
      );
    }
  }

  void loadAllAttendance() {
    final box = DatabaseService.attendanceBox;

    _records.clear();

    for (final key in box.keys) {
      final record = box.get(key);
      if (record != null && record is Attendance) {
        _records[key.toString()] = record;
      }
    }

    _migrateLegacyBaselines();
    _loadBaselines();
    _rebuildStatsCache();

    notifyListeners();
  }

  void loadDayAttendance(DateTime date) {
    if (_records.isEmpty) {
      loadAllAttendance();
    } else {
      notifyListeners();
    }
  }

  void markAttendance(
    DateTime date,
    String subjectId,
    String slotId,
    AttendanceStatus status, {
    int slotIndex = -1,
  }) {
    final key = _slotIdKey(date, slotId);
    final record = Attendance(
      date: DateTime(date.year, date.month, date.day),
      subjectId: subjectId,
      slotIndex: slotIndex,
      status: status,
      slotId: slotId,
    );

    DatabaseService.attendanceBox.put(key, record);
    _records[key] = record;

    _rebuildStatsCache();
    notifyListeners();
    RankingUtils.checkAndAutoUpload();
  }

  void clearAttendance(DateTime date, String slotId, {int? legacySlotIndex}) {
    final key = _slotIdKey(date, slotId);
    DatabaseService.attendanceBox.delete(key);
    _records.remove(key);

    if (legacySlotIndex != null) {
      final legacyKey = _legacyIndexKey(date, legacySlotIndex);
      DatabaseService.attendanceBox.delete(legacyKey);
      _records.remove(legacyKey);
    }

    _rebuildStatsCache();
    notifyListeners();
    RankingUtils.checkAndAutoUpload();
  }

  AttendanceStatus getStatus(
    DateTime date,
    String slotId, {
    int? legacySlotIndex,
  }) {
    final key = _slotIdKey(date, slotId);
    if (_records.containsKey(key)) {
      return _records[key]!.status;
    }

    if (legacySlotIndex != null) {
      final legacyKey = _legacyIndexKey(date, legacySlotIndex);
      if (_records.containsKey(legacyKey)) {
        final legacy = _records[legacyKey]!;
        final migrated = Attendance(
          date: legacy.date,
          subjectId: legacy.subjectId,
          slotIndex: legacy.slotIndex,
          status: legacy.status,
          slotId: slotId,
        );

        DatabaseService.attendanceBox.delete(legacyKey);
        _records.remove(legacyKey);

        DatabaseService.attendanceBox.put(key, migrated);
        _records[key] = migrated;

        return migrated.status;
      }
    }

    return AttendanceStatus.none;
  }

  void markAll(
    DateTime date,
    List<String> subjects,
    AttendanceStatus status, {
    required List<String> slotIds,
  }) {
    final count = subjects.length < slotIds.length
        ? subjects.length
        : slotIds.length;

    for (int i = 0; i < count; i++) {
      final key = _slotIdKey(date, slotIds[i]);
      final record = Attendance(
        date: DateTime(date.year, date.month, date.day),
        subjectId: subjects[i],
        slotIndex: i,
        status: status,
        slotId: slotIds[i],
      );

      DatabaseService.attendanceBox.put(key, record);
      _records[key] = record;
    }

    _rebuildStatsCache();
    notifyListeners();
    RankingUtils.checkAndAutoUpload();
  }

  void deleteRecordsForSubject(String subjectId) {
    final keysToDelete = <String>[];

    for (final entry in _records.entries) {
      if (entry.value.subjectId == subjectId) {
        keysToDelete.add(entry.key);
      }
    }

    for (final key in keysToDelete) {
      DatabaseService.attendanceBox.delete(key);
      _records.remove(key);
    }

    DatabaseService.attendanceBaselinesBox.delete(subjectId);
    _subjectBaselineCache.remove(subjectId);

    _rebuildStatsCache();
    notifyListeners();
    RankingUtils.checkAndAutoUpload(force: true);
  }

  void replaceSubjectAttendanceBaseline(
    String subjectId, {
    required int attended,
    required int total,
  }) {
    final keysToDelete = <String>[];

    for (final entry in _records.entries) {
      if (entry.value.subjectId == subjectId) {
        keysToDelete.add(entry.key);
      }
    }

    for (final key in keysToDelete) {
      DatabaseService.attendanceBox.delete(key);
      _records.remove(key);
    }

    final normalizedTotal = total < 0 ? 0 : total;
    final normalizedAttended = attended.clamp(0, normalizedTotal);

    if (normalizedTotal <= 0) {
      DatabaseService.attendanceBaselinesBox.delete(subjectId);
      _subjectBaselineCache.remove(subjectId);
    } else {
      DatabaseService.attendanceBaselinesBox.put(subjectId, {
        'attended': normalizedAttended,
        'total': normalizedTotal,
      });
      _subjectBaselineCache[subjectId] = AttendanceStats(
        attended: normalizedAttended,
        total: normalizedTotal,
      );
    }

    _rebuildStatsCache();
    notifyListeners();
    RankingUtils.checkAndAutoUpload(force: true);
  }

  void deleteAttendanceForSlotFromDateOnward(int weekdayNumber, String slotId) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final keysToDelete = <String>[];

    for (final entry in _records.entries) {
      final record = entry.value;
      if (record.slotId != slotId) continue;
      if (record.date.weekday != weekdayNumber) continue;
      final recordDate = DateTime(
        record.date.year,
        record.date.month,
        record.date.day,
      );
      if (recordDate.isBefore(today)) continue;
      keysToDelete.add(entry.key);
    }

    for (final key in keysToDelete) {
      DatabaseService.attendanceBox.delete(key);
      _records.remove(key);
    }
  }

  void deleteAttendanceForSlot(String slotId) {
    final keysToDelete = <String>[];

    for (final entry in _records.entries) {
      if (entry.value.slotId == slotId) {
        keysToDelete.add(entry.key);
      }
    }

    for (final key in keysToDelete) {
      DatabaseService.attendanceBox.delete(key);
      _records.remove(key);
    }
  }

  void deleteAttendanceForDateSlot(DateTime date, String slotId) {
    final key = _slotIdKey(date, slotId);
    DatabaseService.attendanceBox.delete(key);
    _records.remove(key);
  }

  void notifyIfChanged() {
    _rebuildStatsCache();
    notifyListeners();
  }

  void clearAll() {
    _records.clear();
    _subjectStatsCache.clear();
    _subjectBaselineCache.clear();

    try {
      DatabaseService.attendanceBox.clear();
    } catch (_) {}

    try {
      DatabaseService.attendanceBaselinesBox.clear();
    } catch (_) {}

    notifyListeners();
    RankingUtils.checkAndAutoUpload(force: true);
  }
}
