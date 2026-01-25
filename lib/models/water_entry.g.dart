// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'water_entry.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WaterEntryAdapter extends TypeAdapter<WaterEntry> {
  @override
  final int typeId = 14;

  @override
  WaterEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WaterEntry(
      id: fields[0] as String,
      date: fields[1] as DateTime,
      amountOz: fields[2] as int,
      timestamp: fields[3] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, WaterEntry obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.amountOz)
      ..writeByte(3)
      ..write(obj.timestamp);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WaterEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
