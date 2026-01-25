import 'package:hive/hive.dart';

part 'workout_history.g.dart';

/// A single completed workout (Push / Pull / Legs)
@HiveType(typeId: 7)
class WorkoutHistory extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String workoutType;

  @HiveField(2)
  DateTime date;

  @HiveField(3)
  int durationMinutes;

  /// List of exercises performed in this workout
  @HiveField(4)
  List<ExerciseHistory> exercises;

  @HiveField(5)
  String? notes;

  /// Used by the storage service when building history summaries
  @HiveField(6)
  List<ExerciseHistory> exerciseData;

  WorkoutHistory({
    required this.id,
    required this.workoutType,
    required this.date,
    required this.durationMinutes,
    required this.exercises,
    this.notes,
    List<ExerciseHistory>? exerciseData,
  }) : exerciseData = exerciseData ?? exercises;
}

/// One exercise inside a workout (e.g., Bench Press)
@HiveType(typeId: 8)
class ExerciseHistory extends HiveObject {
  @HiveField(0)
  String exerciseName;

  @HiveField(1)
  List<int> reps; // Reps per set

  @HiveField(2)
  List<double> weights; // Weight per set

  @HiveField(3)
  bool completedAllSets;

  @HiveField(4)
  bool metRepGoal;

  @HiveField(5)
  int sessionCount;

  @HiveField(6)
  double lastWeight;

  @HiveField(7)
  int lastReps;

  @HiveField(8)
  int consecutiveGoalsMet;

  ExerciseHistory({
    required this.exerciseName,
    required this.reps,
    required this.weights,
    this.completedAllSets = false,
    this.metRepGoal = false,
    this.sessionCount = 0,
    this.lastWeight = 0.0,
    this.lastReps = 0,
    this.consecutiveGoalsMet = 0,
  });

  /// Get the maximum weight used across all sets
  double get maxWeight => weights.isEmpty ? 0 : weights.reduce((a, b) => a > b ? a : b);
  
  /// Get the minimum weight used across all sets (excluding zeros)
  /// This is useful for auto-filling weights when user couldn't complete all sets
  double get minWeight {
    if (weights.isEmpty) return 0;
    final nonZeroWeights = weights.where((w) => w > 0).toList();
    if (nonZeroWeights.isEmpty) return 0;
    return nonZeroWeights.reduce((a, b) => a < b ? a : b);
  }
  
  int get maxReps => reps.isEmpty ? 0 : reps.reduce((a, b) => a > b ? a : b);
  double get totalVolume => List.generate(
        reps.length,
        (i) => (reps[i] * weights[i]),
      ).fold(0, (a, b) => a + b);
}

/// Helper class for progressive overload suggestions
class ProgressiveOverloadChecker {
  static const int weeksToCheck = 3;
  static const double weightIncrement = 5.0; // lbs

  /// Returns a suggestion if the user should increase weight
  /// Uses AVERAGE reps across sets and compares to MINIMUM target (not max)
  static ProgressiveOverloadSuggestion? checkProgression(
    String exerciseName,
    List<WorkoutHistory> recentWorkouts,
    String targetReps,
  ) {
    final List<ExerciseHistory> exerciseHistory = [];

    for (var workout in recentWorkouts) {
      for (var exercise in workout.exercises) {
        if (exercise.exerciseName == exerciseName) {
          exerciseHistory.add(exercise);
        }
      }
    }

    if (exerciseHistory.length < weeksToCheck) return null;

    final List<ExerciseHistory> lastThree = exerciseHistory.take(weeksToCheck).toList();
    
    // Use MINIMUM target reps (e.g., 8 from "8-12") instead of max
    final int minTargetReps = int.tryParse(targetReps.split('-').first) ?? 8;

    // Check if AVERAGE reps per session meets the MINIMUM target
    final bool allMetGoal = lastThree.every((e) {
      if (e.reps.isEmpty) return false;
      final avgReps = e.reps.reduce((a, b) => a + b) / e.reps.length;
      return e.completedAllSets && avgReps >= minTargetReps;
    });

    if (allMetGoal) {
      final double currentWeight = lastThree.first.maxWeight;
      double suggestedWeight = currentWeight + weightIncrement;
      suggestedWeight = (suggestedWeight / 5).round() * 5;

      return ProgressiveOverloadSuggestion(
        exerciseName: exerciseName,
        currentWeight: currentWeight,
        suggestedWeight: suggestedWeight,
        reason:
            'You\'ve hit your rep target for $weeksToCheck consecutive sessions!',
      );
    }
    return null;
  }

  /// Simple check used in workout session screen
  static bool checkForIncrease(ExerciseHistory history) {
    return history.consecutiveGoalsMet >= 3;
  }

  /// Simple weight increase logic
  static double calculateNewWeight(double currentWeight) {
    return (currentWeight / 5).round() * 5 + 5;
  }
}

class ProgressiveOverloadSuggestion {
  final String exerciseName;
  final double currentWeight;
  final double suggestedWeight;
  final String reason;

  ProgressiveOverloadSuggestion({
    required this.exerciseName,
    required this.currentWeight,
    required this.suggestedWeight,
    required this.reason,
  });
}
