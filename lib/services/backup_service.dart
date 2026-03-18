import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
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

      // Basic validation
      if (!backup.containsKey('subjects') || !backup.containsKey('attendance')) {
        throw Exception('Invalid backup file format.');
      }

      // Clear existing data completely
      await DatabaseService.subjectsBox.clear();
      await DatabaseService.attendanceBox.clear();
      await DatabaseService.timetableBox.clear();
      await DatabaseService.settingsBox.clear();
      await DatabaseService.timetableRemovalsBox.clear();

      // Restore subjects
      final List<dynamic> subjectsJson = backup['subjects'];
      for (var sJson in subjectsJson) {
        final subject = Subject.fromJson(Map<String, dynamic>.from(sJson));
        await DatabaseService.subjectsBox.put(subject.id, subject);
      }

      // Restore attendance
      final Map<String, dynamic> attendanceJson = backup['attendance'];
      for (var entry in attendanceJson.entries) {
        await DatabaseService.attendanceBox.put(
          entry.key,
          Attendance.fromJson(Map<String, dynamic>.from(entry.value)),
        );
      }

      // Restore timetable
      final Map<String, dynamic> timetableJson = backup['timetable'];
      await DatabaseService.timetableBox.putAll(timetableJson);

      // Restore settings
      final Map<String, dynamic> settingsJson = backup['settings'];
      await DatabaseService.settingsBox.putAll(settingsJson);

      // Restore timetable_removals
      final Map<String, dynamic> removalsJson = backup['timetable_removals'];
      await DatabaseService.timetableRemovalsBox.putAll(removalsJson);

      return true;
    } catch (e) {
      debugPrint('Import Error: $e');
      rethrow;
    }
  }
}
