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

  @HiveField(6)
  List<String> photoPaths;

  WeightEntry({
    required this.id,
    required this.date,
    required this.weight,
    this.photoPath,
    List<String>? photoPaths,
    this.notes,
    this.unit = 'lbs',
  }) : photoPaths = photoPaths ?? [];

  /// All photos for this entry: the new list if present, otherwise the legacy
  /// single photo, otherwise empty. Every reader should use this.
  List<String> get allPhotos {
    if (photoPaths.isNotEmpty) return photoPaths;
    if (photoPath != null && photoPath!.isNotEmpty) return [photoPath!];
    return [];
  }

  double get weightInKg => unit == 'kg' ? weight : weight * 0.453592;
  double get weightInLbs => unit == 'lbs' ? weight : weight * 2.20462;

  WeightEntry copyWith({
    String? id,
    DateTime? date,
    double? weight,
    String? photoPath,
    List<String>? photoPaths,
    String? notes,
    String? unit,
  }) {
    return WeightEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      weight: weight ?? this.weight,
      photoPath: photoPath ?? this.photoPath,
      photoPaths: photoPaths ?? this.photoPaths,
      notes: notes ?? this.notes,
      unit: unit ?? this.unit,
    );
  }
}
