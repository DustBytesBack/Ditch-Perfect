import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'home_page.dart';
import 'calendar_page.dart';
import 'subject_page.dart';
import 'timetable_page.dart';
import 'settings_page.dart';
import 'ranked_bunking_page.dart';
import '../services/database_service.dart';
import '../services/update_service.dart';
import '../utils/update_checker.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  static const int _primaryNavCount = 5;
  static const int _rankPageIndex = 5;

  int currentIndex = 0;
  int previousIndex = 0;
  bool isNavExpanded = false;

  List<Widget> get pages => [
    const HomePage(),
    const CalendarPage(),
    const SubjectPage(),
    const TimetablePage(),
    const SettingsPage(),
    RankedBunkingPage(onBack: _handleRankBack),
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
    NavigationDestination(
      icon: Icon(Icons.leaderboard_outlined),
      selectedIcon: Icon(Icons.leaderboard),
      label: "Rank",
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
                const horizontalPadding = 20.0;
                final width = constraints.maxWidth - horizontalPadding;
                final itemWidth = width / _primaryNavCount;
                final primaryIndex = currentIndex >= _primaryNavCount
                    ? _primaryNavCount - 1
                    : currentIndex;
                final isSecondarySelected = currentIndex >= _primaryNavCount;

                return GestureDetector(
                  onLongPress: () {
                    HapticFeedback.mediumImpact();
                    setState(() {
                      isNavExpanded = !isNavExpanded;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    height: isNavExpanded ? 164 : 90,
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

                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: 65,
                          child: Stack(
                            children: [
                              /// SLIDING INDICATOR
                              AnimatedAlign(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOutCubic,
                                alignment: Alignment(
                                  -1 +
                                      (primaryIndex *
                                          2 /
                                          (_primaryNavCount - 1)),
                                  0,
                                ),
                                child: Container(
                                  width: itemWidth,
                                  height: 65,
                                  decoration: BoxDecoration(
                                    color: isSecondarySelected
                                        ? Colors.transparent
                                        : scheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(40),
                                  ),
                                ),
                              ),

                              /// NAV ITEMS
                              Row(
                                children: List.generate(
                                  _primaryNavCount,
                                  (index) => navItem(
                                    destinations[index],
                                    index,
                                    width: itemWidth,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOutCubic,
                          child: isNavExpanded
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 10),
                                  child: SizedBox(
                                    height: 49,
                                    child: Row(
                                      children: [
                                        const Spacer(),
                                        secondaryNavItem(
                                          destinations[_primaryNavCount],
                                          _primaryNavCount,
                                        ),
                                        const Spacer(),
                                      ],
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget navItem(
    NavigationDestination destination,
    int index, {
    required double width,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final selected = currentIndex == index;

    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(40),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          onTap: () {
            HapticFeedback.lightImpact();
            _selectTab(index);
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

  Widget secondaryNavItem(NavigationDestination destination, int index) {
    final scheme = Theme.of(context).colorScheme;
    final selected = currentIndex == index;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(32),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        onTap: () {
          HapticFeedback.lightImpact();
          _selectTab(index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          height: 65,
          width: 86,
          decoration: BoxDecoration(
            color: selected ? scheme.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(40),
          ),
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
                        key: ValueKey('${destination.label}-selected'),
                        size: 24,
                        color: scheme.onPrimaryContainer,
                      )
                    : Icon(
                        (destination.icon as Icon).icon,
                        key: ValueKey('${destination.label}-idle'),
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
    );
  }

  void _selectTab(int index) {
    setState(() {
      if (index == _rankPageIndex) {
        previousIndex = currentIndex == _rankPageIndex ? 0 : currentIndex;
      }

      currentIndex = index;
      isNavExpanded = false;
    });
  }

  void _handleRankBack() {
    setState(() {
      currentIndex = previousIndex == _rankPageIndex ? 0 : previousIndex;
      isNavExpanded = false;
    });
  }
}
