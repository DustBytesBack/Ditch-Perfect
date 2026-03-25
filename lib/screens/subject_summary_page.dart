import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/subject.dart';
import '../models/attendance.dart';
import '../providers/attendance_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/attendance_utils.dart';

enum SortOption {
  dateNewest,
  dateOldest,
  status,
}

class SubjectSummaryPage extends StatefulWidget {
  final Subject subject;

  const SubjectSummaryPage({super.key, required this.subject});

  @override
  State<SubjectSummaryPage> createState() => _SubjectSummaryPageState();
}

class _SubjectSummaryPageState extends State<SubjectSummaryPage> {
  SortOption _sortOption = SortOption.dateNewest;
  AttendanceStatus? _filterStatus; // null means "All"
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
                  onTap: () => setState(() => _sortOption = SortOption.dateNewest),
                ),
                _optionTile(
                  context: context,
                  label: "Oldest First",
                  icon: Icons.history_outlined,
                  isSelected: _sortOption == SortOption.dateOldest,
                  onTap: () => setState(() => _sortOption = SortOption.dateOldest),
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
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Filter Records",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _optionTile(
                  context: context,
                  label: "All Statuses",
                  icon: Icons.all_inclusive,
                  isSelected: _filterStatus == null,
                  isFirst: true,
                  onTap: () => setState(() => _filterStatus = null),
                ),
                _optionTile(
                  context: context,
                  label: "Attended Only",
                  icon: Icons.check,
                  isSelected: _filterStatus == AttendanceStatus.present,
                  onTap: () => setState(() => _filterStatus = AttendanceStatus.present),
                ),
                _optionTile(
                  context: context,
                  label: "Missed Only",
                  icon: Icons.close_rounded,
                  isSelected: _filterStatus == AttendanceStatus.absent,
                  onTap: () => setState(() => _filterStatus = AttendanceStatus.absent),
                ),
                _optionTile(
                  context: context,
                  label: "Cancelled Only",
                  icon: Icons.block,
                  isSelected: _filterStatus == AttendanceStatus.cancelled,
                  isLast: true,
                  onTap: () => setState(() => _filterStatus = AttendanceStatus.cancelled),
                ),
              ],
            ),
          ),
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
      padding: EdgeInsets.only(bottom: isSelected ? 4 : 2, top: isSelected ? 4 : 0),
      child: Material(
        color: isSelected 
            ? scheme.tertiaryContainer 
            : scheme.tertiaryContainer.withValues(alpha: .3),
        borderRadius: borderRadius,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
            Navigator.pop(context);
          },
          borderRadius: borderRadius,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Row(
              children: [
                Icon(
                  icon, 
                  color: isSelected ? scheme.onTertiaryContainer : scheme.onSurfaceVariant,
                  size: 24,
                ),
                const SizedBox(width: 16),
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: isSelected ? scheme.onTertiaryContainer : scheme.onSurface,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
                const Spacer(),
                if (isSelected)
                  Icon(Icons.check_circle, color: scheme.onTertiaryContainer, size: 24),
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
    
    final stats = calculateStats(widget.subject.id, attendanceProvider.records.values);
    
    List<Attendance> records = attendanceProvider.records.values
        .where((r) => r.subjectId == widget.subject.id)
        .toList();

    // Filter Logic
    if (_filterStatus != null) {
      records = records.where((r) => r.status == _filterStatus).toList();
    }

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

    final topGradientColor = isAbsolute ? scheme.surface : scheme.primaryContainer;
    final bottomGradientColor = isAbsolute ? scheme.surfaceContainer : scheme.surface;
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
                  colors: [
                    topGradientColor,
                    bottomGradientColor,
                  ],
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
                          color: isAbsolute ? scheme.surfaceContainerHigh : scheme.surface,
                          borderRadius: BorderRadius.circular(40),
                          border: isAbsolute ? Border.all(color: scheme.outlineVariant) : null,
                        ),
                        child: Text(
                          widget.subject.shortName,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: scheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                      const Spacer(),
                      // Back Button Pill
                      Container(
                        decoration: BoxDecoration(
                          color: isAbsolute ? scheme.surfaceContainerHigh : scheme.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: isAbsolute ? Border.all(color: scheme.outlineVariant) : null,
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
                        /// STICKY STATS CARD
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: isAbsolute ? scheme.surfaceContainerHigh : scheme.surfaceContainerHighest.withValues(alpha: .4),
                              borderRadius: BorderRadius.circular(28),
                              border: isAbsolute ? Border.all(color: scheme.outlineVariant) : null,
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _statItem(context, "Attended", stats.attended, Colors.green),
                                    _statItem(context, "Missed", stats.total - stats.attended, Colors.red),
                                    _statItem(context, "Percent", "${(stats.total == 0 ? 100 : (stats.attended / stats.total) * 100).toStringAsFixed(1)}%", scheme.primary),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: LinearProgressIndicator(
                                    value: stats.total == 0 ? 1 : (stats.attended / stats.total),
                                    minHeight: 10,
                                    backgroundColor: scheme.surfaceContainerHighest,
                                    color: (stats.total == 0 || (stats.attended / stats.total) >= 0.75) ? Colors.green : scheme.error,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        /// SORT & FILTER BUTTON GROUP
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                          child: Row(
                            children: [
                              Expanded(
                                child: FilledButton.tonalIcon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: scheme.tertiaryContainer.withValues(alpha: .6),
                                    foregroundColor: scheme.onTertiaryContainer,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
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
                                  label: const Text("Sort", style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: FilledButton.tonalIcon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: scheme.tertiaryContainer.withValues(alpha: .6),
                                    foregroundColor: scheme.onTertiaryContainer,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
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
                                    _filterStatus == null ? Icons.filter_list : Icons.filter_alt,
                                    size: 20,
                                  ),
                                  label: Text(
                                    _filterStatus == null ? "Filter" : "Filtered",
                                    style: const TextStyle(fontWeight: FontWeight.bold),
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
                                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                );
                              }

                              final List<Widget> listItems = [];
                              
                              // Group records by month for positional context
                              final Map<String, List<Attendance>> grouped = {};
                              for (var r in records) {
                                final key = DateFormat('MMMM yyyy').format(r.date).toUpperCase();
                                grouped.putIfAbsent(key, () => []).add(r);
                              }
                              
                              for (var entry in grouped.entries) {
                                final monthYear = entry.key;
                                final monthRecords = entry.value;
                                final isCollapsed = _collapsedMonths.contains(monthYear);
                                
                                listItems.add(_monthHeader(
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
                                ));
                                
                                if (!isCollapsed) {
                                  for (int i = 0; i < monthRecords.length; i++) {
                                    listItems.add(_recordTile(
                                      context: context, 
                                      record: monthRecords[i],
                                      isFirst: i == 0,
                                      isLast: i == monthRecords.length - 1,
                                    ));
                                  }
                                }
                              }

                              return ListView.builder(
                                padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                                itemCount: listItems.length,
                                itemBuilder: (context, index) => listItems[index],
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

  Widget _monthHeader(BuildContext context, String label, bool isCollapsed, {required VoidCallback onToggle}) {
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
                isCollapsed ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                color: scheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statItem(BuildContext context, String label, dynamic value, Color color) {
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
        statusIcon = Icons.check;
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
        statusIcon = Icons.help_outline;
        statusName = "UNKNOWN";
    }

    BorderRadius borderRadius;
    if (isFirst && isLast) {
      borderRadius = BorderRadius.circular(24);
    } else if (isFirst) {
      borderRadius = const BorderRadius.vertical(top: Radius.circular(24), bottom: Radius.circular(10));
    } else if (isLast) {
      borderRadius = const BorderRadius.vertical(bottom: Radius.circular(24),top: Radius.circular(10));
    } else {
      borderRadius = BorderRadius.circular(10);
    }

    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 16 : 2),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: isAbsolute 
            ? scheme.surfaceContainerHigh 
            : scheme.tertiaryContainer.withValues(alpha: .3),
        borderRadius: borderRadius,
        border: isAbsolute ? Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)) : null,
      ),
      child: Row(
        children: [
          // Icon Container
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: .15),
              shape: BoxShape.circle,
            ),
            child: Icon(statusIcon, color: statusColor, size: 22),
          ),
          const SizedBox(width: 16),
          // Date Text
          Expanded(
            child: Text(
              dateStr,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: scheme.onSurface,
              ),
            ),
          ),
          // Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
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
    );
  }
}
