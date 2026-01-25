// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout_history.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WorkoutHistoryAdapter extends TypeAdapter<WorkoutHistory> {
  @override
  final int typeId = 7;

  @override
  WorkoutHistory read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WorkoutHistory(
      id: fields[0] as String,
      workoutType: fields[1] as String,
      date: fields[2] as DateTime,
      durationMinutes: fields[3] as int,
      exercises: (fields[4] as List).cast<ExerciseHistory>(),
      notes: fields[5] as String?,
      exerciseData: (fields[6] as List?)?.cast<ExerciseHistory>(),
    );
  }

  @override
  void write(BinaryWriter writer, WorkoutHistory obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.workoutType)
      ..writeByte(2)
      ..write(obj.date)
      ..writeByte(3)
      ..write(obj.durationMinutes)
      ..writeByte(4)
      ..write(obj.exercises)
      ..writeByte(5)
      ..write(obj.notes)
      ..writeByte(6)
      ..write(obj.exerciseData);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkoutHistoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ExerciseHistoryAdapter extends TypeAdapter<ExerciseHistory> {
  @override
  final int typeId = 8;

  @override
  ExerciseHistory read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ExerciseHistory(
      exerciseName: fields[0] as String,
      reps: (fields[1] as List).cast<int>(),
      weights: (fields[2] as List).cast<double>(),
      completedAllSets: fields[3] as bool,
      metRepGoal: fields[4] as bool,
      sessionCount: fields[5] as int,
      lastWeight: fields[6] as double,
      lastReps: fields[7] as int,
      consecutiveGoalsMet: fields[8] as int,
    );
  }

  @override
  void write(BinaryWriter writer, ExerciseHistory obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.exerciseName)
      ..writeByte(1)
      ..write(obj.reps)
      ..writeByte(2)
      ..write(obj.weights)
      ..writeByte(3)
      ..write(obj.completedAllSets)
      ..writeByte(4)
      ..write(obj.metRepGoal)
      ..writeByte(5)
      ..write(obj.sessionCount)
      ..writeByte(6)
      ..write(obj.lastWeight)
      ..writeByte(7)
      ..write(obj.lastReps)
      ..writeByte(8)
      ..write(obj.consecutiveGoalsMet);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExerciseHistoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
