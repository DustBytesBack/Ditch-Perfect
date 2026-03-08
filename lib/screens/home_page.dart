import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/timetable_provider.dart';
import '../providers/attendance_provider.dart';
import '../providers/subject_provider.dart';
import '../models/attendance.dart';
import '../widgets/day_timetable.dart';
import 'ranked_bunking_page.dart';

enum BulkAction { present, absent, cancelled, clear }

class HomePage extends StatelessWidget {
  const HomePage({super.key});

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
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Select Subject",
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),

                const SizedBox(height: 16),

                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: subjects.length,
                    itemBuilder: (context, index) {
                      final subject = subjects[index];

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: scheme.primaryContainer,
                          child: Text(
                            subject.shortName.isEmpty
                                ? subject.name[0]
                                : subject.shortName[0],
                            style: TextStyle(
                              color: scheme.onPrimaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        title: Text(subject.name),
                        subtitle: Text(subject.shortName),
                        onTap: () {
                          context.read<TimetableProvider>().addSubjectToDate(
                            date,
                            subject.id,
                          );

                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
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

    final today = DateTime.now();

    final slots = timetable.getSlotsForDate(today);

    final isWeekend =
        today.weekday == DateTime.saturday || today.weekday == DateTime.sunday;
    final isHoliday = isWeekend && slots.isEmpty;

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
                          formatDate(today),
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
                            Icons.emoji_events_outlined,
                            color: scheme.onSurface,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const RankedBunkingPage(),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(width: 8),

                      Container(
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: IconButton(
                          iconSize: 28,
                          padding: const EdgeInsets.all(14),
                          icon: Icon(Icons.add, color: scheme.onSurface),
                          onPressed: () {
                            showSubjectPicker(context, today);
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

                    child: isHoliday
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              child: Text(
                                "Its holiday bruv go waste yo life",
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(
                                      color: scheme.onSurfaceVariant,
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

                                          final action = selection.first;

                                          if (action == BulkAction.present) {
                                            attendance.markAll(
                                              today,
                                              slots,
                                              AttendanceStatus.present,
                                            );
                                          }

                                          if (action == BulkAction.absent) {
                                            attendance.markAll(
                                              today,
                                              slots,
                                              AttendanceStatus.absent,
                                            );
                                          }

                                          if (action == BulkAction.cancelled) {
                                            attendance.markAll(
                                              today,
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
                                                today,
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
                              Expanded(child: DayTimetable(date: today)),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),

          /// NAV BAR FIX
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
