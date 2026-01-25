import 'package:hive/hive.dart';

part 'food_library_item.g.dart';

/// A food item stored in the user's personal food library
/// This persists independently of daily food entries
@HiveType(typeId: 15)
class FoodLibraryItem extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  double calories;

  @HiveField(3)
  double protein;

  @HiveField(4)
  double carbs;

  @HiveField(5)
  double fats;

  @HiveField(6)
  double servingSize;

  @HiveField(7)
  String servingUnit;

  @HiveField(8)
  DateTime createdAt;

  @HiveField(9)
  DateTime lastUsed;

  @HiveField(10)
  int useCount;

  FoodLibraryItem({
    required this.id,
    required this.name,
    required this.calories,
    this.protein = 0,
    this.carbs = 0,
    this.fats = 0,
    this.servingSize = 1,
    this.servingUnit = 'serving',
    DateTime? createdAt,
    DateTime? lastUsed,
    this.useCount = 0,
  })  : createdAt = createdAt ?? DateTime.now(),
        lastUsed = lastUsed ?? DateTime.now();

  /// Create from a FoodEntry (when adding a new food)
  factory FoodLibraryItem.fromFoodEntry({
    required String name,
    required double calories,
    double protein = 0,
    double carbs = 0,
    double fats = 0,
    double servingSize = 1,
    String servingUnit = 'serving',
  }) {
    return FoodLibraryItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fats: fats,
      servingSize: servingSize,
      servingUnit: servingUnit,
    );
  }

  /// Mark as used (updates lastUsed and increments useCount)
  void markUsed() {
    lastUsed = DateTime.now();
    useCount++;
    save();
  }

  /// Display string for calories
  String get caloriesDisplay => '${calories.toInt()} cal';

  /// Display string for macros
  String get macrosDisplay {
    final parts = <String>[];
    if (protein > 0) parts.add('${protein.toInt()}p');
    if (carbs > 0) parts.add('${carbs.toInt()}c');
    if (fats > 0) parts.add('${fats.toInt()}f');
    return parts.isEmpty ? '' : parts.join(' / ');
  }

  FoodLibraryItem copyWith({
    String? name,
    double? calories,
    double? protein,
    double? carbs,
    double? fats,
    double? servingSize,
    String? servingUnit,
  }) {
    return FoodLibraryItem(
      id: id,
      name: name ?? this.name,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fats: fats ?? this.fats,
      servingSize: servingSize ?? this.servingSize,
      servingUnit: servingUnit ?? this.servingUnit,
      createdAt: createdAt,
      lastUsed: lastUsed,
      useCount: useCount,
    );
  }
}
