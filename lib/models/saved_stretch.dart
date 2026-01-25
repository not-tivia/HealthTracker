import 'package:hive/hive.dart';

part 'saved_stretch.g.dart';

@HiveType(typeId: 18) // Changed from 15 to avoid conflict with FoodLibraryItem
class SavedStretch extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String? photoPath; // Local photo path

  @HiveField(3)
  String? youtubeUrl; // YouTube tutorial link

  @HiveField(4)
  int defaultDuration; // In seconds (e.g., 30 for a 30-second hold)

  @HiveField(5)
  String? notes;

  @HiveField(6)
  String? muscleGroup; // e.g., "Chest", "Legs"

  @HiveField(7)
  DateTime createdAt;

  @HiveField(8)
  int timesUsed; // Track popularity

  SavedStretch({
    required this.id,
    required this.name,
    this.photoPath,
    this.youtubeUrl,
    this.defaultDuration = 30,
    this.notes,
    this.muscleGroup,
    DateTime? createdAt,
    this.timesUsed = 0,
  }) : createdAt = createdAt ?? DateTime.now();

  String get durationDisplay => '${defaultDuration}s';

  SavedStretch copyWith({
    String? id,
    String? name,
    String? photoPath,
    String? youtubeUrl,
    int? defaultDuration,
    String? notes,
    String? muscleGroup,
    DateTime? createdAt,
    int? timesUsed,
  }) {
    return SavedStretch(
      id: id ?? this.id,
      name: name ?? this.name,
      photoPath: photoPath ?? this.photoPath,
      youtubeUrl: youtubeUrl ?? this.youtubeUrl,
      defaultDuration: defaultDuration ?? this.defaultDuration,
      notes: notes ?? this.notes,
      muscleGroup: muscleGroup ?? this.muscleGroup,
      createdAt: createdAt ?? this.createdAt,
      timesUsed: timesUsed ?? this.timesUsed,
    );
  }
}

// Reuse MuscleGroups from saved_exercise.dart
