import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../models/attendance.dart';
import '../../utils/calendar_stats.dart';
import '../../providers/timetable_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../utils/holiday_utils.dart';
import '../../providers/theme_provider.dart';
import 'day_schedule_page.dart';

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
      final slotIds = timetable.getSlotIdsForDate(date);

      if (slots.isEmpty) {
        emptyCount++;
        continue;
      }

      if (status == null) {
        for (int i = 0; i < slots.length; i++) {
          attendance.clearAttendance(date, slotIds[i], legacySlotIndex: i);
        }
      } else {
        attendance.markAll(date, slots, status, slotIds: slotIds);
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
    final themeProvider = context.watch<ThemeProvider>();
    final isAbsolute = themeProvider.absoluteMode;
    final scheme = Theme.of(context).colorScheme;

    final timetable = context.watch<TimetableProvider>();
    final attendance = context.watch<AttendanceProvider>();

    final stats = calculateMonthStats(focusedDay, attendance, timetable);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Use simple conditional logic for colors while keeping a single structural layout
    final bgColor = isAbsolute ? scheme.surface : scheme.primaryContainer;
    final topGradientColor = isAbsolute
        ? scheme.surface
        : scheme.primaryContainer;
    final bottomGradientColor = isAbsolute
        ? scheme.surfaceContainer
        : scheme.surface;
    final panelColor = isAbsolute ? scheme.surfaceContainer : scheme.surface;
    final headerColor = isAbsolute
        ? scheme.surfaceContainerHigh
        : scheme.surface;

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          /// GRADIENT BACKGROUND
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [topGradientColor, bottomGradientColor],
                ),
              ),
            ),
          ),

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
                          color: headerColor,
                          borderRadius: BorderRadius.circular(40),
                          border: isAbsolute
                              ? Border.all(color: scheme.outlineVariant)
                              : null,
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
                          color: headerColor,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: IconButton(
                          iconSize: 28,
                          padding: const EdgeInsets.all(14),
                          icon: Icon(
                            isMultiSelectMode ? Icons.close : Icons.checklist,
                            color: scheme.onSurface,
                          ),
                          onPressed: _toggleMultiSelectMode,
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
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    padding: EdgeInsets.fromLTRB(
                      20,
                      20,
                      20,
                      MediaQuery.of(context).padding.bottom + 110,
                    ),
                    decoration: BoxDecoration(
                      color: panelColor,
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          /// CALENDAR
                          TableCalendar(
                            firstDay: DateTime(2020),
                            lastDay: DateTime(2100),
                            focusedDay: focusedDay,
                            headerStyle: HeaderStyle(
                              formatButtonVisible: false,
                              titleCentered: true,
                              titleTextStyle: Theme.of(context)
                                  .textTheme
                                  .titleLarge!
                                  .copyWith(fontWeight: FontWeight.w700),
                              leftChevronPadding: const EdgeInsets.all(8),
                              rightChevronPadding: const EdgeInsets.all(8),
                              leftChevronIcon: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: scheme.onSecondaryContainer.withValues(
                                    alpha: 0.1,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: scheme.secondaryContainer,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      if (isDarkMode)
                                        BoxShadow(
                                          color: scheme.primary.withValues(
                                            alpha: 0.3,
                                          ),
                                          blurRadius: 10,
                                          spreadRadius: 2,
                                        )
                                      else ...[
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.2,
                                          ),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                        BoxShadow(
                                          color: scheme.onSecondaryContainer
                                              .withValues(alpha: 0.15),
                                          blurRadius: 1,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.chevron_left,
                                    color: scheme.onSecondaryContainer,
                                    size: 20,
                                  ),
                                ),
                              ),
                              rightChevronIcon: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: scheme.onSecondaryContainer.withValues(
                                    alpha: 0.1,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: scheme.secondaryContainer,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      if (isDarkMode)
                                        BoxShadow(
                                          color: scheme.primary.withValues(
                                            alpha: 0.3,
                                          ),
                                          blurRadius: 10,
                                          spreadRadius: 2,
                                        )
                                      else ...[
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.2,
                                          ),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                        BoxShadow(
                                          color: scheme.onSecondaryContainer
                                              .withValues(alpha: 0.15),
                                          blurRadius: 1,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.chevron_right,
                                    color: scheme.onSecondaryContainer,
                                    size: 20,
                                  ),
                                ),
                              ),
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
                                    boxShadow: (isAbsolute && color != null)
                                        ? [
                                            BoxShadow(
                                              color: color.withValues(
                                                alpha: .25,
                                              ),
                                              blurRadius: 8,
                                            ),
                                          ]
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
                                    boxShadow: isAbsolute
                                        ? [
                                            BoxShadow(
                                              color: scheme.primary.withValues(
                                                alpha: .5,
                                              ),
                                              blurRadius: 10,
                                            ),
                                          ]
                                        : null,
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

                          const SizedBox(height: 24),

                          /// STATS DASHBOARD CARD
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28),
                              color: isAbsolute
                                  ? null
                                  : scheme.secondaryContainer,
                              border: isAbsolute
                                  ? Border.all(color: scheme.outlineVariant)
                                  : null,
                              gradient: isAbsolute
                                  ? LinearGradient(
                                      colors: [
                                        scheme.surfaceContainerHigh,
                                        scheme.surfaceContainerHighest,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : null,
                            ),
                            padding: const EdgeInsets.symmetric(
                              vertical: 18,
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
                                if (!isAbsolute) ...[
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
                              ],
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

          if (isMultiSelectMode)
            Positioned(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(context).padding.bottom + 120,
              child: SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isAbsolute
                        ? scheme.surfaceContainerHigh
                        : scheme.surface,
                    borderRadius: BorderRadius.circular(28),
                    border: isAbsolute
                        ? Border.all(color: scheme.outlineVariant)
                        : null,
                    boxShadow: [
                      if (isAbsolute)
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .5),
                          blurRadius: 25,
                          offset: const Offset(0, 10),
                        )
                      else
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
                      const SizedBox(width: 6),
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
                      const SizedBox(width: 6),
                      Expanded(
                        child: _selectionActionButton(
                          icon: Icons.remove_circle,
                          color: Colors.orange,
                          label: 'Cancel',
                          onTap: selectedDates.isEmpty
                              ? null
                              : () => _applySelectionMarking(
                                  AttendanceStatus.cancelled,
                                ),
                        ),
                      ),
                      const SizedBox(width: 6),
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
                      const SizedBox(width: 6),
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
    final themeProvider = context.read<ThemeProvider>();
    final isAbsolute = themeProvider.absoluteMode;
    final scheme = Theme.of(context).colorScheme;
    final enabled = onTap != null;

    if (isAbsolute) {
      return Material(
        color: enabled ? color.withValues(alpha: .12) : scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: enabled
              ? () {
                  HapticFeedback.lightImpact();
                  onTap();
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: enabled ? color : scheme.onSurfaceVariant,
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Material(
      color: enabled ? color.withValues(alpha: .12) : scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: enabled
            ? () {
                HapticFeedback.lightImpact();
                onTap();
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: enabled ? color : scheme.onSurfaceVariant,
              ),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: enabled ? scheme.onSurface : scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
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
    final themeProvider = context.read<ThemeProvider>();
    final isAbsolute = themeProvider.absoluteMode;
    final scheme = Theme.of(context).colorScheme;

    if (isAbsolute) {
      return Column(
        children: [
          Text(
            value.toString(),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: dotColor.withValues(alpha: .6), blurRadius: 6),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      );
    }

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
