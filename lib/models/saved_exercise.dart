import 'package:hive/hive.dart';

part 'saved_exercise.g.dart';

/// A user-created exercise that can be reused across workouts
@HiveType(typeId: 9)
class SavedExercise extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String? photoPath; // Local photo path

  @HiveField(3)
  String? youtubeUrl; // YouTube tutorial link

  @HiveField(4)
  int defaultSets;

  @HiveField(5)
  int defaultMinReps;

  @HiveField(6)
  int defaultMaxReps;

  @HiveField(7)
  double lastWeight; // Track last used weight for progressive overload

  @HiveField(8)
  String? notes;

  @HiveField(9)
  String? muscleGroup; // e.g., "Chest", "Back", "Legs", etc.

  @HiveField(10)
  DateTime createdAt;

  @HiveField(11)
  int timesUsed; // Track popularity

  SavedExercise({
    required this.id,
    required this.name,
    this.photoPath,
    this.youtubeUrl,
    this.defaultSets = 3,
    this.defaultMinReps = 8,
    this.defaultMaxReps = 12,
    this.lastWeight = 0,
    this.notes,
    this.muscleGroup,
    DateTime? createdAt,
    this.timesUsed = 0,
  }) : createdAt = createdAt ?? DateTime.now();

  String get repsDisplay => '$defaultMinReps-$defaultMaxReps';

  SavedExercise copyWith({
    String? id,
    String? name,
    String? photoPath,
    String? youtubeUrl,
    int? defaultSets,
    int? defaultMinReps,
    int? defaultMaxReps,
    double? lastWeight,
    String? notes,
    String? muscleGroup,
    DateTime? createdAt,
    int? timesUsed,
  }) {
    return SavedExercise(
      id: id ?? this.id,
      name: name ?? this.name,
      photoPath: photoPath ?? this.photoPath,
      youtubeUrl: youtubeUrl ?? this.youtubeUrl,
      defaultSets: defaultSets ?? this.defaultSets,
      defaultMinReps: defaultMinReps ?? this.defaultMinReps,
      defaultMaxReps: defaultMaxReps ?? this.defaultMaxReps,
      lastWeight: lastWeight ?? this.lastWeight,
      notes: notes ?? this.notes,
      muscleGroup: muscleGroup ?? this.muscleGroup,
      createdAt: createdAt ?? this.createdAt,
      timesUsed: timesUsed ?? this.timesUsed,
    );
  }
}

/// Muscle group options
class MuscleGroups {
  static const List<String> all = [
    'Chest',
    'Back',
    'Shoulders',
    'Biceps',
    'Triceps',
    'Legs',
    'Core',
    'Glutes',
    'Calves',
    'Forearms',
    'Full Body',
    'Cardio',
    'Other',
  ];
}
