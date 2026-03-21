import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import '../models/subject.dart';
import '../models/attendance.dart';
import 'database_service.dart';

class BackupService {
  /// Exports all application data to a JSON file.
  static Future<String?> exportBackup() async {
    try {
      final Map<String, dynamic> backup = {
        'version': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'subjects': DatabaseService.subjectsBox.values
            .cast<Subject>()
            .map((s) => s.toJson())
            .toList(),
        'attendance': DatabaseService.attendanceBox.toMap().map(
              (key, value) =>
                  MapEntry(key.toString(), (value as Attendance).toJson()),
            ),
        'timetable': DatabaseService.timetableBox.toMap().map(
              (key, value) => MapEntry(key.toString(), value),
            ),
        'settings': DatabaseService.settingsBox.toMap().map(
              (key, value) => MapEntry(key.toString(), value),
            ),
        'timetable_removals': DatabaseService.timetableRemovalsBox.toMap().map(
              (key, value) => MapEntry(key.toString(), value),
            ),
      };

      final String jsonString = jsonEncode(backup);
      final Uint8List bytes = Uint8List.fromList(utf8.encode(jsonString));

      // Using file_picker to select save location.
      String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Export Backup',
        fileName: 'attendance_backup.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: bytes,
      );

      return outputPath;
    } catch (e) {
      debugPrint('Export Error: $e');
      rethrow;
    }
  }

  /// Imports application data from a JSON file.
  static Future<bool> importBackup() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );

      if (result == null) return false;

      String jsonString;
      if (result.files.single.bytes != null) {
        jsonString = utf8.decode(result.files.single.bytes!);
      } else if (result.files.single.path != null) {
        final file = File(result.files.single.path!);
        jsonString = await file.readAsString();
      } else {
        throw Exception('Could not read backup file data.');
      }

      final Map<String, dynamic> backup = jsonDecode(jsonString);

      // Validate and parse all data before touching the database to avoid data loss on error
      final List<dynamic> subjectsJson = backup['subjects'] ?? [];
      final Map<String, dynamic> attendanceJson = backup['attendance'] ?? {};
      final Map<String, dynamic> timetableJson = backup['timetable'] ?? {};
      final Map<String, dynamic> settingsJson = backup['settings'] ?? {};
      final Map<String, dynamic> removalsJson = backup['timetable_removals'] ?? {};

      // Parse subjects
      final List<Subject> parsedSubjects = [];
      for (var sJson in subjectsJson) {
        parsedSubjects.add(Subject.fromJson(Map<String, dynamic>.from(sJson)));
      }

      // Parse attendance
      final Map<String, Attendance> parsedAttendance = {};
      for (var entry in attendanceJson.entries) {
        parsedAttendance[entry.key] = Attendance.fromJson(Map<String, dynamic>.from(entry.value));
      }

      // Clear existing data ONLY after successful parsing
      await DatabaseService.subjectsBox.clear();
      await DatabaseService.attendanceBox.clear();
      await DatabaseService.timetableBox.clear();
      await DatabaseService.settingsBox.clear();
      await DatabaseService.timetableRemovalsBox.clear();

      // Restore subjects
      for (var subject in parsedSubjects) {
        await DatabaseService.subjectsBox.put(subject.id, subject);
      }

      // Restore attendance
      for (var entry in parsedAttendance.entries) {
        await DatabaseService.attendanceBox.put(entry.key, entry.value);
      }

      // Restore other data
      if (timetableJson.isNotEmpty) await DatabaseService.timetableBox.putAll(timetableJson);
      if (settingsJson.isNotEmpty) await DatabaseService.settingsBox.putAll(settingsJson);
      if (removalsJson.isNotEmpty) await DatabaseService.timetableRemovalsBox.putAll(removalsJson);

      // Ensure default settings exist just in case they were missing from the backup
      final settingsBox = DatabaseService.settingsBox;
      if (!settingsBox.containsKey("hoursPerDay")) {
        await settingsBox.put("hoursPerDay", 8);
      }
      if (!settingsBox.containsKey("minAttendance")) {
        await settingsBox.put("minAttendance", 75);
      }
      if (!settingsBox.containsKey("username")) {
        final randomId = (DateTime.now().millisecondsSinceEpoch % 9000) + 1000;
        await settingsBox.put("username", "User_$randomId");
      }
      if (!settingsBox.containsKey("isUsernameSet")) {
        await settingsBox.put("isUsernameSet", false);
      }

      return true;
    } catch (e) {
      debugPrint('Import Error: $e');
      rethrow;
    }
  }
}
