import 'package:hive/hive.dart';

part 'workout_routine.g.dart';

/// A user-created workout routine containing multiple exercises
@HiveType(typeId: 10)
class WorkoutRoutine extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name; // e.g., "Push Day", "Upper Body", "Monday Workout"

  @HiveField(2)
  List<RoutineExercise> exercises; // Ordered list of exercises in this routine

  @HiveField(3)
  String? description;

  @HiveField(4)
  String? colorHex; // For UI display (e.g., "FF6B6B" for red)

  @HiveField(5)
  DateTime createdAt;

  @HiveField(6)
  DateTime? lastUsed;

  @HiveField(7)
  int timesCompleted;

  WorkoutRoutine({
    required this.id,
    required this.name,
    required this.exercises,
    this.description,
    this.colorHex,
    DateTime? createdAt,
    this.lastUsed,
    this.timesCompleted = 0,
  }) : createdAt = createdAt ?? DateTime.now();

  WorkoutRoutine copyWith({
    String? id,
    String? name,
    List<RoutineExercise>? exercises,
    String? description,
    String? colorHex,
    DateTime? createdAt,
    DateTime? lastUsed,
    int? timesCompleted,
  }) {
    return WorkoutRoutine(
      id: id ?? this.id,
      name: name ?? this.name,
      exercises: exercises ?? List.from(this.exercises),
      description: description ?? this.description,
      colorHex: colorHex ?? this.colorHex,
      createdAt: createdAt ?? this.createdAt,
      lastUsed: lastUsed ?? this.lastUsed,
      timesCompleted: timesCompleted ?? this.timesCompleted,
    );
  }
}

/// Reference to a SavedExercise within a routine, with routine-specific overrides
@HiveType(typeId: 11)
class RoutineExercise extends HiveObject {
  @HiveField(0)
  String savedExerciseId; // References SavedExercise.id

  @HiveField(1)
  int order; // Position in the routine

  @HiveField(2)
  int? overrideSets; // Optional override of default sets

  @HiveField(3)
  int? overrideMinReps; // Optional override of default min reps

  @HiveField(4)
  int? overrideMaxReps; // Optional override of default max reps

  @HiveField(5)
  String? notes; // Routine-specific notes for this exercise

  RoutineExercise({
    required this.savedExerciseId,
    required this.order,
    this.overrideSets,
    this.overrideMinReps,
    this.overrideMaxReps,
    this.notes,
  });

  RoutineExercise copyWith({
    String? savedExerciseId,
    int? order,
    int? overrideSets,
    int? overrideMinReps,
    int? overrideMaxReps,
    String? notes,
  }) {
    return RoutineExercise(
      savedExerciseId: savedExerciseId ?? this.savedExerciseId,
      order: order ?? this.order,
      overrideSets: overrideSets ?? this.overrideSets,
      overrideMinReps: overrideMinReps ?? this.overrideMinReps,
      overrideMaxReps: overrideMaxReps ?? this.overrideMaxReps,
      notes: notes ?? this.notes,
    );
  }
}

/// Predefined routine colors
class RoutineColors {
  static const List<String> all = [
    'FF6B6B', // Red
    'FF8E53', // Orange
    'FFD93D', // Yellow
    '6BCB77', // Green
    '4D96FF', // Blue
    '9B59B6', // Purple
    'E91E63', // Pink
    '00BCD4', // Cyan
    '795548', // Brown
    '607D8B', // Grey
  ];
}
