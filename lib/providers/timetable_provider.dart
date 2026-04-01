import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/attendance.dart';
import '../services/database_service.dart';
import 'attendance_provider.dart';

class TimetableProvider extends ChangeNotifier {
  final AttendanceProvider _attendanceProvider;

  TimetableProvider({required AttendanceProvider attendanceProvider})
    : _attendanceProvider = attendanceProvider;

  final Map<String, List<String>> _week = {};
  final Map<String, List<String>> _weekSlotIds = {};

  final Map<String, List<String>> _extraSlots = {};
  final Map<String, List<String>> _extraSlotIds = {};

  final Map<String, List<String>> _dateBaseOverrides = {};
  final Map<String, List<String>> _dateBaseSlotIdOverrides = {};

  static const String _overridePrefix = '_override_';

  final List<String> days = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

  Map<String, List<String>> get week => _week;

  Map<String, List<String>> get extraSlots => _extraSlots;

  String buildDateKey(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.toIso8601String();
  }

  String _overrideKey(String dateKey) => '$_overridePrefix$dateKey';

  List<String> _cleanStringList(dynamic raw) {
    if (raw == null) return [];
    return List.from(
      raw,
    ).where((e) => e != null).map((e) => e.toString()).toList();
  }

  List<String> _alignedSlotIds({
    required String key,
    required int length,
    required bool isOverride,
  }) {
    final boxKey = isOverride ? _overrideKey(key) : key;
    final existing = _cleanStringList(
      DatabaseService.timetableSlotIdsBox.get(boxKey),
    );

    if (existing.length == length) {
      return existing;
    }

    final uuids = const Uuid();
    final generated = List<String>.generate(length, (_) => uuids.v4());
    DatabaseService.timetableSlotIdsBox.put(boxKey, generated);
    return generated;
  }

  void _persistWeek(String day) {
    DatabaseService.timetableBox.put(day, _week[day] ?? []);
    DatabaseService.timetableSlotIdsBox.put(day, _weekSlotIds[day] ?? []);
  }

  void _persistExtra(String dateKey) {
    final slots = _extraSlots[dateKey] ?? [];
    final slotIds = _extraSlotIds[dateKey] ?? [];

    if (slots.isEmpty) {
      DatabaseService.timetableBox.delete(dateKey);
      DatabaseService.timetableSlotIdsBox.delete(dateKey);
      _extraSlots.remove(dateKey);
      _extraSlotIds.remove(dateKey);
      return;
    }

    DatabaseService.timetableBox.put(dateKey, slots);
    DatabaseService.timetableSlotIdsBox.put(dateKey, slotIds);
  }

  void _persistDateOverride(String dateKey) {
    final slots = _dateBaseOverrides[dateKey] ?? [];
    final slotIds = _dateBaseSlotIdOverrides[dateKey] ?? [];

    if (slots.isEmpty) {
      _dateBaseOverrides.remove(dateKey);
      _dateBaseSlotIdOverrides.remove(dateKey);
      DatabaseService.timetableRemovalsBox.delete(dateKey);
      DatabaseService.timetableSlotIdsBox.delete(_overrideKey(dateKey));
      return;
    }

    DatabaseService.timetableRemovalsBox.put(dateKey, slots);
    DatabaseService.timetableSlotIdsBox.put(_overrideKey(dateKey), slotIds);
  }

  void loadTimetable() {
    _week.clear();
    _weekSlotIds.clear();
    _extraSlots.clear();
    _extraSlotIds.clear();
    _dateBaseOverrides.clear();
    _dateBaseSlotIdOverrides.clear();

    final timetableBox = DatabaseService.timetableBox;

    for (final day in days) {
      final cleanList = _cleanStringList(timetableBox.get(day));
      _week[day] = cleanList;
      _weekSlotIds[day] = _alignedSlotIds(
        key: day,
        length: cleanList.length,
        isOverride: false,
      );

      timetableBox.put(day, cleanList);
      DatabaseService.timetableSlotIdsBox.put(day, _weekSlotIds[day]!);
    }

    for (final key in timetableBox.keys) {
      final keyStr = key.toString();
      if (days.contains(keyStr)) continue;

      final cleanList = _cleanStringList(timetableBox.get(key));
      if (cleanList.isEmpty) continue;

      _extraSlots[keyStr] = cleanList;
      _extraSlotIds[keyStr] = _alignedSlotIds(
        key: keyStr,
        length: cleanList.length,
        isOverride: false,
      );
    }

    final overridesBox = DatabaseService.timetableRemovalsBox;
    for (final key in overridesBox.keys) {
      final dateKey = key.toString();
      final cleanList = _cleanStringList(overridesBox.get(key));
      if (cleanList.isEmpty) continue;

      _dateBaseOverrides[dateKey] = cleanList;
      _dateBaseSlotIdOverrides[dateKey] = _alignedSlotIds(
        key: dateKey,
        length: cleanList.length,
        isOverride: true,
      );
    }

    notifyListeners();
  }

  List<String> getDaySlots(String day) {
    return _week[day] ?? [];
  }

  List<String> getDaySlotIds(String day) {
    return _weekSlotIds[day] ?? [];
  }

  List<String> getBaseSlotsForDate(DateTime date) {
    final dayKey = days[date.weekday - 1];
    final dateKey = buildDateKey(date);
    return _dateBaseOverrides[dateKey] ?? (_week[dayKey] ?? []);
  }

  List<String> getBaseSlotIdsForDate(DateTime date) {
    final dayKey = days[date.weekday - 1];
    final dateKey = buildDateKey(date);
    return _dateBaseSlotIdOverrides[dateKey] ?? (_weekSlotIds[dayKey] ?? []);
  }

  List<String> getTodaySlots() {
    final weekday = DateTime.now().weekday;
    return getDaySlots(days[weekday - 1]);
  }

  List<String> getSlotsForDate(DateTime date) {
    final dateKey = buildDateKey(date);
    final base = getBaseSlotsForDate(date);
    final extra = _extraSlots[dateKey] ?? [];
    return [...base, ...extra];
  }

  List<String> getSlotIdsForDate(DateTime date) {
    final dateKey = buildDateKey(date);
    final base = getBaseSlotIdsForDate(date);
    final extra = _extraSlotIds[dateKey] ?? [];
    return [...base, ...extra];
  }

  void addSubject(String day, String subjectId) {
    final slots = _week[day] ?? [];
    final slotIds = _weekSlotIds[day] ?? [];

    slots.add(subjectId);
    slotIds.add(const Uuid().v4());

    _week[day] = slots;
    _weekSlotIds[day] = slotIds;
    _persistWeek(day);

    notifyListeners();
  }

  void _snapshotPastDates(
    int weekdayNumber,
    List<String> baseSlots,
    List<String> baseSlotIds,
  ) {
    final attendanceBox = DatabaseService.attendanceBox;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final pastDates = <String>{};
    for (final value in attendanceBox.values) {
      if (value is! Attendance) continue;
      if (value.date.weekday != weekdayNumber) continue;

      final recordDate = DateTime(
        value.date.year,
        value.date.month,
        value.date.day,
      );
      if (!recordDate.isBefore(today)) continue;

      pastDates.add(recordDate.toIso8601String());
    }

    for (final dateKey in pastDates) {
      if (_dateBaseOverrides.containsKey(dateKey)) continue;

      _dateBaseOverrides[dateKey] = List<String>.from(baseSlots);
      _dateBaseSlotIdOverrides[dateKey] = List<String>.from(baseSlotIds);
      _persistDateOverride(dateKey);
    }
  }

  void removeSubjectAt(String day, int index) {
    final slots = _week[day];
    final slotIds = _weekSlotIds[day];
    if (slots == null || slotIds == null) return;
    if (index < 0 || index >= slots.length || index >= slotIds.length) return;

    final weekdayNumber = days.indexOf(day) + 1;
    _snapshotPastDates(
      weekdayNumber,
      List<String>.from(slots),
      List<String>.from(slotIds),
    );

    final removedSlotId = slotIds[index];
    _attendanceProvider.deleteAttendanceForSlotFromDateOnward(
      weekdayNumber,
      removedSlotId,
    );

    slots.removeAt(index);
    slotIds.removeAt(index);
    _persistWeek(day);

    _attendanceProvider.notifyIfChanged();
    notifyListeners();
  }

  void reorderSubject(String day, int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;

    final slots = _week[day];
    final slotIds = _weekSlotIds[day];
    if (slots == null || slotIds == null) return;
    if (oldIndex < 0 ||
        oldIndex >= slots.length ||
        newIndex < 0 ||
        newIndex >= slots.length) {
      return;
    }

    final weekdayNumber = days.indexOf(day) + 1;
    _snapshotPastDates(
      weekdayNumber,
      List<String>.from(slots),
      List<String>.from(slotIds),
    );

    final subject = slots.removeAt(oldIndex);
    final slotId = slotIds.removeAt(oldIndex);
    slots.insert(newIndex, subject);
    slotIds.insert(newIndex, slotId);

    _persistWeek(day);
    notifyListeners();
  }

  void updateDaySlots(String day, List<String> newSlots) {
    final oldSlots = _week[day] ?? [];
    final oldSlotIds = _weekSlotIds[day] ?? [];

    final newSlotIds = <String>[];
    final usedOldIndices = <int>{};

    for (final subjectId in newSlots) {
      int matchIndex = -1;
      for (int i = 0; i < oldSlots.length; i++) {
        if (usedOldIndices.contains(i)) continue;
        if (oldSlots[i] == subjectId) {
          matchIndex = i;
          break;
        }
      }

      if (matchIndex >= 0) {
        usedOldIndices.add(matchIndex);
        newSlotIds.add(oldSlotIds[matchIndex]);
      } else {
        newSlotIds.add(const Uuid().v4());
      }
    }

    _week[day] = List<String>.from(newSlots);
    _weekSlotIds[day] = newSlotIds;
    _persistWeek(day);

    notifyListeners();
  }

  void assignSubject(String day, int index, String subjectId) {
    final slots = _week[day] ?? [];
    final slotIds = _weekSlotIds[day] ?? [];

    if (index < slots.length) {
      slots[index] = subjectId;
    } else {
      slots.add(subjectId);
      slotIds.add(const Uuid().v4());
    }

    _week[day] = slots;
    _weekSlotIds[day] = slotIds;
    _persistWeek(day);

    notifyListeners();
  }

  void removeSubject(String day, int index) {
    removeSubjectAt(day, index);
  }

  void removeSlotEverywhere(String day, int index) {
    final slots = _week[day];
    final slotIds = _weekSlotIds[day];
    if (slots == null || slotIds == null) return;
    if (index < 0 || index >= slots.length || index >= slotIds.length) return;

    final subjectId = slots[index];
    final removedSlotId = slotIds[index];
    final weekdayNumber = days.indexOf(day) + 1;

    final overrideKeys = _dateBaseOverrides.keys.toList();
    for (final dateKey in overrideKeys) {
      final parsed = DateTime.tryParse(dateKey);
      if (parsed == null || parsed.weekday != weekdayNumber) continue;

      final overrideSlots = _dateBaseOverrides[dateKey] ?? [];
      final overrideSlotIds = _dateBaseSlotIdOverrides[dateKey] ?? [];

      final removedIndices = <int>[];
      for (int i = 0; i < overrideSlots.length; i++) {
        final sameSlotId =
            i < overrideSlotIds.length && overrideSlotIds[i] == removedSlotId;
        final sameSubject = overrideSlots[i] == subjectId;
        if (sameSlotId || sameSubject) {
          removedIndices.add(i);
        }
      }

      for (int i = removedIndices.length - 1; i >= 0; i--) {
        final removeAt = removedIndices[i];
        if (removeAt < overrideSlots.length) {
          overrideSlots.removeAt(removeAt);
        }
        if (removeAt < overrideSlotIds.length) {
          overrideSlotIds.removeAt(removeAt);
        }
      }

      _dateBaseOverrides[dateKey] = overrideSlots;
      _dateBaseSlotIdOverrides[dateKey] = overrideSlotIds;
      _persistDateOverride(dateKey);
    }

    _attendanceProvider.deleteAttendanceForSlot(removedSlotId);

    slots.removeAt(index);
    slotIds.removeAt(index);
    _persistWeek(day);

    _attendanceProvider.notifyIfChanged();
    notifyListeners();
  }

  void removeRemovalsForSubject(String subjectId) {
    final keys = _dateBaseOverrides.keys.toList();

    for (final key in keys) {
      final slots = _dateBaseOverrides[key] ?? [];
      final slotIds = _dateBaseSlotIdOverrides[key] ?? [];

      final removedIndices = <int>[];
      for (int i = 0; i < slots.length; i++) {
        if (slots[i] == subjectId) removedIndices.add(i);
      }

      for (int i = removedIndices.length - 1; i >= 0; i--) {
        final removeAt = removedIndices[i];
        if (removeAt < slots.length) slots.removeAt(removeAt);
        if (removeAt < slotIds.length) slotIds.removeAt(removeAt);
      }

      _dateBaseOverrides[key] = slots;
      _dateBaseSlotIdOverrides[key] = slotIds;
      _persistDateOverride(key);
    }
  }

  void removeSubjectEverywhereById(String subjectId) {
    for (final day in days) {
      final slots = _week[day] ?? [];
      final slotIds = _weekSlotIds[day] ?? [];

      for (int i = slots.length - 1; i >= 0; i--) {
        if (slots[i] != subjectId) continue;
        final slotId = slotIds[i];
        _attendanceProvider.deleteAttendanceForSlot(slotId);
        slots.removeAt(i);
        slotIds.removeAt(i);
      }

      _week[day] = slots;
      _weekSlotIds[day] = slotIds;
      _persistWeek(day);
    }

    final extraKeys = _extraSlots.keys.toList();
    for (final dateKey in extraKeys) {
      final slots = _extraSlots[dateKey] ?? [];
      final slotIds = _extraSlotIds[dateKey] ?? [];
      final date = DateTime.tryParse(dateKey);

      for (int i = slots.length - 1; i >= 0; i--) {
        if (slots[i] != subjectId) continue;
        final slotId = slotIds[i];
        if (date != null) {
          _attendanceProvider.deleteAttendanceForDateSlot(date, slotId);
        } else {
          _attendanceProvider.deleteAttendanceForSlot(slotId);
        }
        slots.removeAt(i);
        slotIds.removeAt(i);
      }

      _extraSlots[dateKey] = slots;
      _extraSlotIds[dateKey] = slotIds;
      _persistExtra(dateKey);
    }

    removeRemovalsForSubject(subjectId);
    _attendanceProvider.notifyIfChanged();
    notifyListeners();
  }

  void reload() {
    _week.clear();
    _weekSlotIds.clear();
    _extraSlots.clear();
    _extraSlotIds.clear();
    _dateBaseOverrides.clear();
    _dateBaseSlotIdOverrides.clear();

    try {
      DatabaseService.timetableBox.clear();
    } catch (_) {}

    try {
      DatabaseService.timetableRemovalsBox.clear();
    } catch (_) {}

    try {
      DatabaseService.timetableSlotIdsBox.clear();
    } catch (_) {}

    for (final day in days) {
      _week[day] = [];
      _weekSlotIds[day] = [];
    }

    notifyListeners();
  }

  void addSubjectToDate(DateTime date, String subjectId) {
    final key = buildDateKey(date);
    final slots = _extraSlots[key] ?? [];
    final slotIds = _extraSlotIds[key] ?? [];

    slots.add(subjectId);
    slotIds.add(const Uuid().v4());

    _extraSlots[key] = slots;
    _extraSlotIds[key] = slotIds;
    _persistExtra(key);

    notifyListeners();
  }

  void removeExtraSubject(DateTime date, int index) {
    final key = buildDateKey(date);
    final slots = _extraSlots[key];
    final slotIds = _extraSlotIds[key];
    if (slots == null || slotIds == null) return;
    if (index < 0 || index >= slots.length || index >= slotIds.length) return;

    final removedSlotId = slotIds[index];
    slots.removeAt(index);
    slotIds.removeAt(index);
    _persistExtra(key);

    _attendanceProvider.deleteAttendanceForDateSlot(date, removedSlotId);
    _attendanceProvider.notifyIfChanged();

    notifyListeners();
  }
}
