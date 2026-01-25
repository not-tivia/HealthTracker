import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/saved_exercise.dart';
import '../models/workout_routine.dart';
import '../models/saved_stretch.dart';
import '../models/stretch_routine.dart';
import 'storage_service.dart';

/// Result of parsing an import file
class ImportPreview {
  final String type; // 'workout_routine' or 'stretch_routine'
  final String routineName;
  final String? description;
  final String? colorHex;
  final List<ImportedExercise> exercises; // For workout routines
  final List<ImportedStretch> stretches; // For stretch routines
  final String? error;

  ImportPreview({
    required this.type,
    required this.routineName,
    this.description,
    this.colorHex,
    this.exercises = const [],
    this.stretches = const [],
    this.error,
  });

  bool get isWorkoutRoutine => type == 'workout_routine';
  bool get isStretchRoutine => type == 'stretch_routine';
  bool get hasError => error != null;
  
  int get newExerciseCount => exercises.where((e) => !e.existsLocally).length;
  int get existingExerciseCount => exercises.where((e) => e.existsLocally).length;
  int get newStretchCount => stretches.where((s) => !s.existsLocally).length;
  int get existingStretchCount => stretches.where((s) => s.existsLocally).length;
}

class ImportedExercise {
  final String name;
  final String? muscleGroup;
  final int defaultSets;
  final int defaultMinReps;
  final int defaultMaxReps;
  final String? youtubeUrl;
  final String? notes;
  final int? overrideSets;
  final int? overrideMinReps;
  final int? overrideMaxReps;
  final String? routineNotes;
  bool existsLocally;
  String? localExerciseId;

  ImportedExercise({
    required this.name,
    this.muscleGroup,
    this.defaultSets = 3,
    this.defaultMinReps = 8,
    this.defaultMaxReps = 12,
    this.youtubeUrl,
    this.notes,
    this.overrideSets,
    this.overrideMinReps,
    this.overrideMaxReps,
    this.routineNotes,
    this.existsLocally = false,
    this.localExerciseId,
  });
}

class ImportedStretch {
  final String name;
  final String? muscleGroup;
  final int defaultDuration;
  final String? youtubeUrl;
  final String? notes;
  final int? overrideDuration;
  final String? routineNotes;
  bool existsLocally;
  String? localStretchId;

  ImportedStretch({
    required this.name,
    this.muscleGroup,
    this.defaultDuration = 30,
    this.youtubeUrl,
    this.notes,
    this.overrideDuration,
    this.routineNotes,
    this.existsLocally = false,
    this.localStretchId,
  });
}

class RoutineImportExportService {
  static const String _currentVersion = '1.0';
  static const _uuid = Uuid();

  // ============ EXPORT METHODS ============

  /// Export a workout routine to JSON string
  static String exportWorkoutRoutine(
    WorkoutRoutine routine,
    List<SavedExercise> allExercises,
  ) {
    final exerciseMap = {for (var e in allExercises) e.id: e};
    
    final exportedExercises = routine.exercises.map((routineExercise) {
      final exercise = exerciseMap[routineExercise.savedExerciseId];
      if (exercise == null) return null;
      
      return {
        'name': exercise.name,
        'muscleGroup': exercise.muscleGroup,
        'defaultSets': exercise.defaultSets,
        'defaultMinReps': exercise.defaultMinReps,
        'defaultMaxReps': exercise.defaultMaxReps,
        'youtubeUrl': exercise.youtubeUrl,
        'notes': exercise.notes,
        'overrideSets': routineExercise.overrideSets,
        'overrideMinReps': routineExercise.overrideMinReps,
        'overrideMaxReps': routineExercise.overrideMaxReps,
        'routineNotes': routineExercise.notes,
      };
    }).whereType<Map<String, dynamic>>().toList();

    final exportData = {
      'type': 'workout_routine',
      'version': _currentVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'routine': {
        'name': routine.name,
        'description': routine.description,
        'colorHex': routine.colorHex,
        'exercises': exportedExercises,
      },
    };

    return const JsonEncoder.withIndent('  ').convert(exportData);
  }

  /// Export a stretch routine to JSON string
  static String exportStretchRoutine(
    StretchRoutine routine,
    List<SavedStretch> allStretches,
  ) {
    final stretchMap = {for (var s in allStretches) s.id: s};
    
    final exportedStretches = routine.stretches.map((routineStretch) {
      final stretch = stretchMap[routineStretch.savedStretchId];
      if (stretch == null) return null;
      
      return {
        'name': stretch.name,
        'muscleGroup': stretch.muscleGroup,
        'defaultDuration': stretch.defaultDuration,
        'youtubeUrl': stretch.youtubeUrl,
        'notes': stretch.notes,
        'overrideDuration': routineStretch.overrideDuration,
        'routineNotes': routineStretch.notes,
      };
    }).whereType<Map<String, dynamic>>().toList();

    final exportData = {
      'type': 'stretch_routine',
      'version': _currentVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'routine': {
        'name': routine.name,
        'description': routine.description,
        'colorHex': routine.colorHex,
        'stretches': exportedStretches,
      },
    };

    return const JsonEncoder.withIndent('  ').convert(exportData);
  }

  // ============ IMPORT METHODS ============

  /// Parse JSON and return a preview of what will be imported
  static ImportPreview parseImportJson(
    String jsonString,
    List<SavedExercise> existingExercises,
    List<SavedStretch> existingStretches,
  ) {
    try {
      final data = json.decode(jsonString) as Map<String, dynamic>;
      
      // Validate required fields
      if (!data.containsKey('type')) {
        return ImportPreview(
          type: 'unknown',
          routineName: '',
          error: 'Invalid file: missing "type" field',
        );
      }
      
      final type = data['type'] as String;
      final routine = data['routine'] as Map<String, dynamic>?;
      
      if (routine == null) {
        return ImportPreview(
          type: type,
          routineName: '',
          error: 'Invalid file: missing "routine" data',
        );
      }

      final routineName = routine['name'] as String? ?? 'Unnamed Routine';
      final description = routine['description'] as String?;
      final colorHex = routine['colorHex'] as String?;

      if (type == 'workout_routine') {
        final exercisesList = routine['exercises'] as List<dynamic>? ?? [];
        final exercises = exercisesList.map((e) {
          final exerciseData = e as Map<String, dynamic>;
          final name = exerciseData['name'] as String? ?? 'Unknown Exercise';
          
          // Check if exercise already exists locally (case-insensitive)
          final existingExercise = existingExercises.firstWhere(
            (ex) => ex.name.toLowerCase() == name.toLowerCase(),
            orElse: () => SavedExercise(id: '', name: ''),
          );
          final exists = existingExercise.id.isNotEmpty;

          return ImportedExercise(
            name: name,
            muscleGroup: exerciseData['muscleGroup'] as String?,
            defaultSets: exerciseData['defaultSets'] as int? ?? 3,
            defaultMinReps: exerciseData['defaultMinReps'] as int? ?? 8,
            defaultMaxReps: exerciseData['defaultMaxReps'] as int? ?? 12,
            youtubeUrl: exerciseData['youtubeUrl'] as String?,
            notes: exerciseData['notes'] as String?,
            overrideSets: exerciseData['overrideSets'] as int?,
            overrideMinReps: exerciseData['overrideMinReps'] as int?,
            overrideMaxReps: exerciseData['overrideMaxReps'] as int?,
            routineNotes: exerciseData['routineNotes'] as String?,
            existsLocally: exists,
            localExerciseId: exists ? existingExercise.id : null,
          );
        }).toList();

        return ImportPreview(
          type: type,
          routineName: routineName,
          description: description,
          colorHex: colorHex,
          exercises: exercises,
        );
      } else if (type == 'stretch_routine') {
        final stretchesList = routine['stretches'] as List<dynamic>? ?? [];
        final stretches = stretchesList.map((s) {
          final stretchData = s as Map<String, dynamic>;
          final name = stretchData['name'] as String? ?? 'Unknown Stretch';
          
          // Check if stretch already exists locally (case-insensitive)
          final existingStretch = existingStretches.firstWhere(
            (st) => st.name.toLowerCase() == name.toLowerCase(),
            orElse: () => SavedStretch(id: '', name: ''),
          );
          final exists = existingStretch.id.isNotEmpty;

          return ImportedStretch(
            name: name,
            muscleGroup: stretchData['muscleGroup'] as String?,
            defaultDuration: stretchData['defaultDuration'] as int? ?? 30,
            youtubeUrl: stretchData['youtubeUrl'] as String?,
            notes: stretchData['notes'] as String?,
            overrideDuration: stretchData['overrideDuration'] as int?,
            routineNotes: stretchData['routineNotes'] as String?,
            existsLocally: exists,
            localStretchId: exists ? existingStretch.id : null,
          );
        }).toList();

        return ImportPreview(
          type: type,
          routineName: routineName,
          description: description,
          colorHex: colorHex,
          stretches: stretches,
        );
      } else {
        return ImportPreview(
          type: type,
          routineName: routineName,
          error: 'Unknown routine type: $type',
        );
      }
    } catch (e) {
      return ImportPreview(
        type: 'unknown',
        routineName: '',
        error: 'Failed to parse JSON: ${e.toString()}',
      );
    }
  }

  /// Execute the import - create new exercises/stretches and the routine
  static Future<String?> executeImport(
    ImportPreview preview,
    String finalRoutineName,
    StorageService storage,
  ) async {
    try {
      if (preview.isWorkoutRoutine) {
        return await _importWorkoutRoutine(preview, finalRoutineName, storage);
      } else if (preview.isStretchRoutine) {
        return await _importStretchRoutine(preview, finalRoutineName, storage);
      }
      return 'Unknown routine type';
    } catch (e) {
      return 'Import failed: ${e.toString()}';
    }
  }

  static Future<String?> _importWorkoutRoutine(
    ImportPreview preview,
    String finalRoutineName,
    StorageService storage,
  ) async {
    final routineExercises = <RoutineExercise>[];
    int order = 0;

    for (final importedExercise in preview.exercises) {
      String exerciseId;

      if (importedExercise.existsLocally && importedExercise.localExerciseId != null) {
        // Use existing exercise
        exerciseId = importedExercise.localExerciseId!;
      } else {
        // Create new exercise
        exerciseId = _uuid.v4();
        final newExercise = SavedExercise(
          id: exerciseId,
          name: importedExercise.name,
          muscleGroup: importedExercise.muscleGroup,
          defaultSets: importedExercise.defaultSets,
          defaultMinReps: importedExercise.defaultMinReps,
          defaultMaxReps: importedExercise.defaultMaxReps,
          youtubeUrl: importedExercise.youtubeUrl,
          notes: importedExercise.notes,
        );
        await storage.saveSavedExercise(newExercise);
      }

      routineExercises.add(RoutineExercise(
        savedExerciseId: exerciseId,
        order: order++,
        overrideSets: importedExercise.overrideSets,
        overrideMinReps: importedExercise.overrideMinReps,
        overrideMaxReps: importedExercise.overrideMaxReps,
        notes: importedExercise.routineNotes,
      ));
    }

    // Create the routine
    final newRoutine = WorkoutRoutine(
      id: _uuid.v4(),
      name: finalRoutineName,
      description: preview.description,
      colorHex: preview.colorHex,
      exercises: routineExercises,
    );

    await storage.saveWorkoutRoutine(newRoutine);
    return null; // Success
  }

  static Future<String?> _importStretchRoutine(
    ImportPreview preview,
    String finalRoutineName,
    StorageService storage,
  ) async {
    final routineStretches = <RoutineStretch>[];
    int order = 0;

    for (final importedStretch in preview.stretches) {
      String stretchId;

      if (importedStretch.existsLocally && importedStretch.localStretchId != null) {
        // Use existing stretch
        stretchId = importedStretch.localStretchId!;
      } else {
        // Create new stretch
        stretchId = _uuid.v4();
        final newStretch = SavedStretch(
          id: stretchId,
          name: importedStretch.name,
          muscleGroup: importedStretch.muscleGroup,
          defaultDuration: importedStretch.defaultDuration,
          youtubeUrl: importedStretch.youtubeUrl,
          notes: importedStretch.notes,
        );
        await storage.saveSavedStretch(newStretch);
      }

      routineStretches.add(RoutineStretch(
        savedStretchId: stretchId,
        order: order++,
        overrideDuration: importedStretch.overrideDuration,
        notes: importedStretch.routineNotes,
      ));
    }

    // Create the routine
    final newRoutine = StretchRoutine(
      id: _uuid.v4(),
      name: finalRoutineName,
      description: preview.description,
      colorHex: preview.colorHex,
      stretches: routineStretches,
    );

    await storage.saveStretchRoutine(newRoutine);
    return null; // Success
  }

  // ============ FILE OPERATIONS ============

  /// Pick a JSON file and return its contents
  static Future<String?> pickJsonFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        return await file.readAsString();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Save JSON to Downloads folder
  static Future<String?> saveToDownloads(String jsonString, String routineName) async {
    try {
      final directory = await getExternalStorageDirectory();
      if (directory == null) {
        // Fallback to app documents directory
        final appDir = await getApplicationDocumentsDirectory();
        final sanitizedName = _sanitizeFileName(routineName);
        final date = DateTime.now().toIso8601String().split('T')[0];
        final fileName = '${sanitizedName}_$date.json';
        final file = File('${appDir.path}/$fileName');
        await file.writeAsString(jsonString);
        return file.path;
      }

      // Try to save to Downloads
      final downloadsPath = directory.path.replaceAll(RegExp(r'/Android/data/[^/]+/files'), '/Download');
      final downloadsDir = Directory(downloadsPath);
      
      String savePath;
      if (await downloadsDir.exists()) {
        savePath = downloadsPath;
      } else {
        savePath = directory.path;
      }

      final sanitizedName = _sanitizeFileName(routineName);
      final date = DateTime.now().toIso8601String().split('T')[0];
      final fileName = '${sanitizedName}_$date.json';
      final file = File('$savePath/$fileName');
      await file.writeAsString(jsonString);
      return file.path;
    } catch (e) {
      return null;
    }
  }

  /// Share JSON via system share sheet
  static Future<void> shareJson(String jsonString, String routineName) async {
    try {
      // Create a temporary file to share
      final tempDir = await getTemporaryDirectory();
      final sanitizedName = _sanitizeFileName(routineName);
      final date = DateTime.now().toIso8601String().split('T')[0];
      final fileName = '${sanitizedName}_$date.json';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(jsonString);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Health Tracker Routine: $routineName',
      );
    } catch (e) {
      // Fallback to sharing text directly
      await Share.share(jsonString, subject: 'Health Tracker Routine: $routineName');
    }
  }

  /// Copy JSON to clipboard
  static Future<void> copyToClipboard(String jsonString) async {
    await Clipboard.setData(ClipboardData(text: jsonString));
  }

  /// Sanitize routine name for use as filename
  static String _sanitizeFileName(String name) {
    return name
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .toLowerCase();
  }
}
