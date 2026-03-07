import 'package:flutter/material.dart';
import '../models/attendance.dart';
import '../services/database_service.dart';
import 'attendance_provider.dart';

class TimetableProvider extends ChangeNotifier {
  /// The CURRENT weekly timetable. Physically modified on all removals.
  final Map<String, List<String>> _week = {};

  /// Extra date-specific slots added by the user (e.g. "add subject to today").
  final Map<String, List<String>> _extraSlots = {};

  /// Per-date base timetable overrides. When a "Future Only" removal happens,
  /// past dates that had the old timetable get a snapshot saved here so
  /// [getSlotsForDate] can reconstruct what the timetable looked like on
  /// that date. Key = ISO date string, value = base slot list for that date.
  final Map<String, List<String>> _dateBaseOverrides = {};

  /// Caches the base slots returned by the most recent [getSlotsForDate] call.
  /// This allows [getDaySlots] to return date-aware results when called
  /// immediately after [getSlotsForDate] for the same weekday (as happens
  /// inside [DayTimetable.build]).
  String? _lastBaseWeekday;
  List<String> _lastBaseSlots = [];

  Map<String, List<String>> get week => _week;

  Map<String, List<String>> get extraSlots => _extraSlots;

  /// Optional reference to AttendanceProvider for in-memory cache updates.
  AttendanceProvider? _attendanceProvider;

  /// Inject reference to AttendanceProvider.
  void setAttendanceProvider(AttendanceProvider provider) {
    _attendanceProvider = provider;
  }

  final List<String> days = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"];

  String buildDateKey(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.toIso8601String();
  }

  void loadTimetable() {
    final box = DatabaseService.timetableBox;

    _week.clear();
    _extraSlots.clear();
    _dateBaseOverrides.clear();

    for (var day in days) {
      final stored = box.get(day);

      if (stored != null) {
        final rawList = List.from(stored);

        final cleanList = rawList
            .where((e) => e != null)
            .map((e) => e.toString())
            .toList();

        _week[day] = cleanList;

        box.put(day, cleanList);
      } else {
        _week[day] = [];
        box.put(day, []);
      }
    }

    // Load extra date-specific slots from Hive.
    for (var key in box.keys) {
      final keyStr = key.toString();

      if (days.contains(keyStr)) continue;

      final stored = box.get(key);

      if (stored != null) {
        final rawList = List.from(stored);

        final cleanList = rawList
            .where((e) => e != null)
            .map((e) => e.toString())
            .toList();

        if (cleanList.isNotEmpty) {
          _extraSlots[keyStr] = cleanList;
        }
      }
    }

    // Load date base overrides from Hive.
    final overridesBox = DatabaseService.timetableRemovalsBox;
    for (var key in overridesBox.keys) {
      final stored = overridesBox.get(key);
      if (stored != null) {
        final rawList = List.from(stored as List);
        final cleanList = rawList
            .where((e) => e != null)
            .map((e) => e.toString())
            .toList();
        _dateBaseOverrides[key.toString()] = cleanList;
      }
    }

    notifyListeners();
  }

  // ── Slot accessors ──────────────────────────────────────────────

  /// Returns the base slots for a weekday.
  ///
  /// If [getSlotsForDate] was called just before for a date that falls on
  /// the same weekday, this returns the date-aware base (which may be a
  /// [_dateBaseOverrides] snapshot). Otherwise it returns the current
  /// weekly timetable [_week] entry.
  ///
  /// The cache is consumed (cleared) on each call so it doesn't leak into
  /// unrelated callers (e.g. timetable editor, timetable page).
  List<String> getDaySlots(String day) {
    if (_lastBaseWeekday == day) {
      final cached = _lastBaseSlots;
      _lastBaseWeekday = null;
      _lastBaseSlots = [];
      return cached;
    }
    return _week[day] ?? [];
  }

  List<String> getTodaySlots() {
    final weekday = DateTime.now().weekday;
    return getDaySlots(days[weekday - 1]);
  }

  /// Returns the slots that should appear for a specific date.
  /// If a date-base override exists (from a "Future Only" removal), it is
  /// used as the base instead of the current weekly timetable.
  ///
  /// Also caches the base so that a subsequent [getDaySlots] call for the
  /// same weekday returns the date-aware base instead of the current week.
  List<String> getSlotsForDate(DateTime date) {
    final dayKey = days[date.weekday - 1];
    final dateKey = buildDateKey(date);

    // Use the override if one exists for this date, otherwise use current week.
    final base = _dateBaseOverrides[dateKey] ?? (_week[dayKey] ?? []);

    // Cache the base for getDaySlots to pick up.
    _lastBaseWeekday = dayKey;
    _lastBaseSlots = base;

    final extra = _extraSlots[dateKey] ?? [];

    return [...base, ...extra];
  }

  // ── Slot mutations ──────────────────────────────────────────────

  void addSubject(String day, String subjectId) {
    final box = DatabaseService.timetableBox;

    final slots = _week[day] ?? [];

    slots.add(subjectId);

    _week[day] = slots;

    box.put(day, slots);

    notifyListeners();
  }

  /// "Future Only" — remove the slot from the timetable going forward.
  /// Past dates still show the slot (and its attendance data) because we
  /// snapshot the current base timetable into [_dateBaseOverrides] for
  /// every past date on this weekday that has attendance records.
  ///
  /// Today and future dates are affected by the removal: the slot disappears
  /// and any attendance records at that slot index are deleted + re-indexed.
  ///
  /// [index] is relative to the CURRENT [getDaySlots] list.
  void removeSubjectAt(String day, int index) {
    final slots = _week[day];
    if (slots == null || index < 0 || index >= slots.length) return;

    // Snapshot the CURRENT base timetable for all past dates on this weekday
    // that have attendance records (and don't already have an override).
    final weekdayNumber = days.indexOf(day) + 1;
    _snapshotPastDates(day, weekdayNumber, List<String>.from(slots));

    // Delete and re-index attendance records on today (and any future dates)
    // for this weekday, since those dates will use the updated _week.
    _deleteAndReindexSlotFromTodayOnward(weekdayNumber, index);

    // Physically remove the slot from the current timetable.
    slots.removeAt(index);
    DatabaseService.timetableBox.put(day, slots);

    _attendanceProvider?.notifyIfChanged();
    notifyListeners();
  }

  /// Snapshot the current base timetable [baseSlots] into _dateBaseOverrides
  /// for every past date on weekday [weekdayNumber] that has attendance
  /// records and doesn't already have a snapshot.
  void _snapshotPastDates(
    String day,
    int weekdayNumber,
    List<String> baseSlots,
  ) {
    final attendanceBox = DatabaseService.attendanceBox;
    final overridesBox = DatabaseService.timetableRemovalsBox;

    // Collect all unique dates from attendance records that fall on this weekday.
    final pastDates = <String>{};

    for (var k in attendanceBox.keys) {
      final kStr = k.toString();
      // Key format: "ISO8601Date_slotIndex"
      final lastUnderscore = kStr.lastIndexOf('_');
      if (lastUnderscore < 0) continue;

      final datePart = kStr.substring(0, lastUnderscore);
      final parsed = DateTime.tryParse(datePart);
      if (parsed == null) continue;
      if (parsed.weekday != weekdayNumber) continue;

      // Only snapshot past dates (before today).
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      if (!parsed.isBefore(today)) continue;

      pastDates.add(datePart);
    }

    // Save a snapshot for each past date that doesn't already have one.
    for (var dateKey in pastDates) {
      if (!_dateBaseOverrides.containsKey(dateKey)) {
        _dateBaseOverrides[dateKey] = List<String>.from(baseSlots);
        overridesBox.put(dateKey, List<String>.from(baseSlots));
      }
    }
  }

  /// Delete the attendance record at [slotIndex] and re-index higher slots
  /// for all dates on [weekdayNumber] that are today or in the future.
  /// This ensures that when a slot is removed "Future Only", today's (and
  /// any future) attendance data stays consistent with the updated _week.
  void _deleteAndReindexSlotFromTodayOnward(int weekdayNumber, int slotIndex) {
    final attendanceBox = DatabaseService.attendanceBox;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Collect keys grouped by date for today-or-later on this weekday.
    final allKeys = attendanceBox.keys.toList();

    for (var k in allKeys) {
      final kStr = k.toString();
      final record = attendanceBox.get(k);
      if (record == null || record is! Attendance) continue;
      if (record.date.weekday != weekdayNumber) continue;

      final recordDate = DateTime(
        record.date.year,
        record.date.month,
        record.date.day,
      );
      if (recordDate.isBefore(today)) {
        continue; // skip past dates (they have snapshots)
      }

      if (record.slotIndex == slotIndex) {
        // This is the removed slot — delete it.
        attendanceBox.delete(k);
        _attendanceProvider?.records.remove(kStr);
      } else if (record.slotIndex > slotIndex) {
        // Higher slot index — shift down by 1.
        attendanceBox.delete(k);
        _attendanceProvider?.records.remove(kStr);

        record.slotIndex = record.slotIndex - 1;

        final dateIso = recordDate.toIso8601String();
        final newKey = "${dateIso}_${record.slotIndex}";
        attendanceBox.put(newKey, record);
        _attendanceProvider?.records[newKey] = record;
      }
    }
  }

  void updateDaySlots(String day, List<String> newSlots) {
    final box = DatabaseService.timetableBox;

    _week[day] = newSlots;

    box.put(day, newSlots);

    notifyListeners();
  }

  /// Compatibility methods (old code support)

  void assignSubject(String day, int index, String subjectId) {
    final slots = _week[day] ?? [];

    if (index < slots.length) {
      slots[index] = subjectId;
    } else {
      slots.add(subjectId);
    }

    DatabaseService.timetableBox.put(day, slots);

    notifyListeners();
  }

  void removeSubject(String day, int index) {
    removeSubjectAt(day, index);
  }

  /// Remove ONE slot at (day, index) from the weekly timetable AND delete
  /// all past attendance records for that slot on every occurrence of this
  /// weekday. Called from timetable editor "Delete All Entries".
  ///
  /// Unlike [removeSubjectAt] ("Future Only"), this also purges history.
  void removeSlotEverywhere(String day, int index) {
    final slots = _week[day];
    if (slots == null || index < 0 || index >= slots.length) return;

    final subjectId = slots[index];

    // Physically remove the slot from the current timetable.
    slots.removeAt(index);
    DatabaseService.timetableBox.put(day, slots);

    // Find the weekday number (1=mon..7=sun).
    final weekdayNumber = days.indexOf(day) + 1;

    // Delete all attendance records for this subject on this weekday.
    _deleteAttendanceForSubjectOnWeekday(subjectId, weekdayNumber);

    // Clean up any date-base overrides on this weekday: remove the subject
    // from each override's slot list too, so the historical view is consistent.
    _removeSubjectFromOverrides(subjectId, weekdayNumber);

    _attendanceProvider?.notifyIfChanged();
    notifyListeners();
  }

  /// Delete all attendance records for [subjectId] on dates that fall on
  /// [weekdayNumber] (1=Monday..7=Sunday). Only removes ONE occurrence per
  /// date (matching the slot that was deleted).
  void _deleteAttendanceForSubjectOnWeekday(
    String subjectId,
    int weekdayNumber,
  ) {
    final attendanceBox = DatabaseService.attendanceBox;
    final allKeys = attendanceBox.keys.toList();

    for (var k in allKeys) {
      final kStr = k.toString();
      final record = attendanceBox.get(k);
      if (record == null || record is! Attendance) continue;

      if (record.subjectId == subjectId) {
        if (record.date.weekday == weekdayNumber) {
          attendanceBox.delete(k);
          _attendanceProvider?.records.remove(kStr);
        }
      }
    }
  }

  /// Remove one occurrence of [subjectId] from every date-base override
  /// that falls on [weekdayNumber].
  void _removeSubjectFromOverrides(String subjectId, int weekdayNumber) {
    final overridesBox = DatabaseService.timetableRemovalsBox;

    final keysToUpdate = <String>[];

    for (var entry in _dateBaseOverrides.entries) {
      final parsed = DateTime.tryParse(entry.key);
      if (parsed == null || parsed.weekday != weekdayNumber) continue;

      final idx = entry.value.indexOf(subjectId);
      if (idx >= 0) {
        entry.value.removeAt(idx);
        keysToUpdate.add(entry.key);
      }
    }

    for (var key in keysToUpdate) {
      final slots = _dateBaseOverrides[key]!;
      if (slots.isEmpty) {
        _dateBaseOverrides.remove(key);
        overridesBox.delete(key);
      } else {
        overridesBox.put(key, slots);
      }
    }
  }

  /// Remove all overrides and attendance for a subject (used when subject
  /// is deleted completely).
  void removeRemovalsForSubject(String subjectId) {
    final overridesBox = DatabaseService.timetableRemovalsBox;

    final keysToUpdate = <String>[];

    for (var entry in _dateBaseOverrides.entries) {
      if (entry.value.contains(subjectId)) {
        entry.value.removeWhere((s) => s == subjectId);
        keysToUpdate.add(entry.key);
      }
    }

    for (var key in keysToUpdate) {
      final slots = _dateBaseOverrides[key]!;
      if (slots.isEmpty) {
        _dateBaseOverrides.remove(key);
        overridesBox.delete(key);
      } else {
        overridesBox.put(key, slots);
      }
    }
  }

  void reload() {
    _week.clear();
    _extraSlots.clear();
    _dateBaseOverrides.clear();

    try {
      DatabaseService.timetableBox.clear();
    } catch (_) {}

    try {
      DatabaseService.timetableRemovalsBox.clear();
    } catch (_) {}

    for (var day in days) {
      _week[day] = [];
    }

    notifyListeners();
  }

  void addSubjectToDate(DateTime date, String subjectId) {
    final box = DatabaseService.timetableBox;

    final key = buildDateKey(date);

    final slots = _extraSlots[key] ?? [];

    slots.add(subjectId);

    _extraSlots[key] = slots;

    box.put(key, slots);

    notifyListeners();
  }

  void removeExtraSubject(DateTime date, int index) {
    final key = buildDateKey(date);

    final slots = _extraSlots[key];

    if (slots == null) return;

    if (index < 0 || index >= slots.length) return;

    slots.removeAt(index);

    final box = DatabaseService.timetableBox;

    if (slots.isEmpty) {
      _extraSlots.remove(key);
      box.delete(key);
    } else {
      _extraSlots[key] = slots;
      box.put(key, slots);
    }

    // Fix attendance records: remove the deleted slot's record,
    // and re-index any records with higher slot indices.
    final attendanceBox = DatabaseService.attendanceBox;

    final dayKey = days[date.weekday - 1];
    final d = DateTime(date.year, date.month, date.day);
    final dateKeyStr = buildDateKey(date);

    // Base count for this date: use override if present, else current week.
    final baseSlots = _dateBaseOverrides[dateKeyStr] ?? (_week[dayKey] ?? []);
    final baseCount = baseSlots.length;

    final removedSlotIndex = baseCount + index;

    final datePrefix = "${d.toIso8601String()}_";

    final keys = attendanceBox.keys.toList();

    for (var k in keys) {
      final kStr = k.toString();

      if (!kStr.startsWith(datePrefix)) continue;

      final record = attendanceBox.get(k);

      if (record == null || record is! Attendance) continue;

      if (record.slotIndex == removedSlotIndex) {
        attendanceBox.delete(k);
        _attendanceProvider?.records.remove(kStr);
      } else if (record.slotIndex > removedSlotIndex) {
        attendanceBox.delete(k);
        _attendanceProvider?.records.remove(kStr);

        record.slotIndex = record.slotIndex - 1;

        final newKey = "${d.toIso8601String()}_${record.slotIndex}";
        attendanceBox.put(newKey, record);
        _attendanceProvider?.records[newKey] = record;
      }
    }

    _attendanceProvider?.notifyIfChanged();

    notifyListeners();
  }
}
