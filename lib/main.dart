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

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
    ),
  );

  await DatabaseService.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => SubjectProvider()..loadSubjects(),
        ),
        ChangeNotifierProvider(
          create: (_) => TimetableProvider()..loadTimetable(),
        ),
        ChangeNotifierProvider(
          create: (_) => SettingsProvider()..loadSettings(),
        ),
        ChangeNotifierProvider(
          create: (_) => AttendanceProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => ThemeProvider()..loadTheme(),
        ),
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

      themeMode:
          themeProvider.isDark
              ? ThemeMode.dark
              : ThemeMode.light,

      home: const MainShell(),
    );
  }
}