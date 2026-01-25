// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_settings.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserSettingsAdapter extends TypeAdapter<UserSettings> {
  @override
  final int typeId = 6;

  @override
  UserSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserSettings(
      weeklyWorkoutGoal: fields[0] as int,
      dailyCalorieGoal: fields[1] as int,
      dailyProteinGoal: fields[2] as int,
      dailyCarbsGoal: fields[3] as int,
      dailyFatsGoal: fields[4] as int,
      dailyStepGoal: fields[5] as int,
      weightUnit: fields[6] as String,
      useMetric: fields[7] as bool,
      useGoogleFit: fields[8] as bool,
      notificationsEnabled: fields[9] as bool,
      lastGoogleFitSync: fields[10] as DateTime?,
      bestStreak: fields[11] as int,
      currentStreak: fields[12] as int,
      lastWorkoutDate: fields[13] as DateTime?,
      gender: fields[14] as String?,
      userWeight: fields[15] as double?,
      userHeight: fields[16] as double?,
      dailyWaterGoalOz: fields[17] as int,
    );
  }

  @override
  void write(BinaryWriter writer, UserSettings obj) {
    writer
      ..writeByte(18)
      ..writeByte(0)
      ..write(obj.weeklyWorkoutGoal)
      ..writeByte(1)
      ..write(obj.dailyCalorieGoal)
      ..writeByte(2)
      ..write(obj.dailyProteinGoal)
      ..writeByte(3)
      ..write(obj.dailyCarbsGoal)
      ..writeByte(4)
      ..write(obj.dailyFatsGoal)
      ..writeByte(5)
      ..write(obj.dailyStepGoal)
      ..writeByte(6)
      ..write(obj.weightUnit)
      ..writeByte(7)
      ..write(obj.useMetric)
      ..writeByte(8)
      ..write(obj.useGoogleFit)
      ..writeByte(9)
      ..write(obj.notificationsEnabled)
      ..writeByte(10)
      ..write(obj.lastGoogleFitSync)
      ..writeByte(11)
      ..write(obj.bestStreak)
      ..writeByte(12)
      ..write(obj.currentStreak)
      ..writeByte(13)
      ..write(obj.lastWorkoutDate)
      ..writeByte(14)
      ..write(obj.gender)
      ..writeByte(15)
      ..write(obj.userWeight)
      ..writeByte(16)
      ..write(obj.userHeight)
      ..writeByte(17)
      ..write(obj.dailyWaterGoalOz);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
