import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../providers/timetable_provider.dart';
import '../providers/subject_provider.dart';
import '../providers/attendance_provider.dart';
import '../utils/holiday_utils.dart';
import '../models/subject.dart';
import '../models/attendance.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime focusedDay = DateTime.now();
  DateTime selectedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final timetable = context.watch<TimetableProvider>();
    final subjects = context.watch<SubjectProvider>().subjects;
    final attendance = context.watch<AttendanceProvider>();

    final slots = timetable.getDaySlots(weekdayKey(selectedDay));
    final selectedIsHoliday = isHoliday(selectedDay, attendance, timetable);

    return Scaffold(
      backgroundColor: scheme.primaryContainer,

      body: Stack(
        children: [

          /// ORIGINAL PAGE CONTENT
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
                          "Calendar",
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
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
                          icon: Icon(Icons.today, color: scheme.onSurface),
                          onPressed: () {
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
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(32),
                        topRight: Radius.circular(32),
                      ),
                    ),

                    child: Column(
                      children: [

                        /// CALENDAR
                        TableCalendar(
                          firstDay: DateTime(2020),
                          lastDay: DateTime(2100),
                          focusedDay: focusedDay,

                          selectedDayPredicate: (day) =>
                              isSameDay(selectedDay, day),

                          onDaySelected: (selected, focused) {
                            setState(() {
                              selectedDay = selected;
                              focusedDay = focused;
                            });

                            context
                                .read<AttendanceProvider>()
                                .loadDayAttendance(selected);
                          },

                          calendarBuilders: CalendarBuilders(
                            defaultBuilder: (context, day, focusedDay) {
                              final color =
                                  getDayColor(day, attendance, timetable);

                              return Container(
                                margin: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
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
                              final color =
                                  getDayColor(day, attendance, timetable);

                              return Container(
                                margin: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: color ?? scheme.primaryContainer,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: scheme.primary,
                                    width: 2,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  "${day.day}",
                                  style: TextStyle(
                                    color: color != null
                                        ? Colors.white
                                        : scheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            },

                            selectedBuilder: (context, day, focusedDay) {
                              final color =
                                  getDayColor(day, attendance, timetable);

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

                        const SizedBox(height: 20),

                        /// DAY TIMETABLE
                        Expanded(
                          child: selectedIsHoliday
                              ? Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 32,
                                      vertical: 16,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withValues(alpha: .15),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      "Holiday",
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            color: Colors.orange,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: slots.length,
                                  itemBuilder: (context, index) {
                                    final subjectId = slots[index];

                                    if (subjectId == null) {
                                      return const SizedBox();
                                    }

                                    final subject = subjects.firstWhere(
                                      (s) => s.id == subjectId,
                                      orElse: () =>
                                          Subject(id: "", name: "", shortName: ""),
                                    );

                                    final status =
                                        attendance.getStatus(selectedDay, index);

                                    Color statusColor;

                                    if (status == AttendanceStatus.present) {
                                      statusColor = Colors.green;
                                    } else if (status ==
                                        AttendanceStatus.absent) {
                                      statusColor = Colors.red;
                                    } else if (status ==
                                        AttendanceStatus.cancelled) {
                                      statusColor = Colors.orange;
                                    } else {
                                      statusColor =
                                          scheme.secondaryContainer;
                                    }

                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 14),
                                      child: Row(
                                        children: [

                                          /// STATUS PILL
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 18,
                                              vertical: 20,
                                            ),
                                            decoration: BoxDecoration(
                                              color: statusColor,
                                              borderRadius:
                                                  const BorderRadius.only(
                                                topLeft: Radius.circular(20),
                                                bottomLeft:
                                                    Radius.circular(20),
                                              ),
                                            ),
                                            child: Icon(
                                              status ==
                                                      AttendanceStatus.present
                                                  ? Icons.check
                                                  : status ==
                                                          AttendanceStatus
                                                              .absent
                                                      ? Icons.close
                                                      : Icons.block,
                                              color: Colors.white,
                                            ),
                                          ),

                                          const SizedBox(width: 8),

                                          /// SUBJECT PILL
                                          Expanded(
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 20),
                                              decoration: BoxDecoration(
                                                color: scheme
                                                    .secondaryContainer,
                                                borderRadius:
                                                    const BorderRadius.only(
                                                  topRight:
                                                      Radius.circular(20),
                                                  bottomRight:
                                                      Radius.circular(20),
                                                ),
                                              ),
                                              alignment: Alignment.center,
                                              child: Text(
                                                subject.name,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(
                                                      color: scheme
                                                          .onSecondaryContainer,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          /// FIX GESTURE NAV BAR COLOR
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: MediaQuery.of(context).padding.bottom + 12,
              color: scheme.surface,
            ),
          ),
        ],
      ),
    );
  }
}