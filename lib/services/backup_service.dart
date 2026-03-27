import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:uri_file_reader/uri_file_reader.dart';
import '../models/subject.dart';
import '../models/attendance.dart';
import 'database_service.dart';

class BackupService {
  /// Exports all application data to a custom .dpbk file.
  static Future<String?> exportBackup() async {
    try {
      final Map<String, dynamic> backup = {
        'app': 'DitchPerfect',
        'type': 'backup',
        'version': 2,
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
        fileName: 'attendance_backup_${DateTime.now().year}_${DateTime.now().month}_${DateTime.now().day}.dpbk',
        type: FileType.custom,
        allowedExtensions: ['dpbk'],
        bytes: bytes,
      );

      return outputPath;
    } catch (e) {
      debugPrint('Export Error: $e');
      rethrow;
    }
  }

  /// Picks a .dpbk file and returns its JSON string content.
  static Future<String?> pickBackupJson() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );

      if (result == null) return null;

      // Manually check extension
      final selectedFile = result.files.single;
      if (!selectedFile.name.toLowerCase().endsWith('.dpbk')) {
        throw Exception(
          'Please select a .dpbk file. Legacy .json files are no longer supported.',
        );
      }

      String jsonString;
      if (result.files.single.bytes != null) {
        jsonString = utf8.decode(result.files.single.bytes!);
      } else if (result.files.single.path != null) {
        final file = File(result.files.single.path!);
        jsonString = await file.readAsString();
      } else {
        throw Exception('Could not read backup file data.');
      }
      return jsonString;
    } catch (e) {
      debugPrint('Pick Backup Error: $e');
      rethrow;
    }
  }

  /// Imports application data from a .dpbk file.
  static Future<bool> importBackup() async {
    try {
      final jsonString = await pickBackupJson();
      if (jsonString == null) return false;
      return await processBackupJson(jsonString);
    } catch (e) {
      debugPrint('Import Error: $e');
      rethrow;
    }
  }

  /// Handles backup import from an external file path (e.g., intent).
  static Future<bool> importFromPath(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return false;
      final jsonString = await file.readAsString();
      return await processBackupJson(jsonString);
    } catch (e) {
      debugPrint('External Import Error: $e');
      rethrow;
    }
  }

  /// Handles backup import from an external URI (e.g., Android intent).
  static Future<bool> importFromUri(Uri uri) async {
    try {
      final String? jsonString = await _readStringFromUri(uri);
      if (jsonString == null) throw Exception("Could not read backup file.");
      return await processBackupJson(jsonString);
    } catch (e) {
      debugPrint('URI Import Error: $e');
      rethrow;
    }
  }

  /// Peeks at metadata from a URI for previewing.
  static Future<Map<String, dynamic>?> peekMetadataFromUri(Uri uri) async {
    try {
      final String? jsonString = await _readStringFromUri(uri);
      if (jsonString == null) return null;
      return peekMetadataFromJson(jsonString);
    } catch (e) {
      debugPrint('Peek Metadata URI Error: $e');
      return null;
    }
  }

  /// Peeks at metadata from a JSON string for previewing.
  static Map<String, dynamic>? peekMetadataFromJson(String jsonString) {
    try {
      final Map<String, dynamic> backup = jsonDecode(jsonString);

      return {
        'version': backup['version'] ?? 1,
        'exportedAt': backup['exportedAt'],
        'subjectsCount': (backup['subjects'] as List?)?.length ?? 0,
        'app': backup['app'],
        'subjects': (backup['subjects'] as List?)
                ?.map((s) => s['name']?.toString() ?? 'Unknown')
                .toList() ??
            [],
      };
    } catch (e) {
      debugPrint('Peek Metadata JSON Error: $e');
      return null;
    }
  }

  /// Helper to read a String from a URI (handles content:// on Android).
  static Future<String?> _readStringFromUri(Uri uri) async {
    try {
      if (Platform.isAndroid) {
        final stream = await uriFileReader.readFileAsBytesStream(uri.toString());
        if (stream != null) {
          final List<Uint8List> chunks = await stream.toList();
          final List<int> allBytes = chunks.expand((b) => b).toList();
          return utf8.decode(allBytes);
        }
      }
      
      // Fallback for file:// or other platforms
      if (uri.scheme == 'file') {
        final file = File(uri.toFilePath());
        return await file.readAsString();
      } else {
        // Try reading as a path directly if toFilePath fails
        final file = File(uri.path);
        if (await file.exists()) {
          return await file.readAsString();
        }
      }
      return null;
    } catch (e, stack) {
      debugPrint('Read String From URI Error: $e\n$stack');
      return null;
    }
  }

  /// Validates metadata and processes the backup JSON.
  static Future<bool> processBackupJson(String jsonString) async {
    try {
      final Map<String, dynamic> backup = jsonDecode(jsonString);

      // Validate metadata - Strictly enforce .dpbk format with metadata
      if (backup.containsKey('app')) {
        if (backup['app'] != 'DitchPerfect' || backup['type'] != 'backup') {
          throw Exception('Invalid backup file: Incorrect app or type.');
        }
      } else {
        throw Exception('Invalid backup file: Missing app metadata. This app only accepts .dpbk files.');
      }

      // Validate and parse all data before touching the database to avoid data loss on error
      final List<dynamic> subjectsJson = backup['subjects'] ?? [];
      final Map<String, dynamic> attendanceJson = backup['attendance'] ?? {};
      final Map<String, dynamic> timetableJson = backup['timetable'] ?? {};
      final Map<String, dynamic> settingsJson = backup['settings'] ?? {};
      final Map<String, dynamic> removalsJson =
          backup['timetable_removals'] ?? {};

      // Parse subjects
      final List<Subject> parsedSubjects = [];
      for (var sJson in subjectsJson) {
        parsedSubjects.add(Subject.fromJson(Map<String, dynamic>.from(sJson)));
      }

      // Parse attendance
      final Map<String, Attendance> parsedAttendance = {};
      for (var entry in attendanceJson.entries) {
        parsedAttendance[entry.key] = Attendance.fromJson(
          Map<String, dynamic>.from(entry.value),
        );
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
      if (timetableJson.isNotEmpty) {
        await DatabaseService.timetableBox.putAll(timetableJson);
      }
      if (settingsJson.isNotEmpty) {
        await DatabaseService.settingsBox.putAll(settingsJson);
      }
      if (removalsJson.isNotEmpty) {
        await DatabaseService.timetableRemovalsBox.putAll(removalsJson);
      }

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
