import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../utils/calendar_stats.dart';
import '../providers/timetable_provider.dart';
import '../providers/attendance_provider.dart';
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

  @override
  Widget build(BuildContext context) {

    final scheme = Theme.of(context).colorScheme;

    final timetable = context.watch<TimetableProvider>();
    final attendance = context.watch<AttendanceProvider>();

    final stats = calculateMonthStats(
      focusedDay,
      attendance,
      timetable,
    );

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
                          "Calendar",
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
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
                          TableCalendar(
                            firstDay: DateTime(2020),
                            lastDay: DateTime(2100),
                            focusedDay: focusedDay,

                            selectedDayPredicate: (day) =>
                                isSameDay(selectedDay, day),

                            onDaySelected: (selected, focused) {

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => DayDetailsPage(date: selected),
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

                          const SizedBox(height: 24),

                          /// STATS DASHBOARD CARD
                          Card(
                            elevation: 0,
                            color: scheme.secondaryContainer,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 16, horizontal: 16),
                              child: Column(
                                children: [

                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceAround,
                                    children: [

                                      statTile(context, stats.notMarked,
                                          "Not marked", Colors.grey),

                                      statTile(context, stats.cancelled,
                                          "Off", Colors.orange),

                                      statTile(context, stats.missed,
                                          "Missed", Colors.red),

                                      statTile(context, stats.attended,
                                          "Attended", Colors.green),

                                      statTile(context, stats.mixed,
                                          "Mixed", Colors.purple),
                                    ],
                                  ),

                                  const SizedBox(height: 12),

                                  Container(
                                    height: 36,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: scheme.primary,
                                      borderRadius:
                                          const BorderRadius.only(
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
        ],
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
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(
                fontWeight: FontWeight.w600,
                color: scheme.onSecondaryContainer,
              ),
        ),

        const SizedBox(height: 4),

        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
          ),
        ),

        const SizedBox(height: 6),

        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(
                color: scheme.onSecondaryContainer,
              ),
        ),
      ],
    ),
  );
}
}