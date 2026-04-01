import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
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
      'uid': uid,
      'username': username,
      'timestamp': FieldValue.serverTimestamp(),
      'subjects': subjectsSummary,
    };

    // Use .set() with the UID as document ID to overwrite on each sync.
    await FirebaseFirestore.instance
        .collection("rankings")
        .doc(uid)
        .set(dataMap);

    // Reset pending sync count after successful upload
    await DatabaseService.settingsBox.put("pendingSyncCount", 0);
  }
}
