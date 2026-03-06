import 'package:flutter/material.dart';

import 'home_page.dart';
import 'calendar_page.dart';
import 'subject_page.dart';
import 'timetable_page.dart';
import 'settings_page.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {

  int currentIndex = 0;

  final pages = const [
    HomePage(),
    CalendarPage(),
    SubjectPage(),
    TimetablePage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Stack(
        children: [

          pages[currentIndex],

          Positioned(
            bottom: 24,
            left: 20,
            right: 20,
            child: LayoutBuilder(
              builder: (context, constraints) {

                final width = constraints.maxWidth;
                final itemWidth = width / 5;

                return Container(
                  height: 75,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(40),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.shadow.withValues(alpha: .35),
                        blurRadius: 13,
                        offset: const Offset(0,6),
                      )
                    ],
                  ),

                  child: Stack(
                    children: [

                      /// SLIDING INDICATOR
                      AnimatedAlign(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                        alignment: Alignment(
                          -1 + (currentIndex * 2 / 4),
                          0,
                        ),
                        child: Container(
                          width: itemWidth,
                          height: 55,
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            borderRadius: BorderRadius.circular(40),
                          ),
                        ),
                      ),

                      /// NAV ITEMS
                      Row(
                        children: [

                          navItem(Icons.home_rounded, "Home", 0),
                          navItem(Icons.calendar_month_rounded, "Calendar", 1),
                          navItem(Icons.menu_book_rounded, "Subjects", 2),
                          navItem(Icons.schedule_rounded, "Timetable", 3),
                          navItem(Icons.settings_rounded, "Settings", 4),

                        ],
                      )
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

  Widget navItem(IconData icon, String label, int index) {

  final scheme = Theme.of(context).colorScheme;
  final selected = currentIndex == index;

  return Expanded(
    child: GestureDetector(
      onTap: () {
        setState(() {
          currentIndex = index;
        });
      },

      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [

          Icon(
            icon,
            size: 22,
            color: selected
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
          ),

          const SizedBox(height: 4),

          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(
                  color: selected
                      ? scheme.onPrimaryContainer
                      : scheme.onSurfaceVariant,
                  fontWeight: selected
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
          ),
        ],
      ),
    ),
  );
  }
}