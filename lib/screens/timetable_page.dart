import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/timetable_provider.dart';
import '../providers/subject_provider.dart';
import '../models/subject.dart';
import 'timetable_editor_page.dart';

const dayNames = {
  "mon": "Monday",
  "tue": "Tuesday",
  "wed": "Wednesday",
  "thu": "Thursday",
  "fri": "Friday",
  "sat": "Saturday",
  "sun": "Sunday",
};

class TimetablePage extends StatelessWidget {
  const TimetablePage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final timetable = context.watch<TimetableProvider>();
    final subjects = context.watch<SubjectProvider>().subjects;

    final hours = timetable.days.isEmpty
        ? 0
        : timetable.getDaySlots(timetable.days.first).length;

    return Scaffold(
      backgroundColor: scheme.primaryContainer,

      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [

                /// HEADER
                Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [

                  /// TITLE PILL
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 56,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(40),
                    ),
                    child: Text(
                      "Timetable",
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),

                  const Spacer(),

                  /// EDIT BUTTON (same style as add button)
                  Container(
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: IconButton(
                      iconSize: 28,
                      padding: const EdgeInsets.all(14),
                      icon: Icon(Icons.edit, color: scheme.onSurface),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const TimetableEditorPage(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            /// PANEL
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                ),

                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      /// PERIOD HEADER
                      Row(
                        children: [

                          const SizedBox(width: 110),

                          ...List.generate(
                            hours,
                            (index) => Container(
                              width: 80,
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(
                                vertical: 10,
                              ),
                              child: Text(
                                "${index + 1}",
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      /// DAY ROWS
                      ...timetable.days.map((day) {

                        final slots = timetable.getDaySlots(day);

                        return Padding(
                          padding:
                              const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [

                              /// DAY LABEL
                              SizedBox(
                                width: 110,
                                child: Text(
                                  dayNames[day] ?? day,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                              ),

                              /// SLOT CELLS
                              ...List.generate(
                                slots.length,
                                (index) {

                                  final subjectId =
                                      slots[index];

                                  Subject? subject;

                                  if (subjectId != null) {
                                    subject =
                                        subjects.firstWhere(
                                      (s) =>
                                          s.id == subjectId,
                                      orElse: () =>
                                          Subject(
                                        id: "",
                                        name: "Unknown",
                                        shortName: "",
                                      ),
                                    );
                                  }

                                  final label =
                                      subject?.shortName ?? "-";

                                  return Container(
                                    width: 80,
                                    height: 55,
                                    margin:
                                        const EdgeInsets.symmetric(
                                            horizontal: 4),
                                    decoration: BoxDecoration(
                                      color: scheme
                                          .secondaryContainer,
                                      borderRadius:
                                          BorderRadius
                                              .circular(12),
                                    ),
                                    alignment:
                                        Alignment.center,
                                    child: Text(
                                      label,
                                      style: TextStyle(
                                        color: scheme
                                            .onSecondaryContainer,
                                        fontWeight:
                                            FontWeight.w600,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
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
          color: scheme.surface,
        ),
      ),
    ],
  ),
    );
  }
}