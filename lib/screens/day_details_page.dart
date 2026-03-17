import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/timetable_provider.dart';
import '../providers/attendance_provider.dart';
import '../providers/theme_provider.dart';
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

  void _changeDay(int offset) {
    HapticFeedback.lightImpact();

    setState(() {
      _currentDate = _currentDate.add(Duration(days: offset));
    });
  }

  void _handleDaySwitcherSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity == 0) return;

    if (velocity < 0) {
      _changeDay(1);
    } else {
      _changeDay(-1);
    }
  }

  void showSubjectPicker(BuildContext context, DateTime date) {
    final subjects = context.read<SubjectProvider>().subjects;
    final timetable = context.read<TimetableProvider>();
    final scheme = Theme.of(context).colorScheme;
    const weekdays = [
      ('mon', 'Monday'),
      ('tue', 'Tuesday'),
      ('wed', 'Wednesday'),
      ('thu', 'Thursday'),
      ('fri', 'Friday'),
      ('sat', 'Saturday'),
      ('sun', 'Sunday'),
    ];
    final weekdayNames = <String, String>{
      'mon': 'Monday',
      'tue': 'Tuesday',
      'wed': 'Wednesday',
      'thu': 'Thursday',
      'fri': 'Friday',
      'sat': 'Saturday',
      'sun': 'Sunday',
    };

    String shortLabel(String subjectId) {
      final subjectIndex = subjects.indexWhere((item) => item.id == subjectId);
      if (subjectIndex < 0) return '?';
      final subject = subjects[subjectIndex];
      if (subject.shortName.isNotEmpty) return subject.shortName;
      if (subject.name.isNotEmpty) return subject.name[0];
      return '?';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) {
        String? selectedDayKey;

        return DefaultTabController(
          length: 2,
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height * 0.7,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Add Subjects',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const TabBar(
                            dividerColor: Colors.transparent,
                            indicatorSize: TabBarIndicatorSize.tab,
                            tabs: [
                              Tab(text: 'Single'),
                              Tab(text: 'From Day'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: TabBarView(
                            children: [
                              ListView.builder(
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
                                      timetable.addSubjectToDate(
                                        date,
                                        subject.id,
                                      );
                                      Navigator.pop(context);
                                    },
                                  );
                                },
                              ),
                              ListView(
                                children: [
                                  Text(
                                    'Tap a day to add its timetable.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                        ),
                                  ),
                                  const SizedBox(height: 16),
                                  ...weekdays.map((day) {
                                    final isSelected = selectedDayKey == day.$1;
                                    final daySlots = timetable.getDaySlots(
                                      day.$1,
                                    );

                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? scheme.secondaryContainer
                                              : scheme.surfaceContainerHighest,
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            InkWell(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              onTap: () {
                                                HapticFeedback.lightImpact();
                                                setModalState(() {
                                                  selectedDayKey = isSelected
                                                      ? null
                                                      : day.$1;
                                                });
                                              },
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 4,
                                                    ),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons.view_week,
                                                      color: isSelected
                                                          ? scheme
                                                                .onSecondaryContainer
                                                          : scheme
                                                                .onSurfaceVariant,
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Text(
                                                        weekdayNames[day.$1]!,
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .titleMedium
                                                            ?.copyWith(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color: isSelected
                                                                  ? scheme
                                                                        .onSecondaryContainer
                                                                  : scheme
                                                                        .onSurface,
                                                            ),
                                                      ),
                                                    ),
                                                    Icon(
                                                      isSelected
                                                          ? Icons.expand_less
                                                          : Icons.chevron_right,
                                                      color: isSelected
                                                          ? scheme
                                                                .onSecondaryContainer
                                                          : scheme
                                                                .onSurfaceVariant,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            if (isSelected) ...[
                                              const SizedBox(height: 14),
                                              if (daySlots.isEmpty)
                                                Text(
                                                  'No timetable found for ${weekdayNames[day.$1]}.',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.copyWith(
                                                        color: scheme
                                                            .onSecondaryContainer,
                                                      ),
                                                )
                                              else ...[
                                                Wrap(
                                                  spacing: 10,
                                                  runSpacing: 10,
                                                  children: daySlots.map((
                                                    subjectId,
                                                  ) {
                                                    return Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 20,
                                                            vertical: 14,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: scheme.surface,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              18,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        shortLabel(subjectId),
                                                        style: TextStyle(
                                                          fontSize: 16,
                                                          color:
                                                              scheme.onSurface,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                      ),
                                                    );
                                                  }).toList(),
                                                ),
                                                const SizedBox(height: 14),
                                                SizedBox(
                                                  width: double.infinity,
                                                  child: FilledButton.icon(
                                                    onPressed: () {
                                                      for (final subjectId
                                                          in daySlots) {
                                                        timetable
                                                            .addSubjectToDate(
                                                              date,
                                                              subjectId,
                                                            );
                                                      }
                                                      Navigator.pop(context);
                                                    },
                                                    icon: const Icon(
                                                      Icons.copy_all,
                                                    ),
                                                    label: Text(
                                                      daySlots.length == 1
                                                          ? 'Add 1 Subject'
                                                          : 'Add ${daySlots.length} Subjects',
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ],
                                        ),
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isAbsolute = themeProvider.absoluteMode;
    final scheme = Theme.of(context).colorScheme;

    final timetable = context.watch<TimetableProvider>();
    final attendance = context.watch<AttendanceProvider>();

    final date = _currentDate;

    final slots = timetable.getSlotsForDate(date);

    final isHolidayDay = isHoliday(date, timetable);
    final isNoTimetableDay = isNoTimetable(date, timetable);

    return Scaffold(
      backgroundColor: isAbsolute ? scheme.surface : scheme.primaryContainer,
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
                          color: isAbsolute
                              ? scheme.surfaceContainerHigh
                              : scheme.surface,
                          borderRadius: BorderRadius.circular(40),
                          border: isAbsolute
                              ? Border.all(color: scheme.outlineVariant)
                              : null,
                          boxShadow: isAbsolute
                              ? null
                              : [
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
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: scheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: isAbsolute
                              ? scheme.surfaceContainerHigh
                              : scheme.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: isAbsolute
                              ? Border.all(color: scheme.outlineVariant)
                              : null,
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
                      color: isAbsolute ? scheme.surfaceContainer : scheme.surface,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(32),
                        topRight: Radius.circular(32),
                      ),
                      boxShadow: isAbsolute
                          ? null
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: .12),
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
              color: isAbsolute ? scheme.surfaceContainer : scheme.surface,
            ),
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.of(context).padding.bottom + 20,
            child: Center(
              child: GestureDetector(
                onHorizontalDragEnd: _handleDaySwitcherSwipe,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isAbsolute
                        ? scheme.surfaceContainerHigh
                        : scheme.surface,
                    borderRadius: BorderRadius.circular(32),
                    border: isAbsolute
                        ? Border.all(color: scheme.outlineVariant)
                        : null,
                    boxShadow: isAbsolute
                        ? null
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: .12),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => _changeDay(-1),
                        icon: Icon(
                          Icons.chevron_left_rounded,
                          color: scheme.onSurface,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          'Swipe or tap',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _changeDay(1),
                        icon: Icon(
                          Icons.chevron_right_rounded,
                          color: scheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
