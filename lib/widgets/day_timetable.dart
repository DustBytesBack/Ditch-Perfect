import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/timetable_provider.dart';
import '../providers/subject_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/attendance_provider.dart';
import '../providers/settings_provider.dart';
import '../models/attendance.dart';
import '../models/subject.dart';
import '../services/tutorial_service.dart';
import '../utils/attendance_utils.dart';
import '../utils/holiday_utils.dart';

class DayTimetable extends StatelessWidget {
  final DateTime date;

  const DayTimetable({super.key, required this.date});

  int canBunk(int attended, int total, double minPercent) {
    if (total == 0) return 0;

    double p = minPercent / 100;
    int bunk = ((attended / p) - total).floor();

    return bunk < 0 ? 0 : bunk;
  }

  int needToAttend(int attended, int total, double minPercent) {
    if (total == 0) return 0;

    double p = minPercent / 100;
    int need = ((p * total - attended) / (1 - p)).ceil();

    return need < 0 ? 0 : need;
  }

  Widget buildStatusButton(
    BuildContext context,
    AttendanceStatus current,
    AttendanceStatus status,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    final selected = status != AttendanceStatus.none && current == status;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: .25),
          borderRadius: BorderRadius.circular(selected ? 24 : 12),
        ),
        child: Icon(icon, color: selected ? Colors.white : color, size: 20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isAbsolute = themeProvider.absoluteMode;
    final scheme = Theme.of(context).colorScheme;

    final timetable = context.watch<TimetableProvider>();
    final subjects = context.watch<SubjectProvider>().subjects;
    final attendance = context.watch<AttendanceProvider>();
    final minAttendance = context.watch<SettingsProvider>().minAttendance;

    final slots = timetable.getSlotsForDate(date);

    final baseSlots = timetable.getDaySlots(weekdayKey(date));
    final baseCount = baseSlots.length;

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 90),
      itemCount: slots.length,
      itemBuilder: (context, index) {
        final subjectId = slots[index];

        final subject = subjects.firstWhere(
          (s) => s.id == subjectId,
          orElse: () => Subject(id: "", name: "", shortName: ""),
        );

        final status = attendance.getStatus(date, index);

        final stats = calculateStats(subject.id, attendance.records.values);

        int attended = stats.attended;
        int total = stats.total;

        double percent = total == 0 ? 100 : (attended / total) * 100;

        bool lowAttendance = percent < minAttendance;

        int bunk = canBunk(attended, total, minAttendance);
        int need = needToAttend(attended, total, minAttendance);

        final tintedColor = (themeProvider.pookieMode || isAbsolute)
            ? scheme.surfaceContainerHigh
            : (lowAttendance
                ? Color.alphaBlend(
                    scheme.error.withValues(alpha: .12),
                    scheme.secondaryContainer,
                  )
                : scheme.secondaryContainer);

        final isExtra = index >= baseCount;

        return Padding(
          key: index == 0
              ? TutorialService.keyFor(TutorialTargets.homeFirstSubjectRow)
              : null,
          padding: const EdgeInsets.only(bottom: 14),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              /// SUBJECT ROW
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onLongPress: isExtra
                          ? () {
                              HapticFeedback.mediumImpact();
                              showDialog(
                                context: context,
                                builder: (_) {
                                  return AlertDialog(
                                    title: const Text("Remove Extra Subject"),
                                    content: const Text(
                                      "Do you want to remove this extra subject from this day?",
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(context);
                                        },
                                        child: const Text("Cancel"),
                                      ),

                                      TextButton(
                                        onPressed: () {
                                          timetable.removeExtraSubject(
                                            date,
                                            index - baseCount,
                                          );
                                          Navigator.pop(context);
                                        },
                                        child: Text(
                                          "Remove",
                                          style: TextStyle(color: scheme.error),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              );
                            }
                          : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 18,
                          horizontal: 12,
                        ),
                        decoration: BoxDecoration(
                          color: tintedColor,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(5),
                            bottomLeft: Radius.circular(5),
                            bottomRight: Radius.circular(5),
                          ),
                          border: (themeProvider.pookieMode || isAbsolute)
                              ? Border.all(
                                  color: themeProvider.pookieMode || isAbsolute
                                      ? scheme.primary.withValues(alpha: 0.10)
                                      : scheme.outlineVariant.withValues(alpha: 0.2),
                                  width: 1,
                                )
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                subject.shortName.isEmpty
                                    ? subject.name
                                    : subject.shortName,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: lowAttendance
                                          ? scheme.error
                                          : scheme.onSecondaryContainer,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),

                            if (isExtra) ...[
                              const SizedBox(width: 8),

                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: scheme.primary.withValues(alpha: .15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  "EXTRA",
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: scheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 6),

                  /// CLEAR ATTENDANCE
                  buildStatusButton(
                    context,
                    status,
                    AttendanceStatus.none,
                    Icons.clear_all_outlined,
                    Colors.grey,
                    () {
                      attendance.clearAttendance(date, index);
                    },
                  ),

                  const SizedBox(width: 6),

                  /// CANCELLED
                  buildStatusButton(
                    context,
                    status,
                    AttendanceStatus.cancelled,
                    Icons.block,
                    Colors.orange,
                    () {
                      attendance.markAttendance(
                        date,
                        subject.id,
                        index,
                        AttendanceStatus.cancelled,
                      );
                    },
                  ),

                  const SizedBox(width: 6),

                  /// ABSENT
                  buildStatusButton(
                    context,
                    status,
                    AttendanceStatus.absent,
                    Icons.close,
                    Colors.red,
                    () {
                      attendance.markAttendance(
                        date,
                        subject.id,
                        index,
                        AttendanceStatus.absent,
                      );
                    },
                  ),

                  const SizedBox(width: 6),

                  /// PRESENT
                  buildStatusButton(
                    context,
                    status,
                    AttendanceStatus.present,
                    Icons.check,
                    Colors.green,
                    () {
                      attendance.markAttendance(
                        date,
                        subject.id,
                        index,
                        AttendanceStatus.present,
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 6),

              /// INFO PILL
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: tintedColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(5),
                    topRight: Radius.circular(5),
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  border: (themeProvider.pookieMode || isAbsolute)
                      ? Border.all(
                          color: themeProvider.pookieMode || isAbsolute
                              ? scheme.primary.withValues(alpha: 0.10)
                              : scheme.outlineVariant.withValues(alpha: 0.2),
                          width: 1,
                        )
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  lowAttendance
                      ? "Needs to attend $need class${need == 1 ? "" : "es"}"
                      : "Can bunk $bunk class${bunk == 1 ? "" : "es"}",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: lowAttendance
                        ? scheme.error
                        : scheme.onSecondaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
