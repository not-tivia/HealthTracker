// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cardio_workout.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CardioWorkoutAdapter extends TypeAdapter<CardioWorkout> {
  @override
  final int typeId = 13;

  @override
  CardioWorkout read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CardioWorkout(
      id: fields[0] as String,
      type: fields[1] as CardioType,
      date: fields[2] as DateTime,
      durationMinutes: fields[3] as int,
      distanceMiles: fields[4] as double?,
      caloriesBurned: fields[5] as int?,
      avgHeartRate: fields[6] as int?,
      maxHeartRate: fields[7] as int?,
      notes: fields[8] as String?,
      perceivedExertion: fields[9] as int?,
      avgPace: fields[10] as double?,
    );
  }

  @override
  void write(BinaryWriter writer, CardioWorkout obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.type)
      ..writeByte(2)
      ..write(obj.date)
      ..writeByte(3)
      ..write(obj.durationMinutes)
      ..writeByte(4)
      ..write(obj.distanceMiles)
      ..writeByte(5)
      ..write(obj.caloriesBurned)
      ..writeByte(6)
      ..write(obj.avgHeartRate)
      ..writeByte(7)
      ..write(obj.maxHeartRate)
      ..writeByte(8)
      ..write(obj.notes)
      ..writeByte(9)
      ..write(obj.perceivedExertion)
      ..writeByte(10)
      ..write(obj.avgPace);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CardioWorkoutAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CardioTypeAdapter extends TypeAdapter<CardioType> {
  @override
  final int typeId = 12;

  @override
  CardioType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return CardioType.running;
      case 1:
        return CardioType.walking;
      case 2:
        return CardioType.cycling;
      case 3:
        return CardioType.swimming;
      case 4:
        return CardioType.rowing;
      case 5:
        return CardioType.elliptical;
      case 6:
        return CardioType.stairClimber;
      case 7:
        return CardioType.jumpRope;
      case 8:
        return CardioType.hiit;
      case 9:
        return CardioType.other;
      default:
        return CardioType.running;
    }
  }

  @override
  void write(BinaryWriter writer, CardioType obj) {
    switch (obj) {
      case CardioType.running:
        writer.writeByte(0);
        break;
      case CardioType.walking:
        writer.writeByte(1);
        break;
      case CardioType.cycling:
        writer.writeByte(2);
        break;
      case CardioType.swimming:
        writer.writeByte(3);
        break;
      case CardioType.rowing:
        writer.writeByte(4);
        break;
      case CardioType.elliptical:
        writer.writeByte(5);
        break;
      case CardioType.stairClimber:
        writer.writeByte(6);
        break;
      case CardioType.jumpRope:
        writer.writeByte(7);
        break;
      case CardioType.hiit:
        writer.writeByte(8);
        break;
      case CardioType.other:
        writer.writeByte(9);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CardioTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
