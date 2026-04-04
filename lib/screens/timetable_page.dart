import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/timetable_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/subject_provider.dart';
import 'timetable_editor_page.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import 'preset_browser_page.dart';
import '../widgets/slidable_tile.dart';

const dayNames = {
  "mon": "Monday",
  "tue": "Tuesday",
  "wed": "Wednesday",
  "thu": "Thursday",
  "fri": "Friday",
  "sat": "Saturday",
  "sun": "Sunday",
};

class TimetablePage extends StatelessWidget {
  const TimetablePage({super.key});

  void _showEditOptions(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final themeProvider = context.read<ThemeProvider>();
    final isAbsolute = themeProvider.absoluteMode;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: isAbsolute
          ? scheme.surfaceContainerHigh
          : scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildOption(
                  context,
                  icon: Icons.edit_calendar_rounded,
                  label: "Add",
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TimetableEditorPage(),
                      ),
                    );
                  },
                ),
                _buildOption(
                  context,
                  icon: Icons.library_add_rounded,
                  label: "Preset",
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PresetBrowserPage(),
                      ),
                    );
                  },
                ),
                _buildOption(
                  context,
                  icon: Icons.camera_alt_outlined,
                  label: "Scan",
                  onTap: () {
                    Navigator.pop(context);
                    _showFeatureOnWay(context);
                  },
                ),
                _buildOption(
                  context,
                  icon: Icons.photo_library_outlined,
                  label: "Gallery",
                  onTap: () {
                    Navigator.pop(context);
                    _showFeatureOnWay(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: .4),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: scheme.primary, size: 28),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: scheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFeatureOnWay(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Feature on the way"),
        content: const Text("Lazy Developer Problems ¯\\_(ツ)_/¯."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Dismiss"),
          ),
        ],
      ),
    );
  }

  void _showEmptyTimetablePrompt(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("No Timetable Found"),
          content: const Text(
            "It looks like you haven't created a timetable yet. "
            "Please create a timetable first before you can upload it to the cloud!",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  void _showUploadDialog(BuildContext context) {
    final themeProvider = context.read<ThemeProvider>();
    final isDynamic = themeProvider.isDynamicMode;
    final isAbsolute = themeProvider.absoluteMode;
    final scheme = Theme.of(context).colorScheme;

    final timetable = context.read<TimetableProvider>();
    final subjects = context.read<SubjectProvider>().subjects;

    final universityController = TextEditingController();
    final yearController = TextEditingController();
    final branchController = TextEditingController();
    final batchController = TextEditingController();

    int currentStep = 0;
    bool isValidating = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isStepOne = currentStep == 0;

            return AlertDialog(
              title: Text(isStepOne ? "Upload Timetable" : "Confirm Timetable"),
              contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: isStepOne
                    ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildDialogField(
                          context,
                          controller: universityController,
                          label: "University",
                          icon: Icons.account_balance_rounded,
                          isDynamic: isDynamic,
                          isAbsolute: isAbsolute,
                        ),
                        const SizedBox(height: 16),
                        _buildDialogField(
                          context,
                          controller: yearController,
                          label: "Year / Semester / Both",
                          icon: Icons.calendar_today_rounded,
                          isDynamic: isDynamic,
                          isAbsolute: isAbsolute,
                        ),
                        const SizedBox(height: 16),
                        _buildDialogField(
                          context,
                          controller: branchController,
                          label: "Branch",
                          icon: Icons.school_rounded,
                          isDynamic: isDynamic,
                          isAbsolute: isAbsolute,
                        ),
                        const SizedBox(height: 16),
                        _buildDialogField(
                          context,
                          controller: batchController,
                          label: "Batch",
                          icon: Icons.group_rounded,
                          isDynamic: isDynamic,
                          isAbsolute: isAbsolute,
                        ),
                      ],
                    )
                    : ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.5,
                      ),
                      child: SingleChildScrollView(
                        child: Table(
                          border: TableBorder.all(
                            color: scheme.outlineVariant.withValues(alpha: 0.5),
                            width: 1,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          columnWidths: const {
                            0: IntrinsicColumnWidth(),
                            1: FlexColumnWidth(),
                          },
                          defaultVerticalAlignment:
                              TableCellVerticalAlignment.middle,
                          children: [
                            TableRow(
                              decoration: BoxDecoration(
                                color: scheme.primaryContainer.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                              children: [
                                _buildHeaderCell(context, "Day"),
                                _buildHeaderCell(context, "Subjects"),
                              ],
                            ),
                            ...timetable.days.map((day) {
                              final slots = timetable.getDaySlots(day);
                              final subjectNames = slots.map((id) {
                                final s = subjects
                                    .where((s) => s.id == id)
                                    .isNotEmpty
                                    ? subjects.firstWhere((s) => s.id == id)
                                    : null;
                                return s?.shortName ?? "?";
                              }).join(", ");

                              return TableRow(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    child: Text(
                                      dayNames[day] ?? day,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    child: Text(
                                      subjectNames.isEmpty
                                          ? "No Classes"
                                          : subjectNames,
                                      style: TextStyle(
                                        color: scheme.onSurfaceVariant,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
              ),
              actions: [
                if (isStepOne) ...[
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancel"),
                  ),
                  FilledButton(
                    onPressed: isValidating ? null : () async {
                      if (universityController.text.trim().isEmpty ||
                          yearController.text.trim().isEmpty ||
                          branchController.text.trim().isEmpty ||
                          batchController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Please fill all details to proceed"),
                            behavior: SnackBarBehavior.floating,
                            duration: Duration(seconds: 2),
                          ),
                        );
                        return;
                      }

                      setDialogState(() => isValidating = true);
                      try {
                        final ownership = await FirestoreService.checkTimetableOwnership(
                          university: universityController.text,
                          semester: yearController.text,
                          branch: branchController.text,
                          batch: batchController.text,
                        );

                        if (ownership['exists'] == true) {
                          if (context.mounted) {
                            if (ownership['isOwner'] == true) {
                              // If it's the owner, ask for overwrite permission
                              final proceed = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text("Your Preset Exists"),
                                  content: const Text(
                                    "You have already uploaded a timetable with these details. "
                                    "Do you want to overwrite it with your current timetable?",
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: const Text("No, Change Details"),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text("Yes, Overwrite"),
                                    ),
                                  ],
                                ),
                              );
                              if (proceed != true) return;
                            } else {
                              // If someone else's preset, block overwrite
                              await showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text("Preset already exists"),
                                  content: const Text(
                                    "A timetable with these details was already uploaded by another user. "
                                    "Please change the Batch or Branch name to make your preset unique.",
                                  ),
                                  actions: [
                                    FilledButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text("OK, I'll Change"),
                                    ),
                                  ],
                                ),
                              );
                              return; // Stay on Step 0
                            }
                          }
                        }
                        setDialogState(() => currentStep = 1);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Error checking database: $e")),
                          );
                        }
                      } finally {
                        setDialogState(() => isValidating = false);
                      }
                    },
                    child: isValidating 
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text("Next"),
                  ),
                ] else ...[
                  TextButton(
                    onPressed: () {
                      setDialogState(() => currentStep = 0);
                    },
                    child: const Text("Back"),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancel"),
                  ),
                  FilledButton(
                    onPressed: () async {
                      try {
                        // Show loading dialog
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => const Center(
                            child: CircularProgressIndicator.adaptive(),
                          ),
                        );

                        // Prepare data for Firestore
                        final subjectsData = subjects.map((s) => {
                          'name': s.name,
                          'short': s.shortName,
                        }).toList();

                        Map<String, dynamic> timetableData = {};
                        for (var day in timetable.days) {
                          var slots = timetable.getDaySlots(day);
                          timetableData[day] = slots.asMap().entries.map((entry) {
                            int idx = entry.key;
                            String id = entry.value;
                            // Safe lookup for subjects
                            final s = subjects.firstWhere((s) => s.id == id);
                            return {
                              'time': 'Slot ${idx + 1}',
                              'subject': s.shortName,
                            };
                          }).toList();
                        }

                        await FirestoreService.uploadTimetable(
                          university: universityController.text,
                          semester: yearController.text,
                          branch: branchController.text,
                          batch: batchController.text,
                          subjects: subjectsData,
                          timetable: timetableData,
                        );

                        if (context.mounted) {
                          // Close loader
                          Navigator.pop(context);
                          // Close upload dialog
                          Navigator.pop(context);
                          
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Timetable uploaded successfully!"),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          Navigator.pop(context); // Close loader
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Upload failed: $e"),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: Theme.of(context).colorScheme.error,
                            ),
                          );
                        }
                      }
                    },
                    child: const Text("Upload"),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildHeaderCell(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildDialogField(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDynamic,
    required bool isAbsolute,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: .5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: (isDynamic || isAbsolute)
              ? BorderSide(color: scheme.outlineVariant)
              : BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: (isDynamic || isAbsolute)
              ? BorderSide(color: scheme.outlineVariant)
              : BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
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

    final topGradientColor = isAbsolute
        ? scheme.surface
        : scheme.primaryContainer;
    final bottomGradientColor = isAbsolute
        ? scheme.surfaceContainer
        : scheme.surface;
    final panelColor = isAbsolute ? scheme.surfaceContainer : scheme.surface;

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
                  colors: [topGradientColor, bottomGradientColor],
                ),
              ),
            ),
          ),

          /// MAIN PAGE
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
                          "Timetable",
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
                          icon: Icon(Icons.edit, color: scheme.onSurface),
                          onPressed: () => _showEditOptions(context),
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
                      color: panelColor,
                      borderRadius: BorderRadius.circular(32),
                    ),

                    child: ListView(
                      children: [
                        /// PANEL ACTIONS
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            /// MANAGE PRESETS BUTTON
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: scheme.secondaryContainer.withValues(alpha: 0.3),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              icon: Icon(
                                Icons.settings_suggest_outlined,
                                color: scheme.secondary,
                                size: 20,
                              ),
                              label: Text(
                                "Manage",
                                style: TextStyle(
                                  color: scheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              onPressed: () => _showManagePresetsDialog(context),
                            ),
                            const SizedBox(width: 8),

                            /// UPLOAD TIMETABLE BUTTON
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: scheme.primaryContainer.withValues(alpha: 0.3),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              icon: Icon(
                                Icons.cloud_upload_outlined,
                                color: scheme.primary,
                                size: 22,
                              ),
                              label: Text(
                                "Upload Timetable",
                                style: TextStyle(
                                  color: scheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              onPressed: () {
                                final isEmpty = timetable.week.values.every(
                                  (slots) => slots.isEmpty,
                                );

                                if (isEmpty) {
                                  _showEmptyTimetablePrompt(context);
                                } else {
                                  _showUploadDialog(context);
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        ...timetable.days.map((day) {
                          final slots = timetable.getDaySlots(day);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 24),

                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                /// DAY TITLE
                                Text(
                                  dayNames[day] ?? day,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),

                                const SizedBox(height: 12),

                                /// SUBJECT CHIPS
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,

                                  children: slots.map((subjectId) {
                                    final subject =
                                        subjects
                                            .where((s) => s.id == subjectId)
                                            .isNotEmpty
                                        ? subjects.firstWhere(
                                            (s) => s.id == subjectId,
                                          )
                                        : null;

                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 14,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isAbsolute
                                            ? scheme.surfaceContainerHigh
                                            : scheme.secondaryContainer,
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      child: Text(
                                        subject?.shortName ?? "?",
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: scheme.onSecondaryContainer,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 60),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          /// NAV BAR COLOR FIX (same as SubjectPage)
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
  void _showManagePresetsDialog(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("My Contributed Presets"),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            content: SizedBox(
              width: double.maxFinite,
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: FirestoreService.getUserPresets(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      height: 200,
                      child: Center(child: CircularProgressIndicator.adaptive()),
                    );
                  }

                  if (snapshot.hasError) {
                    return SizedBox(
                      height: 200,
                      child: Center(child: Text("Error: ${snapshot.error}")),
                    );
                  }

                  final presets = snapshot.data ?? [];

                  if (presets.isEmpty) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 16),
                        Icon(Icons.layers_clear_outlined, size: 64, color: scheme.outline),
                        const SizedBox(height: 16),
                        const Text("No presets uploaded yet."),
                        const SizedBox(height: 16),
                      ],
                    );
                  }

                  return ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.5,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: presets.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final p = presets[index];
                        final meta = p['displayName'] ?? {};
                        final path = p['path'];
                        final dynamic rawTime = p['createdAt'];
                        String dateStr = "Unknown date";
                        if (rawTime != null) {
                          try {
                            // Firestore Timestamp to DateTime
                            final time = (rawTime as dynamic).toDate();
                            dateStr = DateFormat('MMM d, yyyy • HH:mm').format(time);
                          } catch (_) {}
                        }


                        Future<void> handleDelete() async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text("Delete Preset?"),
                              content: const Text("This contribution will be permanently removed from the cloud. Other users won't be able to find it anymore."),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text("Keep it"),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: scheme.error,
                                    foregroundColor: scheme.onError,
                                  ),
                                  child: const Text("Delete"),
                                ),
                              ],
                            ),
                          );

                          if (confirmed == true) {
                            try {
                              await FirestoreService.deletePreset(path);
                              HapticFeedback.mediumImpact();
                              setDialogState(() {}); // Refresh list
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Preset deleted successfully")),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Failed to delete: $e")),
                                );
                              }
                            }
                          }
                        }

                        Widget deleteBackground(Alignment alignment) => Container(
                          alignment: alignment,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          decoration: BoxDecoration(
                            color: scheme.error,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          margin: const EdgeInsets.symmetric(vertical: 2), // Match the child Container margin
                          child: Icon(Icons.delete_outline_rounded, color: scheme.onError),
                        );

                        return SlidableTile(
                          key: Key(path),
                          leftAction: deleteBackground(Alignment.centerLeft),
                          rightAction: deleteBackground(Alignment.centerRight),
                          onLeftAction: handleDelete,
                          onRightAction: handleDelete,
                          child: Container(
                            decoration: BoxDecoration(
                              color: scheme.surface,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            margin: const EdgeInsets.symmetric(vertical: 2),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              title: Text(
                                "${meta['university'] ?? 'Unknown Uni'}",
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "${meta['semester']} • ${meta['branch']} • ${meta['batch']}",
                                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Uploaded: $dateStr",
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: scheme.primary.withValues(alpha: 0.7),
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
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Close"),
              ),
            ],
          );
        },
      ),
    );
  }
}
