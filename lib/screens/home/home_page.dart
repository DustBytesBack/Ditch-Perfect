import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/timetable_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/subject_provider.dart';
import '../../models/attendance.dart';
import '../../widgets/day_timetable.dart';
import '../../widgets/animated_update_icon.dart';
import '../../providers/settings_provider.dart';
import '../../utils/update_checker.dart';

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
      backgroundColor: Colors.transparent,
      builder: (_) {
        String? selectedDayKey;
        final isAbsolute = context.read<ThemeProvider>().absoluteMode;

        return DefaultTabController(
          length: 2,
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Container(
                height: MediaQuery.of(context).size.height * 0.75,
                decoration: BoxDecoration(
                  color: isAbsolute
                      ? scheme.surfaceContainerHigh
                      : scheme.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(32),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Add Subjects',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: scheme.onSurface,
                                fontSize: 28,
                                letterSpacing: 0.8,
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isAbsolute
                              ? scheme.surfaceContainer
                              : scheme.surfaceContainerHighest
                                  .withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const TabBar(
                          dividerColor: Colors.transparent,
                          indicatorSize: TabBarIndicatorSize.tab,
                          tabs: [
                            Tab(text: 'Subject'),
                            Tab(text: 'Timetable'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(40, 0, 40, 48),
                        child: TabBarView(
                          children: [
                            ListView.separated(
                              itemCount: subjects.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final subject = subjects[index];

                                return InkWell(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    timetable.addSubjectToDate(
                                      date,
                                      subject.id,
                                    );
                                    Navigator.pop(context);
                                  },
                                  borderRadius: BorderRadius.circular(20),
                                  child: AnimatedContainer(
                                    duration:
                                        const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 20,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isAbsolute
                                          ? scheme.surfaceContainer
                                          : scheme.surfaceContainerHighest
                                              .withValues(alpha: 0.3),
                                      borderRadius:
                                          BorderRadius.circular(24),
                                    ),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor:
                                              scheme.primaryContainer,
                                          child: Text(
                                            subject.shortName.isEmpty
                                                ? subject.name[0]
                                                : subject.shortName[0],
                                            style: TextStyle(
                                              color:
                                                  scheme.onPrimaryContainer,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                subject.name,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 16,
                                                  color: scheme.onSurface,
                                                ),
                                              ),
                                              if (subject.shortName
                                                  .isNotEmpty)
                                                Text(
                                                  subject.shortName,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: scheme
                                                        .onSurfaceVariant,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
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
                                  final isSelected =
                                      selectedDayKey == day.$1;
                                  final daySlots = timetable.getDaySlots(
                                    day.$1,
                                  );

                                  return Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: 12,
                                    ),
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? scheme.primaryContainer
                                            : (isAbsolute
                                                ? scheme.surfaceContainer
                                                : scheme
                                                    .surfaceContainerHighest
                                                    .withValues(
                                                      alpha: 0.3,
                                                    )),
                                        borderRadius:
                                            BorderRadius.circular(24),
                                        border: Border.all(
                                          color: isSelected
                                              ? scheme.primary
                                              : Colors.transparent,
                                          width: 2,
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
                                                              .onPrimaryContainer
                                                        : scheme
                                                              .onSurfaceVariant,
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Text(
                                                      weekdayNames[day.$1]!,
                                                      style: TextStyle(
                                                        fontWeight: isSelected
                                                            ? FontWeight.w900
                                                            : FontWeight.w700,
                                                        fontSize: 16,
                                                        color: isSelected
                                                            ? scheme
                                                                  .onPrimaryContainer
                                                            : scheme
                                                                  .onSurface,
                                                      ),
                                                    ),
                                                  ),
                                                  Icon(
                                                    isSelected
                                                        ? Icons.expand_less
                                                        : Icons
                                                              .chevron_right,
                                                    color: isSelected
                                                        ? scheme
                                                              .onPrimaryContainer
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
                                                          .onPrimaryContainer,
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
                                                        const EdgeInsets
                                                            .symmetric(
                                                          horizontal: 20,
                                                          vertical: 14,
                                                        ),
                                                    decoration:
                                                        BoxDecoration(
                                                          color: scheme
                                                              .surface,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                    18,
                                                                  ),
                                                        ),
                                                    child: Text(
                                                      shortLabel(
                                                        subjectId,
                                                      ),
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        color: scheme
                                                            .onSurface,
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
                    ),
                  ],
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

    final today = DateTime.now();

    final slots = timetable.getSlotsForDate(today);
    final slotIds = timetable.getSlotIdsForDate(today);

    final isWeekend =
        today.weekday == DateTime.saturday || today.weekday == DateTime.sunday;
    final isHoliday = isWeekend && slots.isEmpty;

    return Scaffold(
      backgroundColor: isAbsolute ? scheme.surface : scheme.primaryContainer,
      body: Stack(
        children: [
          /// GRADIENT BACKGROUND
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    isAbsolute ? scheme.surface : scheme.primaryContainer,
                    isAbsolute ? scheme.surfaceContainer : scheme.surface,
                  ],
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
                          color: isAbsolute
                              ? scheme.surfaceContainerHigh
                              : scheme.surface,
                          borderRadius: BorderRadius.circular(40),
                          border: isAbsolute
                              ? Border.all(
                                  color: scheme.primary.withValues(alpha: 0.10),
                                )
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
                          color: isAbsolute
                              ? scheme.surfaceContainerHigh
                              : scheme.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: isAbsolute
                              ? Border.all(
                                  color: scheme.primary.withValues(alpha: 0.10),
                                )
                              : null,
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
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isAbsolute
                          ? scheme.surfaceContainer
                          : scheme.surface,
                      borderRadius: BorderRadius.circular(32),
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

                    child: isHoliday
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              child: Text(
                                "Its holiday bruv, go waste yo life",
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                          )
                        : slots.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              child: Text(
                                "Add a subject",
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
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  // UPDATE NOTIFICATION ICON
                                  Consumer<SettingsProvider>(
                                    builder: (context, settings, child) {
                                      final update = settings.updateInfo;
                                      if (update == null) {
                                        return const SizedBox.shrink();
                                      }

                                      return Container(
                                        margin: const EdgeInsets.only(left: 12),
                                        decoration: const BoxDecoration(
                                          color: Colors.transparent,
                                        ),
                                        child: IconButton(
                                          iconSize: 26,
                                          padding: const EdgeInsets.all(12),
                                          icon: AnimatedUpdateIcon(
                                            color: scheme.tertiary,
                                            size: 26,
                                          ),
                                          onPressed: () {
                                            showUpdateDialog(context, update);
                                          },
                                        ),
                                      );
                                    },
                                  ),

                                  SizedBox(
                                    width:
                                        MediaQuery.of(context).size.width * 0.4,

                                    child: SegmentedButton<BulkAction>(
                                      style: SegmentedButton.styleFrom(
                                        selectedBackgroundColor:
                                            scheme.tertiaryContainer,
                                        selectedForegroundColor:
                                            scheme.onTertiaryContainer,
                                        backgroundColor: scheme
                                            .tertiaryContainer
                                            .withValues(alpha: .5),
                                        foregroundColor: scheme
                                            .onTertiaryContainer
                                            .withValues(alpha: .8),
                                        side: BorderSide(
                                          color: scheme.tertiary.withValues(
                                            alpha: 0.8,
                                          ),
                                        ),
                                      ),
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
                                                today,
                                                slots,
                                                AttendanceStatus.present,
                                                slotIds: slotIds,
                                              );
                                            }

                                            if (action == BulkAction.absent) {
                                              attendance.markAll(
                                                today,
                                                slots,
                                                AttendanceStatus.absent,
                                                slotIds: slotIds,
                                              );
                                            }

                                            if (action ==
                                                BulkAction.cancelled) {
                                              attendance.markAll(
                                                today,
                                                slots,
                                                AttendanceStatus.cancelled,
                                                slotIds: slotIds,
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
                                                  slotIds[i],
                                                  legacySlotIndex: i,
                                                );
                                              }
                                            }
                                          },
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 14),

                              /// TIMETABLE
                              Expanded(child: DayTimetable(date: today)),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
