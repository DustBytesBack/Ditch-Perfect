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
        'version': 3,
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
        'timetable_slot_ids': DatabaseService.timetableSlotIdsBox.toMap().map(
          (key, value) => MapEntry(key.toString(), value),
        ),
        'attendance_baselines': DatabaseService.attendanceBaselinesBox
            .toMap()
            .map((key, value) => MapEntry(key.toString(), value)),
      };

      final String jsonString = jsonEncode(backup);
      final Uint8List bytes = Uint8List.fromList(utf8.encode(jsonString));

      // Using file_picker to select save location.
      String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Export Backup',
        fileName:
            'attendance_backup_${DateTime.now().year}_${DateTime.now().month}_${DateTime.now().day}.dpbk',
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
      final List<dynamic> subjectsJson = backup['subjects'] ?? [];
      final Map<String, dynamic> attendanceJson = backup['attendance'] ?? {};

      final List<Map<String, dynamic>> detailedSubjects = [];

      for (var sJson in subjectsJson) {
        final String id = sJson['id'] ?? '';
        final String name = sJson['name'] ?? 'Unknown';
        final double minAtt =
            (sJson['minAttendance'] as num?)?.toDouble() ?? 75.0;

        int present = 0;
        int absent = 0;

        // Count attendance for this subject
        for (var att in attendanceJson.values) {
          if (att['subjectId'] == id) {
            final status = att['status'];
            if (status == 'present') {
              present++;
            } else if (status == 'absent') {
              absent++;
            }
          }
        }

        final int total = present + absent;
        final double percentage = total > 0 ? (present / total) * 100 : 100.0;

        detailedSubjects.add({
          'name': name,
          'present': present,
          'absent': absent,
          'total': total,
          'percentage': percentage,
          'minAttendance': minAtt,
        });
      }

      return {
        'version': backup['version'] ?? 1,
        'exportedAt': backup['exportedAt'],
        'subjectsCount': subjectsJson.length,
        'app': backup['app'],
        'subjects': detailedSubjects,
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
        final stream = await uriFileReader.readFileAsBytesStream(
          uri.toString(),
        );
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
        throw Exception(
          'Invalid backup file: Missing app metadata. This app only accepts .dpbk files.',
        );
      }

      // Validate top-level sections before touching storage.
      final subjectsRaw = backup['subjects'];
      final attendanceRaw = backup['attendance'];
      final timetableRaw = backup['timetable'];
      final settingsRaw = backup['settings'];
      final removalsRaw = backup['timetable_removals'];
      final slotIdsRaw = backup['timetable_slot_ids'];
      final baselinesRaw = backup['attendance_baselines'];

      if (subjectsRaw != null && subjectsRaw is! List) {
        throw Exception('Invalid backup file: subjects must be a list.');
      }
      if (attendanceRaw != null && attendanceRaw is! Map) {
        throw Exception('Invalid backup file: attendance must be a map.');
      }
      if (timetableRaw != null && timetableRaw is! Map) {
        throw Exception('Invalid backup file: timetable must be a map.');
      }
      if (settingsRaw != null && settingsRaw is! Map) {
        throw Exception('Invalid backup file: settings must be a map.');
      }
      if (removalsRaw != null && removalsRaw is! Map) {
        throw Exception(
          'Invalid backup file: timetable_removals must be a map.',
        );
      }
      if (slotIdsRaw != null && slotIdsRaw is! Map) {
        throw Exception(
          'Invalid backup file: timetable_slot_ids must be a map.',
        );
      }
      if (baselinesRaw != null && baselinesRaw is! Map) {
        throw Exception(
          'Invalid backup file: attendance_baselines must be a map.',
        );
      }

      final List<dynamic> subjectsJson = (subjectsRaw as List?) ?? [];
      final Map<dynamic, dynamic> attendanceJson =
          (attendanceRaw as Map?)?.cast<dynamic, dynamic>() ??
          <dynamic, dynamic>{};
      final Map<dynamic, dynamic> timetableJson =
          (timetableRaw as Map?)?.cast<dynamic, dynamic>() ??
          <dynamic, dynamic>{};
      final Map<dynamic, dynamic> settingsJson =
          (settingsRaw as Map?)?.cast<dynamic, dynamic>() ??
          <dynamic, dynamic>{};
      final Map<dynamic, dynamic> removalsJson =
          (removalsRaw as Map?)?.cast<dynamic, dynamic>() ??
          <dynamic, dynamic>{};
      final Map<dynamic, dynamic> slotIdsJson =
          (slotIdsRaw as Map?)?.cast<dynamic, dynamic>() ??
          <dynamic, dynamic>{};
      final Map<dynamic, dynamic> baselinesJson =
          (baselinesRaw as Map?)?.cast<dynamic, dynamic>() ??
          <dynamic, dynamic>{};

      // Parse subjects
      final List<Subject> parsedSubjects = [];
      for (var sJson in subjectsJson) {
        if (sJson is! Map) {
          throw Exception('Invalid backup file: malformed subject entry.');
        }
        parsedSubjects.add(Subject.fromJson(Map<String, dynamic>.from(sJson)));
      }

      // Parse attendance
      final Map<String, Attendance> parsedAttendance = {};
      for (var entry in attendanceJson.entries) {
        if (entry.value is! Map) {
          throw Exception(
            'Invalid backup file: malformed attendance entry for key ${entry.key}.',
          );
        }
        parsedAttendance[entry.key.toString()] = Attendance.fromJson(
          Map<String, dynamic>.from(entry.value),
        );
      }

      // Parse timetable and removals as normalized string lists.
      final Map<String, List<String>> parsedTimetable = {};
      for (var entry in timetableJson.entries) {
        final key = entry.key.toString();
        final value = entry.value;
        if (value is! List) {
          throw Exception(
            'Invalid backup file: timetable[$key] must be a list.',
          );
        }
        parsedTimetable[key] = value
            .where((e) => e != null)
            .map((e) => e.toString())
            .toList();
      }

      final Map<String, dynamic> parsedSettings = settingsJson.map(
        (key, value) => MapEntry(key.toString(), value),
      );

      final Map<String, List<String>> parsedRemovals = {};
      for (var entry in removalsJson.entries) {
        final key = entry.key.toString();
        final value = entry.value;
        if (value is! List) {
          throw Exception(
            'Invalid backup file: timetable_removals[$key] must be a list.',
          );
        }
        parsedRemovals[key] = value
            .where((e) => e != null)
            .map((e) => e.toString())
            .toList();
      }

      final Map<String, List<String>> parsedSlotIds = {};
      for (var entry in slotIdsJson.entries) {
        final key = entry.key.toString();
        final value = entry.value;
        if (value is! List) {
          throw Exception(
            'Invalid backup file: timetable_slot_ids[$key] must be a list.',
          );
        }
        parsedSlotIds[key] = value
            .where((e) => e != null)
            .map((e) => e.toString())
            .toList();
      }

      final Map<String, Map<String, int>> parsedBaselines = {};
      for (var entry in baselinesJson.entries) {
        final key = entry.key.toString();
        final value = entry.value;
        if (value is! Map) {
          throw Exception(
            'Invalid backup file: attendance_baselines[$key] must be a map.',
          );
        }

        final attended = (value['attended'] as num?)?.toInt() ?? 0;
        final total = (value['total'] as num?)?.toInt() ?? 0;
        parsedBaselines[key] = {'attended': attended, 'total': total};
      }

      // Snapshot existing data for rollback safety.
      final previousSubjects = Map<dynamic, dynamic>.from(
        DatabaseService.subjectsBox.toMap(),
      );
      final previousAttendance = Map<dynamic, dynamic>.from(
        DatabaseService.attendanceBox.toMap(),
      );
      final previousTimetable = Map<dynamic, dynamic>.from(
        DatabaseService.timetableBox.toMap(),
      );
      final previousSettings = Map<dynamic, dynamic>.from(
        DatabaseService.settingsBox.toMap(),
      );
      final previousRemovals = Map<dynamic, dynamic>.from(
        DatabaseService.timetableRemovalsBox.toMap(),
      );
      final previousSlotIds = Map<dynamic, dynamic>.from(
        DatabaseService.timetableSlotIdsBox.toMap(),
      );
      final previousBaselines = Map<dynamic, dynamic>.from(
        DatabaseService.attendanceBaselinesBox.toMap(),
      );

      try {
        // Clear existing data ONLY after successful parsing/validation.
        await DatabaseService.subjectsBox.clear();
        await DatabaseService.attendanceBox.clear();
        await DatabaseService.timetableBox.clear();
        await DatabaseService.settingsBox.clear();
        await DatabaseService.timetableRemovalsBox.clear();
        await DatabaseService.timetableSlotIdsBox.clear();
        await DatabaseService.attendanceBaselinesBox.clear();

        // Restore subjects
        for (var subject in parsedSubjects) {
          await DatabaseService.subjectsBox.put(subject.id, subject);
        }

        // Restore attendance
        for (var entry in parsedAttendance.entries) {
          await DatabaseService.attendanceBox.put(entry.key, entry.value);
        }

        // Restore other data
        if (parsedTimetable.isNotEmpty) {
          await DatabaseService.timetableBox.putAll(parsedTimetable);
        }
        if (parsedSettings.isNotEmpty) {
          await DatabaseService.settingsBox.putAll(parsedSettings);
        }
        if (parsedRemovals.isNotEmpty) {
          await DatabaseService.timetableRemovalsBox.putAll(parsedRemovals);
        }
        if (parsedSlotIds.isNotEmpty) {
          await DatabaseService.timetableSlotIdsBox.putAll(parsedSlotIds);
        }
        if (parsedBaselines.isNotEmpty) {
          await DatabaseService.attendanceBaselinesBox.putAll(parsedBaselines);
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
          final randomId =
              (DateTime.now().millisecondsSinceEpoch % 9000) + 1000;
          await settingsBox.put("username", "User_$randomId");
        }
        if (!settingsBox.containsKey("isUsernameSet")) {
          await settingsBox.put("isUsernameSet", false);
        }
      } catch (e) {
        // Roll back to pre-import state if any write fails.
        try {
          await DatabaseService.subjectsBox.clear();
          await DatabaseService.subjectsBox.putAll(previousSubjects);

          await DatabaseService.attendanceBox.clear();
          await DatabaseService.attendanceBox.putAll(previousAttendance);

          await DatabaseService.timetableBox.clear();
          await DatabaseService.timetableBox.putAll(previousTimetable);

          await DatabaseService.settingsBox.clear();
          await DatabaseService.settingsBox.putAll(previousSettings);

          await DatabaseService.timetableRemovalsBox.clear();
          await DatabaseService.timetableRemovalsBox.putAll(previousRemovals);

          await DatabaseService.timetableSlotIdsBox.clear();
          await DatabaseService.timetableSlotIdsBox.putAll(previousSlotIds);

          await DatabaseService.attendanceBaselinesBox.clear();
          await DatabaseService.attendanceBaselinesBox.putAll(
            previousBaselines,
          );
        } catch (rollbackError) {
          debugPrint('Rollback Error: $rollbackError');
        }

        rethrow;
      }

      return true;
    } catch (e) {
      debugPrint('Import Error: $e');
      rethrow;
    }
  }
}
