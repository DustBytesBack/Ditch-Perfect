import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'subject_summary_page.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/subject_provider.dart';
import '../providers/attendance_provider.dart';
import '../utils/attendance_utils.dart';
import '../models/subject.dart';
import '../models/attendance.dart';

class SubjectPage extends StatefulWidget {
  const SubjectPage({super.key});

  @override
  State<SubjectPage> createState() => _SubjectPageState();
}

class _SubjectPageState extends State<SubjectPage> {
  String? _selectedSubjectId;

  static const List<(String, String)> _attendanceInputModes = [
    ('total', 'I know total classes'),
    ('attended', 'I know attended classes'),
  ];

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
    final themeProvider = context.read<ThemeProvider>();
    final isDynamic = themeProvider.isDynamicMode;
    final isAbsolute = themeProvider.absoluteMode;
    
    final nameController = TextEditingController();
    final shortController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Add Subject"),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: "Subject Name",
                  prefixIcon: const Icon(Icons.subject),
                  filled: true,
                  fillColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: .5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: (isDynamic || isAbsolute) 
                        ? BorderSide(color: Theme.of(context).colorScheme.outlineVariant) 
                        : BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: (isDynamic || isAbsolute) 
                        ? BorderSide(color: Theme.of(context).colorScheme.outlineVariant) 
                        : BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              TextField(
                controller: shortController,
                maxLength: 8,
                decoration: InputDecoration(
                  labelText: "Short Name (max 8 letters)",
                  prefixIcon: const Icon(Icons.short_text),
                  filled: true,
                  fillColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: .5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: (isDynamic || isAbsolute) 
                        ? BorderSide(color: Theme.of(context).colorScheme.outlineVariant) 
                        : BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: (isDynamic || isAbsolute) 
                        ? BorderSide(color: Theme.of(context).colorScheme.outlineVariant) 
                        : BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                  ),
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

  void showAttendanceEditDialog(
    BuildContext context,
    Subject subject,
    AttendanceStats stats,
  ) {
    final themeProvider = context.read<ThemeProvider>();
    final isDynamic = themeProvider.isDynamicMode;
    final isAbsolute = themeProvider.absoluteMode;
    
    final percentController = TextEditingController(
      text: stats.total == 0 ? '' : stats.percentage.toStringAsFixed(2),
    );
    final totalController = TextEditingController(
      text: stats.total == 0 ? '' : stats.total.toString(),
    );
    final attendedController = TextEditingController(
      text: stats.attended == 0 ? '' : stats.attended.toString(),
    );
    String inputMode = 'total';

    showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final currentController = inputMode == 'total'
                ? totalController
                : attendedController;

            return AlertDialog(
              title: Text('Edit ${subject.shortName} Attendance'),
              contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: percentController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Current attendance %',
                      prefixIcon: const Icon(Icons.percent),
                      filled: true,
                      fillColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: .5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: (isDynamic || isAbsolute) 
                            ? BorderSide(color: Theme.of(context).colorScheme.outlineVariant) 
                            : BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: (isDynamic || isAbsolute) 
                            ? BorderSide(color: Theme.of(context).colorScheme.outlineVariant) 
                            : BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownMenu<String>(
                    width:
                        MediaQuery.of(context).size.width -
                        96, // AlertDialog content padding is 24 on each side, + arbitrary dialog margin
                    initialSelection: inputMode,
                    label: const Text('Known value'),
                    leadingIcon: const Icon(Icons.tune),
                    menuStyle: MenuStyle(
                      backgroundColor: WidgetStatePropertyAll(
                        Theme.of(context).colorScheme.surface,
                      ),
                      elevation: const WidgetStatePropertyAll(4),
                      shape: WidgetStatePropertyAll(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                    inputDecorationTheme: InputDecorationTheme(
                      filled: true,
                      fillColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: .5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: (isDynamic || isAbsolute) 
                            ? BorderSide(color: Theme.of(context).colorScheme.outlineVariant) 
                            : BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: (isDynamic || isAbsolute) 
                            ? BorderSide(color: Theme.of(context).colorScheme.outlineVariant) 
                            : BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 18,
                      ),
                    ),
                    textStyle: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                    dropdownMenuEntries: _attendanceInputModes.map((mode) {
                      return DropdownMenuEntry<String>(
                        value: mode.$1,
                        label: mode.$2,
                        style: MenuItemButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          textStyle: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w500),
                        ),
                      );
                    }).toList(),
                    onSelected: (value) {
                      if (value != null) {
                        HapticFeedback.lightImpact();
                        setDialogState(() {
                          inputMode = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: currentController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: inputMode == 'total'
                          ? 'Total classes'
                          : 'Attended classes',
                      prefixIcon: Icon(
                        inputMode == 'total'
                            ? Icons.class_outlined
                            : Icons.check_circle_outline,
                      ),
                      filled: true,
                      fillColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: .5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: (isDynamic || isAbsolute) 
                            ? BorderSide(color: Theme.of(context).colorScheme.outlineVariant) 
                            : BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: (isDynamic || isAbsolute) 
                            ? BorderSide(color: Theme.of(context).colorScheme.outlineVariant) 
                            : BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final percent = double.tryParse(
                      percentController.text.trim(),
                    );
                    final knownValue = int.tryParse(
                      currentController.text.trim(),
                    );

                    if (percent == null || percent < 0 || percent > 100) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Enter a valid attendance percentage'),
                        ),
                      );
                      return;
                    }

                    if (knownValue == null || knownValue < 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Enter a valid class count'),
                        ),
                      );
                      return;
                    }

                    int attended;
                    int total;

                    if (inputMode == 'total') {
                      total = knownValue;
                      attended = ((percent / 100) * total).round();
                    } else {
                      attended = knownValue;
                      if (percent == 0) {
                        if (attended > 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                '0% attendance cannot have attended classes',
                              ),
                            ),
                          );
                          return;
                        }
                        total = 0;
                      } else {
                        total = (attended / (percent / 100)).round();
                      }
                    }

                    if (attended > total) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Attended classes cannot be greater than total classes',
                          ),
                        ),
                      );
                      return;
                    }

                    final computedPercent = total == 0
                        ? 0.0
                        : (attended / total) * 100;

                    if ((computedPercent - percent).abs() > 0.6) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Those values do not produce a close enough attendance percentage',
                          ),
                        ),
                      );
                      return;
                    }

                    context
                        .read<AttendanceProvider>()
                        .replaceSubjectAttendanceBaseline(
                          subject.id,
                          attended: attended,
                          total: total,
                        );

                    Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void showSubjectInfo(
    BuildContext context,
    Subject subject,
    AttendanceStats stats,
  ) {
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
              Text(subject.name, style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),

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

              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 64,
                      child: FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          backgroundColor: scheme.tertiaryContainer,
                          foregroundColor: scheme.onTertiaryContainer,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.horizontal(
                              left: Radius.circular(32),
                              right: Radius.circular(4),
                            ),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  SubjectSummaryPage(subject: subject),
                            ),
                          );
                        },
                        icon: const Icon(Icons.analytics_outlined, size: 24),
                        label: const Text("Summary"),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: SizedBox(
                      height: 64,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: scheme.tertiary,
                          foregroundColor: scheme.onTertiary,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.horizontal(
                              left: Radius.circular(4),
                              right: Radius.circular(32),
                            ),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          showAttendanceEditDialog(context, subject, stats);
                        },
                        icon: const Icon(Icons.edit, size: 24),
                        label: const Text("Edit"),
                      ),
                    ),
                  ),
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
          width: 50,
          height: 50,
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
    final themeProvider = context.watch<ThemeProvider>();
    final isAbsolute = themeProvider.absoluteMode;
    final scheme = Theme.of(context).colorScheme;

    final subjects = context.watch<SubjectProvider>().subjects;
    final attendanceProvider = context.watch<AttendanceProvider>();
    final minAttendance = context.watch<SettingsProvider>().minAttendance;

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
                  stops: const [0, 1.0],
                  colors: [
                    isAbsolute ? scheme.surface : scheme.primaryContainer,
                    isAbsolute ? scheme.surfaceContainer : scheme.surface,
                  ],
                ),
              ),
            ),
          ),

          /// BACKGROUND TAP TO DESELECT
          if (_selectedSubjectId != null)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  setState(() {
                    _selectedSubjectId = null;
                  });
                },
                child: const SizedBox(),
              ),
            ),

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
                          color: isAbsolute
                              ? scheme.surfaceContainerHigh
                              : scheme.surface,
                          borderRadius: BorderRadius.circular(40),
                          border: isAbsolute
                              ? Border.all(color: scheme.outlineVariant)
                              : null,
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
                          color: isAbsolute
                              ? scheme.surfaceContainerHigh
                              : scheme.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: isAbsolute
                              ? Border.all(color: scheme.outlineVariant)
                              : null,
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
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isAbsolute
                          ? scheme.surfaceContainer
                          : scheme.surface,
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

                        final tintedColor = (themeProvider.pookieMode)
                            ? scheme.surfaceContainerHigh
                            : (lowAttendance
                                  ? Color.alphaBlend(
                                      scheme.error.withValues(alpha: .2),
                                      scheme.onError,
                                    )
                                  : (isAbsolute
                                        ? scheme.surfaceContainerHigh
                                        : scheme.secondaryContainer));

                        final isSelected = _selectedSubjectId == subject.id;
                        final isAnySelected = _selectedSubjectId != null;

                        return Dismissible(
                          key: ValueKey(subject.id),
                          direction: isAnySelected
                              ? DismissDirection.none
                              : DismissDirection.horizontal,

                          confirmDismiss: (direction) async {
                            if (direction == DismissDirection.startToEnd) {
                              HapticFeedback.mediumImpact();
                              showDeleteDialog(context, subject);
                            } else {
                              HapticFeedback.lightImpact();
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

                          child: GestureDetector(
                            onLongPress: () {
                              HapticFeedback.mediumImpact();
                              setState(() {
                                _selectedSubjectId = subject.id;
                              });
                            },
                            onTap: isAnySelected
                                ? () {
                                    if (isSelected) {
                                      setState(() {
                                        _selectedSubjectId = null;
                                      });
                                    } else {
                                      HapticFeedback.lightImpact();
                                      setState(() {
                                        _selectedSubjectId = subject.id;
                                      });
                                    }
                                  }
                                : null,
                            child: AnimatedScale(
                              scale: isSelected
                                  ? 1.02
                                  : (isAnySelected ? 0.95 : 1.0),
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOutCubic,
                              child: AnimatedOpacity(
                                opacity: isAnySelected && !isSelected
                                    ? 0.4
                                    : 1.0,
                                duration: const Duration(milliseconds: 200),
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: Row(
                                    children: [
                                      /// ATTENDANCE PILL
                                      Container(
                                        width: 100,
                                        alignment: Alignment.center,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 39,
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
                                        child: stats.total == 0
                                            ? Text(
                                                "-%",
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyLarge
                                                    ?.copyWith(
                                                      fontSize: 18,
                                                      color: lowAttendance
                                                          ? scheme.error
                                                          : scheme
                                                                .onSecondaryContainer,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                              )
                                            : RichText(
                                                text: TextSpan(
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodyLarge
                                                      ?.copyWith(
                                                        fontSize: 24,
                                                        color: lowAttendance
                                                            ? scheme.error
                                                            : scheme
                                                                  .onSecondaryContainer,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                  children: [
                                                    TextSpan(
                                                      text: percent
                                                          .toStringAsFixed(2)
                                                          .split('.')[0],
                                                    ),
                                                    TextSpan(
                                                      text:
                                                          ".${percent.toStringAsFixed(2).split('.')[1]}%",
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ],
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
                                              onTap: isAnySelected
                                                  ? null
                                                  : () {
                                                      showSubjectInfo(
                                                        context,
                                                        subject,
                                                        stats,
                                                      );
                                                    },
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 20,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: tintedColor,
                                                  borderRadius:
                                                      const BorderRadius.only(
                                                        topRight:
                                                            Radius.circular(20),
                                                        topLeft:
                                                            Radius.circular(5),
                                                        bottomLeft:
                                                            Radius.circular(5),
                                                        bottomRight:
                                                            Radius.circular(5),
                                                      ),
                                                  border:
                                                      (themeProvider.pookieMode)
                                                      ? Border.all(
                                                          color: scheme.primary
                                                              .withValues(
                                                                alpha: 0.15,
                                                              ),
                                                          width: 1,
                                                        )
                                                      : null,
                                                ),
                                                alignment: Alignment.center,
                                                child: Text(
                                                  subject.name,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleLarge
                                                      ?.copyWith(
                                                        color: scheme
                                                            .onSecondaryContainer,
                                                        fontWeight:
                                                            FontWeight.w800,
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
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 10,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: tintedColor,
                                                    borderRadius:
                                                        const BorderRadius.only(
                                                          topLeft:
                                                              Radius.circular(
                                                                5,
                                                              ),
                                                          topRight:
                                                              Radius.circular(
                                                                5,
                                                              ),
                                                          bottomLeft:
                                                              Radius.circular(
                                                                5,
                                                              ),
                                                          bottomRight:
                                                              Radius.circular(
                                                                20,
                                                              ),
                                                        ),
                                                    border:
                                                        (themeProvider
                                                            .pookieMode)
                                                        ? Border.all(
                                                            color: scheme
                                                                .primary
                                                                .withValues(
                                                                  alpha: 0.15,
                                                                ),
                                                            width: 1,
                                                          )
                                                        : null,
                                                  ),
                                                  alignment: Alignment.center,
                                                  child: Text(
                                                    lowAttendance
                                                        ? "Needs to attend $need class${need == 1 ? "" : "es"}"
                                                        : "Can bunk $bunk class${bunk == 1 ? "" : "es"}",
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
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
                              ),
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

          /// FLOATING ACTION BAR FOR SELECTION
          AnimatedPositioned(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            bottom: _selectedSubjectId != null
                ? MediaQuery.of(context).padding.bottom + 140
                : -100,
            left: 24,
            right: 24,
            child: AnimatedScale(
              scale: _selectedSubjectId != null ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.shadow.withValues(alpha: .12),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Row(
                children: [
                  Expanded(
                    child: _selectionActionButton(
                      context: context,
                      icon: Icons.edit,
                      color: scheme.primary,
                      label: 'Rename',
                      onTap: () {
                        final subject = subjects.firstWhere(
                          (s) => s.id == _selectedSubjectId,
                        );
                        setState(() => _selectedSubjectId = null);
                        showRenameDialog(context, subject);
                      },
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _selectionActionButton(
                      context: context,
                      icon: Icons.fact_check_outlined,
                      color: scheme.primary,
                      label: 'Attendance',
                      onTap: () {
                        final subject = subjects.firstWhere(
                          (s) => s.id == _selectedSubjectId,
                        );
                        final stats = calculateStats(
                          subject.id,
                          attendanceProvider.records.values,
                        );
                        setState(() => _selectedSubjectId = null);
                        showAttendanceEditDialog(context, subject, stats);
                      },
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _selectionActionButton(
                      context: context,
                      icon: Icons.delete,
                      color: scheme.error,
                      label: 'Delete',
                      onTap: () {
                        final subject = subjects.firstWhere(
                          (s) => s.id == _selectedSubjectId,
                        );
                        setState(() => _selectedSubjectId = null);
                        showDeleteDialog(context, subject);
                      },
                    ),
                  ),
                ],
              ),
              ),
            ),
          ),

          /// FIX GESTURE NAV BAR COLOR
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: MediaQuery.of(context).padding.bottom + 12,
              color: isAbsolute ? scheme.surfaceContainer : scheme.surface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _selectionActionButton({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 24, color: color),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
