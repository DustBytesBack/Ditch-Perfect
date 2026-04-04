import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/subject.dart';
import '../models/attendance.dart';
import '../providers/attendance_provider.dart';
import '../providers/theme_provider.dart';

enum SortOption { dateNewest, dateOldest, status }

class SubjectSummaryPage extends StatefulWidget {
  final Subject subject;

  const SubjectSummaryPage({super.key, required this.subject});

  @override
  State<SubjectSummaryPage> createState() => _SubjectSummaryPageState();
}

class _SubjectSummaryPageState extends State<SubjectSummaryPage> {
  SortOption _sortOption = SortOption.dateNewest;
  Set<AttendanceStatus> _selectedFilters = {
    AttendanceStatus.present,
    AttendanceStatus.absent,
    AttendanceStatus.cancelled,
  };
  final Set<String> _collapsedMonths = {};

  void _showSortOptions(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Sort Records",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _optionTile(
                  context: context,
                  label: "Newest First",
                  icon: Icons.calendar_today_outlined,
                  isSelected: _sortOption == SortOption.dateNewest,
                  isFirst: true,
                  onTap: () =>
                      setState(() => _sortOption = SortOption.dateNewest),
                ),
                _optionTile(
                  context: context,
                  label: "Oldest First",
                  icon: Icons.history_outlined,
                  isSelected: _sortOption == SortOption.dateOldest,
                  onTap: () =>
                      setState(() => _sortOption = SortOption.dateOldest),
                ),
                _optionTile(
                  context: context,
                  label: "By Status",
                  icon: Icons.filter_list,
                  isSelected: _sortOption == SortOption.status,
                  isLast: true,
                  onTap: () => setState(() => _sortOption = SortOption.status),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showFilterOptions(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final allSelected = _selectedFilters.length >= 3;
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Filter Records",
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    _optionTile(
                      context: context,
                      label: "All Statuses",
                      icon: Icons.all_inclusive,
                      isSelected: allSelected,
                      isFirst: true,
                      closeOnTap: false,
                      onTap: () {
                        setState(() {
                          if (allSelected) {
                            _selectedFilters.clear();
                          } else {
                            _selectedFilters = {
                              AttendanceStatus.present,
                              AttendanceStatus.absent,
                              AttendanceStatus.cancelled,
                            };
                          }
                        });
                        setModalState(() {});
                      },
                    ),
                    _optionTile(
                      context: context,
                      label: "Attended Only",
                      icon: Icons.check,
                      isSelected: _selectedFilters.contains(
                        AttendanceStatus.present,
                      ),
                      closeOnTap: false,
                      onTap: () {
                        setState(() {
                          if (_selectedFilters.contains(
                            AttendanceStatus.present,
                          )) {
                            _selectedFilters.remove(AttendanceStatus.present);
                          } else {
                            _selectedFilters.add(AttendanceStatus.present);
                          }
                        });
                        setModalState(() {});
                      },
                    ),
                    _optionTile(
                      context: context,
                      label: "Missed Only",
                      icon: Icons.close_rounded,
                      isSelected: _selectedFilters.contains(
                        AttendanceStatus.absent,
                      ),
                      closeOnTap: false,
                      onTap: () {
                        setState(() {
                          if (_selectedFilters.contains(
                            AttendanceStatus.absent,
                          )) {
                            _selectedFilters.remove(AttendanceStatus.absent);
                          } else {
                            _selectedFilters.add(AttendanceStatus.absent);
                          }
                        });
                        setModalState(() {});
                      },
                    ),
                    _optionTile(
                      context: context,
                      label: "Cancelled Only",
                      icon: Icons.block,
                      isSelected: _selectedFilters.contains(
                        AttendanceStatus.cancelled,
                      ),
                      isLast: true,
                      closeOnTap: false,
                      onTap: () {
                        setState(() {
                          if (_selectedFilters.contains(
                            AttendanceStatus.cancelled,
                          )) {
                            _selectedFilters.remove(AttendanceStatus.cancelled);
                          } else {
                            _selectedFilters.add(AttendanceStatus.cancelled);
                          }
                        });
                        setModalState(() {});
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _optionTile({
    required BuildContext context,
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    bool isFirst = false,
    bool isLast = false,
    bool closeOnTap = true,
  }) {
    final scheme = Theme.of(context).colorScheme;

    BorderRadius borderRadius;
    if (isSelected) {
      borderRadius = BorderRadius.circular(28);
    } else if (isFirst) {
      borderRadius = const BorderRadius.vertical(top: Radius.circular(20));
    } else if (isLast) {
      borderRadius = const BorderRadius.vertical(bottom: Radius.circular(20));
    } else {
      borderRadius = BorderRadius.zero;
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: isSelected ? 4 : 2,
        top: isSelected ? 4 : 0,
      ),
      child: Material(
        color: isSelected
            ? scheme.tertiaryContainer
            : scheme.tertiaryContainer.withValues(alpha: .3),
        borderRadius: borderRadius,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
            if (closeOnTap) {
              Navigator.pop(context);
            }
          },
          borderRadius: borderRadius,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSelected
                      ? scheme.onTertiaryContainer
                      : scheme.onSurfaceVariant,
                  size: 24,
                ),
                const SizedBox(width: 16),
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: isSelected
                        ? scheme.onTertiaryContainer
                        : scheme.onSurface,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
                const Spacer(),
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    color: scheme.onTertiaryContainer,
                    size: 24,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isAbsolute = themeProvider.absoluteMode;
    final scheme = Theme.of(context).colorScheme;
    final attendanceProvider = context.watch<AttendanceProvider>();

    final stats = attendanceProvider.getStatsForSubject(widget.subject.id);

    List<Attendance> records = attendanceProvider.records.values
        .where((r) => r.subjectId == widget.subject.id)
        .toList();

    // Filter Logic
    records = records
        .where((r) => _selectedFilters.contains(r.status))
        .toList();

    // Sorting Logic
    switch (_sortOption) {
      case SortOption.dateNewest:
        records.sort((a, b) => b.date.compareTo(a.date));
        break;
      case SortOption.dateOldest:
        records.sort((a, b) => a.date.compareTo(b.date));
        break;
      case SortOption.status:
        records.sort((a, b) {
          int cmp = a.status.index.compareTo(b.status.index);
          if (cmp == 0) return b.date.compareTo(a.date);
          return cmp;
        });
        break;
    }

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

          SafeArea(
            child: Column(
              children: [
                /// CUSTOM HEADER
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Title Pill
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
                          widget.subject.shortName,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: scheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                      const Spacer(),
                      // Back Button Pill
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
                          icon: Icon(Icons.close, color: scheme.onSurface),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ],
                  ),
                ),

                /// STICKY STATS CARD
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isAbsolute
                          ? scheme.surfaceContainerHigh
                          : scheme.surface,
                      borderRadius: BorderRadius.circular(28),
                      border: isAbsolute
                          ? Border.all(color: scheme.outlineVariant)
                          : null,
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _statItem(
                              context,
                              "Attended",
                              stats.attended,
                              Colors.green,
                            ),
                            _statItem(
                              context,
                              "Missed",
                              stats.total - stats.attended,
                              Colors.red,
                            ),
                            TweenAnimationBuilder<double>(
                              duration: const Duration(milliseconds: 2500),
                              curve: Curves.easeOutExpo,
                              tween: Tween<double>(
                                begin: 0,
                                end: stats.total == 0
                                    ? 100
                                    : (stats.attended / stats.total) * 100,
                              ),
                              builder: (context, value, child) {
                                final color = value >= 75
                                    ? Colors.green
                                    : scheme.error;
                                return _statItem(
                                  context,
                                  "Percent",
                                  "${value.toStringAsFixed(1)}%",
                                  color,
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        ExpressiveProgressBar(
                          value: stats.total == 0
                              ? 1
                              : (stats.attended / stats.total),
                          color:
                              (stats.total == 0 ||
                                  (stats.attended / stats.total) >= 0.75)
                              ? Colors.green
                              : scheme.error,
                          backgroundColor: themeProvider.isDynamicMode
                              ? scheme.outlineVariant.withValues(alpha: 0.5)
                              : scheme.surfaceContainerHighest,
                        ),
                      ],
                    ),
                  ),
                ),

                /// MAIN PANEL
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: panelColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(32),
                        topRight: Radius.circular(32),
                      ),
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),

                        /// SORT & FILTER BUTTON GROUP
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: FilledButton.tonalIcon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: scheme.tertiaryContainer
                                        .withValues(alpha: .6),
                                    foregroundColor: scheme.onTertiaryContainer,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.horizontal(
                                        left: Radius.circular(24),
                                        right: Radius.circular(4),
                                      ),
                                    ),
                                  ),
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    _showSortOptions(context);
                                  },
                                  icon: const Icon(Icons.sort, size: 20),
                                  label: const Text(
                                    "Sort",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: FilledButton.tonalIcon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: scheme.tertiaryContainer
                                        .withValues(alpha: .6),
                                    foregroundColor: scheme.onTertiaryContainer,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.horizontal(
                                        left: Radius.circular(4),
                                        right: Radius.circular(24),
                                      ),
                                    ),
                                  ),
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    _showFilterOptions(context);
                                  },
                                  icon: Icon(
                                    _selectedFilters.length >= 3
                                        ? Icons.filter_list
                                        : Icons.filter_alt,
                                    size: 20,
                                  ),
                                  label: Text(
                                    _selectedFilters.length >= 3
                                        ? "Filter"
                                        : "Filtered",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        /// SCROLLABLE HISTORY LIST
                        Expanded(
                          child: Builder(
                            builder: (context) {
                              if (records.isEmpty) {
                                return Center(
                                  child: Text(
                                    "No attendance records yet",
                                    style: Theme.of(context).textTheme.bodyLarge
                                        ?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                        ),
                                  ),
                                );
                              }

                              final List<Widget> listItems = [];

                              // Group records by month for positional context
                              final Map<String, List<Attendance>> grouped = {};
                              for (var r in records) {
                                final key = DateFormat(
                                  'MMMM yyyy',
                                ).format(r.date).toUpperCase();
                                grouped.putIfAbsent(key, () => []).add(r);
                              }

                              for (var entry in grouped.entries) {
                                final monthYear = entry.key;
                                final monthRecords = entry.value;
                                final isCollapsed = _collapsedMonths.contains(
                                  monthYear,
                                );

                                listItems.add(
                                  _monthHeader(
                                    context,
                                    monthYear,
                                    isCollapsed,
                                    onToggle: () {
                                      HapticFeedback.mediumImpact();
                                      setState(() {
                                        if (isCollapsed) {
                                          _collapsedMonths.remove(monthYear);
                                        } else {
                                          _collapsedMonths.add(monthYear);
                                        }
                                      });
                                    },
                                  ),
                                );

                                if (!isCollapsed) {
                                  for (
                                    int i = 0;
                                    i < monthRecords.length;
                                    i++
                                  ) {
                                    listItems.add(
                                      _recordTile(
                                        context: context,
                                        record: monthRecords[i],
                                        isFirst: i == 0,
                                        isLast: i == monthRecords.length - 1,
                                      ),
                                    );
                                  }
                                }
                              }

                              return ListView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  12,
                                  20,
                                  100,
                                ),
                                itemCount: listItems.length,
                                itemBuilder: (context, index) =>
                                    listItems[index],
                              );
                            },
                          ),
                        ),
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

  Widget _monthHeader(
    BuildContext context,
    String label,
    bool isCollapsed, {
    required VoidCallback onToggle,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 24, 0, 8),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Icon(
                isCollapsed
                    ? Icons.keyboard_arrow_down
                    : Icons.keyboard_arrow_up,
                color: scheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statItem(
    BuildContext context,
    String label,
    dynamic value,
    Color color,
  ) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _recordTile({
    required BuildContext context,
    required Attendance record,
    bool isFirst = false,
    bool isLast = false,
  }) {
    final themeProvider = context.watch<ThemeProvider>();
    final isAbsolute = themeProvider.absoluteMode;
    final scheme = Theme.of(context).colorScheme;
    final dateStr = DateFormat('EEE, d').format(record.date);

    Color statusColor;
    IconData statusIcon;
    String statusName;

    switch (record.status) {
      case AttendanceStatus.present:
        statusColor = Colors.green;
        statusIcon = Icons.done_rounded;
        statusName = "PRESENT";
        break;
      case AttendanceStatus.absent:
        statusColor = Colors.red;
        statusIcon = Icons.close_rounded;
        statusName = "ABSENT";
        break;
      case AttendanceStatus.cancelled:
        statusColor = Colors.orange;
        statusIcon = Icons.block;
        statusName = "CANCELLED";
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline_rounded;
        statusName = "UNKNOWN";
    }

    BorderRadius borderRadius;
    if (isFirst && isLast) {
      borderRadius = BorderRadius.circular(24);
    } else if (isFirst) {
      borderRadius = const BorderRadius.vertical(
        top: Radius.circular(24),
        bottom: Radius.circular(10),
      );
    } else if (isLast) {
      borderRadius = const BorderRadius.vertical(
        bottom: Radius.circular(24),
        top: Radius.circular(10),
      );
    } else {
      borderRadius = BorderRadius.circular(10);
    }

    final iconBorderRadius = borderRadius.copyWith(
      topRight: const Radius.circular(10),
      bottomRight: const Radius.circular(10),
    );
    final dateBorderRadius = borderRadius.copyWith(
      topLeft: const Radius.circular(10),
      bottomLeft: const Radius.circular(10),
    );

    // Summary Pill
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Icon Pill - Speed Dial Trigger
          Expanded(
            flex: 1,
            child: AttendanceSpeedDial(
              record: record,
              iconBorderRadius: iconBorderRadius,
              statusColor: statusColor,
              statusIcon: statusIcon,
              isAbsolute: isAbsolute,
              isLast: isLast,
            ),
          ),
          const SizedBox(width: 8),
          // Date & Status Pill (Three Quarters)
          Expanded(
            flex: 3,
            child: Container(
              margin: EdgeInsets.only(bottom: isLast ? 16 : 8),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
              decoration: BoxDecoration(
                color: isAbsolute
                    ? scheme.surfaceContainerHigh
                    : scheme.tertiaryContainer.withValues(alpha: .3),
                borderRadius: dateBorderRadius,
                border: isAbsolute
                    ? Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.5),
                      )
                    : null,
              ),
              child: Row(
                children: [
                  // Date Text
                  Expanded(
                    child: Text(
                      dateStr,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusName,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AttendanceSpeedDial extends StatefulWidget {
  final Attendance record;
  final BorderRadius iconBorderRadius;
  final Color statusColor;
  final IconData statusIcon;
  final bool isAbsolute;
  final bool isLast;

  const AttendanceSpeedDial({
    super.key,
    required this.record,
    required this.iconBorderRadius,
    required this.statusColor,
    required this.statusIcon,
    required this.isAbsolute,
    required this.isLast,
  });

  @override
  State<AttendanceSpeedDial> createState() => _AttendanceSpeedDialState();
}

class _AttendanceSpeedDialState extends State<AttendanceSpeedDial>
    with SingleTickerProviderStateMixin {
  final _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  late AnimationController _controller;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
  }

  @override
  void dispose() {
    _removeOverlay();
    _controller.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    if (_isOpen) {
      _controller.reverse().then((_) => _removeOverlay());
    } else {
      _showOverlay();
      _controller.forward();
    }
    setState(() => _isOpen = !_isOpen);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _showOverlay() {
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  OverlayEntry _createOverlayEntry() {
    final attendanceProvider = context.read<AttendanceProvider>();

    return OverlayEntry(
      builder: (context) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _toggleMenu,
        child: Stack(
          children: [
            FadeTransition(
              opacity: _controller,
              child: Container(color: Colors.black12),
            ),
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: const Offset(8, -12),
              followerAnchor: Alignment.bottomLeft,
              targetAnchor: Alignment.topLeft,
              child: Material(
                color: Colors.transparent,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMenuItem(
                      icon: Icons.delete_sweep_rounded,
                      label: "Clear marking",
                      color: Colors.grey,
                      index: 3,
                      onTap: () {
                        attendanceProvider.clearAttendance(
                          widget.record.date,
                          widget.record.slotId ?? "-1",
                          legacySlotIndex: widget.record.slotIndex,
                        );
                        _toggleMenu();
                      },
                    ),
                    _buildMenuItem(
                      icon: Icons.block,
                      label: "Cancelled",
                      color: Colors.orange,
                      index: 2,
                      onTap: () {
                        attendanceProvider.markAttendance(
                          widget.record.date,
                          widget.record.subjectId,
                          widget.record.slotId ?? "-1",
                          AttendanceStatus.cancelled,
                          slotIndex: widget.record.slotIndex,
                        );
                        _toggleMenu();
                      },
                    ),
                    _buildMenuItem(
                      icon: Icons.close_rounded,
                      label: "Absent",
                      color: Colors.red,
                      index: 1,
                      onTap: () {
                        attendanceProvider.markAttendance(
                          widget.record.date,
                          widget.record.subjectId,
                          widget.record.slotId ?? "-1",
                          AttendanceStatus.absent,
                          slotIndex: widget.record.slotIndex,
                        );
                        _toggleMenu();
                      },
                    ),
                    _buildMenuItem(
                      icon: Icons.check_rounded,
                      label: "Attended",
                      color: Colors.green,
                      index: 0,
                      onTap: () {
                        attendanceProvider.markAttendance(
                          widget.record.date,
                          widget.record.subjectId,
                          widget.record.slotId ?? "-1",
                          AttendanceStatus.present,
                          slotIndex: widget.record.slotIndex,
                        );
                        _toggleMenu();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required Color color,
    required int index,
    required VoidCallback onTap,
  }) {
    final staggeredAnimation = CurvedAnimation(
      parent: _controller,
      curve: Interval(
        index * 0.1,
        1.0,
        curve: Curves.easeOutBack,
      ),
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Tonal container colors for M3 Expressive
    Color bgColor;
    Color textColor;
    
    if (color == Colors.green) {
      bgColor = isDark ? Colors.green.shade900.withValues(alpha: 0.95) : Colors.green.shade100;
      textColor = isDark ? Colors.green.shade100 : Colors.green.shade900;
    } else if (color == Colors.red) {
      bgColor = isDark ? Colors.red.shade900.withValues(alpha: 0.95) : Colors.red.shade100;
      textColor = isDark ? Colors.red.shade100 : Colors.red.shade900;
    } else if (color == Colors.orange) {
      bgColor = isDark ? Colors.orange.shade900.withValues(alpha: 0.95) : Colors.orange.shade100;
      textColor = isDark ? Colors.orange.shade100 : Colors.orange.shade900;
    } else {
      bgColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;
      textColor = isDark ? Colors.grey.shade200 : Colors.grey.shade800;
    }

    return ScaleTransition(
      scale: staggeredAnimation,
      child: FadeTransition(
        opacity: staggeredAnimation,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: InkWell(
            onTap: () {
              HapticFeedback.mediumImpact();
              onTap();
            },
            borderRadius: BorderRadius.circular(28),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 12,
                    spreadRadius: 2,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: textColor, size: 28),
                  const SizedBox(width: 16),
                  Text(
                    label,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return CompositedTransformTarget(
      link: _layerLink,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          _toggleMenu();
        },
        borderRadius: widget.iconBorderRadius,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: EdgeInsets.only(bottom: widget.isLast ? 16 : 8),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: _isOpen
                ? scheme.surfaceContainerHighest
                : widget.statusColor.withValues(alpha: .2),
            borderRadius: widget.iconBorderRadius,
            boxShadow: _isOpen
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 15,
                      spreadRadius: 1,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: widget.statusColor.withValues(alpha: 0.2),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
            border: widget.isAbsolute
                ? Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.5),
                  )
                : null,
          ),
          child: Center(
            child: AnimatedRotation(
              duration: const Duration(milliseconds: 300),
              turns: _isOpen ? 0.375 : 0,
              child: Icon(
                _isOpen ? Icons.add : widget.statusIcon,
                color: _isOpen ? scheme.primary : widget.statusColor,
                size: 32,
                shadows: _isOpen
                    ? []
                    : [
                        Shadow(
                          color: widget.statusColor.withValues(alpha: 0.5),
                          offset: const Offset(1.0, 0),
                        ),
                        Shadow(
                          color: widget.statusColor.withValues(alpha: 0.5),
                          offset: const Offset(-1.0, 0),
                        ),
                        Shadow(
                          color: widget.statusColor.withValues(alpha: 0.5),
                          offset: const Offset(0, 1.0),
                        ),
                        Shadow(
                          color: widget.statusColor.withValues(alpha: 0.5),
                          offset: const Offset(0, -1.0),
                        ),
                      ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ExpressiveProgressBar extends StatefulWidget {
  final double value;
  final Color color;
  final Color backgroundColor;

  const ExpressiveProgressBar({
    super.key,
    required this.value,
    required this.color,
    required this.backgroundColor,
  });

  @override
  State<ExpressiveProgressBar> createState() => _ExpressiveProgressBarState();
}

class _ExpressiveProgressBarState extends State<ExpressiveProgressBar>
    with TickerProviderStateMixin {
  late AnimationController _phaseController;
  late AnimationController _revealController;
  late Animation<double> _revealAnimation;

  @override
  void initState() {
    super.initState();
    _phaseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _revealAnimation = CurvedAnimation(
      parent: _revealController,
      curve: Curves.easeOutExpo,
    );

    _revealController.forward();
  }

  @override
  void didUpdateWidget(ExpressiveProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _revealController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _phaseController.dispose();
    _revealController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: Listenable.merge([_phaseController, _revealAnimation]),
      builder: (context, child) {
        final currentProgress = widget.value * _revealAnimation.value;
        // If current progress is < 75%, show as error color (red)
        // Once it passes 75% AND the final target is also >= 75%, it will show as the final target color (green)
        final displayColor = (currentProgress >= 0.75)
            ? widget.color
            : scheme.error;

        return CustomPaint(
          size: const Size(double.infinity, 24),
          painter: _WavyPainter(
            progress: currentProgress,
            color: displayColor,
            backgroundColor: widget.backgroundColor,
            phase: _phaseController.value,
          ),
        );
      },
    );
  }
}

class _WavyPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;
  final double phase;

  _WavyPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
    required this.phase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final progressPaint = Paint()
      ..color = color
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final double centerY = size.height / 2;

    // 1. Draw background line (only the non-filled portion, after a gap)
    const double gap = 16.0;
    final double progressWidth = size.width * progress;
    final double startX = progressWidth + gap;

    if (startX < size.width) {
      canvas.drawLine(
        Offset(startX, centerY),
        Offset(size.width, centerY),
        backgroundPaint,
      );
    }

    // 2. Draw progress portion (wavy)
    if (progress > 0) {
      final path = Path();
      final double width = size.width * progress;

      const double wavelength = 50.0;
      const double amplitude = 5.0;

      for (double x = 0; x <= width; x += 1.0) {
        // Only taper at the heavy start (first 12px) and very sharp end (last 4px)
        double modulation = 1.0;
        if (x < 12) {
          modulation = x / 12.0;
        } else if (width - x < 4) {
          modulation = (width - x) / 4.0;
        }

        final double y =
            centerY +
            amplitude *
                modulation *
                math.sin(
                  ((x / wavelength) * 2 * math.pi) - (phase * 2 * math.pi),
                );

        if (x == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      canvas.drawPath(path, progressPaint);
    }
  }

  @override
  bool shouldRepaint(_WavyPainter oldDelegate) => true;
}
