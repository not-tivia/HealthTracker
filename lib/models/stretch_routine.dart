import 'package:hive/hive.dart';

part 'stretch_routine.g.dart';

@HiveType(typeId: 19) // Changed from 16
class StretchRoutine extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name; // e.g., "Full Body Warmup"

  @HiveField(2)
  List<RoutineStretch> stretches; // Ordered list

  @HiveField(3)
  String? description;

  @HiveField(4)
  String? colorHex; // For UI

  @HiveField(5)
  DateTime createdAt;

  @HiveField(6)
  DateTime? lastUsed;

  @HiveField(7)
  int timesCompleted;

  StretchRoutine({
    required this.id,
    required this.name,
    required this.stretches,
    this.description,
    this.colorHex,
    DateTime? createdAt,
    this.lastUsed,
    this.timesCompleted = 0,
  }) : createdAt = createdAt ?? DateTime.now();

  StretchRoutine copyWith({
    String? id,
    String? name,
    List<RoutineStretch>? stretches,
    String? description,
    String? colorHex,
    DateTime? createdAt,
    DateTime? lastUsed,
    int? timesCompleted,
  }) {
    return StretchRoutine(
      id: id ?? this.id,
      name: name ?? this.name,
      stretches: stretches ?? List.from(this.stretches),
      description: description ?? this.description,
      colorHex: colorHex ?? this.colorHex,
      createdAt: createdAt ?? this.createdAt,
      lastUsed: lastUsed ?? this.lastUsed,
      timesCompleted: timesCompleted ?? this.timesCompleted,
    );
  }
}

@HiveType(typeId: 20) // Changed from 17
class RoutineStretch extends HiveObject {
  @HiveField(0)
  String savedStretchId; // References SavedStretch.id

  @HiveField(1)
  int order; // Position in routine

  @HiveField(2)
  int? overrideDuration; // Optional override

  @HiveField(3)
  String? notes; // Routine-specific

  RoutineStretch({
    required this.savedStretchId,
    required this.order,
    this.overrideDuration,
    this.notes,
  });

  RoutineStretch copyWith({
    String? savedStretchId,
    int? order,
    int? overrideDuration,
    String? notes,
  }) {
    return RoutineStretch(
      savedStretchId: savedStretchId ?? this.savedStretchId,
      order: order ?? this.order,
      overrideDuration: overrideDuration ?? this.overrideDuration,
      notes: notes ?? this.notes,
    );
  }
}

// Reuse RoutineColors from workout_routine.dart
