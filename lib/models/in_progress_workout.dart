import 'dart:convert';

import 'package:uuid/uuid.dart';

import 'workout.dart';

/// One logged set inside an in-progress exercise. `weight`/`reps` are the raw
/// values the user typed (0 means blank).
class InProgressSet {
  final double weight;
  final int reps;

  const InProgressSet({required this.weight, required this.reps});

  /// A set the user never filled in.
  bool get isEmpty => weight <= 0 && reps <= 0;

  Map<String, dynamic> toJson() => {'weight': weight, 'reps': reps};

  factory InProgressSet.fromJson(Map<String, dynamic> j) => InProgressSet(
        weight: (j['weight'] as num?)?.toDouble() ?? 0,
        reps: (j['reps'] as num?)?.toInt() ?? 0,
      );
}

/// One exercise inside an in-progress workout. Stores enough to both restore
/// the live session and reconstruct a completed [Exercise].
class InProgressExercise {
  final String? savedExerciseId;
  final String name;
  final int targetSets;
  final String targetReps;
  final String? youtubeUrl;
  final List<InProgressSet> sets;

  const InProgressExercise({
    required this.savedExerciseId,
    required this.name,
    required this.targetSets,
    required this.targetReps,
    required this.youtubeUrl,
    required this.sets,
  });

  Map<String, dynamic> toJson() => {
        'savedExerciseId': savedExerciseId,
        'name': name,
        'targetSets': targetSets,
        'targetReps': targetReps,
        'youtubeUrl': youtubeUrl,
        'sets': sets.map((s) => s.toJson()).toList(),
      };

  factory InProgressExercise.fromJson(Map<String, dynamic> j) =>
      InProgressExercise(
        savedExerciseId: j['savedExerciseId'] as String?,
        name: j['name'] as String? ?? 'Exercise',
        targetSets: (j['targetSets'] as num?)?.toInt() ?? 3,
        targetReps: j['targetReps'] as String? ?? '8-12',
        youtubeUrl: j['youtubeUrl'] as String?,
        sets: ((j['sets'] as List?) ?? [])
            .map((e) => InProgressSet.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

/// A snapshot of an in-progress workout session, serializable to JSON for
/// persistence in the app-data box. Pure Dart - no Hive, no Flutter.
class InProgressWorkout {
  static const int currentVersion = 1;

  final String routineId;
  final String routineName;
  final DateTime startTime;
  final DateTime lastSaved;
  final int currentExerciseIndex;
  final List<InProgressExercise> exercises;

  const InProgressWorkout({
    required this.routineId,
    required this.routineName,
    required this.startTime,
    required this.lastSaved,
    required this.currentExerciseIndex,
    required this.exercises,
  });

  /// Number of exercises that have at least one filled-in set.
  int get loggedExerciseCount =>
      exercises.where((e) => e.sets.any((s) => !s.isEmpty)).length;

  Map<String, dynamic> toJson() => {
        'version': currentVersion,
        'routineId': routineId,
        'routineName': routineName,
        'startTime': startTime.toIso8601String(),
        'lastSaved': lastSaved.toIso8601String(),
        'currentExerciseIndex': currentExerciseIndex,
        'exercises': exercises.map((e) => e.toJson()).toList(),
      };

  String toJsonString() => jsonEncode(toJson());

  /// Parses a stored JSON string. Returns null on any malformed input or a
  /// version mismatch, so a bad record can never wedge the app.
  static InProgressWorkout? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = Map<String, dynamic>.from(jsonDecode(raw));
      if ((map['version'] as num?)?.toInt() != currentVersion) return null;
      final routineId = map['routineId'] as String?;
      final startTime = DateTime.tryParse(map['startTime'] as String? ?? '');
      if (routineId == null || startTime == null) return null;
      return InProgressWorkout(
        routineId: routineId,
        routineName: map['routineName'] as String? ?? 'Workout',
        startTime: startTime,
        lastSaved: DateTime.tryParse(map['lastSaved'] as String? ?? '') ??
            startTime,
        currentExerciseIndex:
            (map['currentExerciseIndex'] as num?)?.toInt() ?? 0,
        exercises: ((map['exercises'] as List?) ?? [])
            .map((e) => InProgressExercise.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Reconstructs completed [Exercise]s, dropping empty sets and any exercise
  /// left with no real sets. Set numbers are renumbered from 1.
  List<Exercise> toExercises() {
    final result = <Exercise>[];
    for (final ex in exercises) {
      final sets = <ExerciseSet>[];
      var n = 1;
      for (final s in ex.sets) {
        if (!s.isEmpty) {
          sets.add(ExerciseSet(setNumber: n++, weight: s.weight, reps: s.reps));
        }
      }
      if (sets.isNotEmpty) {
        result.add(Exercise(
          id: const Uuid().v4(),
          name: ex.name,
          targetSets: ex.targetSets,
          targetReps: ex.targetReps,
          completedSets: sets,
          youtubeUrl: ex.youtubeUrl,
          isCompleted: true,
          savedExerciseId: ex.savedExerciseId,
        ));
      }
    }
    return result;
  }
}
