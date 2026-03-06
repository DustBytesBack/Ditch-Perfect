import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/timetable_provider.dart';
import '../providers/subject_provider.dart';
import '../providers/attendance_provider.dart';
import '../models/attendance.dart';
import '../models/subject.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  String formatDate(DateTime date) {
    const months = [
      "January","February","March","April","May","June",
      "July","August","September","October","November","December"
    ];

    return "${date.day} ${months[date.month - 1]} ${date.year}";
  }

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

          borderRadius: BorderRadius.circular(
            selected ? 24 : 12,
          ),
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

    final today = DateTime.now();
    final slots = timetable.getTodaySlots();

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
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 12,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),

                child: ListView.builder(
                  itemCount: slots.length,

                  itemBuilder: (context, index) {

                    final subjectId = slots[index];

                    if (subjectId == null) {
                      return const SizedBox();
                    }

                    final subject = subjects.firstWhere(
                      (s) => s.id == subjectId,
                      orElse: () => Subject(
                        id: "",
                        name: "",
                        shortName: "",
                      ),
                    );

                    final status =
                        attendance.getStatus(today, index);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),

                      child: Row(
                        children: [

                          /// SUBJECT PILL
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 18,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.secondaryContainer,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(20),
                                  topRight: Radius.circular(5),
                                  bottomLeft: Radius.circular(20),
                                  bottomRight: Radius.circular(5)
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

                          /// CANCELLED
                          buildStatusButton(
                            context,
                            status,
                            AttendanceStatus.cancelled,
                            Icons.block,
                            Colors.orange,
                            () {
                              context
                                  .read<AttendanceProvider>()
                                  .markAttendance(
                                    today,
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
                              context
                                  .read<AttendanceProvider>()
                                  .markAttendance(
                                    today,
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
                              context
                                  .read<AttendanceProvider>()
                                  .markAttendance(
                                    today,
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
                ),
              ),
            ),
          ],
        ),
      ),

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