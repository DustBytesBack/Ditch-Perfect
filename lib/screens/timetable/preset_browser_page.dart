import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/firestore_service.dart';
import '../../providers/subject_provider.dart';
import '../../providers/timetable_provider.dart';
import '../../providers/theme_provider.dart';
// import '../models/subject.dart';
// import 'package:uuid/uuid.dart';

class PresetBrowserPage extends StatefulWidget {
  const PresetBrowserPage({super.key});

  @override
  State<PresetBrowserPage> createState() => _PresetBrowserPageState();
}

class _PresetBrowserPageState extends State<PresetBrowserPage> {
  String? selectedUniversity;
  String? selectedSemester;
  String? selectedBranch;
  String? selectedBatch;

  List<String> universities = [];
  List<String> semesters = [];
  List<String> branches = [];
  List<String> batches = [];

  bool isLoading = false;
  Map<String, dynamic>? previewData;

  @override
  void initState() {
    super.initState();
    _loadUniversities();
  }

  Future<void> _loadUniversities() async {
    setState(() => isLoading = true);
    try {
      final unis = await FirestoreService.getAvailableUniversities();
      setState(() {
        universities = unis;
        isLoading = false;
      });
    } catch (e) {
      _showError("Failed to load universities: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadSemesters(String uni) async {
    setState(() {
      isLoading = true;
      semesters = [];
      branches = [];
      batches = [];
      selectedSemester = null;
      selectedBranch = null;
      selectedBatch = null;
      previewData = null;
    });
    try {
      final sems = await FirestoreService.getAvailableSemesters(uni);
      setState(() {
        semesters = sems;
        isLoading = false;
      });
    } catch (e) {
      _showError("Failed to load semesters: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadBranches(String sem) async {
    setState(() {
      isLoading = true;
      branches = [];
      batches = [];
      selectedBranch = null;
      selectedBatch = null;
      previewData = null;
    });
    try {
      final brs = await FirestoreService.getAvailableBranches(selectedUniversity!, sem);
      setState(() {
        branches = brs;
        isLoading = false;
      });
    } catch (e) {
      _showError("Failed to load branches: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadBatches(String branch) async {
    setState(() {
      isLoading = true;
      batches = [];
      selectedBatch = null;
      previewData = null;
    });
    try {
      final bts = await FirestoreService.getAvailableBatches(selectedUniversity!, selectedSemester!, branch);
      setState(() {
        batches = bts;
        isLoading = false;
      });
    } catch (e) {
      _showError("Failed to load batches: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadPreview(String batch) async {
    setState(() {
      isLoading = true;
      previewData = null;
    });
    try {
      final doc = await FirestoreService.getTimetableDoc(
        selectedUniversity!,
        selectedSemester!,
        selectedBranch!,
        batch,
      );
      setState(() {
        previewData = doc.data();
        isLoading = false;
      });
    } catch (e) {
      _showError("Failed to load preview: $e");
      setState(() => isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Theme.of(context).colorScheme.error),
    );
  }

  Future<void> _importPreset() async {
    if (previewData == null) return;

    final subjectProvider = context.read<SubjectProvider>();
    final timetableProvider = context.read<TimetableProvider>();

    // CHECK IF DATA EXISTS
    final bool hasSubjects = subjectProvider.subjects.isNotEmpty;
    final bool hasTimetable = timetableProvider.week.values.any((slots) => slots.isNotEmpty);

    if (hasSubjects || hasTimetable) {
      final scheme = Theme.of(context).colorScheme;
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Import & Overwrite?"),
          content: const Text(
            "You already have subjects or a timetable set up. Importing this preset will overwrite your current timetable and may add new subjects. \n\nThis action cannot be undone. Do you want to proceed?",
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: scheme.errorContainer,
                foregroundColor: scheme.onErrorContainer,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text("Overwrite"),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    }

    setState(() => isLoading = true);
    try {
      final List<dynamic> subjectsData = previewData!['subjects'];
      final Map<String, dynamic> timetableMap = previewData!['timetable'];

      // 1. Map preset subjects to local subjects (by short name)
      Map<String, String> presetShortToLocalId = {};

      for (var sData in subjectsData) {
        final String name = sData['name'];
        final String short = sData['short'];

        // Check if subject already exists
        final existing = subjectProvider.subjects.where((s) => s.shortName == short);
        if (existing.isNotEmpty) {
          presetShortToLocalId[short] = existing.first.id;
        } else {
          // Create new subject
          subjectProvider.addSubject(name, short);
          
          // The provider adds it immediately. We need its ID.
          // Since it's added last, we can grab it.
          final newSubject = subjectProvider.subjects.last;
          presetShortToLocalId[short] = newSubject.id;
        }
      }

      // 2. Apply timetable structure
      for (var day in timetableProvider.days) {
        if (timetableMap.containsKey(day)) {
          final List<dynamic> slots = timetableMap[day];
          final List<String> subjectIds = slots.map((slot) {
            final String short = slot['subject'];
            return presetShortToLocalId[short] ?? "";
          }).where((id) => id.isNotEmpty).toList();
          
          timetableProvider.updateDaySlots(day, subjectIds);
        } else {
          timetableProvider.updateDaySlots(day, []);
        }
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Timetable preset imported!")),
        );
      }
    } catch (e) {
      _showError("Import failed: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final themeProvider = context.watch<ThemeProvider>();
    final isAbsolute = themeProvider.absoluteMode;

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
                  colors: [topGradientColor, bottomGradientColor],
                ),
              ),
            ),
          ),

          /// MAIN PAGE
          SafeArea(
            child: Column(
              children: [
                /// HEADER (STANDARD PILL ROW)
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
                          boxShadow: isAbsolute ? null : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: .08),
                              blurRadius: 12,
                              spreadRadius: 1,
                              offset: const Offset(0, -1),
                            ),
                          ],
                        ),
                        child: Text(
                          "Preset Browser",
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Close Button Pill
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

                /// PANEL (STANDARD TOP-ROUNDED)
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: panelColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(32),
                        topRight: Radius.circular(32),
                      ),
                    ),
                    child: ListView(
                      physics: const BouncingScrollPhysics(),
                      children: [
                        if (!isLoading && universities.isEmpty)
                          _buildEmptyState(scheme),

                        _buildInputSection(
                          label: "University",
                          value: selectedUniversity,
                          items: universities,
                          icon: Icons.account_balance_rounded,
                          onSelected: (val) {
                            if (val != null) {
                              setState(() => selectedUniversity = val);
                              _loadSemesters(val);
                            }
                          },
                        ),
                        const SizedBox(height: 18),
                        _buildInputSection(
                          label: "Semester / Year",
                          value: selectedSemester,
                          items: semesters,
                          enabled: selectedUniversity != null,
                          icon: Icons.calendar_today_rounded,
                          onSelected: (val) {
                            if (val != null) {
                              setState(() => selectedSemester = val);
                              _loadBranches(val);
                            }
                          },
                        ),
                        const SizedBox(height: 18),
                        _buildInputSection(
                          label: "Branch",
                          value: selectedBranch,
                          items: branches,
                          enabled: selectedSemester != null,
                          icon: Icons.school_rounded,
                          onSelected: (val) {
                            if (val != null) {
                              setState(() => selectedBranch = val);
                              _loadBatches(val);
                            }
                          },
                        ),
                        const SizedBox(height: 18),
                        _buildInputSection(
                          label: "Batch",
                          value: selectedBatch,
                          items: batches,
                          enabled: selectedBranch != null,
                          icon: Icons.group_rounded,
                          onSelected: (val) {
                            if (val != null) {
                              setState(() => selectedBatch = val);
                              _loadPreview(val);
                            }
                          },
                        ),
                        
                        if (isLoading)
                          const Padding(
                            padding: EdgeInsets.all(48.0),
                            child: Center(child: CircularProgressIndicator.adaptive()),
                          ),

                        if (previewData != null) ...[
                          const SizedBox(height: 32),
                          Row(
                            children: [
                              Icon(Icons.visibility_outlined, color: scheme.primary, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                "Preview Preview",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: scheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildPreviewTable(scheme),
                          const SizedBox(height: 32),
                          FilledButton.icon(
                            onPressed: _importPreset,
                            icon: const Icon(Icons.download_rounded),
                            label: const Text("Import to My Timetable"),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                              backgroundColor: scheme.primary,
                              foregroundColor: scheme.onPrimary,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
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

  Widget _buildEmptyState(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        children: [
          Icon(Icons.cloud_off_rounded, size: 80, color: scheme.primary.withValues(alpha: .3)),
          const SizedBox(height: 24),
          Text(
            "No presets found in the cloud.",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: scheme.onSurface),
          ),
          const SizedBox(height: 8),
          Text(
            "Be the first to contribute by uploading yours!",
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          FilledButton.tonalIcon(
            onPressed: _loadUniversities,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text("Refresh List"),
          ),
        ],
      ),
    );
  }

  Widget _buildInputSection({
    required String label,
    required String? value,
    required List<String> items,
    required IconData icon,
    bool enabled = true,
    required Function(String?) onSelected,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final themeProvider = context.watch<ThemeProvider>();
    final isAbsolute = themeProvider.absoluteMode;
    final isDynamic = themeProvider.isDynamicMode;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isAbsolute ? scheme.surfaceContainerHigh : scheme.surfaceContainerHighest.withValues(alpha: enabled ? 1 : 0.4),
        borderRadius: BorderRadius.circular(24),
        border: (isAbsolute || isDynamic) ? Border.all(color: scheme.outlineVariant) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: enabled ? scheme.onSurface : scheme.outline,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              return DropdownMenu<String>(
                width: constraints.maxWidth,
                initialSelection: value,
                enabled: enabled && items.isNotEmpty,
                menuStyle: MenuStyle(
                  backgroundColor: WidgetStatePropertyAll(scheme.surface),
                  elevation: const WidgetStatePropertyAll(4),
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
                inputDecorationTheme: InputDecorationTheme(
                  filled: true,
                  fillColor: scheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: (isDynamic || isAbsolute) ? BorderSide(color: scheme.outlineVariant) : BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: (isDynamic || isAbsolute) ? BorderSide(color: scheme.outlineVariant) : BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(color: scheme.primary, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                ),
                leadingIcon: Icon(icon, color: enabled ? scheme.primary : scheme.outline),
                textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: enabled ? scheme.onSurface : scheme.outline,
                ),
                dropdownMenuEntries: items.map((e) {
                  return DropdownMenuEntry<String>(
                    value: e,
                    label: e.toUpperCase(),
                    style: MenuItemButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
                onSelected: (val) {
                  HapticFeedback.lightImpact();
                  onSelected(val);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewTable(ColorScheme scheme) {
    final Map<String, dynamic> timetableMap = previewData!['timetable'];
    final List<String> days = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"];
    final dayNames = {
      "mon": "Monday", "tue": "Tuesday", "wed": "Wednesday", 
      "thu": "Thursday", "fri": "Friday", "sat": "Saturday", "sun": "Sunday"
    };

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Table(
          columnWidths: const {
            0: IntrinsicColumnWidth(),
            1: FlexColumnWidth(),
          },
          children: days.where((d) => timetableMap.containsKey(d)).map((day) {
            final List<dynamic> slots = timetableMap[day];
            final subjectStr = slots.map((s) => s['subject']).join(", ");

            return TableRow(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.3))),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Text(
                    dayNames[day] ?? day, 
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: scheme.primary),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Text(
                    subjectStr.isEmpty ? "No Classes" : subjectStr,
                    style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
