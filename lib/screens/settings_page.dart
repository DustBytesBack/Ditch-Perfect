import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/database_service.dart';
import '../providers/timetable_provider.dart';
import '../providers/theme_provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {

  late double hours;
  late double minAttendance;

  @override
  void initState() {
    super.initState();

    final storedHours =
        DatabaseService.settingsBox.get("hoursPerDay", defaultValue: 8);

    final storedAttendance =
        DatabaseService.settingsBox.get("minAttendance", defaultValue: 75);

    hours = storedHours.toDouble();
    minAttendance = storedAttendance.toDouble();
  }

  @override
  Widget build(BuildContext context) {

    final scheme = Theme.of(context).colorScheme;
    final themeProvider = context.watch<ThemeProvider>();

    final modeLabel =
        themeProvider.isDark ? "Light Mode" : "Dark Mode";

    final modeIcon =
        themeProvider.isDark ? Icons.light_mode : Icons.dark_mode;

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
                            horizontal: 56, vertical: 16),
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          borderRadius: BorderRadius.circular(40),
                        ),
                        child: Text(
                          "Settings",
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
                          icon: Icon(Icons.info_outline,
                              color: scheme.onSurface),
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

                        /// HOURS PER DAY
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 18),
                          decoration: BoxDecoration(
                            color: scheme.secondaryContainer,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(28),
                              topRight: Radius.circular(28),
                              bottomLeft: Radius.circular(10),
                              bottomRight: Radius.circular(10)
                            ),
                          ),
                          child: Column(
                            children: [

                              Row(
                                children: [

                                  Icon(Icons.schedule,
                                      color: scheme.onSecondaryContainer),

                                  const SizedBox(width: 18),

                                  const Expanded(
                                    child: Text(
                                      "Hours per Day",
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),

                                  Text(
                                    hours.toInt().toString(),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: scheme.primary,
                                    ),
                                  ),
                                ],
                              ),

                              Slider(
                                year2023: false,
                                min: 1,
                                max: 12,
                                divisions: 11,
                                value: hours,

                                onChanged: (value) {
                                  setState(() {
                                    hours = value;
                                  });
                                },

                                onChangeEnd: (value) {

                                  final newHours = value.toInt();

                                  DatabaseService.settingsBox
                                      .put("hoursPerDay", newHours);

                                  context
                                      .read<TimetableProvider>()
                                      .updateHours(newHours);
                                },
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 8),

                        /// MIN ATTENDANCE
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 18),
                          decoration: BoxDecoration(
                            color: scheme.secondaryContainer,
                            borderRadius: BorderRadius.only(
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

                                  Icon(Icons.percent,
                                      color: scheme.onSecondaryContainer),

                                  const SizedBox(width: 18),

                                  const Expanded(
                                    child: Text(
                                      "Minimum Attendance %",
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600),
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

                                  DatabaseService.settingsBox
                                      .put("minAttendance", value.toInt());
                                },
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 28),

                        /// DARK / LIGHT MODE
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 14),
                          decoration: BoxDecoration(
                            color: scheme.secondaryContainer,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(28),
                              topRight: Radius.circular(28),
                              bottomLeft: Radius.circular(10),
                              bottomRight: Radius.circular(10),
                            ),
                          ),

                          child: Row(
                            children: [

                              Icon(modeIcon,
                                  color: scheme.onSecondaryContainer),

                              const SizedBox(width: 18),

                              Expanded(
                                child: Text(
                                  modeLabel,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
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

                        /// POOKIE MODE
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 14),
                          decoration: BoxDecoration(
                            color: scheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),

                          child: Row(
                            children: [

                              const Text("🎀",
                                  style: TextStyle(fontSize: 20)),

                              const SizedBox(width: 18),

                              const Expanded(
                                child: Text(
                                  "Pookie Mode",
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                              ),

                              Switch.adaptive(
                                value: themeProvider.pookieMode,
                                onChanged: (value) {
                                  context
                                      .read<ThemeProvider>()
                                      .togglePookie(value);
                                },
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 8),

                        /// COLOR SCHEME
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 18),
                          decoration: BoxDecoration(
                            color: scheme.secondaryContainer,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(10),
                              topRight: Radius.circular(10),
                              bottomLeft: Radius.circular(28),
                              bottomRight: Radius.circular(28),
                            ),
                          ),

                          child:Column(
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

  Widget colorOption(BuildContext context, Color color) {

    final themeProvider = context.watch<ThemeProvider>();

    final selected =
        themeProvider.seedColor.value == color.value;

    return GestureDetector(
      onTap: () {
        context.read<ThemeProvider>().setSeedColor(color);
      },

      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: selected
              ? Border.all(color: Colors.white, width: 3)
              : null,
        ),
      ),
    );
  }
}