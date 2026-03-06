import 'package:flutter/material.dart';
import '../services/database_service.dart';

class TimetableProvider extends ChangeNotifier {

  final Map<String, List<String?>> _week = {};

  Map<String, List<String?>> get week => _week;

  final List<String> days = [
    "mon",
    "tue",
    "wed",
    "thu",
    "fri",
    "sat",
    "sun",
  ];

  int get hoursPerDay {
    final settings = DatabaseService.settingsBox;
    return settings.get("hoursPerDay", defaultValue: 8) as int;
  }

  void loadTimetable() {

    final box = DatabaseService.timetableBox;
    final hours = hoursPerDay;

    _week.clear();

    for (var day in days) {

      final stored = box.get(day);

      if (stored != null) {

        final slots = List<String?>.from(stored);

        if (slots.length != hours) {

          if (slots.length < hours) {
            slots.addAll(List.filled(hours - slots.length, null));
          } else {
            slots.removeRange(hours, slots.length);
          }

          box.put(day, slots);
        }

        _week[day] = slots;

      } else {

        final newSlots = List<String?>.filled(hours, null);

        box.put(day, newSlots);
        _week[day] = newSlots;
      }
    }

    notifyListeners();
  }

  void updateHours(int hours) {

    final box = DatabaseService.timetableBox;

    for (var day in days) {

      final slots = _week[day] ?? [];

      if (slots.length < hours) {
        slots.addAll(List.filled(hours - slots.length, null));
      } else if (slots.length > hours) {
        slots.removeRange(hours, slots.length);
      }

      _week[day] = slots;

      box.put(day, slots);
    }

    notifyListeners();
  }

  void assignSubject(String day, int slotIndex, String subjectId) {

    final box = DatabaseService.timetableBox;

    final slots = _week[day];

    if (slots == null) return;

    if (slotIndex >= 0 && slotIndex < slots.length) {
      slots[slotIndex] = subjectId;
    }

    box.put(day, slots);

    notifyListeners();
  }

  void removeSubject(String day, int slotIndex) {

    final box = DatabaseService.timetableBox;

    final slots = _week[day];

    if (slots == null) return;

    if (slotIndex >= 0 && slotIndex < slots.length) {
      slots[slotIndex] = null;
    }

    box.put(day, slots);

    notifyListeners();
  }

  /// Remove this slot index across all weeks
  void removeSlotEverywhere(String day, int slotIndex) {

    final box = DatabaseService.timetableBox;

    final slots = _week[day];

    if (slots == null) return;

    if (slotIndex >= 0 && slotIndex < slots.length) {
      slots[slotIndex] = null;
    }

    box.put(day, slots);

    notifyListeners();
  }

  /// Used for drag reorder to update a whole day at once
  void updateDaySlots(String day, List<String?> newSlots) {

    final box = DatabaseService.timetableBox;

    _week[day] = newSlots;

    box.put(day, newSlots);

    notifyListeners();
  }

  List<String?> getDaySlots(String day) {
    return _week[day] ?? [];
  }

  List<String?> getTodaySlots() {

    final weekday = DateTime.now().weekday;

    const dayMap = {
      1: "mon",
      2: "tue",
      3: "wed",
      4: "thu",
      5: "fri",
      6: "sat",
      7: "sun"
    };

    final dayKey = dayMap[weekday];

    if (dayKey == null) return [];

    return _week[dayKey] ?? [];
  }
}