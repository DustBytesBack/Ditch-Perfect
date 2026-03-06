import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../providers/subject_provider.dart';
import '../providers/attendance_provider.dart';
import '../utils/attendance_utils.dart';
import '../models/subject.dart';

class SubjectPage extends StatelessWidget {
  const SubjectPage({super.key});

  void showAddDialog(BuildContext context) {
    final nameController = TextEditingController();
    final shortController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Add Subject"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: "Subject Name",
                ),
              ),

              TextField(
                controller: shortController,
                maxLength: 8,
                decoration: const InputDecoration(
                  labelText: "Short Name (max 8 letters)",
                ),
              ),
            ],
          ),
          actions: [

            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),

            FilledButton(
              onPressed: () {

                final name = nameController.text.trim();
                final short = shortController.text.trim();

                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Subject name is required"),
                    ),
                  );
                  return;
                }

                if (short.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Short name is required"),
                    ),
                  );
                  return;
                }

                if (short.length > 8) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Short name must be ≤ 8 characters"),
                    ),
                  );
                  return;
                }

                context.read<SubjectProvider>().addSubject(name, short);

                Navigator.pop(context);
              },
              child: const Text("Add"),
            ),
          ],
        );
      },
    );
  }

  void showDeleteDialog(BuildContext context, Subject subject) {
    final scheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Delete Subject"),
          content: const Text(
              "Do you want to remove this subject from past entries or only future timetable entries?"),
          actions: [

            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),

            TextButton(
              onPressed: () {
                context
                    .read<SubjectProvider>()
                    .deleteSubjectFuture(subject.id);
                Navigator.pop(context);
              },
              child: const Text("Future Only"),
            ),

            TextButton(
              onPressed: () {
                context
                    .read<SubjectProvider>()
                    .deleteSubjectCompletely(subject.id);
                Navigator.pop(context);
              },
              child: Text(
                "Delete All Entries",
                style: TextStyle(
                  color: scheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final subjects = context.watch<SubjectProvider>().subjects;
    final attendanceProvider = context.watch<AttendanceProvider>();
    final minAttendance = context.watch<SettingsProvider>().minAttendance;

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
                            horizontal: 56, vertical: 16),
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          borderRadius: BorderRadius.circular(40),
                        ),
                        child: Text(
                          "Subjects",
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                  color: scheme.onSurface,
                                  fontWeight: FontWeight.w600),
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
                          icon: Icon(Icons.add, color: scheme.onSurface),
                          onPressed: () => showAddDialog(context),
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

                    child: ListView.builder(
                      itemCount: subjects.length,
                      itemBuilder: (context, index) {

                        final subject = subjects[index];

                        final stats = calculateStats(
                          subject.id,
                          attendanceProvider.records.values,
                        );

                        double percent = stats.total == 0
                            ? 100
                            : (stats.attended / stats.total) * 100;

                        bool lowAttendance = percent < minAttendance;

                        return Dismissible(
                          key: ValueKey(subject.id),
                          direction: DismissDirection.horizontal,

                          confirmDismiss: (_) async {
                            showDeleteDialog(context, subject);
                            return false;
                          },

                          background: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
                              decoration: BoxDecoration(
                                color: scheme.errorContainer,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(18),
                                  bottomLeft: Radius.circular(18),
                                ),
                              ),
                              child: Icon(
                                Icons.delete,
                                color: scheme.onErrorContainer,
                              ),
                            ),
                          ),

                          secondaryBackground: Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
                              decoration: BoxDecoration(
                                color: scheme.errorContainer,
                                borderRadius: const BorderRadius.only(
                                  topRight: Radius.circular(18),
                                  bottomRight: Radius.circular(18),
                                ),
                              ),
                              child: Icon(
                                Icons.delete,
                                color: scheme.onErrorContainer,
                              ),
                            ),
                          ),

                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Row(
                              children: [

                                /// ATTENDANCE PILL
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 18, vertical: 20),
                                  decoration: BoxDecoration(
                                    color: scheme.secondaryContainer,
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(20),
                                      bottomLeft: Radius.circular(20),
                                    ),
                                  ),
                                  child: Text(
                                    "${stats.attended}/${stats.total}",
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.copyWith(
                                          color: lowAttendance
                                              ? scheme.error
                                              : scheme.onSecondaryContainer,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ),

                                const SizedBox(width: 8),

                                /// SUBJECT PILL
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 20),
                                    decoration: BoxDecoration(
                                      color: scheme.secondaryContainer,
                                      borderRadius: const BorderRadius.only(
                                        topRight: Radius.circular(20),
                                        bottomRight: Radius.circular(20),
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
                              ],
                            ),
                          ),
                        );
                      },
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