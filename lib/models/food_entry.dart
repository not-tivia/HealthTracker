import 'package:hive/hive.dart';

part 'food_entry.g.dart';

@HiveType(typeId: 4)
class FoodEntry extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  DateTime date;

  @HiveField(3)
  String mealType; // breakfast, lunch, dinner, snack

  @HiveField(4)
  double calories;

  @HiveField(5)
  double protein;

  @HiveField(6)
  double carbs;

  @HiveField(7)
  double fats;

  @HiveField(8)
  double servingSize;

  @HiveField(9)
  String servingUnit;

  @HiveField(10)
  int useCount; // Track frequency for quick-add

  FoodEntry({
    required this.id,
    required this.name,
    required this.date,
    required this.mealType,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fats,
    this.servingSize = 1.0,
    this.servingUnit = 'serving',
    this.useCount = 1,
  });

  FoodEntry copyWith({
    String? id,
    String? name,
    DateTime? date,
    String? mealType,
    double? calories,
    double? protein,
    double? carbs,
    double? fats,
    double? servingSize,
    String? servingUnit,
    int? useCount,
  }) {
    return FoodEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      date: date ?? this.date,
      mealType: mealType ?? this.mealType,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fats: fats ?? this.fats,
      servingSize: servingSize ?? this.servingSize,
      servingUnit: servingUnit ?? this.servingUnit,
      useCount: useCount ?? this.useCount,
    );
  }

  // Create a new entry based on this template for a specific date
  FoodEntry asNewEntry(DateTime newDate, String newMealType) {
    return FoodEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      date: newDate,
      mealType: newMealType,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fats: fats,
      servingSize: servingSize,
      servingUnit: servingUnit,
      useCount: 1,
    );
  }
}

// Helper class for daily totals
class DailyNutrition {
  final DateTime date;
  final double totalCalories;
  final double totalProtein;
  final double totalCarbs;
  final double totalFats;
  final List<FoodEntry> entries;

  DailyNutrition({
    required this.date,
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFats,
    required this.entries,
  });

  factory DailyNutrition.fromEntries(DateTime date, List<FoodEntry> entries) {
    return DailyNutrition(
      date: date,
      totalCalories: entries.fold(0, (sum, e) => sum + e.calories),
      totalProtein: entries.fold(0, (sum, e) => sum + e.protein),
      totalCarbs: entries.fold(0, (sum, e) => sum + e.carbs),
      totalFats: entries.fold(0, (sum, e) => sum + e.fats),
      entries: entries,
    );
  }
}

// Common food templates
class CommonFoods {
  static final List<FoodEntry> templates = [
    FoodEntry(
      id: 'template_1',
      name: 'Chicken Breast (4oz)',
      date: DateTime.now(),
      mealType: 'lunch',
      calories: 165,
      protein: 31,
      carbs: 0,
      fats: 3.6,
      servingSize: 4,
      servingUnit: 'oz',
    ),
    FoodEntry(
      id: 'template_2',
      name: 'Brown Rice (1 cup)',
      date: DateTime.now(),
      mealType: 'lunch',
      calories: 216,
      protein: 5,
      carbs: 45,
      fats: 1.8,
      servingSize: 1,
      servingUnit: 'cup',
    ),
    FoodEntry(
      id: 'template_3',
      name: 'Eggs (2 large)',
      date: DateTime.now(),
      mealType: 'breakfast',
      calories: 156,
      protein: 12,
      carbs: 1.2,
      fats: 10,
      servingSize: 2,
      servingUnit: 'eggs',
    ),
    FoodEntry(
      id: 'template_4',
      name: 'Greek Yogurt (1 cup)',
      date: DateTime.now(),
      mealType: 'snack',
      calories: 130,
      protein: 17,
      carbs: 8,
      fats: 0.7,
      servingSize: 1,
      servingUnit: 'cup',
    ),
    FoodEntry(
      id: 'template_5',
      name: 'Whey Protein Shake',
      date: DateTime.now(),
      mealType: 'snack',
      calories: 120,
      protein: 24,
      carbs: 3,
      fats: 1.5,
      servingSize: 1,
      servingUnit: 'scoop',
    ),
    FoodEntry(
      id: 'template_6',
      name: 'Banana',
      date: DateTime.now(),
      mealType: 'snack',
      calories: 105,
      protein: 1.3,
      carbs: 27,
      fats: 0.4,
      servingSize: 1,
      servingUnit: 'medium',
    ),
    FoodEntry(
      id: 'template_7',
      name: 'Salmon (4oz)',
      date: DateTime.now(),
      mealType: 'dinner',
      calories: 233,
      protein: 25,
      carbs: 0,
      fats: 14,
      servingSize: 4,
      servingUnit: 'oz',
    ),
    FoodEntry(
      id: 'template_8',
      name: 'Oatmeal (1 cup)',
      date: DateTime.now(),
      mealType: 'breakfast',
      calories: 158,
      protein: 6,
      carbs: 27,
      fats: 3,
      servingSize: 1,
      servingUnit: 'cup',
    ),
    FoodEntry(
      id: 'template_9',
      name: 'Almonds (1oz)',
      date: DateTime.now(),
      mealType: 'snack',
      calories: 164,
      protein: 6,
      carbs: 6,
      fats: 14,
      servingSize: 1,
      servingUnit: 'oz',
    ),
    FoodEntry(
      id: 'template_10',
      name: 'Avocado (half)',
      date: DateTime.now(),
      mealType: 'lunch',
      calories: 161,
      protein: 2,
      carbs: 9,
      fats: 15,
      servingSize: 0.5,
      servingUnit: 'avocado',
    ),
  ];
}
