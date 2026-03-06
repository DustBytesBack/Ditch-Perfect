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

  @override
  void initState() {
    super.initState();

    final stored =
        DatabaseService.settingsBox.get("hoursPerDay", defaultValue: 8);

    hours = stored.toDouble();
  }

  @override
  Widget build(BuildContext context) {

    final scheme = Theme.of(context).colorScheme;
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      backgroundColor: scheme.primaryContainer,

      appBar: AppBar(
        title: const Text("Settings"),

        actions: [

          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: "About",
            onPressed: () {
              showAboutDialog(
                context: context,
                applicationName: "Attendance Tracker",
                applicationVersion: "1.0",
                applicationLegalese: "Aint got no shit here",
              );
            },
          ),
        ],
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),

        child: Column(
          children: [

            /// DARK MODE SETTING
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(28),
              ),

              child: Row(
                children: [

                  Icon(Icons.dark_mode, color: scheme.primary),

                  const SizedBox(width: 18),

                  const Expanded(
                    child: Text(
                      "Dark Mode",
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),

                  Switch.adaptive(
                    value: themeProvider.isDark,
                    onChanged: (value) {
                      context.read<ThemeProvider>().toggleTheme(value);
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            /// HOURS PER DAY
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(28),
              ),

              child: Column(
                children: [

                  Row(
                    children: [

                      Icon(Icons.schedule, color: scheme.primary),

                      const SizedBox(width: 18),

                      const Expanded(
                        child: Text(
                          "Hours per Day",
                          style: TextStyle(fontWeight: FontWeight.w600),
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

                  const SizedBox(height: 10),

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
          ],
        ),
      ),
    );
  }
}
