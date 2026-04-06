import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/attendance_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/subject_provider.dart';
import '../../utils/attendance_utils.dart';

class AttendanceCalculatorPage extends StatefulWidget {
  const AttendanceCalculatorPage({super.key});

  @override
  State<AttendanceCalculatorPage> createState() =>
      _AttendanceCalculatorPageState();
}

class _AttendanceCalculatorPageState extends State<AttendanceCalculatorPage> {
  final TextEditingController _futureClassesController =
      TextEditingController();
  String? _selectedSubjectId;

  @override
  void dispose() {
    _futureClassesController.dispose();
    super.dispose();
  }

  int get _futureClasses {
    return int.tryParse(_futureClassesController.text.trim()) ?? 0;
  }

  _Projection _buildProjection({
    required int attended,
    required int total,
    required int futureClasses,
    required double minAttendance,
  }) {
    if (futureClasses <= 0) {
      final currentPercent = total == 0 ? 100.0 : (attended / total) * 100;
      return _Projection(
        canCut: 0,
        mustAttend: 0,
        projectedPercent: currentPercent,
        shortage: 0,
      );
    }

    final targetRatio = minAttendance / 100;
    final requiredAttendance =
        (targetRatio * (total + futureClasses) - attended).ceil();
    final mustAttend = requiredAttendance < 0 ? 0 : requiredAttendance;

    if (mustAttend > futureClasses) {
      final projectedPercent = total + futureClasses == 0
          ? 100.0
          : ((attended + futureClasses) / (total + futureClasses)) * 100;

      return _Projection(
        canCut: 0,
        mustAttend: futureClasses,
        projectedPercent: projectedPercent,
        shortage: mustAttend - futureClasses,
      );
    }

    return _Projection(
      canCut: futureClasses - mustAttend,
      mustAttend: mustAttend,
      projectedPercent: total + futureClasses == 0
          ? 100.0
          : ((attended + mustAttend) / (total + futureClasses)) * 100,
      shortage: 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isAbsolute = themeProvider.absoluteMode;
    final isDynamic = themeProvider.isDynamicMode;
    final scheme = Theme.of(context).colorScheme;
    final subjects = context.watch<SubjectProvider>().subjects;
    final attendance = context.watch<AttendanceProvider>();
    final minAttendance = context.watch<SettingsProvider>().minAttendance;

    final selectedSubject =
        subjects.where((s) => s.id == _selectedSubjectId).isNotEmpty
        ? subjects.firstWhere((s) => s.id == _selectedSubjectId)
        : (subjects.isEmpty ? null : subjects.first);

    final stats = selectedSubject == null
        ? const AttendanceStats(attended: 0, total: 0)
        : attendance.getStatsForSubject(selectedSubject.id);

    final currentPercent = stats.total == 0
        ? 100.0
        : (stats.attended / stats.total) * 100;
    final projection = _buildProjection(
      attended: stats.attended,
      total: stats.total,
      futureClasses: _futureClasses,
      minAttendance: minAttendance,
    );

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
                              ? Border.all(color: scheme.outlineVariant)
                              : null,
                          boxShadow: isAbsolute
                              ? null
                              : [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: .08),
                                    blurRadius: 12,
                                    spreadRadius: 1,
                                    offset: const Offset(0, -1),
                                  ),
                                ],
                        ),
                        child: Text(
                          'Calculator',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: scheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: panelColor,
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: subjects.isEmpty
                        ? Center(
                            child: Text(
                              'Add a subject first to use the attendance calculator.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          )
                        : ListView(
                            children: [
                              const SizedBox(height: 20),
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: isAbsolute
                                      ? scheme.surfaceContainerHigh
                                      : scheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(24),
                                  border: (isAbsolute || isDynamic)
                                      ? Border.all(color: scheme.outlineVariant)
                                      : null,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Subject',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 12),
                                    LayoutBuilder(
                                      builder: (context, constraints) {
                                        return DropdownMenu<String>(
                                          width: constraints.maxWidth,
                                          initialSelection: selectedSubject?.id,
                                          menuStyle: MenuStyle(
                                            backgroundColor:
                                                WidgetStatePropertyAll(
                                                  scheme.surface,
                                                ),
                                            elevation:
                                                const WidgetStatePropertyAll(4),
                                            shape: WidgetStatePropertyAll(
                                              RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                            ),
                                          ),
                                          inputDecorationTheme:
                                              InputDecorationTheme(
                                                filled: true,
                                                fillColor: scheme.surface,
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(18),
                                                  borderSide:
                                                      (isDynamic || isAbsolute)
                                                      ? BorderSide(
                                                          color: scheme
                                                              .outlineVariant,
                                                        )
                                                      : BorderSide.none,
                                                ),
                                                enabledBorder: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(18),
                                                  borderSide:
                                                      (isDynamic || isAbsolute)
                                                      ? BorderSide(
                                                          color: scheme
                                                              .outlineVariant,
                                                        )
                                                      : BorderSide.none,
                                                ),
                                                focusedBorder:
                                                    OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            18,
                                                          ),
                                                      borderSide: BorderSide(
                                                        color: scheme.primary,
                                                        width: 2,
                                                      ),
                                                    ),
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 20,
                                                      vertical: 18,
                                                    ),
                                              ),
                                          textStyle: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                                color: scheme.onSurface,
                                              ),
                                          dropdownMenuEntries: subjects.map((
                                            subject,
                                          ) {
                                            return DropdownMenuEntry<String>(
                                              value: subject.id,
                                              label: subject.name,
                                              style: MenuItemButton.styleFrom(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 20,
                                                      vertical: 14,
                                                    ),
                                                textStyle: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                              ),
                                            );
                                          }).toList(),
                                          onSelected: (value) {
                                            if (value != null) {
                                              HapticFeedback.lightImpact();
                                              setState(() {
                                                _selectedSubjectId = value;
                                              });
                                            }
                                          },
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 18),
                                    Text(
                                      'More classes left',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        IconButton.filledTonal(
                                          style: IconButton.styleFrom(
                                            backgroundColor:
                                                scheme.tertiaryContainer,
                                            foregroundColor:
                                                scheme.onTertiaryContainer,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                          ),
                                          onPressed: () {
                                            final current = _futureClasses;
                                            if (current > 0) {
                                              HapticFeedback.lightImpact();
                                              setState(() {
                                                _futureClassesController.text =
                                                    (current - 1).toString();
                                              });
                                            }
                                          },
                                          icon: const Icon(Icons.remove),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: TextField(
                                            controller:
                                                _futureClassesController,
                                            textAlign: TextAlign.center,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                            keyboardType: TextInputType.number,
                                            inputFormatters: [
                                              FilteringTextInputFormatter
                                                  .digitsOnly,
                                            ],
                                            onChanged: (_) => setState(() {}),
                                            decoration: InputDecoration(
                                              hintText: 'Classes',
                                              filled: true,
                                              fillColor: scheme.surface,
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                borderSide:
                                                    (isDynamic || isAbsolute)
                                                    ? BorderSide(
                                                        color: scheme
                                                            .outlineVariant,
                                                      )
                                                    : BorderSide.none,
                                              ),
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 16,
                                                  ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton.filledTonal(
                                          style: IconButton.styleFrom(
                                            backgroundColor:
                                                scheme.tertiaryContainer,
                                            foregroundColor:
                                                scheme.onTertiaryContainer,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                          ),
                                          onPressed: () {
                                            final current = _futureClasses;
                                            HapticFeedback.lightImpact();
                                            setState(() {
                                              _futureClassesController.text =
                                                  (current + 1).toString();
                                            });
                                          },
                                          icon: const Icon(Icons.add),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Slider(
                                      // ignore: deprecated_member_use
                                      year2023: false,
                                      value: _futureClasses
                                          .clamp(0, 20)
                                          .toDouble(),
                                      min: 0,
                                      max: 20,
                                      divisions: 20,
                                      label: _futureClasses.toString(),
                                      onChanged: (value) {
                                        HapticFeedback.selectionClick();
                                        setState(() {
                                          _futureClassesController.text = value
                                              .toInt()
                                              .toString();
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: scheme.secondaryContainer,
                                  borderRadius: BorderRadius.circular(28),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      selectedSubject?.name ?? 'Subject',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                            color: scheme.onSecondaryContainer,
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    const SizedBox(height: 14),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _statTile(
                                            context,
                                            label: 'Current %',
                                            value:
                                                '${currentPercent.toStringAsFixed(1)}%',
                                            color: scheme.onSecondaryContainer,
                                          ),
                                        ),
                                        Expanded(
                                          child: _statTile(
                                            context,
                                            label: 'Criteria',
                                            value:
                                                '${minAttendance.toStringAsFixed(0)}%',
                                            color: scheme.onSecondaryContainer,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _statTile(
                                            context,
                                            label: 'Present',
                                            value: '${stats.attended}',
                                            color: scheme.onSecondaryContainer,
                                          ),
                                        ),
                                        Expanded(
                                          child: _statTile(
                                            context,
                                            label: 'Total',
                                            value: '${stats.total}',
                                            color: scheme.onSecondaryContainer,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: projection.shortage > 0
                                      ? scheme.errorContainer
                                      : scheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(28),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Projection',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            color: projection.shortage > 0
                                                ? scheme.onErrorContainer
                                                : scheme.onPrimaryContainer,
                                          ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      projection.shortage > 0
                                          ? 'Even if you attend all $_futureClasses remaining classes, you still fall short by ${projection.shortage} classes.'
                                          : 'You can cut ${projection.canCut} out of $_futureClasses upcoming classes and still meet the attendance criteria.',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: projection.shortage > 0
                                                ? scheme.onErrorContainer
                                                : scheme.onPrimaryContainer,
                                            height: 1.4,
                                            fontWeight: FontWeight.w400,
                                          ),
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _statTile(
                                            context,
                                            label: 'Can cut',
                                            value: '${projection.canCut}',
                                            color: projection.shortage > 0
                                                ? scheme.onErrorContainer
                                                : scheme.onPrimaryContainer,
                                          ),
                                        ),
                                        Expanded(
                                          child: _statTile(
                                            context,
                                            label: 'Must attend',
                                            value: '${projection.mustAttend}',
                                            color: projection.shortage > 0
                                                ? scheme.onErrorContainer
                                                : scheme.onPrimaryContainer,
                                          ),
                                        ),
                                        Expanded(
                                          child: _statTile(
                                            context,
                                            label: 'Projected %',
                                            value:
                                                '${projection.projectedPercent.toStringAsFixed(1)}%',
                                            color: projection.shortage > 0
                                                ? scheme.onErrorContainer
                                                : scheme.onPrimaryContainer,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
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
              color: isAbsolute ? scheme.surfaceContainer : scheme.surface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statTile(
    BuildContext context, {
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: color.withValues(alpha: .8)),
        ),
      ],
    );
  }
}

class _Projection {
  final int canCut;
  final int mustAttend;
  final double projectedPercent;
  final int shortage;

  const _Projection({
    required this.canCut,
    required this.mustAttend,
    required this.projectedPercent,
    required this.shortage,
  });
}
