import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/timetable_provider.dart';
import '../providers/attendance_provider.dart';
import '../providers/subject_provider.dart';
import '../models/attendance.dart';
import '../utils/holiday_utils.dart';
import '../widgets/day_timetable.dart';

enum BulkAction { present, absent, cancelled, clear }

class DayDetailsPage extends StatefulWidget {
  final DateTime date;

  const DayDetailsPage({super.key, required this.date});

  @override
  State<DayDetailsPage> createState() => _DayDetailsPageState();
}

class _DayDetailsPageState extends State<DayDetailsPage> {
  late DateTime _currentDate;

  @override
  void initState() {
    super.initState();
    _currentDate = widget.date;
  }

  String formatDate(DateTime date) {
    const months = [
      "January",
      "February",
      "March",
      "April",
      "May",
      "June",
      "July",
      "August",
      "September",
      "October",
      "November",
      "December",
    ];

    return "${date.day} ${months[date.month - 1]} ${date.year}";
  }

  void showSubjectPicker(BuildContext context, DateTime date) {
    final subjects = context.read<SubjectProvider>().subjects;
    final scheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
            children: subjects.map((subject) {
              return ListTile(
                title: Text(subject.name),
                onTap: () {
                  context.read<TimetableProvider>().addSubjectToDate(
                    date,
                    subject.id,
                  );

                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final timetable = context.watch<TimetableProvider>();
    final attendance = context.watch<AttendanceProvider>();

    final date = _currentDate;

    final slots = timetable.getSlotsForDate(date);

    final isHolidayDay = isHoliday(date, timetable);
    final isNoTimetableDay = isNoTimetable(date, timetable);

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
                      GestureDetector(
                        onHorizontalDragEnd: (details) {
                          final velocity = details.primaryVelocity ?? 0;
                          if (velocity == 0) return;

                          HapticFeedback.lightImpact();

                          setState(() {
                            if (velocity < 0) {
                              // Swipe left → next day
                              _currentDate = _currentDate.add(
                                const Duration(days: 1),
                              );
                            } else {
                              // Swipe right → previous day
                              _currentDate = _currentDate.subtract(
                                const Duration(days: 1),
                              );
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 56,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.surface,
                            borderRadius: BorderRadius.circular(40),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: .08),
                                blurRadius: 12,
                                spreadRadius: 1,
                                offset: const Offset(0, -1),
                              ),
                            ],
                          ),
                          child: Text(
                            formatDate(date),
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: scheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      ),

                      const Spacer(),

                      const SizedBox(width: 12),

                      Container(
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: IconButton(
                          iconSize: 26,
                          padding: const EdgeInsets.all(14),
                          icon: Icon(Icons.add, color: scheme.onSurface),
                          onPressed: () {
                            showSubjectPicker(context, date);
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
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(.12),
                          blurRadius: 12,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),

                    child: isHolidayDay
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
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      color: Colors.orange,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                          )
                        : isNoTimetableDay
                        ? Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                "No timetable created",
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      color: scheme.onSecondaryContainer,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                          )
                        : Column(
                            children: [
                              /// BULK ACTION BUTTONS
                              Align(
                                alignment: Alignment.topRight,
                                child: SizedBox(
                                  width:
                                      MediaQuery.of(context).size.width * 0.4,

                                  child: SegmentedButton<BulkAction>(
                                    segments: const [
                                      ButtonSegment(
                                        value: BulkAction.clear,
                                        icon: Icon(Icons.clear_all_outlined),
                                      ),

                                      ButtonSegment(
                                        value: BulkAction.cancelled,
                                        icon: Icon(Icons.block),
                                      ),

                                      ButtonSegment(
                                        value: BulkAction.absent,
                                        icon: Icon(Icons.close_rounded),
                                      ),

                                      ButtonSegment(
                                        value: BulkAction.present,
                                        icon: Icon(Icons.check),
                                      ),
                                    ],

                                    selected: const <BulkAction>{},
                                    emptySelectionAllowed: true,

                                    onSelectionChanged:
                                        (Set<BulkAction> selection) {
                                          if (selection.isEmpty) return;

                                          HapticFeedback.mediumImpact();

                                          final action = selection.first;

                                          if (action == BulkAction.present) {
                                            attendance.markAll(
                                              date,
                                              slots,
                                              AttendanceStatus.present,
                                            );
                                          }

                                          if (action == BulkAction.absent) {
                                            attendance.markAll(
                                              date,
                                              slots,
                                              AttendanceStatus.absent,
                                            );
                                          }

                                          if (action == BulkAction.cancelled) {
                                            attendance.markAll(
                                              date,
                                              slots,
                                              AttendanceStatus.cancelled,
                                            );
                                          }

                                          if (action == BulkAction.clear) {
                                            for (
                                              int i = 0;
                                              i < slots.length;
                                              i++
                                            ) {
                                              attendance.clearAttendance(
                                                date,
                                                i,
                                              );
                                            }
                                          }
                                        },
                                  ),
                                ),
                              ),

                              const SizedBox(height: 16),

                              /// TIMETABLE
                              Expanded(child: DayTimetable(date: date)),
                            ],
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
}
