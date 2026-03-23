import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

import 'services/database_service.dart';
import 'services/notification_service.dart';

import 'providers/subject_provider.dart';
import 'providers/timetable_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/attendance_provider.dart';
import 'providers/theme_provider.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/main_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('LICENSE');
    yield LicenseEntryWithLineBreaks(['Ditch Perfect'], license);
  });
  await DatabaseService.init();
  await NotificationService.init();

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

  // Re-schedule notification on every app launch with fresh data.
  try {
    await settingsProvider.rescheduleNotificationIfEnabled();
  } catch (_) {
    // Don't let notification scheduling prevent the app from launching.
  }

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
        colorScheme: ColorScheme.fromSeed(
          seedColor: themeProvider.seedColor,
          brightness: Brightness.dark,
        ).copyWith(
          surface: themeProvider.absoluteMode ? Colors.black : null,
          surfaceContainer: themeProvider.pookieMode
              ? const Color(0xFF1A1218) // Richer pinkish black
              : (themeProvider.absoluteMode 
                  ? Color.alphaBlend(themeProvider.seedColor.withValues(alpha: 0.03), const Color(0xFF0A0A0A)) 
                  : null),
          surfaceContainerHigh: themeProvider.pookieMode
              ? const Color(0xFF2B1B26) // Noticeable pink tint
              : (themeProvider.absoluteMode 
                  ? Color.alphaBlend(themeProvider.seedColor.withValues(alpha: 0.06), const Color(0xFF161616)) 
                  : null),
          surfaceContainerHighest: themeProvider.pookieMode
              ? const Color(0xFF382331) // Strong pink-tinted panel
              : (themeProvider.absoluteMode 
                  ? Color.alphaBlend(themeProvider.seedColor.withValues(alpha: 0.10), const Color(0xFF222222)) 
                  : null),
          onSurface: themeProvider.pookieMode
              ? const Color(0xFFF7A5E1)
              : null,
          onSurfaceVariant: themeProvider.pookieMode
              ? const Color(0xFFF7A5E1).withValues(alpha: 0.8)
              : null,
          onSecondaryContainer: themeProvider.pookieMode
              ? const Color(0xFFF7A5E1)
              : null,
          primary: themeProvider.pookieMode
              ? const Color(0xFFF7A5E1)
              : null,
          secondary: themeProvider.pookieMode
              ? const Color(0xFFF7A5E1)
              : null,
          secondaryContainer: themeProvider.pookieMode
              ? const Color(0xFF2B1B26) // Same as surfaceContainerHigh
              : null,
        ),
      ),

      themeMode: themeProvider.isDark ? ThemeMode.dark : ThemeMode.light,

      home: const MainShell(),
    );
  }
}
