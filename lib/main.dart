import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:dynamic_color/dynamic_color.dart';

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
  return TextStyle(
    fontFamily: 'RobotoFlex',
    fontSize: fontSize,
    height: height,
    letterSpacing: letterSpacing,
    fontVariations: <FontVariation>[
      FontVariation('wght', weight),
      const FontVariation('GRAD', 150), // Grade: increased optical weight boost
      const FontVariation('slnt', 0), // Slant: upright
      const FontVariation('wdth', 100), // Width: standard
      const FontVariation('XOPQ', 60), // Thick Stroke: slightly bolder
      const FontVariation('YOPQ', 70), // Thin Stroke: crisper thin strokes
      const FontVariation('XTRA', 560), // Counter Width: slightly wider openings
      const FontVariation('YTUC', 750), // Uppercase Height: taller caps
      const FontVariation('YTLC', 540), // Lowercase Height: taller x-height
      const FontVariation('YTAS', 760), // Ascender Height: taller ascenders
      const FontVariation('YTDE', -210), // Descender Depth: deeper descenders
      const FontVariation('YTFI', 745), // Figure Height: taller numerals
    ],
  );
}

/// Material 3 TextTheme using Roboto Flex with expressive-pixel tuning.
/// Cached as a top-level final to avoid rebuilding 15 TextStyles on every frame.
final TextTheme _robotoFlexTextTheme = TextTheme(
  displayLarge: _robotoFlexStyle(
    weight: 400,
    fontSize: 57,
    height: 1.12,
    letterSpacing: -0.25,
  ),
  displayMedium: _robotoFlexStyle(weight: 400, fontSize: 45, height: 1.16),
  displaySmall: _robotoFlexStyle(weight: 400, fontSize: 36, height: 1.22),
  headlineLarge: _robotoFlexStyle(weight: 500, fontSize: 32, height: 1.25),
  headlineMedium: _robotoFlexStyle(weight: 500, fontSize: 28, height: 1.29),
  headlineSmall: _robotoFlexStyle(weight: 500, fontSize: 24, height: 1.33),
  titleLarge: _robotoFlexStyle(weight: 600, fontSize: 22, height: 1.27),
  titleMedium: _robotoFlexStyle(
    weight: 600,
    fontSize: 18,
    height: 1.50,
    letterSpacing: 0.15,
  ),
  titleSmall: _robotoFlexStyle(
    weight: 600,
    fontSize: 14,
    height: 1.43,
    letterSpacing: 0.10,
  ),
  bodyLarge: _robotoFlexStyle(
    weight: 400,
    fontSize: 16,
    height: 1.50,
    letterSpacing: 0.15,
  ),
  bodyMedium: _robotoFlexStyle(
    weight: 400,
    fontSize: 14,
    height: 1.43,
    letterSpacing: 0.25,
  ),
  bodySmall: _robotoFlexStyle(
    weight: 400,
    fontSize: 12,
    height: 1.33,
    letterSpacing: 0.40,
  ),
  labelLarge: _robotoFlexStyle(
    weight: 600,
    fontSize: 14,
    height: 1.43,
    letterSpacing: 0.10,
  ),
  labelMedium: _robotoFlexStyle(
    weight: 600,
    fontSize: 12,
    height: 1.33,
    letterSpacing: 0.50,
  ),
  labelSmall: _robotoFlexStyle(
    weight: 600,
    fontSize: 11,
    height: 1.45,
    letterSpacing: 0.50,
  ),
);

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI immediately — no await needed.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
    ),
  );

  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('LICENSE');
    yield LicenseEntryWithLineBreaks(['Ditch Perfect'], license);
  });

  // Launch the UI IMMEDIATELY — no awaits before runApp.
  runApp(const OutStanding());
}

/// Performs all async initialization (Firebase, Hive, Providers).
/// Returns the list of providers once ready.
Future<List<SingleChildWidget>> _initializeApp() async {
  // Only block on Hive initialization — it's extremely fast (<100ms).
  await DatabaseService.init();

  // Start Firebase initialization in the background — don't block the UI.
  Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final attendanceProvider = AttendanceProvider()..loadAllAttendance();
  final timetableProvider = TimetableProvider()..loadTimetable();
  final subjectProvider = SubjectProvider()..loadSubjects();
  final settingsProvider = SettingsProvider()..loadSettings();
  final themeProvider = ThemeProvider()..loadTheme();

  subjectProvider.setProviders(
    attendanceProvider: attendanceProvider,
    timetableProvider: timetableProvider,
  );
  timetableProvider.setAttendanceProvider(attendanceProvider);

  // Fire-and-forget notification scheduling — don't block.
  NotificationService.init().then((_) {
    settingsProvider.rescheduleNotificationIfEnabled().catchError((_) {});
  });

  return [
    ChangeNotifierProvider.value(value: subjectProvider),
    ChangeNotifierProvider.value(value: timetableProvider),
    ChangeNotifierProvider.value(value: settingsProvider),
    ChangeNotifierProvider.value(value: attendanceProvider),
    ChangeNotifierProvider.value(value: themeProvider),
  ];
}

class OutStanding extends StatefulWidget {
  const OutStanding({super.key});

  @override
  State<OutStanding> createState() => _OutStandingState();
}

class _OutStandingState extends State<OutStanding> {
  late final Future<List<SingleChildWidget>> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = _initializeApp();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SingleChildWidget>>(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done ||
            !snapshot.hasData) {
          // Lightweight loading screen — renders on the very first frame.
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.dark,
              colorSchemeSeed: Colors.blue,
              textTheme: _robotoFlexTextTheme,
            ),
            home: const Scaffold(
              body: Center(child: CircularProgressIndicator.adaptive()),
            ),
          );
        }

        return MultiProvider(
          providers: snapshot.data!,
          child: DynamicColorBuilder(
            builder: (lightDynamic, darkDynamic) {
              return Builder(
                builder: (context) {
                  final themeProvider = context.watch<ThemeProvider>();
                  final isDynamic = themeProvider.isDynamicMode;

                  return MaterialApp(
                    debugShowCheckedModeBanner: false,
                    title: 'Ditch Perfect',

                    theme: ThemeData(
                      useMaterial3: true,
                      brightness: Brightness.light,
                      colorScheme: (isDynamic && lightDynamic != null)
                          ? lightDynamic
                          : ColorScheme.fromSeed(
                              seedColor: themeProvider.seedColor,
                            ),
                      textTheme: _robotoFlexTextTheme,
                    ),

                    darkTheme: ThemeData(
                      useMaterial3: true,
                      brightness: Brightness.dark,
                      textTheme: _robotoFlexTextTheme,
                      colorScheme: (() {
                        final baseScheme = (isDynamic && darkDynamic != null)
                            ? darkDynamic
                            : ColorScheme.fromSeed(
                                seedColor: themeProvider.seedColor,
                                brightness: Brightness.dark,
                              );

                        final effectiveSeed = (isDynamic && darkDynamic != null)
                            ? darkDynamic.primary
                            : themeProvider.seedColor;

                        return baseScheme.copyWith(
                          surface: themeProvider.absoluteMode
                              ? Colors.black
                              : null,
                          surfaceContainer: themeProvider.pookieMode
                              ? const Color(0xFF1A1218)
                              : (themeProvider.absoluteMode
                                    ? Color.alphaBlend(
                                        effectiveSeed.withAlpha(0x08),
                                        const Color(0xFF0A0A0A),
                                      )
                                    : null),
                          surfaceContainerHigh: themeProvider.pookieMode
                              ? const Color(0xFF2B1B26)
                              : (themeProvider.absoluteMode
                                    ? Color.alphaBlend(
                                        effectiveSeed.withAlpha(0x0F),
                                        const Color(0xFF161616),
                                      )
                                    : null),
                          surfaceContainerHighest: themeProvider.pookieMode
                              ? const Color(0xFF382331)
                              : (themeProvider.absoluteMode
                                    ? Color.alphaBlend(
                                        effectiveSeed.withAlpha(0x1A),
                                        const Color(0xFF222222),
                                      )
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
                              ? const Color(0xFF2B1B26)
                              : null,
                        );
                      })(),
                    ),

                    themeMode: themeProvider.themeMode,

                    home: const MainShell(),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
