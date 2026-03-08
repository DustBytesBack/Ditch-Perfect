import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'home_page.dart';
import 'calendar_page.dart';
import 'subject_page.dart';
import 'timetable_page.dart';
import 'settings_page.dart';
import '../services/database_service.dart';
import '../services/update_service.dart';
import '../utils/update_checker.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int currentIndex = 0;

  final pages = const [
    HomePage(),
    CalendarPage(),
    SubjectPage(),
    TimetablePage(),
    SettingsPage(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onLaunchChecks();
    });
  }

  Future<void> _onLaunchChecks() async {
    // Show release notes first if the app was just updated.
    // If notes were shown, skip the update check (user just updated).
    final wasJustUpdated = await _wasAppJustUpdated();

    if (wasJustUpdated) {
      if (mounted) await checkForPostUpdateNotes(context);
    } else {
      // Seed lastSeenVersion so future updates can be detected.
      await _saveCurrentVersion();
      if (mounted) await checkForUpdate(context);
    }
  }

  /// Returns true if the running version is newer than lastSeenVersion.
  Future<bool> _wasAppJustUpdated() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final current = packageInfo.version;
      final lastSeen =
          DatabaseService.settingsBox.get("lastSeenVersion") as String?;
      if (lastSeen == null) return false; // First ever launch
      return UpdateService.isVersionNewer(current, lastSeen);
    } catch (_) {
      return false;
    }
  }

  /// Writes the current app version to Hive so we can detect upgrades later.
  Future<void> _saveCurrentVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      await DatabaseService.settingsBox.put(
        "lastSeenVersion",
        packageInfo.version,
      );
    } catch (_) {
      // Non-critical — don't block the app.
    }
  }

  final destinations = const [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: "Home",
    ),
    NavigationDestination(
      icon: Icon(Icons.calendar_month_outlined),
      selectedIcon: Icon(Icons.calendar_month),
      label: "Calendar",
    ),
    NavigationDestination(
      icon: Icon(Icons.menu_book_outlined),
      selectedIcon: Icon(Icons.menu_book),
      label: "Subjects",
    ),
    NavigationDestination(
      icon: Icon(Icons.schedule_outlined),
      selectedIcon: Icon(Icons.schedule),
      label: "Timetable",
    ),
    NavigationDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings),
      label: "Settings",
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          pages[currentIndex],

          Positioned(
            bottom: 25,
            left: 20,
            right: 20,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final itemWidth = width / destinations.length;

                return Container(
                  height: 90,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(40),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.shadow.withValues(alpha: .35),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),

                  child: Stack(
                    children: [
                      /// SLIDING INDICATOR
                      AnimatedAlign(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment(
                          -1 + (currentIndex * 2 / (destinations.length - 1)),
                          0,
                        ),
                        child: Container(
                          width: itemWidth,
                          height: 65,
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            borderRadius: BorderRadius.circular(40),
                          ),
                        ),
                      ),

                      /// NAV ITEMS
                      Row(
                        children: List.generate(
                          destinations.length,
                          (index) => navItem(destinations[index], index),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget navItem(NavigationDestination destination, int index) {
    final scheme = Theme.of(context).colorScheme;
    final selected = currentIndex == index;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(40),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() {
              currentIndex = index;
            });
          },
          child: SizedBox(
            height: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, anim) =>
                      ScaleTransition(scale: anim, child: child),
                  child: selected
                      ? Icon(
                          (destination.selectedIcon as Icon).icon,
                          key: const ValueKey(true),
                          size: 24,
                          color: scheme.onPrimaryContainer,
                        )
                      : Icon(
                          (destination.icon as Icon).icon,
                          key: const ValueKey(false),
                          size: 22,
                          color: scheme.onSurfaceVariant,
                        ),
                ),

                const SizedBox(height: 4),

                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: Theme.of(context).textTheme.labelSmall!.copyWith(
                    color: selected
                        ? scheme.onPrimaryContainer
                        : scheme.onSurfaceVariant,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                  child: Text(destination.label),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
