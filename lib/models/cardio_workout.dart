import 'package:hive/hive.dart';

part 'cardio_workout.g.dart';

/// Types of cardio activities
@HiveType(typeId: 12)
enum CardioType {
  @HiveField(0)
  running,
  @HiveField(1)
  walking,
  @HiveField(2)
  cycling,
  @HiveField(3)
  swimming,
  @HiveField(4)
  rowing,
  @HiveField(5)
  elliptical,
  @HiveField(6)
  stairClimber,
  @HiveField(7)
  jumpRope,
  @HiveField(8)
  hiit,
  @HiveField(9)
  other,
}

extension CardioTypeExtension on CardioType {
  String get displayName {
    switch (this) {
      case CardioType.running:
        return 'Running';
      case CardioType.walking:
        return 'Walking';
      case CardioType.cycling:
        return 'Cycling';
      case CardioType.swimming:
        return 'Swimming';
      case CardioType.rowing:
        return 'Rowing';
      case CardioType.elliptical:
        return 'Elliptical';
      case CardioType.stairClimber:
        return 'Stair Climber';
      case CardioType.jumpRope:
        return 'Jump Rope';
      case CardioType.hiit:
        return 'HIIT';
      case CardioType.other:
        return 'Other';
    }
  }
  
  String get icon {
    switch (this) {
      case CardioType.running:
        return '\u{1F3C3}'; // 🏃
      case CardioType.walking:
        return '\u{1F6B6}'; // 🚶
      case CardioType.cycling:
        return '\u{1F6B4}'; // 🚴
      case CardioType.swimming:
        return '\u{1F3CA}'; // 🏊
      case CardioType.rowing:
        return '\u{1F6A3}'; // 🚣
      case CardioType.elliptical:
        return '\u{1F3CB}'; // 🏋
      case CardioType.stairClimber:
        return '\u{1FA9C}'; // 🪜
      case CardioType.jumpRope:
        return '\u{1FA62}'; // 🩢
      case CardioType.hiit:
        return '\u{1F4A5}'; // 💥
      case CardioType.other:
        return '\u{2764}\u{FE0F}'; // ❤️
    }
  }
  
  /// Calories burned per minute (rough estimate based on 155lb person)
  double get caloriesPerMinute {
    switch (this) {
      case CardioType.running:
        return 11.4; // ~8 min/mile pace
      case CardioType.walking:
        return 4.3;
      case CardioType.cycling:
        return 8.5;
      case CardioType.swimming:
        return 10.0;
      case CardioType.rowing:
        return 10.0;
      case CardioType.elliptical:
        return 8.0;
      case CardioType.stairClimber:
        return 9.0;
      case CardioType.jumpRope:
        return 12.0;
      case CardioType.hiit:
        return 12.5;
      case CardioType.other:
        return 7.0;
    }
  }
  
  /// Whether this activity type counts towards steps
  bool get countsAsSteps {
    switch (this) {
      case CardioType.running:
      case CardioType.walking:
      case CardioType.stairClimber:
      case CardioType.hiit:
      case CardioType.jumpRope:
      case CardioType.elliptical:
        return true;
      case CardioType.cycling:
      case CardioType.swimming:
      case CardioType.rowing:
      case CardioType.other:
        return false;
    }
  }
  
  /// Estimated steps per minute for step-counting activities
  int get stepsPerMinute {
    switch (this) {
      case CardioType.running:
        return 160; // Average running cadence
      case CardioType.walking:
        return 100; // Average walking cadence
      case CardioType.stairClimber:
        return 80;  // Slower cadence on stairs
      case CardioType.hiit:
        return 120; // Variable, moderate estimate
      case CardioType.jumpRope:
        return 140; // Jump rope cadence
      case CardioType.elliptical:
        return 120; // Elliptical stride rate
      default:
        return 0;
    }
  }
}

/// A completed cardio workout session
@HiveType(typeId: 13)
class CardioWorkout extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  CardioType type;

  @HiveField(2)
  DateTime date;

  @HiveField(3)
  int durationMinutes;

  @HiveField(4)
  double? distanceMiles; // Optional - for running, cycling, etc.

  @HiveField(5)
  int? caloriesBurned; // Can be entered manually or calculated

  @HiveField(6)
  int? avgHeartRate; // Optional - if user has heart rate monitor

  @HiveField(7)
  int? maxHeartRate; // Optional

  @HiveField(8)
  String? notes;

  @HiveField(9)
  int? perceivedExertion; // 1-10 scale (RPE)

  @HiveField(10)
  double? avgPace; // minutes per mile (for running/walking)

  CardioWorkout({
    required this.id,
    required this.type,
    required this.date,
    required this.durationMinutes,
    this.distanceMiles,
    this.caloriesBurned,
    this.avgHeartRate,
    this.maxHeartRate,
    this.notes,
    this.perceivedExertion,
    this.avgPace,
  });

  /// Calculate estimated calories if not manually entered
  int get estimatedCalories {
    if (caloriesBurned != null) return caloriesBurned!;
    return (type.caloriesPerMinute * durationMinutes).round();
  }
  
  /// Estimate steps from this cardio workout
  /// Returns 0 for activities that don't count as steps (cycling, swimming, etc.)
  int get estimatedSteps {
    if (!type.countsAsSteps) return 0;
    
    // If we have distance for running/walking, use more accurate calculation
    if ((type == CardioType.running || type == CardioType.walking) && 
        distanceMiles != null && distanceMiles! > 0) {
      // Average stride length: running ~4ft, walking ~2.5ft
      final strideLength = type == CardioType.running ? 4.0 : 2.5;
      final feetPerMile = 5280.0;
      return ((distanceMiles! * feetPerMile) / strideLength).round();
    }
    
    // Otherwise estimate from duration and activity type
    return type.stepsPerMinute * durationMinutes;
  }

  /// Calculate pace from distance and duration
  String? get paceDisplay {
    if (distanceMiles == null || distanceMiles! <= 0) return null;
    final paceMinutes = durationMinutes / distanceMiles!;
    final minutes = paceMinutes.floor();
    final seconds = ((paceMinutes - minutes) * 60).round();
    return '$minutes:${seconds.toString().padLeft(2, '0')} /mi';
  }

  /// Format distance display
  String? get distanceDisplay {
    if (distanceMiles == null) return null;
    return '${distanceMiles!.toStringAsFixed(2)} mi';
  }

  /// Format duration display
  String get durationDisplay {
    if (durationMinutes < 60) {
      return '$durationMinutes min';
    }
    final hours = durationMinutes ~/ 60;
    final mins = durationMinutes % 60;
    return '${hours}h ${mins}m';
  }

  CardioWorkout copyWith({
    String? id,
    CardioType? type,
    DateTime? date,
    int? durationMinutes,
    double? distanceMiles,
    int? caloriesBurned,
    int? avgHeartRate,
    int? maxHeartRate,
    String? notes,
    int? perceivedExertion,
    double? avgPace,
  }) {
    return CardioWorkout(
      id: id ?? this.id,
      type: type ?? this.type,
      date: date ?? this.date,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      distanceMiles: distanceMiles ?? this.distanceMiles,
      caloriesBurned: caloriesBurned ?? this.caloriesBurned,
      avgHeartRate: avgHeartRate ?? this.avgHeartRate,
      maxHeartRate: maxHeartRate ?? this.maxHeartRate,
      notes: notes ?? this.notes,
      perceivedExertion: perceivedExertion ?? this.perceivedExertion,
      avgPace: avgPace ?? this.avgPace,
    );
  }
}

/// Calorie calculation helpers
class CardioCalorieCalculator {
  /// Calculate calories burned based on activity, duration, and body weight
  static int calculateCalories({
    required CardioType type,
    required int durationMinutes,
    required double weightLbs,
    double? distanceMiles,
    int? avgHeartRate,
  }) {
    // MET values for different activities
    double met = _getMET(type);
    
    // If we have distance for running, adjust based on speed
    if (type == CardioType.running && distanceMiles != null && distanceMiles > 0) {
      final speedMph = distanceMiles / (durationMinutes / 60);
      met = _getRunningMET(speedMph);
    }
    
    // Calories = MET × weight in kg × duration in hours
    final weightKg = weightLbs * 0.453592;
    final durationHours = durationMinutes / 60;
    
    return (met * weightKg * durationHours).round();
  }
  
  static double _getMET(CardioType type) {
    switch (type) {
      case CardioType.running:
        return 9.8; // Default ~6 mph
      case CardioType.walking:
        return 3.8;
      case CardioType.cycling:
        return 7.5;
      case CardioType.swimming:
        return 8.0;
      case CardioType.rowing:
        return 7.0;
      case CardioType.elliptical:
        return 5.0;
      case CardioType.stairClimber:
        return 9.0;
      case CardioType.jumpRope:
        return 11.0;
      case CardioType.hiit:
        return 12.0;
      case CardioType.other:
        return 5.0;
    }
  }
  
  static double _getRunningMET(double speedMph) {
    if (speedMph < 4) return 6.0;
    if (speedMph < 5) return 8.3;
    if (speedMph < 6) return 9.8;
    if (speedMph < 7) return 10.5;
    if (speedMph < 8) return 11.5;
    if (speedMph < 9) return 12.8;
    if (speedMph < 10) return 14.5;
    return 16.0;
  }
}
