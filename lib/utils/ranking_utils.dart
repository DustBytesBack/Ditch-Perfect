import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/database_service.dart';
import '../models/subject.dart';
import '../models/attendance.dart';
import '../utils/attendance_utils.dart';

class RankingUtils {
  /// Checks for internet and automatically uploads ranking data if a username is set.
  static Future<void> checkAndAutoUpload() async {
    final username = DatabaseService.settingsBox.get("username") as String?;
    final isUsernameSet = DatabaseService.settingsBox.get("isUsernameSet", defaultValue: false) as bool;

    if (!isUsernameSet || username == null || username.isEmpty) return;

    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) return;

    await uploadRankingData();
  }

  /// Performs the actual data gathering and Firestore upload.
  static Future<void> uploadRankingData() async {
    final username = DatabaseService.settingsBox.get("username") as String?;
    if (username == null || username.isEmpty) return;

    final subjectsBox = DatabaseService.subjectsBox;
    final attendanceBox = DatabaseService.attendanceBox;

    final subjects = subjectsBox.values.cast<Subject>().toList();
    final allAttendance = attendanceBox.values.cast<Attendance>().toList();

    if (subjects.isEmpty) return;

    final subjectsSummary = subjects.map((subject) {
      final stats = calculateStats(subject.id, allAttendance);
      return {
        'subjectName': subject.name,
        'totalClasses': stats.total,
        'attendedClasses': stats.attended,
      };
    }).toList();

    final dataMap = {
      'username': username,
      'timestamp': FieldValue.serverTimestamp(),
      'subjects': subjectsSummary,
    };

    await FirebaseFirestore.instance.collection("rankings").add(dataMap);
  }
}
