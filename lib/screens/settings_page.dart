import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../services/database_service.dart';
import '../providers/theme_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/subject_provider.dart';
import '../providers/timetable_provider.dart';
import '../providers/attendance_provider.dart';
import '../utils/update_checker.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
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
                await Hive.close();
                await Hive.deleteFromDisk();

                await DatabaseService.init();

                if (!context.mounted) return;

                context.read<SubjectProvider>().reload();
                context.read<TimetableProvider>().reload();
                context.read<AttendanceProvider>().records.clear();
                context.read<AttendanceProvider>().clearAll();

                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("All data deleted")),
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
                          color: scheme.surface,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: IconButton(
                          iconSize: 28,
                          padding: const EdgeInsets.all(14),
                          icon: Icon(
                            Icons.info_outline,
                            color: scheme.onSurface,
                          ),
                          onPressed: () {
                            showAboutDialog(
                              context: context,
                              applicationName: "Attendance Tracker",
                              applicationVersion: "1.0",
                              applicationLegalese: "Aint got no shit here",
                            );
                          },
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
                            color: scheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(28),
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
                                year2023: false,
                                min: 50,
                                max: 100,
                                divisions: 50,
                                value: minAttendance,

                                onChanged: (value) {
                                  setState(() {
                                    minAttendance = value;
                                  });
                                },

                                onChangeEnd: (value) {
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

                        /// NOTIFICATION
                        sectionTitle(context, "Notification"),

                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.secondaryContainer,
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
                                color: scheme.secondaryContainer,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(10),
                                  topRight: Radius.circular(10),
                                  bottomLeft: Radius.circular(28),
                                  bottomRight: Radius.circular(28),
                                ),
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

                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.secondaryContainer,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(28),
                              topRight: Radius.circular(28),
                              bottomLeft: Radius.circular(10),
                              bottomRight: Radius.circular(10),
                            ),
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
                                onChanged: themeProvider.pookieMode
                                    ? null
                                    : (value) {
                                        context
                                            .read<ThemeProvider>()
                                            .toggleTheme(value);
                                      },
                              ),
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
                            color: scheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),

                          child: Row(
                            children: [
                              const Text("🎀", style: TextStyle(fontSize: 20)),

                              const SizedBox(width: 18),

                              const Expanded(
                                child: Text(
                                  "Pookie Mode",
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),

                              Switch.adaptive(
                                value: themeProvider.pookieMode,
                                onChanged: (value) {
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
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 18,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.secondaryContainer,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(10),
                              topRight: Radius.circular(10),
                              bottomLeft: Radius.circular(28),
                              bottomRight: Radius.circular(28),
                            ),
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

                                  const Text(
                                    "Color Scheme",
                                    style: TextStyle(
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

                        const SizedBox(height: 28),

                        /// RESOURCES
                        sectionTitle(context, "Resources"),

                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.secondaryContainer,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(28),
                              topRight: Radius.circular(28),
                              bottomLeft: Radius.circular(10),
                              bottomRight: Radius.circular(10),
                            ),
                          ),

                          child: ListTile(
                            leading: const Icon(Icons.system_update),
                            title: const Text("Check for Updates"),
                            onTap: () {
                              checkForUpdate(context);
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
                            color: scheme.errorContainer,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(10),
                              topRight: Radius.circular(10),
                              bottomLeft: Radius.circular(28),
                              bottomRight: Radius.circular(28),
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
    final selected = themeProvider.seedColor.value == color.value;

    return GestureDetector(
      onTap: () {
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
}
