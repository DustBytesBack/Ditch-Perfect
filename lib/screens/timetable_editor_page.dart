import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/timetable_provider.dart';
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

  void showSubjectPicker(BuildContext context, String day, int slotIndex) {
    final subjects = context.read<SubjectProvider>().subjects;
    final scheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
            children: [

              const Text(
                "Select Subject",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),

              const SizedBox(height: 16),

              ...subjects.map((subject) {
                return ListTile(
                  title: Text(subject.name),
                  onTap: () {
                    context.read<TimetableProvider>().assignSubject(
                      day,
                      slotIndex,
                      subject.id,
                    );
                    Navigator.pop(context);
                  },
                );
              }),

              ListTile(
                title: const Text("Free Slot"),
                onTap: () {
                  context.read<TimetableProvider>()
                      .removeSubject(day, slotIndex);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void showDeleteDialog(
    BuildContext context,
    String day,
    int slotIndex,
  ) {
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

                context
                    .read<TimetableProvider>()
                    .removeSubject(day, slotIndex);

                Navigator.pop(context);
              },
              child: const Text("Future Only"),
            ),

            TextButton(
              onPressed: () {

                context
                    .read<TimetableProvider>()
                    .removeSlotEverywhere(day, slotIndex);

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

    final scheme = Theme.of(context).colorScheme;
    final timetable = context.watch<TimetableProvider>();
    final subjects = context.watch<SubjectProvider>().subjects;

    return DefaultTabController(
      length: timetable.days.length,
      child: Scaffold(
        backgroundColor: scheme.primaryContainer,

        appBar: AppBar(
          title: const Text("Edit Timetable"),
          bottom: TabBar(
            isScrollable: true,
            tabs: timetable.days
                .map((d) => Tab(text: dayNames[d]))
                .toList(),
          ),
        ),

        body: Stack(
          children: [
            TabBarView(
              children: timetable.days.map((day) {

            final slots = timetable.getDaySlots(day);

            return Padding(
              padding: const EdgeInsets.all(20),

              child: ReorderableListView.builder(
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

                  final list = List<String?>.from(slots);

                  final item = list.removeAt(oldIndex);
                  list.insert(newIndex, item);

                  Future.microtask(() {
                    context.read<TimetableProvider>().updateDaySlots(day, list);
                  });
                },

                itemBuilder: (context, index) {

                  final subjectId = slots[index];

                  Subject? subject;

                  if (subjectId != null) {
                    subject = subjects.firstWhere(
                      (s) => s.id == subjectId,
                      orElse: () => Subject(
                        id: "",
                        name: "Unknown",
                        shortName: "",
                      ),
                    );
                  }

                  final label = subject?.shortName ?? "-";

                  return Padding(
                    key: ValueKey(index),
                    padding: const EdgeInsets.only(bottom: 12),

                    child: Row(
                      children: [

                        /// SUBJECT PILL
                        Expanded(
                          child: GestureDetector(

                            onTap: () =>
                                showSubjectPicker(context, day, index),

                            onLongPress: () {
                              if (subjectId != null) {
                                showDeleteDialog(
                                  context,
                                  day,
                                  index,
                                );
                              }
                            },

                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.onSecondary,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(18),
                                  bottomLeft: Radius.circular(18),
                                ),
                              ),
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onSecondaryContainer,
                                ),
                              ),
                            ),
                          ),
                        ),

                        /// DRAG HANDLE
                        ReorderableDragStartListener(
                          index: index,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHigh,
                              borderRadius: const BorderRadius.only(
                                topRight: Radius.circular(18),
                                bottomRight: Radius.circular(18),
                              ),
                            ),
                            child: const Icon(
                              Icons.drag_handle,
                              size: 22,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          }).toList(),
        ),

        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: MediaQuery.of(context).padding.bottom + 12,
            color: scheme.surface,
          ),
        ),
      ],
    ),
      ),
    );
  }
}