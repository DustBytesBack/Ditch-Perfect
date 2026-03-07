import 'package:flutter/material.dart';
import '../services/database_service.dart';

class TimetableProvider extends ChangeNotifier {

  final Map<String, List<String>> _week = {};

  final Map<String, List<String>> _extraSlots = {};

  Map<String, List<String>> get week => _week;

  final List<String> days = [
    "mon",
    "tue",
    "wed",
    "thu",
    "fri",
    "sat",
    "sun",
  ];

  String buildDateKey(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.toIso8601String();
  }

  void loadTimetable() {
    final box = DatabaseService.timetableBox;

    _week.clear();

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

    notifyListeners();
  }

  List<String> getDaySlots(String day) {
    return _week[day] ?? [];
  }

  List<String> getTodaySlots() {
    final weekday = DateTime.now().weekday;
    return _week[days[weekday - 1]] ?? [];
  }

  List<String> getSlotsForDate(DateTime date) {

    final base = _week[days[date.weekday - 1]] ?? [];

    final key = buildDateKey(date);

    final extra = _extraSlots[key] ?? [];

    return [...base, ...extra];
  }

  void addSubject(String day, String subjectId) {

    final box = DatabaseService.timetableBox;

    final slots = _week[day] ?? [];

    slots.add(subjectId);

    _week[day] = slots;

    box.put(day, slots);

    notifyListeners();
  }

  void removeSubjectAt(String day, int index) {

    final box = DatabaseService.timetableBox;

    final slots = _week[day];

    if (slots == null) return;

    if (index >= 0 && index < slots.length) {
      slots.removeAt(index);
    }

    box.put(day, slots);

    notifyListeners();
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

  void removeSlotEverywhere(String day, int index) {
    removeSubjectAt(day, index);
  }

  void reload() {
    loadTimetable();
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

    if (slots.isEmpty) {
      _extraSlots.remove(key);
    } else {
      _extraSlots[key] = slots;
    }

    final attendanceBox = DatabaseService.attendanceBox;

    final baseSlots = getDaySlots(days[date.weekday - 1]);
    final baseCount = baseSlots.length;

    final removedSlotIndex = baseCount + index;

    final keys = attendanceBox.keys.toList();

    for (var k in keys) {

      final record = attendanceBox.get(k);

      if (record == null) continue;

      if (record.date.year == date.year &&
          record.date.month == date.month &&
          record.date.day == date.day) {

        if (record.slotIndex == removedSlotIndex) {

          attendanceBox.delete(k);

        } else if (record.slotIndex > removedSlotIndex) {

          record.slotIndex = record.slotIndex - 1;
          attendanceBox.put(k, record);
        }
      }
    }

    notifyListeners();
  }

}