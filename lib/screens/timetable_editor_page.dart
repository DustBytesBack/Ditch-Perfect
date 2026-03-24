import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/timetable_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/subject_provider.dart';
import '../models/subject.dart';

const dayNames = {
  "mon": "Monday",
  "tue": "Tuesday",
  "wed": "Wednesday",
  "thu": "Thursday",
  "fri": "Friday",
  "sat": "Saturday",
  "sun": "Sunday",
};

class TimetableEditorPage extends StatelessWidget {
  const TimetableEditorPage({super.key});

  void showSubjectPicker(BuildContext context, String day) {
    final subjects = context.read<SubjectProvider>().subjects;
    final scheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Select Subject",
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),

                const SizedBox(height: 16),

                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: subjects.length,
                    itemBuilder: (context, index) {
                      final subject = subjects[index];

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: scheme.primaryContainer,
                          child: Text(
                            subject.shortName.isEmpty
                                ? subject.name[0]
                                : subject.shortName[0],
                            style: TextStyle(
                              color: scheme.onPrimaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        title: Text(subject.name),
                        subtitle: Text(subject.shortName),
                        onTap: () {
                          context.read<TimetableProvider>().addSubject(
                            day,
                            subject.id,
                          );

                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void showDeleteDialog(BuildContext context, String day, int index) {
    final scheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Remove Subject"),
          content: const Text(
            "Do you want to remove this subject only from this slot or from every week?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),

            TextButton(
              onPressed: () {
                context.read<TimetableProvider>().removeSubjectAt(day, index);
                Navigator.pop(context);
              },
              child: const Text("Future Only"),
            ),

            TextButton(
              onPressed: () {
                context.read<TimetableProvider>().removeSlotEverywhere(
                  day,
                  index,
                );
                Navigator.pop(context);
              },
              child: Text(
                "Delete All Entries",
                style: TextStyle(color: scheme.error),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isAbsolute = themeProvider.absoluteMode;
    final scheme = Theme.of(context).colorScheme;

    final timetable = context.watch<TimetableProvider>();
    final subjects = context.watch<SubjectProvider>().subjects;

    final topGradientColor = isAbsolute ? scheme.surface : scheme.primaryContainer;
    final bottomGradientColor = isAbsolute ? scheme.surfaceContainer : scheme.surface;
    final panelColor = isAbsolute ? scheme.surfaceContainer : scheme.surface;

    return DefaultTabController(
      length: timetable.days.length,
      child: Scaffold(
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
                  /// HEADER
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
                                      color: Colors.black.withValues(
                                        alpha: .08,
                                      ),
                                      blurRadius: 12,
                                      spreadRadius: 1,
                                      offset: const Offset(0, -1),
                                    ),
                                  ],
                          ),
                          child: Text(
                            "Edit Timetable",
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: scheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),

                        const Spacer(),

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
                            iconSize: 26,
                            padding: const EdgeInsets.all(14),
                            icon: Icon(
                              Icons.arrow_back,
                              color: scheme.onSurface,
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  /// PANEL
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: panelColor,
                        borderRadius: BorderRadius.circular(32),
                      ),

                      child: Column(
                        children: [
                          /// TAB BAR
                          TabBar(
                            isScrollable: true,
                            tabs: timetable.days
                                .map((d) => Tab(text: dayNames[d]))
                                .toList(),
                          ),

                          const SizedBox(height: 16),

                          /// TAB CONTENT
                          Expanded(
                            child: TabBarView(
                              children: timetable.days.map((day) {
                                final slots = timetable.getDaySlots(day);

                                return ReorderableListView.builder(
                                  buildDefaultDragHandles: false,

                                  proxyDecorator: (child, index, animation) {
                                    return Material(
                                      elevation: 8,
                                      borderRadius: BorderRadius.circular(18),
                                      child: child,
                                    );
                                  },

                                  itemCount: slots.length,

                                  onReorder: (oldIndex, newIndex) {
                                    if (newIndex > oldIndex) newIndex--;

                                    context
                                        .read<TimetableProvider>()
                                        .reorderSubject(
                                          day,
                                          oldIndex,
                                          newIndex,
                                        );
                                  },

                                  itemBuilder: (context, index) {
                                    final subjectId = slots[index];

                                    final subject = subjects.firstWhere(
                                      (s) => s.id == subjectId,
                                      orElse: () => Subject(
                                        id: "",
                                        name: "Unknown",
                                        shortName: "",
                                      ),
                                    );

                                    return Padding(
                                      key: ValueKey("$day-$index"),
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),

                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: GestureDetector(
                                              onTap: () => showSubjectPicker(
                                                context,
                                                day,
                                              ),

                                              onLongPress: () {
                                                HapticFeedback.mediumImpact();
                                                showDeleteDialog(
                                                  context,
                                                  day,
                                                  index,
                                                );
                                              },

                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 20,
                                                      vertical: 16,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: isAbsolute
                                                      ? scheme
                                                            .surfaceContainerHigh
                                                      : scheme.onSecondary,
                                                  borderRadius:
                                                      const BorderRadius.only(
                                                        topLeft:
                                                            Radius.circular(18),
                                                        bottomLeft:
                                                            Radius.circular(18),
                                                      ),
                                                ),
                                                child: Text(
                                                  subject.shortName.isEmpty
                                                      ? subject.name
                                                      : subject.shortName,
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                    color: scheme
                                                        .onSecondaryContainer,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),

                                          ReorderableDragStartListener(
                                            index: index,
                                            child: Container(
                                              padding: const EdgeInsets.all(16),
                                              decoration: BoxDecoration(
                                                color:
                                                    scheme.surfaceContainerHigh,
                                                borderRadius:
                                                    const BorderRadius.only(
                                                      topRight: Radius.circular(
                                                        18,
                                                      ),
                                                      bottomRight:
                                                          Radius.circular(18),
                                                    ),
                                              ),
                                              child: const Icon(
                                                Icons.drag_handle,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            /// FAB
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 24,
              right: 24,
              child: Builder(
                builder: (fabContext) {
                  return FloatingActionButton.extended(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      final controller = DefaultTabController.of(fabContext);
                      final animIndex = controller.animation!.value.round();
                      final day = timetable.days[animIndex];

                      showSubjectPicker(fabContext, day);
                    },
                    icon: const Icon(Icons.add),
                    label: const Text("Add Subject"),
                  );
                },
              ),
            ),

            /// NAV BAR FIX
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: MediaQuery.of(context).padding.bottom + 12,
                color: isAbsolute ? scheme.surfaceContainer : scheme.surface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
