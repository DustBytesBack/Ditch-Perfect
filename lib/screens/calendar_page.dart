import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/attendance.dart';
import '../utils/calendar_stats.dart';
import '../providers/timetable_provider.dart';
import '../providers/attendance_provider.dart';
import '../services/tutorial_service.dart';
import '../utils/holiday_utils.dart';
import 'day_details_page.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime focusedDay = DateTime.now();
  DateTime selectedDay = DateTime.now();
  bool isMultiSelectMode = false;
  final Set<DateTime> selectedDates = <DateTime>{};

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  bool _isDateSelected(DateTime date) {
    return selectedDates.contains(_normalizeDate(date));
  }

  void _toggleMultiSelectMode() {
    HapticFeedback.lightImpact();
    setState(() {
      isMultiSelectMode = !isMultiSelectMode;
      if (!isMultiSelectMode) {
        selectedDates.clear();
      }
    });
  }

  void _toggleDateSelection(DateTime date) {
    final normalized = _normalizeDate(date);

    HapticFeedback.lightImpact();
    setState(() {
      if (selectedDates.contains(normalized)) {
        selectedDates.remove(normalized);
      } else {
        selectedDates.add(normalized);
      }
    });
  }

  Future<void> _showEmptyDatesDialog(int count) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Some dates were skipped'),
          content: Text(
            count == 1
                ? 'One selected date had no timetable, so it was not marked.'
                : '$count selected dates had no timetable, so they were not marked.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _clearSelectionMode() {
    HapticFeedback.lightImpact();
    setState(() {
      selectedDates.clear();
      isMultiSelectMode = false;
    });
  }

  Future<void> _applySelectionMarking(AttendanceStatus? status) async {
    final timetable = context.read<TimetableProvider>();
    final attendance = context.read<AttendanceProvider>();

    int markedCount = 0;
    int emptyCount = 0;

    final dates = selectedDates.toList()..sort();

    for (final date in dates) {
      final slots = timetable.getSlotsForDate(date);

      if (slots.isEmpty) {
        emptyCount++;
        continue;
      }

      if (status == null) {
        for (int i = 0; i < slots.length; i++) {
          attendance.clearAttendance(date, i);
        }
      } else {
        attendance.markAll(date, slots, status);
      }

      markedCount++;
    }

    if (!mounted) return;

    if (markedCount > 0) {
      final actionLabel = switch (status) {
        AttendanceStatus.present => 'present',
        AttendanceStatus.absent => 'absent',
        AttendanceStatus.cancelled => 'cancelled',
        AttendanceStatus.none => 'updated',
        null => 'cleared',
      };

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            markedCount == 1
                ? 'Marked 1 date $actionLabel.'
                : 'Marked $markedCount dates $actionLabel.',
          ),
        ),
      );
    }

    setState(() {
      selectedDates.clear();
      isMultiSelectMode = false;
    });

    if (emptyCount > 0) {
      await _showEmptyDatesDialog(emptyCount);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final timetable = context.watch<TimetableProvider>();
    final attendance = context.watch<AttendanceProvider>();

    final stats = calculateMonthStats(focusedDay, attendance, timetable);

    return Scaffold(
      backgroundColor: scheme.primaryContainer,

      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                /// HEADER
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 56,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          borderRadius: BorderRadius.circular(40),
                        ),
                        child: Text(
                          isMultiSelectMode
                              ? '${selectedDates.length} selected'
                              : "Calendar",
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: scheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),

                      const Spacer(),

                      Container(
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: IconButton(
                          iconSize: 28,
                          padding: const EdgeInsets.all(14),
                          icon: Icon(
                            isMultiSelectMode ? Icons.close : Icons.checklist,
                            color: scheme.onSurface,
                          ),
                          onPressed: () {
                            _toggleMultiSelectMode();
                          },
                          onLongPress: () {
                            HapticFeedback.lightImpact();
                            setState(() {
                              selectedDay = DateTime.now();
                              focusedDay = DateTime.now();
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                /// PANEL
                Expanded(
                  child: Container(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      20,
                      20,
                      MediaQuery.of(context).padding.bottom + 110,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(32),
                        topRight: Radius.circular(32),
                      ),
                    ),

                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          /// CALENDAR
                          Container(
                            key: TutorialService.keyFor(
                              TutorialTargets.calendarMain,
                            ),
                            child: TableCalendar(
                              firstDay: DateTime(2020),
                              lastDay: DateTime(2100),
                              focusedDay: focusedDay,

                              headerStyle: const HeaderStyle(
                                formatButtonVisible: false,
                                titleCentered: true,
                              ),

                              selectedDayPredicate: (day) =>
                                  !isMultiSelectMode &&
                                  isSameDay(selectedDay, day),

                              onDaySelected: (selected, focused) {
                                if (isMultiSelectMode) {
                                  _toggleDateSelection(selected);
                                  setState(() {
                                    focusedDay = focused;
                                  });
                                  return;
                                }

                                setState(() {
                                  selectedDay = selected;
                                  focusedDay = focused;
                                });

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        DayDetailsPage(date: selected),
                                  ),
                                );
                              },

                              onPageChanged: (focused) {
                                setState(() {
                                  focusedDay = focused;
                                });
                              },

                              calendarBuilders: CalendarBuilders(
                                defaultBuilder: (context, day, focusedDay) {
                                  final color = getDayColor(
                                    day,
                                    attendance,
                                    timetable,
                                  );

                                  return Container(
                                    margin: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                      border: _isDateSelected(day)
                                          ? Border.all(
                                              color: scheme.primary,
                                              width: 2.5,
                                            )
                                          : null,
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      "${day.day}",
                                      style: TextStyle(
                                        color: color == null
                                            ? scheme.onSurface
                                            : Colors.white,
                                      ),
                                    ),
                                  );
                                },

                                todayBuilder: (context, day, focusedDay) {
                                  final color = getDayColor(
                                    day,
                                    attendance,
                                    timetable,
                                  );

                                  return Container(
                                    margin: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: _isDateSelected(day)
                                            ? scheme.tertiary
                                            : scheme.primary,
                                        width: 2.5,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      "${day.day}",
                                      style: TextStyle(
                                        color: color == null
                                            ? scheme.onSurface
                                            : Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  );
                                },

                                selectedBuilder: (context, day, focusedDay) {
                                  final color = getDayColor(
                                    day,
                                    attendance,
                                    timetable,
                                  );

                                  return Container(
                                    margin: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: color ?? scheme.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      "${day.day}",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          /// STATS DASHBOARD CARD
                          Card(
                            key: TutorialService.keyFor(
                              TutorialTargets.calendarStats,
                            ),
                            elevation: 0,
                            color: scheme.secondaryContainer,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 16,
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceAround,
                                    children: [
                                      statTile(
                                        context,
                                        stats.notMarked,
                                        "Not marked",
                                        Colors.grey,
                                      ),

                                      statTile(
                                        context,
                                        stats.cancelled,
                                        "Off",
                                        Colors.orange,
                                      ),

                                      statTile(
                                        context,
                                        stats.missed,
                                        "Missed",
                                        Colors.red,
                                      ),

                                      statTile(
                                        context,
                                        stats.attended,
                                        "Attended",
                                        Colors.green,
                                      ),

                                      statTile(
                                        context,
                                        stats.mixed,
                                        "Mixed",
                                        Colors.purple,
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 12),

                                  Container(
                                    height: 36,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: scheme.primary,
                                      borderRadius: const BorderRadius.only(
                                        bottomLeft: Radius.circular(20),
                                        bottomRight: Radius.circular(20),
                                      ),
                                    ),
                                    child: Text(
                                      "Days",
                                      style: TextStyle(
                                        color: scheme.onPrimary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          /// NAV BAR COLOR FIX
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: MediaQuery.of(context).padding.bottom + 12,
              color: scheme.surface,
            ),
          ),

          if (isMultiSelectMode)
            Positioned(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(context).padding.bottom + 28,
              child: SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.shadow.withValues(alpha: .18),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _selectionActionButton(
                          icon: Icons.check_circle,
                          color: Colors.green,
                          label: 'Present',
                          onTap: selectedDates.isEmpty
                              ? null
                              : () => _applySelectionMarking(
                                  AttendanceStatus.present,
                                ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _selectionActionButton(
                          icon: Icons.cancel,
                          color: Colors.red,
                          label: 'Absent',
                          onTap: selectedDates.isEmpty
                              ? null
                              : () => _applySelectionMarking(
                                  AttendanceStatus.absent,
                                ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _selectionActionButton(
                          icon: Icons.remove_circle,
                          color: Colors.orange,
                          label: 'Cancelled',
                          onTap: selectedDates.isEmpty
                              ? null
                              : () => _applySelectionMarking(
                                  AttendanceStatus.cancelled,
                                ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _selectionActionButton(
                          icon: Icons.layers_clear,
                          color: scheme.primary,
                          label: 'Clear',
                          onTap: selectedDates.isEmpty
                              ? null
                              : () => _applySelectionMarking(null),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _selectionActionButton(
                          icon: Icons.close,
                          color: scheme.onSurfaceVariant,
                          label: 'Done',
                          onTap: _clearSelectionMode,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _selectionActionButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback? onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onTap != null;

    return Material(
      color: enabled ? color.withValues(alpha: .12) : scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: enabled
            ? () {
                HapticFeedback.lightImpact();
                onTap();
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: enabled ? color : scheme.onSurfaceVariant,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: enabled ? scheme.onSurface : scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget statTile(
    BuildContext context,
    int value,
    String label,
    Color dotColor,
  ) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      child: Column(
        children: [
          Text(
            value.toString(),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: scheme.onSecondaryContainer,
            ),
          ),

          const SizedBox(height: 4),

          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),

          const SizedBox(height: 6),

          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSecondaryContainer),
          ),
        ],
      ),
    );
  }
}
