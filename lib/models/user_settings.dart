import 'package:hive/hive.dart';

part 'user_settings.g.dart';

@HiveType(typeId: 6)
class UserSettings extends HiveObject {
  @HiveField(0)
  int weeklyWorkoutGoal;

  @HiveField(1)
  int dailyCalorieGoal;

  @HiveField(2)
  int dailyProteinGoal;

  @HiveField(3)
  int dailyCarbsGoal;

  @HiveField(4)
  int dailyFatsGoal;

  @HiveField(5)
  int dailyStepGoal;

  @HiveField(6)
  String weightUnit; // 'lbs' or 'kg'

  @HiveField(7)
  bool useMetric;

  @HiveField(8)
  bool useGoogleFit;

  @HiveField(9)
  bool notificationsEnabled;

  @HiveField(10)
  DateTime? lastGoogleFitSync;

  @HiveField(11)
  int bestStreak;

  @HiveField(12)
  int currentStreak;

  @HiveField(13)
  DateTime? lastWorkoutDate;

  // New fields for user profile
  @HiveField(14)
  String? gender; // 'male', 'female', or null

  @HiveField(15)
  double? userWeight; // Current weight in user's preferred unit

  @HiveField(16)
  double? userHeight; // Height in inches (or cm if metric)

  @HiveField(17)
  int dailyWaterGoalOz; // Daily water goal in oz

  UserSettings({
    this.weeklyWorkoutGoal = 4,
    this.dailyCalorieGoal = 2000,
    this.dailyProteinGoal = 150,
    this.dailyCarbsGoal = 200,
    this.dailyFatsGoal = 65,
    this.dailyStepGoal = 10000,
    this.weightUnit = 'lbs',
    this.useMetric = false,
    this.useGoogleFit = false, // Changed to false - use simple pedometer instead
    this.notificationsEnabled = false, // Changed to false - user must tap to enable
    this.lastGoogleFitSync,
    this.bestStreak = 0,
    this.currentStreak = 0,
    this.lastWorkoutDate,
    this.gender,
    this.userWeight,
    this.userHeight,
    this.dailyWaterGoalOz = 92, // Default for female, 124 for male
  });

  /// Get the recommended water goal based on gender
  int get recommendedWaterGoal {
    if (gender == 'male') return 124;
    return 92; // Default/female
  }

  /// Get height display string
  String get heightDisplay {
    if (userHeight == null) return '--';
    if (useMetric) {
      return '${userHeight!.toStringAsFixed(0)} cm';
    } else {
      final feet = (userHeight! / 12).floor();
      final inches = (userHeight! % 12).round();
      return "$feet'$inches\"";
    }
  }

  /// Get weight display string
  String get weightDisplay {
    if (userWeight == null) return '--';
    return '${userWeight!.toStringAsFixed(1)} $weightUnit';
  }

  UserSettings copyWith({
    int? weeklyWorkoutGoal,
    int? dailyCalorieGoal,
    int? dailyProteinGoal,
    int? dailyCarbsGoal,
    int? dailyFatsGoal,
    int? dailyStepGoal,
    String? weightUnit,
    bool? useMetric,
    bool? useGoogleFit,
    bool? notificationsEnabled,
    DateTime? lastGoogleFitSync,
    int? bestStreak,
    int? currentStreak,
    DateTime? lastWorkoutDate,
    String? gender,
    double? userWeight,
    double? userHeight,
    int? dailyWaterGoalOz,
  }) {
    return UserSettings(
      weeklyWorkoutGoal: weeklyWorkoutGoal ?? this.weeklyWorkoutGoal,
      dailyCalorieGoal: dailyCalorieGoal ?? this.dailyCalorieGoal,
      dailyProteinGoal: dailyProteinGoal ?? this.dailyProteinGoal,
      dailyCarbsGoal: dailyCarbsGoal ?? this.dailyCarbsGoal,
      dailyFatsGoal: dailyFatsGoal ?? this.dailyFatsGoal,
      dailyStepGoal: dailyStepGoal ?? this.dailyStepGoal,
      weightUnit: weightUnit ?? this.weightUnit,
      useMetric: useMetric ?? this.useMetric,
      useGoogleFit: useGoogleFit ?? this.useGoogleFit,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      lastGoogleFitSync: lastGoogleFitSync ?? this.lastGoogleFitSync,
      bestStreak: bestStreak ?? this.bestStreak,
      currentStreak: currentStreak ?? this.currentStreak,
      lastWorkoutDate: lastWorkoutDate ?? this.lastWorkoutDate,
      gender: gender ?? this.gender,
      userWeight: userWeight ?? this.userWeight,
      userHeight: userHeight ?? this.userHeight,
      dailyWaterGoalOz: dailyWaterGoalOz ?? this.dailyWaterGoalOz,
    );
  }
}
