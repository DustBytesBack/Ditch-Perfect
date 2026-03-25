import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../services/tutorial_service.dart';
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
import '../widgets/tutorial_overlay.dart';
import '../utils/ranking_utils.dart';
import '../providers/theme_provider.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  static const int _primaryNavCount = 5;
  static const int _rankPageIndex = 6;

  int currentIndex = 0;
  int previousIndex = 0;
  bool isNavExpanded = false;
  int? _swappedSecondaryIndex;
  bool isReordering = false;
  bool _tutorialActive = false;
  int _tutorialStepIndex = 0;
  Rect? _currentTutorialRect;
  Rect? _previousTutorialRect;

  List<_TutorialStep> get _tutorialSteps => const [
    _TutorialStep(
      title: 'Home Dashboard',
      description:
          'This home screen is your day-at-a-glance dashboard. It shows today\'s classes.',
      targetIds: [TutorialTargets.homeOverview],
      pageIndex: 0,
    ),
    _TutorialStep(
      title: 'Quick Add',
      description:
          'Tap this add button to insert an extra subject into today\'s schedule. The sheet now has a Single tab for one subject and a From Day tab that copies an entire weekday timetable into today.',
      targetIds: [TutorialTargets.homeQuickAdd],
      pageIndex: 0,
    ),
    _TutorialStep(
      title: 'Attendance Controls',
      description:
          'Tap these controls to update attendance in bulk. Subject rows also support tap actions for present, absent, cancelled, and clear.',
      targetIds: [
        TutorialTargets.homeFirstSubjectRow,
        TutorialTargets.homeBulkActions,
      ],
      pageIndex: 0,
    ),
    _TutorialStep(
      title: 'Subjects',
      description:
          'Manage your courses here. Tap add to create a subject, tap a card for details, and swipe subject cards left or right to rename or remove them.',
      targetIds: [TutorialTargets.subjectFirstCard, TutorialTargets.subjectAdd],
      pageIndex: 2,
    ),
    _TutorialStep(
      title: 'Navigation Bar',
      description:
          'Tap these floating pills to switch sections. Tap the pill on top or swipe up to reveal extra shortcuts. Long-press the bar to enter reorder mode and rearrange all buttons.',
      targetIds: [TutorialTargets.navBar],
      pageIndex: 2,
    ),
    _TutorialStep(
      title: 'Calculator Shortcut',
      description:
          'Expand the nav bar to find the Calc button. Open it to estimate how many future classes you can skip while staying at or above your attendance criteria.',
      targetIds: [TutorialTargets.navCalculator],
      pageIndex: 2,
      expandNav: true,
    ),
    _TutorialStep(
      title: 'Calculator Page',
      description:
          'Pick a subject, enter how many non-cancelled classes are still left, and the calculator shows how many you can skip, how many you must attend, and the projected final percentage.',
      targetIds: [TutorialTargets.calculatorMain],
      pageIndex: 5,
    ),
    _TutorialStep(
      title: 'Rank Shortcut',
      description:
          'The Rank button sits beside the calculator in the expanded nav row. You can also long-press the bar and drag buttons around to customise which ones appear on the main row.',
      targetIds: [TutorialTargets.navRank],
      pageIndex: 2,
      expandNav: true,
    ),
    _TutorialStep(
      title: 'Calendar History',
      description:
          'Use the calendar to review attendance by date. Tap a day to open details, then use the bottom arrows or swipe on the day switcher to move across dates.',
      targetIds: [TutorialTargets.calendarMain],
      pageIndex: 1,
    ),
    _TutorialStep(
      title: 'Calendar Multi-Select',
      description:
          'Tap this checklist button to switch the calendar into multi-select mode. Then tap several dates and use the floating pill above the nav bar to mark them present, absent, cancelled, or clear them in one go.',
      targetIds: [TutorialTargets.calendarMultiSelect],
      pageIndex: 1,
    ),
    _TutorialStep(
      title: 'Monthly Stats',
      description:
          'This summary card shows your monthly picture: attended, missed, off, mixed, and not-marked days.',
      targetIds: [TutorialTargets.calendarStats],
      pageIndex: 1,
    ),
    _TutorialStep(
      title: 'Settings And Replay',
      description:
          'Settings is where you tune preferences and manage app data. You can restart this tutorial anytime from this Replay Tutorial tile.',
      targetIds: [TutorialTargets.settingsTutorialRestart],
      pageIndex: 4,
    ),
  ];

  final List<Widget> pages = const [
    HomePage(),
    CalendarPage(),
    SubjectPage(),
    TimetablePage(),
    SettingsPage(),
    AttendanceCalculatorPage(),
    RankPage(),
  ];

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

    TutorialService.restartListenable.addListener(_handleTutorialRestart);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onLaunchChecks();
    });
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
    TutorialService.restartListenable.removeListener(_handleTutorialRestart);
    super.dispose();
  }

  int _getDisplayIndex([int? specificCurrentIndex]) {
    int index = specificCurrentIndex ?? currentIndex;
    int displayIndex = index;
    if (index < _allDestinations.length) {
      final label = _allDestinations[index].label;
      if (label == "Home") { displayIndex = 0; }
      else if (label == "Calendar") { displayIndex = 1; }
      else if (label == "Subjects") { displayIndex = 2; }
      else if (label == "Timetable") { displayIndex = 3; }
      else if (label == "Settings") { displayIndex = 4; }
      else if (label == "Calc") { displayIndex = 5; }
      else if (label == "Rank") { displayIndex = 6; }
    }
    if (displayIndex >= pages.length) displayIndex = 0;
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
      await _maybeStartTutorial();
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
    final currentStep = _tutorialActive
        ? _tutorialSteps[_tutorialStepIndex]
        : null;

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _currentDisplayIndex,
            children: pages,
          ),

          PeekingPony(
            active: context.watch<ThemeProvider>().pookieMode,
            navbarHeight: isReordering ? 225.0 : (isNavExpanded ? 189.0 : 115.0),
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
                        key: TutorialService.keyFor(TutorialTargets.navBar),
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
                                padding: const EdgeInsets.only(top: 8, bottom: 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    (dest.icon as Icon).icon,
                                                    size: 24,
                                                    color: scheme.primary,
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    dest.label,
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: scheme.primary,
                                                      fontWeight: FontWeight.w600,
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
                                            color: scheme.onSurfaceVariant.withValues(alpha: 0.3),
                                          ),
                                        ),
                                      ),
                                      onDragStarted: () {
                                        HapticFeedback.lightImpact();
                                      },
                                      child: DragTarget<int>(
                                        onWillAcceptWithDetails: (_) => true,
                                        onAcceptWithDetails: (details) {
                                          final oldIndex = details.data;
                                          final newIndex = index;
                                          if (oldIndex == newIndex) return;
                                          HapticFeedback.selectionClick();
                                          setState(() {
                                            final item = _allDestinations.removeAt(oldIndex);
                                            _allDestinations.insert(newIndex, item);

                                            if (currentIndex == oldIndex) {
                                              currentIndex = newIndex;
                                            } else if (oldIndex < newIndex &&
                                                currentIndex > oldIndex &&
                                                currentIndex <= newIndex) {
                                              currentIndex--;
                                            } else if (oldIndex > newIndex &&
                                                currentIndex < oldIndex &&
                                                currentIndex >= newIndex) {
                                              currentIndex++;
                                            }
                                          });
                                          _saveNavOrder();
                                        },
                                        builder: (context, candidateData, rejectedData) {
                                          final isHovered = candidateData.isNotEmpty;
                                          return AnimatedContainer(
                                            duration: const Duration(milliseconds: 150),
                                            width: itemWidth,
                                            height: 65,
                                            decoration: BoxDecoration(
                                              color: isHovered
                                                  ? scheme.primaryContainer.withValues(alpha: 0.5)
                                                  : Colors.transparent,
                                              borderRadius: BorderRadius.circular(16),
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
                                            tutorialTargetId:
                                                TutorialTargets.navCalculator,
                                          ),
                                          const SizedBox(width: 14),
                                          secondaryNavItem(
                                            _allDestinations[_primaryNavCount + 1],
                                            _primaryNavCount + 1,
                                            tutorialTargetId:
                                                TutorialTargets.navRank,
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
                                  color: scheme.shadow.withValues(alpha: .15),
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
          if (_tutorialActive &&
              _currentTutorialRect != null &&
              currentStep != null)
            Positioned.fill(
              child: TutorialOverlay(
                targetRect: _currentTutorialRect!,
                previousTargetRect:
                    _previousTutorialRect ?? _currentTutorialRect!,
                title: currentStep.title,
                description: currentStep.description,
                stepIndex: _tutorialStepIndex,
                totalSteps: _tutorialSteps.length,
                canGoBack: _tutorialStepIndex > 0,
                allowTapOutside: true,
                onNext: _goToNextTutorialStep,
                onPrevious: _goToPreviousTutorialStep,
                onSkip: _skipTutorial,
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
          child: SizedBox(
            height: double.infinity,
            child: content,
          ),
        ),
      ),
    );
  }

  Widget secondaryNavItem(
    NavigationDestination destination,
    int index, {
    String? tutorialTargetId,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final selected = currentIndex == index;

    return Material(
      key: tutorialTargetId == null
          ? null
          : TutorialService.keyFor(tutorialTargetId),
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
        if (_swappedSecondaryIndex != null &&
            index != _primaryNavCount - 1) {
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

  Future<void> _maybeStartTutorial() async {
    if (TutorialService.isCompleted) return;
    await _startTutorial();
  }

  Future<void> _startTutorial() async {
    if (!mounted) return;

    setState(() {
      _tutorialActive = true;
      TutorialService.isActive = true;
      _tutorialStepIndex = 0;
      _currentTutorialRect = null;
      _previousTutorialRect = null;
      currentIndex = 0;
      previousIndex = 0;
      isNavExpanded = false;
      
      int nextDisplayIndex = _getDisplayIndex();
      if (nextDisplayIndex != _currentDisplayIndex) {
        _currentDisplayIndex = nextDisplayIndex;
      }
    });

    await _showTutorialStep(0);
  }

  Future<void> _showTutorialStep(int index) async {
    if (!mounted) return;

    final step = _tutorialSteps[index];

    setState(() {
      _tutorialStepIndex = index;
      currentIndex = step.pageIndex;
      isNavExpanded = step.expandNav;
      if (step.pageIndex != _rankPageIndex) {
        previousIndex = step.pageIndex;
      }
      
      int nextDisplayIndex = _getDisplayIndex();
      if (nextDisplayIndex != _currentDisplayIndex) {
        _currentDisplayIndex = nextDisplayIndex;
      }
    });

    await Future<void>.delayed(const Duration(milliseconds: 200));
    await WidgetsBinding.instance.endOfFrame;

    final rect = _resolveTutorialRect(step.targetIds);
    if (rect == null) {
      if (index >= _tutorialSteps.length - 1) {
        await _completeTutorial();
      } else {
        await _showTutorialStep(index + 1);
      }
      return;
    }

    if (!mounted) return;

    setState(() {
      _previousTutorialRect = _currentTutorialRect ?? rect;
      _currentTutorialRect = rect;
      _tutorialActive = true;
    });
  }

  Rect? _resolveTutorialRect(List<String> targetIds) {
    for (final targetId in targetIds) {
      final rect = TutorialService.rectFor(targetId);
      if (rect != null) return rect;
    }
    return null;
  }

  Future<void> _goToNextTutorialStep() async {
    if (_tutorialStepIndex >= _tutorialSteps.length - 1) {
      await _completeTutorial();
      return;
    }

    await _showTutorialStep(_tutorialStepIndex + 1);
  }

  Future<void> _goToPreviousTutorialStep() async {
    if (_tutorialStepIndex == 0) return;
    await _showTutorialStep(_tutorialStepIndex - 1);
  }

  Future<void> _skipTutorial() async {
    await _completeTutorial();
  }

  Future<void> _completeTutorial() async {
    await TutorialService.markCompleted();
    if (!mounted) return;

    setState(() {
      _tutorialActive = false;
      TutorialService.isActive = false;
      _currentTutorialRect = null;
      _previousTutorialRect = null;
      isNavExpanded = false;
    });
  }

  void _handleTutorialRestart() {
    if (!mounted) return;
    _startTutorial();
  }
}

class _TutorialStep {
  final String title;
  final String description;
  final List<String> targetIds;
  final int pageIndex;
  final bool expandNav;

  const _TutorialStep({
    required this.title,
    required this.description,
    required this.targetIds,
    required this.pageIndex,
    this.expandNav = false,
  });
}

class PeekingPony extends StatefulWidget {
  final bool active;
  final double navbarHeight;
  const PeekingPony({super.key, required this.active, required this.navbarHeight});

  @override
  State<PeekingPony> createState() => _PeekingPonyState();
}

class _PeekingPonyState extends State<PeekingPony> with SingleTickerProviderStateMixin {
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
            offset: Offset(
              0,
              100 * (1 - _animation.value),
            ),
            child: Opacity(
              opacity: _animation.value.clamp(0.0, 1.0),
              child: child,
            ),
          );
        },
        child: Image.asset(
          'assets/gif/pony.gif',
          height: 100,
          width: 100,
        ),
      ),
    );
  }
}
