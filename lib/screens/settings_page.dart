import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/database_service.dart';
import '../services/tutorial_service.dart';
import '../providers/theme_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/subject_provider.dart';
import '../providers/timetable_provider.dart';
import '../providers/attendance_provider.dart';
import '../utils/update_checker.dart';
import '../services/update_service.dart';
import '../services/backup_service.dart';
import '../widgets/wavy_progress_indicator.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'edit_username_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Future<void> _handleExport() async {
    HapticFeedback.mediumImpact();
    try {
      final path = await BackupService.exportBackup();
      if (path != null && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Data exported to $path")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Export failed: $e"),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _handleImport() async {
    HapticFeedback.mediumImpact();
    final scheme = Theme.of(context).colorScheme;

    try {
      // 1. Pick the file and get JSON string
      final jsonString = await BackupService.pickBackupJson();
      if (jsonString == null) return;

      // 2. Peek at metadata for preview
      final metadata = BackupService.peekMetadataFromJson(jsonString);
      if (metadata == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to read backup metadata.")),
          );
        }
        return;
      }

      // 3. Show detailed preview and confirm
      if (!mounted) return;
      final bool? confirm = await _showImportPreviewDialog(metadata);
      if (confirm != true) return;

      // 4. Show loading dialog and proceed with restoration
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          content: Row(
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: WavyCircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(width: 20),
              Text(
                "Importing backup...",
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );

      final success = await BackupService.processBackupJson(jsonString);

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
      }

      if (success && mounted) {
        // Refresh all providers to reflect imported data
        context.read<SubjectProvider>().loadSubjects();
        context.read<TimetableProvider>().loadTimetable();
        context.read<AttendanceProvider>().loadAllAttendance();

        final settingsProvider = context.read<SettingsProvider>();
        settingsProvider.loadSettings();
        // Ensure notifications are rescheduled according to imported settings
        settingsProvider.rescheduleNotificationIfEnabled();

        context.read<ThemeProvider>().loadTheme();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Data restored successfully!")),
        );

        // Force UI update
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        // If the loading dialog was open, close it (Navigator might fail if not open, but usually fine)
        // We'll just show the error snackbar.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Import failed: $e"),
            backgroundColor: scheme.error,
          ),
        );
      }
    }
  }

  Future<bool?> _showImportPreviewDialog(Map<String, dynamic> metadata) {
    final String date =
        metadata['exportedAt'] != null
            ? DateTime.parse(metadata['exportedAt'])
                .toLocal()
                .toString()
                .split('.')[0]
            : 'Unknown';
    final int version = metadata['version'];
    final int subjectsCount = metadata['subjectsCount'];
    final List<String> subjects = List<String>.from(metadata['subjects']);
    final String app = metadata['app'] ?? 'Unknown';

    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: const Text("Confirm Restore"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "This will replace all current data. Review the backup details below:",
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("• App: $app"),
                    Text("• Date: $date"),
                    Text("• Version: v$version"),
                    Text("• Subjects ($subjectsCount):"),
                    if (subjects.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0, top: 4),
                        child: Text(
                          subjects.join(", "),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel"),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                foregroundColor: scheme.error,
                backgroundColor: scheme.errorContainer,
              ),
              child: const Text("Restore & Replace"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBackupButton(
    BuildContext context, {
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    required bool isAbsolute,
    required ColorScheme scheme,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isAbsolute
            ? scheme.surfaceContainerHigh
            : scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isAbsolute
              ? scheme.primary.withValues(alpha: 0.2)
              : scheme.primary.withValues(alpha: 0.1),
          width: 1.5,
        ),
        boxShadow: isAbsolute
            ? null
            : [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: scheme.onSecondaryContainer, size: 28),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSecondaryContainer,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  late double minAttendance;

  @override
  void initState() {
    super.initState();

    final storedAttendance = DatabaseService.settingsBox.get(
      "minAttendance",
      defaultValue: 75,
    );

    minAttendance = storedAttendance.toDouble();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _showAppInfoDialog() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (!mounted) return;

    final scheme = Theme.of(context).colorScheme;
    final themeProvider = context.read<ThemeProvider>();
    final isAbsolute = themeProvider.absoluteMode;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          decoration: BoxDecoration(
            color: isAbsolute ? scheme.surfaceContainerHigh : scheme.surface,
            borderRadius: BorderRadius.circular(36),
            border: isAbsolute
                ? Border.all(color: scheme.primary.withValues(alpha: 0.12))
                : null,
            boxShadow: isAbsolute
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: isAbsolute
                      ? scheme.primary.withValues(alpha: 0.1)
                      : scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    "assets/icon/Ditch_Perfect_Icon.png",
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.auto_awesome_rounded,
                      size: 32,
                      color: scheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "Ditch Perfect",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "v${packageInfo.version}",
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "Attendance Tracker Application.",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Licensed under MIT",
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.65),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () {
                        showLicensePage(
                          context: context,
                          applicationName: "Ditch Perfect",
                          applicationVersion: packageInfo.version,
                        );
                      },
                      child: const Text("Licenses"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Got it"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void showDeleteAllDialog(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Delete All Data"),
          content: const Text(
            "This will permanently delete all subjects, timetable entries and attendance data. This action cannot be undone.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),

            TextButton(
              onPressed: () async {
                // Instead of extreme deleteFromDisk which kills everything,
                // let's clear each box and re-init settings.
                await DatabaseService.subjectsBox.clear();
                await DatabaseService.attendanceBox.clear();
                await DatabaseService.timetableBox.clear();
                await DatabaseService.timetableRemovalsBox.clear();

                // Specifically reset the username lock
                await DatabaseService.settingsBox.put("isUsernameSet", false);

                // Generate a new random username so it feels truly reset
                final randomId =
                    (DateTime.now().millisecondsSinceEpoch % 9000) + 1000;
                await DatabaseService.settingsBox.put(
                  "username",
                  "User_$randomId",
                );

                if (!context.mounted) return;

                context.read<SubjectProvider>().reload();
                context.read<TimetableProvider>().reload();
                context.read<AttendanceProvider>().records.clear();
                context.read<AttendanceProvider>().clearAll();

                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("All data deleted and username reset"),
                  ),
                );
              },
              child: Text(
                "Delete Everything",
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
    final themeProvider = context.watch<ThemeProvider>();
    final settingsProvider = context.watch<SettingsProvider>();

    final isAbsolute = themeProvider.absoluteMode;

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
                          borderRadius: BorderRadius.circular(30),
                          border: isAbsolute
                              ? Border.all(
                                  color: scheme.primary.withValues(alpha: 0.10),
                                )
                              : null,
                        ),
                        child: Text(
                          "Settings",
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
                          icon: Icon(
                            Icons.info_outline,
                            color: scheme.onSurface,
                          ),
                          onPressed: _showAppInfoDialog,
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

                    child: ListView(
                      children: [
                        /// GENERAL
                        sectionTitle(context, "General"),

                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 20,
                          ),
                          decoration: BoxDecoration(
                            color: isAbsolute
                                ? scheme.surfaceContainerHigh
                                : scheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: isAbsolute
                                  ? scheme.primary.withValues(alpha: 0.2)
                                  : scheme.primary.withValues(alpha: 0.1),
                              width: 1.5,
                            ),
                            boxShadow: isAbsolute
                                ? null
                                : [
                                    BoxShadow(
                                      color: scheme.primary.withValues(
                                        alpha: 0.05,
                                      ),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                          ),

                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.percent,
                                    color: scheme.onSecondaryContainer,
                                  ),

                                  const SizedBox(width: 18),

                                  const Expanded(
                                    child: Text(
                                      "Minimum Attendance %",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),

                                  Text(
                                    "${minAttendance.toInt()}%",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: scheme.primary,
                                    ),
                                  ),
                                ],
                              ),

                              Slider(
                                // ignore: deprecated_member_use
                                year2023: false,
                                min: 50,
                                max: 99,
                                divisions: 49,
                                value: minAttendance > 99 ? 99 : minAttendance,

                                onChanged: (value) {
                                  setState(() {
                                    minAttendance = value;
                                  });
                                },

                                onChangeEnd: (value) {
                                  HapticFeedback.lightImpact();
                                  DatabaseService.settingsBox.put(
                                    "minAttendance",
                                    value.toInt(),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        sectionTitle(context, "Profile"),

                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isAbsolute
                                ? scheme.surfaceContainerHigh
                                : scheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: isAbsolute
                                  ? scheme.primary.withValues(alpha: 0.2)
                                  : scheme.primary.withValues(alpha: 0.1),
                              width: 1.5,
                            ),
                            boxShadow: isAbsolute
                                ? null
                                : [
                                    BoxShadow(
                                      color: scheme.primary.withValues(
                                        alpha: 0.05,
                                      ),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                          ),
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              Icons.person_outline,
                              color: scheme.onSecondaryContainer,
                            ),
                            title: const Text(
                              "Display Name",
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              (DatabaseService.settingsBox.get("username")
                                      as String?) ??
                                  "Not set",
                            ),
                            onTap: () async {
                              HapticFeedback.lightImpact();
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const EditUsernamePage(),
                                ),
                              );
                              if (mounted) setState(() {});
                            },
                          ),
                        ),

                        const SizedBox(height: 16),

                        sectionTitle(context, "Tutorial"),

                        Container(
                          key: TutorialService.keyFor(
                            TutorialTargets.settingsTutorialRestart,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isAbsolute
                                ? scheme.surfaceContainerHigh
                                : scheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: isAbsolute
                                  ? scheme.primary.withValues(alpha: 0.2)
                                  : scheme.primary.withValues(alpha: 0.1),
                              width: 1.5,
                            ),
                            boxShadow: isAbsolute
                                ? null
                                : [
                                    BoxShadow(
                                      color: scheme.primary.withValues(
                                        alpha: 0.05,
                                      ),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                          ),
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              Icons.play_circle_outline,
                              color: scheme.onSecondaryContainer,
                            ),
                            title: const Text(
                              "Replay Tutorial",
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: const Text(
                              "Don't skip it again. Read, for once in your life.",
                            ),
                            onTap: () {
                              HapticFeedback.lightImpact();
                              TutorialService.requestRestart();
                            },
                          ),
                        ),

                        const SizedBox(height: 16),

                        /// NOTIFICATION
                        sectionTitle(context, "Notification"),

                        _buildSelectionTile(
                          context,
                          title: "Daily Reminder",
                          subtitle: "Never forget your purpose.",
                          icon: Icons.notifications_none_rounded,
                          value: settingsProvider.notificationsEnabled,
                          borderRadius: settingsProvider.notificationsEnabled
                              ? const BorderRadius.only(
                                  topLeft: Radius.circular(30),
                                  topRight: Radius.circular(30),
                                  bottomLeft: Radius.circular(10),
                                  bottomRight: Radius.circular(10),
                                )
                              : BorderRadius.circular(30),
                          onChanged: (value) {
                            HapticFeedback.lightImpact();
                            context
                                .read<SettingsProvider>()
                                .setNotificationsEnabled(value);
                          },
                        ),

                        if (settingsProvider.notificationsEnabled) ...[
                          const SizedBox(height: 8),

                          GestureDetector(
                            onTap: () async {
                              final current = settingsProvider.notificationTime;

                              final picked = await showTimePicker(
                                context: context,
                                initialTime: current,
                              );

                              if (picked != null && context.mounted) {
                                context
                                    .read<SettingsProvider>()
                                    .setNotificationTime(picked);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 22,
                              ),
                              decoration: BoxDecoration(
                                color: isAbsolute
                                    ? scheme.surfaceContainerHigh
                                    : scheme.secondaryContainer,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(10),
                                  topRight: Radius.circular(10),
                                  bottomLeft: Radius.circular(30),
                                  bottomRight: Radius.circular(30),
                                ),
                                border: Border.all(
                                  color: isAbsolute
                                      ? scheme.primary.withValues(alpha: 0.2)
                                      : scheme.primary.withValues(alpha: 0.1),
                                  width: 1.5,
                                ),
                                boxShadow: isAbsolute
                                    ? null
                                    : [
                                        BoxShadow(
                                          color: scheme.primary.withValues(
                                            alpha: 0.05,
                                          ),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                              ),

                              child: Row(
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    color: scheme.onSecondaryContainer,
                                  ),

                                  const SizedBox(width: 18),

                                  const Expanded(
                                    child: Text(
                                      "Notification Time",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),

                                  Text(
                                    settingsProvider.notificationTime.format(
                                      context,
                                    ),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: scheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 16),

                        /// APPEARANCE
                        sectionTitle(context, "Appearance"),

                        Column(
                          children: [
                            /// APP THEME PILL
                            _buildAppThemePill(context, themeProvider),

                            const SizedBox(height: 12),

                            /// DYNAMIC MODE (Wallpaper Colors)
                            _buildSelectionTile(
                              context,
                              title: "Dynamic Mode",
                              subtitle: "Use system wallpaper colors",
                              icon: Icons.wallpaper_rounded,
                              value: themeProvider.isDynamicMode,
                              onChanged: (value) {
                                HapticFeedback.lightImpact();
                                themeProvider.toggleDynamicMode(value);
                              },
                            ),

                            const SizedBox(height: 12),

                            /// OTHER SETTINGS (Locked when Dynamic is on)
                            IgnorePointer(
                              ignoring: themeProvider.isDynamicMode,
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 250),
                                opacity: themeProvider.isDynamicMode
                                    ? 0.35
                                    : 1.0,
                                child: Column(
                                  children: [
                                    /// POOKIE MODE
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 14,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isAbsolute
                                            ? scheme.surfaceContainerHigh
                                            : scheme.secondaryContainer,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: isAbsolute
                                              ? scheme.primary.withValues(
                                                  alpha: 0.2,
                                                )
                                              : scheme.primary.withValues(
                                                  alpha: 0.1,
                                                ),
                                          width: 1.5,
                                        ),
                                        boxShadow: isAbsolute
                                            ? null
                                            : [
                                                BoxShadow(
                                                  color: scheme.primary
                                                      .withValues(alpha: 0.05),
                                                  blurRadius: 10,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                      ),
                                      child: Row(
                                        children: [
                                          Text(
                                            themeProvider.pookieMode &&
                                                    themeProvider.themeMode ==
                                                        ThemeMode.dark
                                                ? "🖤"
                                                : "🎀",
                                            style: const TextStyle(
                                              fontSize: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 18),
                                          Expanded(
                                            child: Text(
                                              themeProvider.pookieMode &&
                                                      themeProvider.themeMode ==
                                                          ThemeMode.dark
                                                  ? "Emo Pookie Mode 🕸️"
                                                  : "Pookie Mode",
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          Switch.adaptive(
                                            value: themeProvider.pookieMode,
                                            onChanged: (value) {
                                              HapticFeedback.lightImpact();
                                              context
                                                  .read<ThemeProvider>()
                                                  .togglePookie(value);
                                            },
                                          ),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(height: 12),

                                    /// COLOR SCHEME
                                    IgnorePointer(
                                      ignoring: themeProvider.pookieMode,
                                      child: AnimatedOpacity(
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        opacity: themeProvider.pookieMode
                                            ? 0.4
                                            : 1.0,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 18,
                                            vertical: 18,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isAbsolute
                                                ? scheme.surfaceContainerHigh
                                                : scheme.secondaryContainer,
                                            borderRadius:
                                                const BorderRadius.only(
                                                  topLeft: Radius.circular(10),
                                                  topRight: Radius.circular(10),
                                                  bottomLeft: Radius.circular(
                                                    30,
                                                  ),
                                                  bottomRight: Radius.circular(
                                                    30,
                                                  ),
                                                ),
                                            border: Border.all(
                                              color: isAbsolute
                                                  ? scheme.primary.withValues(
                                                      alpha: 0.2,
                                                    )
                                                  : scheme.primary.withValues(
                                                      alpha: 0.1,
                                                    ),
                                              width: 1.5,
                                            ),
                                            boxShadow: isAbsolute
                                                ? null
                                                : [
                                                    BoxShadow(
                                                      color: scheme.primary
                                                          .withValues(
                                                            alpha: 0.05,
                                                          ),
                                                      blurRadius: 10,
                                                      offset: const Offset(
                                                        0,
                                                        4,
                                                      ),
                                                    ),
                                                  ],
                                          ),
                                          child: Column(
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.palette,
                                                    color: scheme
                                                        .onSecondaryContainer,
                                                  ),
                                                  const SizedBox(width: 18),
                                                  const Text(
                                                    "Color Scheme",
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 16),
                                              Wrap(
                                                alignment: WrapAlignment.center,
                                                spacing: 16,
                                                runSpacing: 16,
                                                children: [
                                                  colorOption(
                                                    context,
                                                    Colors.indigo,
                                                  ),
                                                  colorOption(
                                                    context,
                                                    Colors.blue,
                                                  ),
                                                  colorOption(
                                                    context,
                                                    Colors.cyan,
                                                  ),
                                                  colorOption(
                                                    context,
                                                    Colors.teal,
                                                  ),
                                                  colorOption(
                                                    context,
                                                    Colors.green,
                                                  ),
                                                  colorOption(
                                                    context,
                                                    Colors.lime,
                                                  ),
                                                  colorOption(
                                                    context,
                                                    Colors.amber,
                                                  ),
                                                  colorOption(
                                                    context,
                                                    Colors.orange,
                                                  ),
                                                  colorOption(
                                                    context,
                                                    Colors.deepOrange,
                                                  ),
                                                  colorOption(
                                                    context,
                                                    Colors.red,
                                                  ),
                                                  colorOption(
                                                    context,
                                                    Colors.pink,
                                                  ),
                                                  colorOption(
                                                    context,
                                                    Colors.deepPurple,
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        /// RESOURCES
                        sectionTitle(context, "Resources"),

                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isAbsolute
                                ? scheme.surfaceContainerHigh
                                : scheme.secondaryContainer,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(30),
                              topRight: Radius.circular(30),
                              bottomLeft: Radius.circular(10),
                              bottomRight: Radius.circular(10),
                            ),
                            border: Border.all(
                              color: isAbsolute
                                  ? scheme.primary.withValues(alpha: 0.2)
                                  : scheme.primary.withValues(alpha: 0.1),
                              width: 1.5,
                            ),
                            boxShadow: isAbsolute
                                ? null
                                : [
                                    BoxShadow(
                                      color: scheme.primary.withValues(
                                        alpha: 0.05,
                                      ),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                          ),

                          child: ListTile(
                            leading: const Icon(Icons.system_update),
                            title: const Text("Check for Updates"),
                            onTap: () {
                              HapticFeedback.lightImpact();
                              checkForUpdateManual(context);
                            },
                          ),
                        ),

                        const SizedBox(height: 12),

                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isAbsolute
                                ? scheme.surfaceContainerHigh
                                : scheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isAbsolute
                                  ? scheme.primary.withValues(alpha: 0.2)
                                  : scheme.primary.withValues(alpha: 0.1),
                              width: 1.5,
                            ),
                            boxShadow: isAbsolute
                                ? null
                                : [
                                    BoxShadow(
                                      color: scheme.primary.withValues(
                                        alpha: 0.05,
                                      ),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                          ),

                          child: ListTile(
                            leading: const Icon(Icons.article_outlined),
                            title: const Text("Release Notes"),
                            onTap: () async {
                              HapticFeedback.lightImpact();
                              final packageInfo =
                                  await PackageInfo.fromPlatform();
                              final version = packageInfo.version;
                              if (!context.mounted) return;

                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (_) => AlertDialog(
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const SizedBox(height: 16),
                                      const WavyCircularProgressIndicator(),
                                      const SizedBox(height: 24),
                                      Text(
                                        "Fetching notes…",
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium,
                                      ),
                                      const SizedBox(height: 8),
                                    ],
                                  ),
                                ),
                              );

                              String? notes;
                              try {
                                notes = await Future.wait([
                                  UpdateService.fetchReleaseNotes(version),
                                  Future.delayed(const Duration(seconds: 3)),
                                ]).then((values) => values[0] as String?);
                              } catch (_) {}

                              if (!context.mounted) return;
                              Navigator.pop(context); // dismiss loading

                              showDialog(
                                context: context,
                                builder: (_) => _buildReleaseNotesDialog(
                                  context,
                                  version,
                                  notes,
                                ),
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Expanded(
                              child: _buildBackupButton(
                                context,
                                title: "Export Data",
                                icon: Icons.upload_rounded,
                                onTap: _handleExport,
                                isAbsolute: isAbsolute,
                                scheme: scheme,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildBackupButton(
                                context,
                                title: "Import Data",
                                icon: Icons.download_rounded,
                                onTap: _handleImport,
                                isAbsolute: isAbsolute,
                                scheme: scheme,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.errorContainer,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(10),
                              topRight: Radius.circular(10),
                              bottomLeft: Radius.circular(30),
                              bottomRight: Radius.circular(30),
                            ),
                            border: Border.all(
                              color: scheme.error.withValues(alpha: 0.2),
                              width: 1.5,
                            ),
                          ),

                          child: ListTile(
                            leading: Icon(
                              Icons.delete_forever,
                              color: scheme.onErrorContainer,
                            ),
                            title: Text(
                              "Delete All Data",
                              style: TextStyle(
                                color: scheme.onErrorContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              "Clear all subjects, timetable and attendance",
                              style: TextStyle(color: scheme.onErrorContainer),
                            ),
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              showDeleteAllDialog(context);
                            },
                          ),
                        ),
                        const SizedBox(height: 90),
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

  Widget sectionTitle(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget colorOption(BuildContext context, Color color) {
    final themeProvider = context.watch<ThemeProvider>();
    final selected = themeProvider.seedColor.toARGB32() == color.toARGB32();

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        context.read<ThemeProvider>().setSeedColor(color);
      },

      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.white : Colors.transparent,
            width: 3,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: .6),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : [],
        ),
        child: selected
            ? const Icon(Icons.check, size: 18, color: Colors.white)
            : null,
      ),
    );
  }

  Widget _buildReleaseNotesDialog(
    BuildContext context,
    String version,
    String? notes,
  ) {
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.article_outlined, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Release Notes — v$version",
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 400, maxWidth: 400),
        child: notes != null
            ? () {
                final controller = ScrollController();
                return Scrollbar(
                  controller: controller,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: controller,
                    child: MarkdownBody(
                      data: notes,
                      selectable: true,
                      onTapLink: (text, href, title) {
                        if (href != null) {
                          launchUrl(
                            Uri.parse(href),
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      },
                      styleSheet:
                          MarkdownStyleSheet.fromTheme(
                            Theme.of(context),
                          ).copyWith(
                            p: Theme.of(context).textTheme.bodyMedium,
                            h1: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                            h2: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                            h3: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                            listBullet: Theme.of(context).textTheme.bodyMedium,
                          ),
                    ),
                  ),
                );
              }()
            : Text(
                "No release notes available for version $version.",
                style: Theme.of(context).textTheme.bodyMedium,
              ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Got it"),
        ),
      ],
    );
  }

  Widget _buildSelectionTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
    BorderRadius? borderRadius,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final isAbsolute = context.read<ThemeProvider>().absoluteMode;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: isAbsolute
            ? scheme.surfaceContainerHigh
            : scheme.secondaryContainer,
        borderRadius: borderRadius ?? BorderRadius.circular(10),
        border: Border.all(
          color: isAbsolute
              ? scheme.primary.withValues(alpha: 0.2)
              : scheme.primary.withValues(alpha: 0.1),
          width: 1.5,
        ),
        boxShadow: isAbsolute
            ? null
            : [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Row(
        children: [
          Icon(icon, color: scheme.onSecondaryContainer),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: scheme.onSecondaryContainer.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _buildAppThemePill(BuildContext context, ThemeProvider themeProvider) {
    final scheme = Theme.of(context).colorScheme;
    final isAbsolute = themeProvider.absoluteMode;

    final brightness = MediaQuery.platformBrightnessOf(context);
    final isCurrentDark = themeProvider.themeMode == ThemeMode.system
        ? brightness == Brightness.dark
        : themeProvider.themeMode == ThemeMode.dark;

    String themeLabel;
    IconData themeIcon;

    switch (themeProvider.themeMode) {
      case ThemeMode.light:
        themeLabel = "Light Mode";
        themeIcon = Icons.light_mode_rounded;
        break;
      case ThemeMode.dark:
        themeLabel = "Dark Mode";
        themeIcon = Icons.dark_mode_rounded;
        break;
      case ThemeMode.system:
        themeLabel = "Auto Mode";
        themeIcon = Icons.brightness_auto_rounded;
        break;
    }

    return GestureDetector(
      onTap: () => _showThemeSelectionModal(context, themeProvider),
      onHorizontalDragEnd: (details) {
        // Swipe to toggle Absolute Mode (only if in dark/auto-dark)
        if (isCurrentDark) {
          if (details.primaryVelocity != null &&
              details.primaryVelocity!.abs() > 300) {
            HapticFeedback.mediumImpact();
            themeProvider.toggleAbsoluteMode(!themeProvider.absoluteMode);
          }
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: isAbsolute
              ? scheme.surfaceContainerHigh
              : scheme.secondaryContainer,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
            bottomLeft: Radius.circular(10),
            bottomRight: Radius.circular(10),
          ),
          border: Border.all(
            color: isAbsolute
                ? scheme.primary.withValues(alpha: 0.2)
                : scheme.primary.withValues(alpha: 0.1),
            width: 1.5,
          ),
          boxShadow: isAbsolute
              ? null
              : [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          children: [
            Icon(themeIcon, color: scheme.primary, size: 28),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "App theme",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    isAbsolute && isCurrentDark ? "Absolute Dark" : themeLabel,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            if (isCurrentDark)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.swap_horiz_rounded,
                  size: 16,
                  color: scheme.primary.withValues(alpha: 0.6),
                ),
              ),
            const SizedBox(width: 8),
            Icon(Icons.expand_more_rounded, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  void _showThemeSelectionModal(
    BuildContext context,
    ThemeProvider themeProvider,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final isAbsolute = themeProvider.absoluteMode;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isAbsolute ? scheme.surfaceContainerHigh : scheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.fromLTRB(40, 12, 40, 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Select Theme",
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: scheme.onSurface,
                  fontSize: 28,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildThemeOption(
              context,
              title: "Light Mode",
              icon: Icons.light_mode_rounded,
              selected: themeProvider.themeMode == ThemeMode.light,
              onTap: () {
                themeProvider.setThemeMode(ThemeMode.light);
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 12),
            _buildThemeOption(
              context,
              title: "Dark Mode",
              icon: Icons.dark_mode_rounded,
              selected: themeProvider.themeMode == ThemeMode.dark,
              onTap: () {
                themeProvider.setThemeMode(ThemeMode.dark);
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 12),
            _buildThemeOption(
              context,
              title: "Auto Mode",
              icon: Icons.brightness_auto_rounded,
              selected: themeProvider.themeMode == ThemeMode.system,
              onTap: () {
                themeProvider.setThemeMode(ThemeMode.system);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption(
    BuildContext context, {
    required String title,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final isAbsolute = context.read<ThemeProvider>().absoluteMode;

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primaryContainer
              : (isAbsolute
                    ? scheme.surfaceContainer
                    : scheme.surfaceContainerHighest.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? scheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected
                  ? scheme.onPrimaryContainer
                  : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                  fontSize: 18,
                  color: selected
                      ? scheme.onPrimaryContainer
                      : scheme.onSurface,
                ),
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, color: scheme.primary),
          ],
        ),
      ),
    );
  }
}
