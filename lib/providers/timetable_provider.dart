import 'package:flutter/material.dart';
import '../services/database_service.dart';

class TimetableProvider extends ChangeNotifier {

  final Map<String, List<String>> _week = {};

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
    return _week[days[date.weekday - 1]] ?? [];
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

  void updateHours(int hours) {
    /// no longer used
  }
}