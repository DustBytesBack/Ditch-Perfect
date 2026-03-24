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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Data exported to $path")),
        );
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

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Import Data?"),
        content: const Text(
          "This will REPLACE all current subjects, attendance, and settings with the data from the backup file. This cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              "Import & Replace",
              style: TextStyle(
                color: scheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Show loading dialog
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
              child: CircularProgressIndicator(strokeWidth: 2.5),
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

    try {
      final success = await BackupService.importBackup();
      
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
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Import failed: $e"),
            backgroundColor: scheme.error,
          ),
        );
      }
    }
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
        border: isAbsolute ? Border.all(color: scheme.primary.withValues(alpha: 0.10)) : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
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
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    final storedAttendance = DatabaseService.settingsBox.get(
      "minAttendance",
      defaultValue: 75,
    );

    minAttendance = storedAttendance.toDouble();
  }

  @override
  void dispose() {
    _pageController.dispose();
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
                  color: isAbsolute ? scheme.primary.withValues(alpha: 0.1) : scheme.primaryContainer,
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                final randomId = (DateTime.now().millisecondsSinceEpoch % 9000) + 1000;
                await DatabaseService.settingsBox.put("username", "User_$randomId");

                if (!context.mounted) return;

                context.read<SubjectProvider>().reload();
                context.read<TimetableProvider>().reload();
                context.read<AttendanceProvider>().records.clear();
                context.read<AttendanceProvider>().clearAll();

                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("All data deleted and username reset")),
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

    final modeLabel = themeProvider.isDark ? "Light Mode" : "Dark Mode";

    final modeIcon = themeProvider.isDark ? Icons.light_mode : Icons.dark_mode;

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
                          borderRadius: BorderRadius.circular(40),
                          border: isAbsolute
                              ? Border.all(color: scheme.primary.withValues(alpha: 0.10))
                              : null,
                        ),
                        child: Text(
                          "Settings",
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
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
                              ? Border.all(color: scheme.primary.withValues(alpha: 0.10))
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
                      color: isAbsolute ? scheme.surfaceContainer : scheme.surface,
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
                            horizontal: 18,
                            vertical: 18,
                          ),
                          decoration: BoxDecoration(
                            color: isAbsolute
                                ? scheme.surfaceContainerHigh
                                : scheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(28),
                            border: isAbsolute
                                ? Border.all(color: scheme.primary.withValues(alpha: 0.10))
                                : null,
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

                        const SizedBox(height: 28),

                        sectionTitle(context, "Profile"),

                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: isAbsolute
                                ? scheme.surfaceContainerHigh
                                : scheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(28),
                            border: isAbsolute
                                ? Border.all(color: scheme.primary.withValues(alpha: 0.10))
                                : null,
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
                              (DatabaseService.settingsBox.get("username") as String?) ?? "Not set",
                            ),
                            onTap: () async {
                              HapticFeedback.lightImpact();
                              await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const EditUsernamePage()),
                              );
                              if (mounted) setState(() {});
                            },
                          ),
                        ),

                        const SizedBox(height: 28),

                        sectionTitle(context, "Tutorial"),

                        Container(
                          key: TutorialService.keyFor(
                            TutorialTargets.settingsTutorialRestart,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: isAbsolute
                                ? scheme.surfaceContainerHigh
                                : scheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(28),
                            border: isAbsolute
                                ? Border.all(color: scheme.primary.withValues(alpha: 0.10))
                                : null,
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

                        const SizedBox(height: 28),

                        /// NOTIFICATION
                        sectionTitle(context, "Notification"),

                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: isAbsolute
                                ? scheme.surfaceContainerHigh
                                : scheme.secondaryContainer,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(28),
                              topRight: const Radius.circular(28),
                              bottomLeft: Radius.circular(
                                settingsProvider.notificationsEnabled ? 10 : 28,
                              ),
                              bottomRight: Radius.circular(
                                settingsProvider.notificationsEnabled ? 10 : 28,
                              ),
                            ),
                            border: isAbsolute
                                ? Border.all(color: scheme.primary.withValues(alpha: 0.10))
                                : null,
                          ),

                          child: Row(
                            children: [
                              Icon(
                                Icons.notifications_outlined,
                                color: scheme.onSecondaryContainer,
                              ),

                              const SizedBox(width: 18),

                              const Expanded(
                                child: Text(
                                  "Daily Reminder",
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),

                              Switch.adaptive(
                                value: settingsProvider.notificationsEnabled,
                                onChanged: (value) {
                                  HapticFeedback.lightImpact();
                                  context
                                      .read<SettingsProvider>()
                                      .setNotificationsEnabled(value);
                                },
                              ),
                            ],
                          ),
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
                                horizontal: 18,
                                vertical: 22,
                              ),
                              decoration: BoxDecoration(
                                color: isAbsolute
                                    ? scheme.surfaceContainerHigh
                                    : scheme.secondaryContainer,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(10),
                                  topRight: Radius.circular(10),
                                  bottomLeft: Radius.circular(28),
                                  bottomRight: Radius.circular(28),
                                ),
                                border: isAbsolute
                                    ? Border.all(color: scheme.primary.withValues(alpha: 0.10))
                                    : null,
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

                        const SizedBox(height: 28),

                        /// APPEARANCE
                        sectionTitle(context, "Appearance"),

                        SizedBox(
                          height: 75, // Standard container height
                          child: PageView(
                            controller: _pageController,
                            physics: themeProvider.isDark
                                ? const BouncingScrollPhysics()
                                : const NeverScrollableScrollPhysics(),
                            onPageChanged: (index) {
                              setState(() {
                                _currentPage = index;
                              });
                            },
                            children: [
                              /// PAGE 1: Theme Mode
                              Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: isAbsolute
                                      ? scheme.surfaceContainerHigh
                                      : scheme.secondaryContainer,
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(25),
                                    topRight: Radius.circular(25),
                                    bottomLeft: Radius.circular(10),
                                    bottomRight: Radius.circular(10),
                                  ),
                                  border: isAbsolute
                                      ? Border.all(color: scheme.primary.withValues(alpha: 0.10))
                                      : null,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      modeIcon,
                                      color: scheme.onSecondaryContainer,
                                    ),
                                    const SizedBox(width: 18),
                                    Expanded(
                                      child: Text(
                                        modeLabel,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Switch.adaptive(
                                      value: themeProvider.isDark,
                                      onChanged: (value) {
                                        HapticFeedback.lightImpact();
                                        if (!value && _currentPage == 1) {
                                          _pageController.animateToPage(
                                            0,
                                            duration: const Duration(
                                              milliseconds: 300,
                                            ),
                                            curve: Curves.easeInOut,
                                          );
                                        }
                                        context
                                            .read<ThemeProvider>()
                                            .toggleTheme(value);
                                      },
                                    ),
                                  ],
                                ),
                              ),

                              /// PAGE 2: Absolute Mode
                              if (themeProvider.isDark)
                                Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isAbsolute
                                        ? scheme.surfaceContainerHigh
                                        : scheme.secondaryContainer,
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(25),
                                      topRight: Radius.circular(25),
                                      bottomLeft: Radius.circular(10),
                                      bottomRight: Radius.circular(10),
                                    ),
                                    border: isAbsolute
                                        ? Border.all(
                                          color: scheme.primary.withValues(alpha: 0.10),
                                        )
                                        : null,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.settings_brightness,
                                        color: scheme.onSecondaryContainer,
                                      ),
                                      const SizedBox(width: 18),
                                      const Expanded(
                                        child: Text(
                                          "Absolute Mode",
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      Switch.adaptive(
                                        value: themeProvider.absoluteMode,
                                        onChanged: (value) {
                                          HapticFeedback.lightImpact();
                                          context
                                              .read<ThemeProvider>()
                                              .toggleAbsoluteMode(value);
                                        },
                                      ),
                                    ],
                                  ),
                                )
                              else
                                const SizedBox.shrink(),
                            ],
                          ),
                        ),

                        const SizedBox(height: 8),

                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: isAbsolute
                                ? scheme.surfaceContainerHigh
                                : scheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(10),
                            border: isAbsolute
                                ? Border.all(color: scheme.primary.withValues(alpha: 0.10))
                                : null,
                          ),

                          child: Row(
                            children: [
                              Text(
                                themeProvider.pookieMode && themeProvider.isDark
                                    ? "🖤"
                                    : "🎀",
                                style: const TextStyle(fontSize: 20),
                              ),

                              const SizedBox(width: 18),

                              Expanded(
                                child: Text(
                                  themeProvider.pookieMode && themeProvider.isDark
                                      ? "Emo Pookie Mode 🕸️"
                                      : "Pookie Mode",
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),

                              Switch.adaptive(
                                value: themeProvider.pookieMode,
                                onChanged: (value) {
                                  HapticFeedback.lightImpact();
                                  context.read<ThemeProvider>().togglePookie(
                                    value,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 8),

                        /// COLOR SCHEME
                        IgnorePointer(
                          ignoring: themeProvider.pookieMode,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: themeProvider.pookieMode ? 0.4 : 1.0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 18,
                              ),
                              decoration: BoxDecoration(
                                color: isAbsolute
                                    ? scheme.surfaceContainerHigh
                                    : scheme.secondaryContainer,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(10),
                                  topRight: Radius.circular(10),
                                  bottomLeft: Radius.circular(28),
                                  bottomRight: Radius.circular(28),
                                ),
                                border: isAbsolute
                                    ? Border.all(color: scheme.primary.withValues(alpha: 0.10))
                                    : null,
                              ),

                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.palette,
                                        color: scheme.onSecondaryContainer,
                                      ),

                                      const SizedBox(width: 18),

                                      Text(
                                        themeProvider.pookieMode
                                            ? "Color Scheme (Pookie Mode)"
                                            : "Color Scheme",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
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
                                      colorOption(context, Colors.indigo),
                                      colorOption(context, Colors.blue),
                                      colorOption(context, Colors.cyan),
                                      colorOption(context, Colors.teal),
                                      colorOption(context, Colors.green),
                                      colorOption(context, Colors.lime),
                                      colorOption(context, Colors.amber),
                                      colorOption(context, Colors.orange),
                                      colorOption(context, Colors.deepOrange),
                                      colorOption(context, Colors.red),
                                      colorOption(context, Colors.pink),
                                      colorOption(context, Colors.deepPurple),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 28),

                        /// RESOURCES
                        sectionTitle(context, "Resources"),

                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: isAbsolute
                                ? scheme.surfaceContainerHigh
                                : scheme.secondaryContainer,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(28),
                              topRight: Radius.circular(28),
                              bottomLeft: Radius.circular(10),
                              bottomRight: Radius.circular(10),
                            ),
                            border: isAbsolute
                                ? Border.all(color: scheme.primary.withValues(alpha: 0.10))
                                : null,
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

                        const SizedBox(height: 8),

                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: isAbsolute
                                ? scheme.surfaceContainerHigh
                                : scheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(10),
                            border: isAbsolute
                                ? Border.all(color: scheme.primary.withValues(alpha: 0.10))
                                : null,
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
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium,
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

                        const SizedBox(height: 8),

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

                        const SizedBox(height: 8),

                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.errorContainer,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(10),
                              topRight: Radius.circular(10),
                              bottomLeft: Radius.circular(28),
                              bottomRight: Radius.circular(28),
                            ),
                            border: isAbsolute
                                ? Border.all(color: scheme.primary.withValues(alpha: 0.10))
                                : null,
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
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
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
                          MarkdownStyleSheet.fromTheme(Theme.of(context))
                              .copyWith(
                                p: Theme.of(context).textTheme.bodyMedium,
                                h1: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                                h2: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                                h3: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.bold),
                                listBullet:
                                    Theme.of(context).textTheme.bodyMedium,
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
}
