// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'food_library_item.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FoodLibraryItemAdapter extends TypeAdapter<FoodLibraryItem> {
  @override
  final int typeId = 15;

  @override
  FoodLibraryItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FoodLibraryItem(
      id: fields[0] as String,
      name: fields[1] as String,
      calories: fields[2] as double,
      protein: fields[3] as double,
      carbs: fields[4] as double,
      fats: fields[5] as double,
      servingSize: fields[6] as double,
      servingUnit: fields[7] as String,
      createdAt: fields[8] as DateTime?,
      lastUsed: fields[9] as DateTime?,
      useCount: fields[10] as int,
    );
  }

  @override
  void write(BinaryWriter writer, FoodLibraryItem obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.calories)
      ..writeByte(3)
      ..write(obj.protein)
      ..writeByte(4)
      ..write(obj.carbs)
      ..writeByte(5)
      ..write(obj.fats)
      ..writeByte(6)
      ..write(obj.servingSize)
      ..writeByte(7)
      ..write(obj.servingUnit)
      ..writeByte(8)
      ..write(obj.createdAt)
      ..writeByte(9)
      ..write(obj.lastUsed)
      ..writeByte(10)
      ..write(obj.useCount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FoodLibraryItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
