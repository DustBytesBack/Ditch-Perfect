import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'services/database_service.dart';

import 'providers/subject_provider.dart';
import 'providers/timetable_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/attendance_provider.dart';
import 'providers/theme_provider.dart';

import 'screens/main_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseService.init();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
    ),
  );

  // Create providers before runApp so we can wire cross-references.
  final attendanceProvider = AttendanceProvider()..loadAllAttendance();
  final timetableProvider = TimetableProvider()..loadTimetable();
  final subjectProvider = SubjectProvider()..loadSubjects();
  final settingsProvider = SettingsProvider()..loadSettings();
  final themeProvider = ThemeProvider()..loadTheme();

  // Wire cross-provider references for cache invalidation.
  subjectProvider.setProviders(
    attendanceProvider: attendanceProvider,
    timetableProvider: timetableProvider,
  );
  timetableProvider.setAttendanceProvider(attendanceProvider);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: subjectProvider),
        ChangeNotifierProvider.value(value: timetableProvider),
        ChangeNotifierProvider.value(value: settingsProvider),
        ChangeNotifierProvider.value(value: attendanceProvider),
        ChangeNotifierProvider.value(value: themeProvider),
      ],
      child: const OutStanding(),
    ),
  );
}

class OutStanding extends StatelessWidget {
  const OutStanding({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      debugShowCheckedModeBanner: false,

      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: themeProvider.seedColor,
      ),

      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: themeProvider.seedColor,
      ),

      themeMode: themeProvider.isDark ? ThemeMode.dark : ThemeMode.light,

      home: const MainShell(),
    );
  }
}
