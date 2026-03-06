import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/timetable_provider.dart';
import '../providers/subject_provider.dart';
import '../providers/attendance_provider.dart';
import '../models/attendance.dart';
import '../models/subject.dart';
import '../utils/holiday_utils.dart';

class DayTimetable extends StatelessWidget {

  final DateTime date;

  const DayTimetable({
    super.key,
    required this.date,
  });

  Widget buildStatusButton(
    BuildContext context,
    AttendanceStatus current,
    AttendanceStatus status,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {

    final selected = current == status;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),

        decoration: BoxDecoration(
          color: selected ? color : color.withOpacity(.25),
          borderRadius: BorderRadius.circular(selected ? 24 : 12),
        ),

        child: Icon(
          icon,
          color: selected ? Colors.white : color,
          size: 20,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    final scheme = Theme.of(context).colorScheme;

    final timetable = context.watch<TimetableProvider>();
    final subjects = context.watch<SubjectProvider>().subjects;
    final attendance = context.watch<AttendanceProvider>();

    final slots = timetable.getDaySlots(weekdayKey(date));

    return ListView.builder(
      itemCount: slots.length,
      itemBuilder: (context, index) {

        final subjectId = slots[index];

        if (subjectId == null) {
          return const SizedBox();
        }

        final subject = subjects.firstWhere(
          (s) => s.id == subjectId,
          orElse: () => Subject(id: "", name: "", shortName: ""),
        );

        final status = attendance.getStatus(date, index);

        return Padding(
          padding: const EdgeInsets.only(bottom: 14),

          child: Row(
            children: [

              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(5),
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(5),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    subject.name,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                          color: scheme.onSecondaryContainer,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ),
              ),

              const SizedBox(width: 6),

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
        );
      },
    );
  }
}