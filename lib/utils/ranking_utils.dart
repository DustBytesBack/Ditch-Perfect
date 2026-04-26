import 'dart:math' as math;
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/database_service.dart';
import '../models/subject.dart';
import '../models/attendance.dart';
import '../utils/attendance_utils.dart';

class RankingUtils {
  /// Returns the persistent user UID, generating one on first call.
  static String getOrCreateUid() {
    final box = DatabaseService.settingsBox;
    String? uid = box.get("userUid") as String?;
    if (uid == null || uid.isEmpty) {
      uid = const Uuid().v4();
      box.put("userUid", uid);
    }
    return uid;
  }

  /// Returns the current ISO week ID (e.g., "2024-W17") for today.
  static String getCurrentWeekId() => getWeekId(DateTime.now());

  /// Returns the ISO week ID (e.g., "2024-W17") for a given date.
  /// Week starts on Monday, ends on Sunday.
  static String getWeekId(DateTime date) {
    // ISO 8601 week number calculation.
    // The first week of the year is the week that contains the first Thursday.
    // We adjust the date to the nearest Thursday.
    final DateTime nearestThursday = date.add(Duration(days: 4 - (date.weekday == 0 ? 7 : date.weekday)));
    final int year = nearestThursday.year;
    final DateTime jan1 = DateTime(year, 1, 1);
    final int dayOfYear = nearestThursday.difference(jan1).inDays;
    final int weekNumber = (dayOfYear / 7).floor() + 1;
    
    return "$year-W${weekNumber.toString().padLeft(2, '0')}";
  }

  /// Checks for internet and automatically uploads ranking data if a username is set.
  /// Only syncs if [force] is true OR if the number of pending changes exceeds the threshold (5).
  static Future<void> checkAndAutoUpload({bool force = false}) async {
    final box = DatabaseService.settingsBox;
    final username = box.get("username") as String?;
    final isUsernameSet =
        box.get("isUsernameSet", defaultValue: false) as bool;

    if (!isUsernameSet || username == null || username.isEmpty) return;

    // Logic for change-based threshold
    if (!force) {
      int count = box.get("pendingSyncCount", defaultValue: 0) as int;
      count++;
      if (count < 5) {
        await box.put("pendingSyncCount", count);
        return;
      }
    }

    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) return;

    await uploadRankingData();
  }

  /// Performs the actual data gathering and Firestore upload.
  /// Uses the persistent UID as the document ID so each user has exactly one record.
  static Future<void> uploadRankingData() async {
    // Ensure Firebase is ready before accessing Firestore.
    await Firebase.initializeApp();

    final username = DatabaseService.settingsBox.get("username") as String?;
    if (username == null || username.isEmpty) return;

    final uid = getOrCreateUid();
    
    String appVersion = "0.0.0-unknown";
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      appVersion = packageInfo.version;
    } catch (_) {}

    final subjectsBox = DatabaseService.subjectsBox;
    final attendanceBox = DatabaseService.attendanceBox;
    final baselinesBox = DatabaseService.attendanceBaselinesBox;

    final subjects = subjectsBox.values.cast<Subject>().toList();
    final allAttendance = attendanceBox.values.cast<Attendance>().toList();

    if (subjects.isEmpty) return;
    
    final now = DateTime.now();
    final currentWeekId = getCurrentWeekId();
    final previousWeekDate = now.subtract(const Duration(days: 7));
    final previousWeekId = getWeekId(previousWeekDate);

    final batch = FirebaseFirestore.instance.batch();
    final db = FirebaseFirestore.instance;

    // 1. Calculate Global Summary (Cumulative + Baselines)
    final globalSummary = subjects.map((subject) {
      final stats = calculateStats(subject.id, allAttendance);
      final baselineRaw = baselinesBox.get(subject.id);
      int baselineAttended = 0;
      int baselineTotal = 0;
      if (baselineRaw is Map) {
        baselineAttended = (baselineRaw['attended'] as num?)?.toInt() ?? 0;
        baselineTotal = (baselineRaw['total'] as num?)?.toInt() ?? 0;
      }
      return {
        'subjectName': subject.name,
        'totalClasses': stats.total + baselineTotal,
        'attendedClasses': stats.attended + baselineAttended,
      };
    }).toList();

    final baseData = {
      'uid': uid,
      'username': username,
      'timestamp': FieldValue.serverTimestamp(),
      'appVersion': appVersion,
    };

    // Global Sync
    final globalData = Map<String, dynamic>.from(baseData);
    globalData['subjects'] = globalSummary;
    batch.set(db.collection("rankings").doc(uid), globalData);

    // 2. Sync Weekly Data for both Current and Previous Weeks
    for (String weekId in [currentWeekId, previousWeekId]) {
      final weekAttendance = allAttendance.where((a) => getWeekId(a.date) == weekId).toList();
      
      // Only sync if there is any data for that week
      if (weekAttendance.isNotEmpty) {
        final weeklySummary = subjects.map((subject) {
          final stats = calculateStats(subject.id, weekAttendance);
          return {
            'subjectName': subject.name,
            'totalClasses': stats.total,
            'attendedClasses': stats.attended,
          };
        }).toList();

        final weeklyData = Map<String, dynamic>.from(baseData);
        weeklyData['subjects'] = weeklySummary;
        weeklyData['weekId'] = weekId;
        
        // Use a composite ID to allow historical week data to persist
        final docId = "${weekId}_$uid";
        batch.set(db.collection("weekly_rankings").doc(docId), weeklyData);
      }
    }

    // Commit all at once
    await batch.commit();

    // Reset pending sync count after successful upload
    await DatabaseService.settingsBox.put("pendingSyncCount", 0);
  }

  /// Calculates the ranking score for a user's subject summary.
  /// Replicated from the Python worker to ensure consistency for live previews.
  static double calculateRankingScore(List<Map<String, dynamic>> subjects) {
    if (subjects.isEmpty) return 0;

    double rankingValueSum = 0;
    int totalClassesSum = 0;
    double totalClassValue = 0;

    for (var sub in subjects) {
      final attended = (sub['attendedClasses'] as num?)?.toInt() ?? 0;
      final total = (sub['totalClasses'] as num?)?.toInt() ?? 0;
      if (total == 0) continue;

      final percentage = (attended / total) * 100;
      final difference = percentage - 75;
      totalClassesSum += total;

      double value;
      if (difference >= 0) {
        // Safety Buffer logic: (2^(((100-diff)-75)/25)*10) * total
        value = (math.pow(2, ((((100 - difference) - 75) / 25) * 10))).toDouble() * total;
      } else {
        // Penalty logic: (percentage - 75) * absentClasses
        final absentClasses = total - attended;
        value = (difference * absentClasses).toDouble();
      }

      rankingValueSum += value;
      totalClassValue += math.pow(2, 10).toDouble();
    }

    if (totalClassesSum == 0) return 0;

    double score = (rankingValueSum / totalClassesSum);
    score = (score / totalClassValue) * 100000;
    return score;
  }
}
