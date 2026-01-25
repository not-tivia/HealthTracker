import 'package:hive/hive.dart';

part 'weight_entry.g.dart';

@HiveType(typeId: 3)
class WeightEntry extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  DateTime date;

  @HiveField(2)
  double weight;

  @HiveField(3)
  String? photoPath;

  @HiveField(4)
  String? notes;

  @HiveField(5)
  String unit; // 'lbs' or 'kg'

  WeightEntry({
    required this.id,
    required this.date,
    required this.weight,
    this.photoPath,
    this.notes,
    this.unit = 'lbs',
  });

  double get weightInKg => unit == 'kg' ? weight : weight * 0.453592;
  double get weightInLbs => unit == 'lbs' ? weight : weight * 2.20462;

  WeightEntry copyWith({
    String? id,
    DateTime? date,
    double? weight,
    String? photoPath,
    String? notes,
    String? unit,
  }) {
    return WeightEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      weight: weight ?? this.weight,
      photoPath: photoPath ?? this.photoPath,
      notes: notes ?? this.notes,
      unit: unit ?? this.unit,
    );
  }
}
