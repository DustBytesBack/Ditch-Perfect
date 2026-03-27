import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:app_links/app_links.dart';

import '../services/backup_service.dart';
import 'home_page.dart';
import 'calendar_page.dart';
import 'subject_page.dart';
import 'timetable_page.dart';
import 'settings_page.dart';
import 'attendance_calculator_page.dart';
import 'rank_page.dart';
import '../services/database_service.dart';
import '../services/update_service.dart';
import '../utils/update_checker.dart';
import '../widgets/wavy_progress_indicator.dart';
import '../utils/ranking_utils.dart';
import '../providers/theme_provider.dart';
import '../providers/subject_provider.dart';
import '../providers/timetable_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/attendance_provider.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  static const int _primaryNavCount = 5;
  static const int _rankPageIndex = 6;
  static const int _pageCount = 7;

  int currentIndex = 0;
  int previousIndex = 0;
  bool isNavExpanded = false;
  int? _swappedSecondaryIndex;
  bool isReordering = false;

  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  // Flags to prevent concurrent or duplicate restore triggers
  bool _isProcessingRestore = false;
  Uri? _lastProcessedUri;
  DateTime? _lastRestoreTime;



  List<NavigationDestination> _allDestinations = [
    const NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: "Home",
    ),
    const NavigationDestination(
      icon: Icon(Icons.calendar_month_outlined),
      selectedIcon: Icon(Icons.calendar_month),
      label: "Calendar",
    ),
    const NavigationDestination(
      icon: Icon(Icons.menu_book_outlined),
      selectedIcon: Icon(Icons.menu_book),
      label: "Subjects",
    ),
    const NavigationDestination(
      icon: Icon(Icons.schedule_outlined),
      selectedIcon: Icon(Icons.schedule),
      label: "Timetable",
    ),
    const NavigationDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings),
      label: "Settings",
    ),
    const NavigationDestination(
      icon: Icon(Icons.calculate_outlined),
      selectedIcon: Icon(Icons.calculate),
      label: "Calc",
    ),
    const NavigationDestination(
      icon: Icon(Icons.leaderboard_outlined),
      selectedIcon: Icon(Icons.leaderboard),
      label: "Rank",
    ),
  ];

  int _currentDisplayIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadNavOrder();
    _currentDisplayIndex = _getDisplayIndex();

    _initAppLinks();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onLaunchChecks();
    });
  }

  void _initAppLinks() async {
    _appLinks = AppLinks();

    if (kDebugMode) print("AppLinks initialized, checking initial link...");

    // Check for initial link
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        if (kDebugMode) print("Initial link found: $initialUri");
        _handleBackupLink(initialUri);
      }
    } catch (e) {
      debugPrint("Error getting initial link: $e");
    }

    // Subscribe to incoming links
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      if (kDebugMode) print("Steam link received: $uri");
      _handleBackupLink(uri);
    });
  }

  void _handleBackupLink(Uri uri) {
    if (kDebugMode) print("Received backup link: $uri");
    
    // Debounce identical URIs arriving in short succession (common on Android)
    final now = DateTime.now();
    if (_lastProcessedUri == uri &&
        _lastRestoreTime != null &&
        now.difference(_lastRestoreTime!) < const Duration(seconds: 2)) {
      if (kDebugMode) print("Ignoring duplicate backup link: $uri");
      return;
    }

    if (_isProcessingRestore) {
      if (kDebugMode) print("Already processing a restore, ignoring: $uri");
      return;
    }

    _lastProcessedUri = uri;
    _lastRestoreTime = now;

    // We rely on BackupService.peekMetadataFromUri to validate the file.
    // content:// URIs often don't end with the extension, so we skip the strict check.
    _showRestoreConfirmation(uri);
  }

  void _showRestoreConfirmation(Uri uri) async {
    if (!mounted) return;
    if (kDebugMode) print("Starting restore confirmation flow for: $uri");

    _isProcessingRestore = true;

    try {
      // Show a temporary loading indicator while we peek at the file
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) =>
            const Center(child: CircularProgressIndicator.adaptive()),
      );

      Map<String, dynamic>? metadata;
      try {
        metadata = await BackupService.peekMetadataFromUri(uri);
      } finally {
        if (mounted) {
          final nav = Navigator.of(context, rootNavigator: true);
          if (nav.canPop()) nav.pop(); // safe dismiss loading
        }
      }

      if (metadata == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to read backup metadata.")),
          );
        }
        return;
      }

      if (!mounted) return;

      final String date = metadata['exportedAt'] != null
          ? DateTime.parse(metadata['exportedAt'])
              .toLocal()
              .toString()
              .split('.')[0]
          : 'Unknown';
      final int version = metadata['version'];
      final int subjects = metadata['subjectsCount'];
      final String app = metadata['app'];

      final bool? result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Restore Backup?"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "This will replace all your current attendance data. This action cannot be undone.",
              ),
              const SizedBox(height: 16),
              Text(
                "Backup Details:",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text("• App: $app"),
              Text("• Date: $date"),
              Text("• Version: v$version"),
              Text("• Subjects: $subjects"),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Restore"),
            ),
          ],
        ),
      );

      if (result != true || !mounted) return;

      // Show another loading dialog for the actual import
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Row(
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: WavyCircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(width: 20),
              Text(
                "Restoring backup...",
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );

      try {
        final success = await BackupService.importFromUri(uri);
        if (mounted) {
          final nav = Navigator.of(context, rootNavigator: true);
          if (nav.canPop()) nav.pop(); // safe dismiss loading
        }

        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Backup restored successfully!")),
          );
          // Refresh all providers to reflect the new data
          context.read<SubjectProvider>().loadSubjects();
          context.read<AttendanceProvider>().loadAllAttendance();
          context.read<TimetableProvider>().loadTimetable();
          context.read<SettingsProvider>().loadSettings();
          context.read<ThemeProvider>().loadTheme();
        }
      } catch (e) {
        if (mounted) {
          final nav = Navigator.of(context, rootNavigator: true);
          if (nav.canPop()) nav.pop(); // safe dismiss loading
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to restore backup: $e")),
          );
        }
      }
    } finally {
      _isProcessingRestore = false;
    }
  }

  void _loadNavOrder() {
    final savedOrder = DatabaseService.settingsBox.get("navOrder") as List?;
    if (savedOrder != null && savedOrder.length == _allDestinations.length) {
      final newDestinations = <NavigationDestination>[];
      for (final label in savedOrder) {
        final dest = _allDestinations.firstWhere(
          (d) => d.label == label,
          orElse: () => _allDestinations[0],
        );
        newDestinations.add(dest);
      }
      setState(() {
        _allDestinations = newDestinations;
      });
    }
  }

  void _saveNavOrder() {
    final order = _allDestinations.map((d) => d.label).toList();
    DatabaseService.settingsBox.put("navOrder", order);
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  int _getDisplayIndex([int? specificCurrentIndex]) {
    int index = specificCurrentIndex ?? currentIndex;
    int displayIndex = index;
    if (index < _allDestinations.length) {
      final label = _allDestinations[index].label;
      if (label == "Home") {
        displayIndex = 0;
      } else if (label == "Calendar") {
        displayIndex = 1;
      } else if (label == "Subjects") {
        displayIndex = 2;
      } else if (label == "Timetable") {
        displayIndex = 3;
      } else if (label == "Settings") {
        displayIndex = 4;
      } else if (label == "Calc") {
        displayIndex = 5;
      } else if (label == "Rank") {
        displayIndex = 6;
      }
    }
    if (displayIndex >= _pageCount) displayIndex = 0;
    return displayIndex;
  }

  Future<void> _onLaunchChecks() async {
    // Show release notes first if the app was just updated.
    // If notes were shown, skip the update check (user just updated).
    final wasJustUpdated = await _wasAppJustUpdated();

    if (wasJustUpdated) {
      if (mounted) {
        await checkForPostUpdateNotes(context);
      }
    } else {
      // Seed lastSeenVersion so future updates can be detected.
      await _saveCurrentVersion();
      if (mounted) {
        await checkForUpdate(context);
      }
    }

    if (mounted) {
      await RankingUtils.checkAndAutoUpload();
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pagesList = [
      const HomePage(),
      const CalendarPage(),
      const SubjectPage(),
      const TimetablePage(),
      const SettingsPage(),
      const AttendanceCalculatorPage(),
      const RankPage(),
    ];

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(index: _currentDisplayIndex, children: pagesList),

          PeekingPony(
            active: context.watch<ThemeProvider>().pookieMode,
            navbarHeight: isReordering
                ? 225.0
                : (isNavExpanded ? 189.0 : 115.0),
          ),

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
                  onVerticalDragEnd: isReordering
                      ? null
                      : (details) {
                          final velocity = details.primaryVelocity ?? 0;
                          if (velocity < -100 && !isNavExpanded) {
                            HapticFeedback.mediumImpact();
                            setState(() => isNavExpanded = true);
                          } else if (velocity > 100 && isNavExpanded) {
                            HapticFeedback.mediumImpact();
                            setState(() => isNavExpanded = false);
                          }
                        },
                  onLongPress: isReordering
                      ? null
                      : () {
                          HapticFeedback.mediumImpact();
                          setState(() {
                            isReordering = true;
                            isNavExpanded = true;
                          });
                        },
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutCubic,
                        height: isReordering ? 200 : (isNavExpanded ? 164 : 90),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: isReordering
                              ? scheme.surfaceContainerHighest
                              : scheme.surfaceContainerHigh,
                          border: isReordering
                              ? Border.all(color: scheme.primary, width: 2)
                              : null,
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
                            if (isReordering)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 8,
                                  bottom: 4,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(left: 16),
                                      child: Text(
                                        "Reorder Navbar",
                                        style: TextStyle(
                                          color: scheme.primary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        HapticFeedback.lightImpact();
                                        setState(() {
                                          isReordering = false;
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: scheme.primaryContainer,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.check,
                                          size: 16,
                                          color: scheme.onPrimaryContainer,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (isReordering)
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Wrap(
                                    alignment: WrapAlignment.center,
                                    spacing: 0,
                                    runSpacing: 0,
                                    children: List.generate(
                                      _allDestinations.length,
                                      (index) {
                                        final dest = _allDestinations[index];
                                        return LongPressDraggable<int>(
                                          data: index,
                                          feedback: Material(
                                            color: Colors.transparent,
                                            child: Opacity(
                                              opacity: 0.8,
                                              child: SizedBox(
                                                width: itemWidth,
                                                height: 65,
                                                child: Center(
                                                  child: Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Icon(
                                                        (dest.icon as Icon)
                                                            .icon,
                                                        size: 24,
                                                        color: scheme.primary,
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        dest.label,
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          color: scheme.primary,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          childWhenDragging: SizedBox(
                                            width: itemWidth,
                                            height: 65,
                                            child: Center(
                                              child: Icon(
                                                (dest.icon as Icon).icon,
                                                size: 20,
                                                color: scheme.onSurfaceVariant
                                                    .withValues(alpha: 0.3),
                                              ),
                                            ),
                                          ),
                                          onDragStarted: () {
                                            HapticFeedback.lightImpact();
                                          },
                                          child: DragTarget<int>(
                                            onWillAcceptWithDetails: (_) =>
                                                true,
                                            onAcceptWithDetails: (details) {
                                              final oldIndex = details.data;
                                              final newIndex = index;
                                              if (oldIndex == newIndex) return;
                                              HapticFeedback.selectionClick();
                                              setState(() {
                                                final item = _allDestinations
                                                    .removeAt(oldIndex);
                                                _allDestinations.insert(
                                                  newIndex,
                                                  item,
                                                );

                                                if (currentIndex == oldIndex) {
                                                  currentIndex = newIndex;
                                                } else if (oldIndex <
                                                        newIndex &&
                                                    currentIndex > oldIndex &&
                                                    currentIndex <= newIndex) {
                                                  currentIndex--;
                                                } else if (oldIndex >
                                                        newIndex &&
                                                    currentIndex < oldIndex &&
                                                    currentIndex >= newIndex) {
                                                  currentIndex++;
                                                }
                                              });
                                              _saveNavOrder();
                                            },
                                            builder:
                                                (
                                                  context,
                                                  candidateData,
                                                  rejectedData,
                                                ) {
                                                  final isHovered =
                                                      candidateData.isNotEmpty;
                                                  return AnimatedContainer(
                                                    duration: const Duration(
                                                      milliseconds: 150,
                                                    ),
                                                    width: itemWidth,
                                                    height: 65,
                                                    decoration: BoxDecoration(
                                                      color: isHovered
                                                          ? scheme
                                                                .primaryContainer
                                                                .withValues(
                                                                  alpha: 0.5,
                                                                )
                                                          : Colors.transparent,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            16,
                                                          ),
                                                    ),
                                                    child: navItem(
                                                      dest,
                                                      index,
                                                      isReordering: true,
                                                    ),
                                                  );
                                                },
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              )
                            else ...[
                              SizedBox(
                                height: 65,
                                child: Stack(
                                  children: [
                                    /// SLIDING INDICATOR
                                    AnimatedAlign(
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
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
                                          borderRadius: BorderRadius.circular(
                                            40,
                                          ),
                                        ),
                                      ),
                                    ),

                                    /// NAV ITEMS
                                    Row(
                                      children: List.generate(
                                        _primaryNavCount,
                                        (index) => Expanded(
                                          child: navItem(
                                            _allDestinations[index],
                                            index,
                                          ),
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
                                                _allDestinations[_primaryNavCount],
                                                _primaryNavCount,
                                              ),
                                              const SizedBox(width: 14),
                                              secondaryNavItem(
                                                _allDestinations[_primaryNavCount +
                                                    1],
                                                _primaryNavCount + 1,
                                              ),
                                              const Spacer(),
                                            ],
                                          ),
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Chevron pill floating on top of navbar
                      if (!isReordering)
                        Positioned(
                          top: -10,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                setState(() {
                                  isNavExpanded = !isNavExpanded;
                                });
                              },
                              child: Container(
                                width: 40,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: scheme.onInverseSurface,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: scheme.shadow.withValues(
                                        alpha: .15,
                                      ),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  isNavExpanded
                                      ? Icons.keyboard_arrow_down
                                      : Icons.keyboard_arrow_up,
                                  size: 18,
                                  color: scheme.primary,
                                ),
                              ),
                            ),
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

  Widget navItem(
    NavigationDestination destination,
    int index, {
    double? width,
    bool isReordering = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final selected = currentIndex == index && !isReordering;

    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, anim) =>
              ScaleTransition(scale: anim, child: child),
          child: selected
              ? Icon(
                  (destination.selectedIcon as Icon).icon,
                  key: ValueKey("${destination.label}-true"),
                  size: 24,
                  color: scheme.onPrimaryContainer,
                )
              : Icon(
                  (destination.icon as Icon).icon,
                  key: ValueKey("${destination.label}-false"),
                  size: 22,
                  color: isReordering
                      ? scheme.primary
                      : scheme.onSurfaceVariant,
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
    );

    // In reorder mode, skip Material/InkWell so the grid can receive
    // the long-press gesture needed to start dragging.
    if (isReordering) {
      return SizedBox(
        width: width,
        child: Center(child: content),
      );
    }

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
          child: SizedBox(height: double.infinity, child: content),
        ),
      ),
    );
  }

  Widget secondaryNavItem(
    NavigationDestination destination,
    int index,
  ) {
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
    // Resolve the intended page BEFORE any list swapping happens
    final int nextDisplayIndex = _getDisplayIndex(index);

    setState(() {
      if (index == _rankPageIndex) {
        previousIndex = currentIndex == _rankPageIndex ? 0 : currentIndex;
      }

      // If a secondary (expanded-only) item is selected, swap it into
      // the last primary slot so the selection pill stays visible.
      if (index >= _primaryNavCount) {
        // Undo any previous swap first.
        if (_swappedSecondaryIndex != null) {
          final temp = _allDestinations[_primaryNavCount - 1];
          _allDestinations[_primaryNavCount - 1] =
              _allDestinations[_swappedSecondaryIndex!];
          _allDestinations[_swappedSecondaryIndex!] = temp;
          _swappedSecondaryIndex = null;
        }

        // Swap the selected secondary item with the last primary item.
        final temp = _allDestinations[_primaryNavCount - 1];
        _allDestinations[_primaryNavCount - 1] = _allDestinations[index];
        _allDestinations[index] = temp;
        _swappedSecondaryIndex = index;
        currentIndex = _primaryNavCount - 1;
      } else {
        // Primary item selected — undo any active swap, UNLESS
        // the user tapped the slot that holds the swapped-in item
        // (they want to stay on that page, not switch away).
        if (_swappedSecondaryIndex != null && index != _primaryNavCount - 1) {
          final temp = _allDestinations[_primaryNavCount - 1];
          _allDestinations[_primaryNavCount - 1] =
              _allDestinations[_swappedSecondaryIndex!];
          _allDestinations[_swappedSecondaryIndex!] = temp;
          _swappedSecondaryIndex = null;
        }
        currentIndex = index;
      }

      if (nextDisplayIndex != _currentDisplayIndex) {
        _currentDisplayIndex = nextDisplayIndex;
      }
      isNavExpanded = false;
    });
  }
}

class PeekingPony extends StatefulWidget {
  final bool active;
  final double navbarHeight;
  const PeekingPony({
    super.key,
    required this.active,
    required this.navbarHeight,
  });

  @override
  State<PeekingPony> createState() => _PeekingPonyState();
}

class _PeekingPonyState extends State<PeekingPony>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isVisible = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 35), (timer) {
      if (widget.active && !_isVisible && mounted) {
        _showPony();
      }
    });
  }

  void _showPony() async {
    if (!mounted) return;
    setState(() => _isVisible = true);
    await _controller.forward();
    await Future.delayed(const Duration(seconds: 10));
    if (!mounted) return;
    await _controller.reverse();
    if (!mounted) return;
    setState(() => _isVisible = false);
  }

  @override
  void didUpdateWidget(PeekingPony oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active != oldWidget.active) {
      if (widget.active) {
        _startTimer();
      } else {
        _timer?.cancel();
        if (_isVisible) {
          _controller.reverse().then((_) {
            if (mounted) setState(() => _isVisible = false);
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active && !_isVisible) return const SizedBox.shrink();

    return Positioned(
      bottom: widget.navbarHeight,
      right: 80,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, 100 * (1 - _animation.value)),
            child: Opacity(
              opacity: _animation.value.clamp(0.0, 1.0),
              child: child,
            ),
          );
        },
        child: Image.asset('assets/gif/pony.gif', height: 100, width: 100),
      ),
    );
  }
}
