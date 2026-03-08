import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../providers/subject_provider.dart';
import '../providers/attendance_provider.dart';
import '../utils/attendance_utils.dart';
import '../models/subject.dart';
import '../models/attendance.dart';

class SubjectPage extends StatelessWidget {
  const SubjectPage({super.key});

  int canBunk(int attended, int total, double minPercent) {
    if (total == 0) return 0;

    double p = minPercent / 100;
    int bunk = ((attended / p) - total).floor();

    if (bunk < 0) return 0;
    return bunk;
  }

  int needToAttend(int attended, int total, double minPercent) {
    if (total == 0) return 0;

    double p = minPercent / 100;
    int need = ((p * total - attended) / (1 - p)).ceil();

    if (need < 0) return 0;
    return need;
  }

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
                decoration: const InputDecoration(labelText: "Subject Name"),
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
                    const SnackBar(content: Text("Subject name is required")),
                  );
                  return;
                }

                if (short.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Short name is required")),
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
            "Do you want to remove this subject from past entries or only future timetable entries?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),

            TextButton(
              onPressed: () {
                context.read<SubjectProvider>().deleteSubjectFuture(subject.id);
                Navigator.pop(context);
              },
              child: const Text("Future Only"),
            ),

            TextButton(
              onPressed: () {
                context.read<SubjectProvider>().deleteSubjectCompletely(
                  subject.id,
                );
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

  void showRenameDialog(BuildContext context, Subject subject) {
    final nameController = TextEditingController(text: subject.name);
    final shortController = TextEditingController(text: subject.shortName);

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Rename Subject"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Subject Name"),
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
                    const SnackBar(content: Text("Subject name is required")),
                  );
                  return;
                }

                if (short.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Short name is required")),
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

                context.read<SubjectProvider>().renameSubject(
                  subject.id,
                  name,
                  short,
                );

                Navigator.pop(context);
              },
              child: const Text("Rename"),
            ),
          ],
        );
      },
    );
  }

  void showSubjectInfo(BuildContext context, Subject subject) {
    final scheme = Theme.of(context).colorScheme;

    final attendanceProvider = context.read<AttendanceProvider>();

    final records = attendanceProvider.records.values;

    int attended = 0;
    int missed = 0;
    int cancelled = 0;

    for (final r in records) {
      if (r.subjectId != subject.id) continue;

      if (r.status == AttendanceStatus.present) attended++;

      if (r.status == AttendanceStatus.absent) missed++;

      if (r.status == AttendanceStatus.cancelled) cancelled++;
    }

    final total = attended + missed;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(subject.name, style: Theme.of(context).textTheme.titleLarge),

              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  statTile("Total", total, Colors.blue),

                  statTile("Attended", attended, Colors.green),

                  statTile("Missed", missed, Colors.red),

                  statTile("Cancelled", cancelled, Colors.orange),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget statTile(String label, int value, Color color) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .15),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            value.toString(),
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
        ),

        const SizedBox(height: 6),

        Text(label),
      ],
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
                          horizontal: 56,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          borderRadius: BorderRadius.circular(40),
                        ),
                        child: Text(
                          "Subjects",
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
                      itemCount: subjects.length + 1,
                      itemBuilder: (context, index) {
                        if (index == subjects.length) {
                          return const SizedBox(height: 90);
                        }

                        final subject = subjects[index];

                        final stats = calculateStats(
                          subject.id,
                          attendanceProvider.records.values,
                        );

                        double percent = stats.total == 0
                            ? 100
                            : (stats.attended / stats.total) * 100;

                        bool lowAttendance = percent < minAttendance;

                        final tintedColor = lowAttendance
                            ? Color.alphaBlend(
                                scheme.error.withValues(alpha: .2),
                                scheme.onError,
                              )
                            : scheme.secondaryContainer;

                        return Dismissible(
                          key: ValueKey(subject.id),
                          direction: DismissDirection.horizontal,

                          confirmDismiss: (direction) async {
                            if (direction == DismissDirection.startToEnd) {
                              showDeleteDialog(context, subject);
                            } else {
                              showRenameDialog(context, subject);
                            }
                            return false;
                          },

                          background: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 38,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.errorContainer,
                                borderRadius: BorderRadius.circular(28),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 38,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.primaryContainer,
                                borderRadius: BorderRadius.circular(28),
                              ),
                              child: Icon(
                                Icons.edit,
                                color: scheme.onPrimaryContainer,
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
                                    horizontal: 18,
                                    vertical: 42,
                                  ),
                                  decoration: BoxDecoration(
                                    color: tintedColor,
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(20),
                                      topRight: Radius.circular(5),
                                      bottomLeft: Radius.circular(20),
                                      bottomRight: Radius.circular(5),
                                    ),
                                  ),
                                  child: Text(
                                    stats.total == 0
                                        ? "-%"
                                        : "${percent.toStringAsFixed(0)}%",
                                    style: Theme.of(context).textTheme.bodyLarge
                                        ?.copyWith(
                                          fontSize: 18,
                                          color: lowAttendance
                                              ? scheme.error
                                              : scheme.onSecondaryContainer,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ),

                                const SizedBox(width: 8),

                                /// SUBJECT PILL
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      GestureDetector(
                                        onTap: () {
                                          showSubjectInfo(context, subject);
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 20,
                                          ),
                                          decoration: BoxDecoration(
                                            color: tintedColor,
                                            borderRadius:
                                                const BorderRadius.only(
                                                  topRight: Radius.circular(20),
                                                  topLeft: Radius.circular(5),
                                                  bottomLeft: Radius.circular(
                                                    5,
                                                  ),
                                                  bottomRight: Radius.circular(
                                                    5,
                                                  ),
                                                ),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            subject.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleLarge
                                                ?.copyWith(
                                                  color: scheme
                                                      .onSecondaryContainer,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                          ),
                                        ),
                                      ),

                                      const SizedBox(height: 4),

                                      Builder(
                                        builder: (context) {
                                          int attended = stats.attended;
                                          int total = stats.total;

                                          int bunk = canBunk(
                                            attended,
                                            total,
                                            minAttendance,
                                          );
                                          int need = needToAttend(
                                            attended,
                                            total,
                                            minAttendance,
                                          );

                                          bool lowAttendance =
                                              percent < minAttendance;

                                          return Container(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 10,
                                            ),
                                            decoration: BoxDecoration(
                                              color: tintedColor,
                                              borderRadius:
                                                  const BorderRadius.only(
                                                    topLeft: Radius.circular(5),
                                                    topRight: Radius.circular(
                                                      5,
                                                    ),
                                                    bottomLeft: Radius.circular(
                                                      5,
                                                    ),
                                                    bottomRight:
                                                        Radius.circular(20),
                                                  ),
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(
                                              lowAttendance
                                                  ? "Needs to attend $need class${need == 1 ? "" : "es"}"
                                                  : "Can bunk $bunk class${bunk == 1 ? "" : "es"}",
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: lowAttendance
                                                    ? scheme.error
                                                    : scheme
                                                          .onSecondaryContainer,
                                              ),
                                            ),
                                          );
                                        },
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
