import 'package:hive/hive.dart';

part 'workout.g.dart';

/// Represents a completed or in-progress workout session
@HiveType(typeId: 0)
class Workout extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String type; // Routine name or custom type

  @HiveField(3)
  DateTime date;

  @HiveField(4)
  List<Exercise> exercises;

  @HiveField(5)
  bool isCompleted;

  @HiveField(6)
  int durationMinutes; // Store duration as int, not Duration

  @HiveField(7)
  String? routineId; // Reference to WorkoutRoutine if from a saved routine

  @HiveField(8)
  String? notes;

  Workout({
    required this.id,
    required this.name,
    required this.type,
    required this.date,
    required this.exercises,
    this.isCompleted = false,
    this.durationMinutes = 0,
    this.routineId,
    this.notes,
  });

  /// Convenience getter to get Duration object
  Duration get duration => Duration(minutes: durationMinutes);

  Workout copyWith({
    String? id,
    String? name,
    String? type,
    DateTime? date,
    List<Exercise>? exercises,
    bool? isCompleted,
    int? durationMinutes,
    String? routineId,
    String? notes,
  }) {
    return Workout(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      date: date ?? this.date,
      exercises: exercises ?? this.exercises,
      isCompleted: isCompleted ?? this.isCompleted,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      routineId: routineId ?? this.routineId,
      notes: notes ?? this.notes,
    );
  }
}

/// One exercise inside a workout
@HiveType(typeId: 1)
class Exercise extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  int targetSets;

  @HiveField(3)
  String targetReps; // e.g., "8-12"

  @HiveField(4)
  List<ExerciseSet> completedSets;

  @HiveField(5)
  String? photoPath; // Local photo or from SavedExercise

  @HiveField(6)
  String? youtubeUrl;

  @HiveField(7)
  String? notes;

  @HiveField(8)
  bool isCompleted;

  @HiveField(9)
  String? savedExerciseId; // Reference to SavedExercise if applicable

  /// Alias for completedSets
  List<ExerciseSet> get sets => completedSets;

  /// Computed min reps from targetReps string
  int get minReps {
    final parts = targetReps.split('-');
    if (parts.isEmpty) return 8;
    final cleaned = parts.first.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(cleaned) ?? 8;
  }

  /// Computed max reps from targetReps string
  int get maxReps {
    final parts = targetReps.split('-');
    if (parts.length < 2) return minReps;
    final cleaned = parts.last.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(cleaned) ?? 12;
  }

  Exercise({
    required this.id,
    required this.name,
    required this.targetSets,
    required this.targetReps,
    List<ExerciseSet>? completedSets,
    this.photoPath,
    this.youtubeUrl,
    this.notes,
    this.isCompleted = false,
    this.savedExerciseId,
  }) : completedSets = completedSets ?? [];

  Exercise copyWith({
    String? id,
    String? name,
    int? targetSets,
    String? targetReps,
    List<ExerciseSet>? completedSets,
    String? photoPath,
    String? youtubeUrl,
    String? notes,
    bool? isCompleted,
    String? savedExerciseId,
  }) {
    return Exercise(
      id: id ?? this.id,
      name: name ?? this.name,
      targetSets: targetSets ?? this.targetSets,
      targetReps: targetReps ?? this.targetReps,
      completedSets: completedSets ?? List.from(this.completedSets),
      photoPath: photoPath ?? this.photoPath,
      youtubeUrl: youtubeUrl ?? this.youtubeUrl,
      notes: notes ?? this.notes,
      isCompleted: isCompleted ?? this.isCompleted,
      savedExerciseId: savedExerciseId ?? this.savedExerciseId,
    );
  }
}

/// One set of an exercise (reps + weight)
@HiveType(typeId: 2)
class ExerciseSet extends HiveObject {
  @HiveField(0)
  int setNumber;

  @HiveField(1)
  int reps;

  @HiveField(2)
  double weight;

  @HiveField(3)
  bool isCompleted;

  ExerciseSet({
    required this.setNumber,
    required this.reps,
    required this.weight,
    this.isCompleted = false,
  });

  ExerciseSet copyWith({
    int? setNumber,
    int? reps,
    double? weight,
    bool? isCompleted,
  }) {
    return ExerciseSet(
      setNumber: setNumber ?? this.setNumber,
      reps: reps ?? this.reps,
      weight: weight ?? this.weight,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}
