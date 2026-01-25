// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'saved_stretch.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SavedStretchAdapter extends TypeAdapter<SavedStretch> {
  @override
  final int typeId = 18;

  @override
  SavedStretch read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SavedStretch(
      id: fields[0] as String,
      name: fields[1] as String,
      photoPath: fields[2] as String?,
      youtubeUrl: fields[3] as String?,
      defaultDuration: fields[4] as int,
      notes: fields[5] as String?,
      muscleGroup: fields[6] as String?,
      createdAt: fields[7] as DateTime?,
      timesUsed: fields[8] as int,
    );
  }

  @override
  void write(BinaryWriter writer, SavedStretch obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.photoPath)
      ..writeByte(3)
      ..write(obj.youtubeUrl)
      ..writeByte(4)
      ..write(obj.defaultDuration)
      ..writeByte(5)
      ..write(obj.notes)
      ..writeByte(6)
      ..write(obj.muscleGroup)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.timesUsed);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SavedStretchAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
