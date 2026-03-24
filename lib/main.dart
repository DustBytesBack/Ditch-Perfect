import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

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

/// Builds a single Roboto Flex TextStyle with tuned variable-font axes.
TextStyle _robotoFlexStyle({
  required double weight,
  double? fontSize,
  double? height,
  double? letterSpacing,
}) {
  return GoogleFonts.robotoFlex(
    fontSize: fontSize,
    height: height,
    letterSpacing: letterSpacing,
    fontWeight: FontWeight.w400,
  ).copyWith(
    fontVariations: <FontVariation>[
      FontVariation('wght', weight),
      const FontVariation('GRAD', 150),   // Grade: increased optical weight boost
      const FontVariation('slnt', 0),     // Slant: upright
      const FontVariation('wdth', 100),   // Width: standard
      const FontVariation('XOPQ', 100),   // Thick Stroke: slightly bolder
      const FontVariation('YOPQ', 82),    // Thin Stroke: crisper thin strokes
      const FontVariation('XTRA', 480),   // Counter Width: slightly wider openings
      const FontVariation('YTUC', 720),   // Uppercase Height: taller caps
      const FontVariation('YTLC', 520),   // Lowercase Height: taller x-height
      const FontVariation('YTAS', 760),   // Ascender Height: taller ascenders
      const FontVariation('YTDE', -210),  // Descender Depth: deeper descenders
      const FontVariation('YTFI', 745),   // Figure Height: taller numerals
    ],
  );
}

/// Material 3 TextTheme using Roboto Flex with expressive-pixel tuning.
TextTheme _buildRobotoFlexTextTheme() {
  return TextTheme(
    displayLarge:  _robotoFlexStyle(weight: 400, fontSize: 57, height: 1.12, letterSpacing: -0.25),
    displayMedium: _robotoFlexStyle(weight: 400, fontSize: 45, height: 1.16),
    displaySmall:  _robotoFlexStyle(weight: 400, fontSize: 36, height: 1.22),
    headlineLarge: _robotoFlexStyle(weight: 500, fontSize: 32, height: 1.25),
    headlineMedium:_robotoFlexStyle(weight: 500, fontSize: 28, height: 1.29),
    headlineSmall: _robotoFlexStyle(weight: 500, fontSize: 24, height: 1.33),
    titleLarge:    _robotoFlexStyle(weight: 600, fontSize: 22, height: 1.27),
    titleMedium:   _robotoFlexStyle(weight: 600, fontSize: 18, height: 1.50, letterSpacing: 0.15),
    titleSmall:    _robotoFlexStyle(weight: 600, fontSize: 14, height: 1.43, letterSpacing: 0.10),
    bodyLarge:     _robotoFlexStyle(weight: 400, fontSize: 16, height: 1.50, letterSpacing: 0.15),
    bodyMedium:    _robotoFlexStyle(weight: 400, fontSize: 14, height: 1.43, letterSpacing: 0.25),
    bodySmall:     _robotoFlexStyle(weight: 400, fontSize: 12, height: 1.33, letterSpacing: 0.40),
    labelLarge:    _robotoFlexStyle(weight: 600, fontSize: 14, height: 1.43, letterSpacing: 0.10),
    labelMedium:   _robotoFlexStyle(weight: 600, fontSize: 12, height: 1.33, letterSpacing: 0.50),
    labelSmall:    _robotoFlexStyle(weight: 600, fontSize: 11, height: 1.45, letterSpacing: 0.50),
  );
}

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
        textTheme: _buildRobotoFlexTextTheme(),
      ),

      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        textTheme: _buildRobotoFlexTextTheme(),
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
