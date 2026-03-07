import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/timetable_provider.dart';
import '../providers/subject_provider.dart';
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

    return Scaffold(
      backgroundColor: scheme.primaryContainer,

      body: Stack(
        children: [

          /// MAIN PAGE
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
                                builder: (_) => const TimetableEditorPage(),
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

                    child: ListView(
                      children: [
                        ...timetable.days.map((day) {

                          final slots = timetable.getDaySlots(day);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 24),

                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [

                                /// DAY TITLE
                                Text(
                                  dayNames[day] ?? day,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),

                                const SizedBox(height: 12),

                                /// SUBJECT CHIPS
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,

                                  children: slots.map((subjectId) {

                                    final subject = subjects.where((s) => s.id == subjectId).isNotEmpty
                                        ? subjects.firstWhere((s) => s.id == subjectId)
                                        : null;

                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 14,
                                        ),
                                        decoration: BoxDecoration(
                                          color: scheme.secondaryContainer,
                                          borderRadius: BorderRadius.circular(18),
                                        ),
                                        child: Text(
                                          subject?.shortName ?? "?",
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: scheme.onSecondaryContainer,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      );

                                  }).toList(),
                                ),
                              ],
                            ),
                          );

                        }),
                        const SizedBox(height: 60,)
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          /// NAV BAR COLOR FIX (same as SubjectPage)
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