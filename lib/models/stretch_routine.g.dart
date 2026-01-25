// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stretch_routine.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class StretchRoutineAdapter extends TypeAdapter<StretchRoutine> {
  @override
  final int typeId = 19;

  @override
  StretchRoutine read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return StretchRoutine(
      id: fields[0] as String,
      name: fields[1] as String,
      stretches: (fields[2] as List).cast<RoutineStretch>(),
      description: fields[3] as String?,
      colorHex: fields[4] as String?,
      createdAt: fields[5] as DateTime?,
      lastUsed: fields[6] as DateTime?,
      timesCompleted: fields[7] as int,
    );
  }

  @override
  void write(BinaryWriter writer, StretchRoutine obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.stretches)
      ..writeByte(3)
      ..write(obj.description)
      ..writeByte(4)
      ..write(obj.colorHex)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.lastUsed)
      ..writeByte(7)
      ..write(obj.timesCompleted);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StretchRoutineAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class RoutineStretchAdapter extends TypeAdapter<RoutineStretch> {
  @override
  final int typeId = 20;

  @override
  RoutineStretch read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RoutineStretch(
      savedStretchId: fields[0] as String,
      order: fields[1] as int,
      overrideDuration: fields[2] as int?,
      notes: fields[3] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, RoutineStretch obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.savedStretchId)
      ..writeByte(1)
      ..write(obj.order)
      ..writeByte(2)
      ..write(obj.overrideDuration)
      ..writeByte(3)
      ..write(obj.notes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoutineStretchAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
