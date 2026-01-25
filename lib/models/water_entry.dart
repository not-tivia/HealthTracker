import 'package:hive/hive.dart';

part 'water_entry.g.dart';

/// Represents a single water intake entry
@HiveType(typeId: 14)
class WaterEntry extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  DateTime date;

  @HiveField(2)
  int amountOz; // Amount in ounces

  @HiveField(3)
  DateTime timestamp; // When the water was logged

  WaterEntry({
    required this.id,
    required this.date,
    required this.amountOz,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Display amount in oz or ml based on preference
  String displayAmount(bool useMetric) {
    if (useMetric) {
      final ml = (amountOz * 29.5735).round();
      return '$ml ml';
    }
    return '$amountOz oz';
  }
}

/// Helper class for daily water totals
class DailyWaterIntake {
  final DateTime date;
  final int totalOz;
  final int goalOz;
  final List<WaterEntry> entries;

  DailyWaterIntake({
    required this.date,
    required this.totalOz,
    required this.goalOz,
    required this.entries,
  });

  double get progress => (totalOz / goalOz).clamp(0.0, 1.0);
  bool get goalReached => totalOz >= goalOz;
  int get remainingOz => (goalOz - totalOz).clamp(0, goalOz);

  /// Display remaining in oz or ml
  String remainingDisplay(bool useMetric) {
    if (useMetric) {
      final ml = (remainingOz * 29.5735).round();
      return '$ml ml';
    }
    return '$remainingOz oz';
  }
}

/// Common water amounts for quick add
class WaterAmounts {
  static const List<int> quickAddOz = [8, 12, 17, 32]; // 17 oz ≈ 16.9 oz water bottle
  
  static String displayAmount(int oz, bool useMetric) {
    if (useMetric) {
      final ml = (oz * 29.5735).round();
      return '$ml ml';
    }
    // Show 16.9 for the water bottle size
    if (oz == 17) return '16.9 oz';
    return '$oz oz';
  }

  static String getIcon(int oz) {
    switch (oz) {
      case 8:
        return '\u{1F964}'; // Small cup
      case 12:
        return '\u{1F95B}'; // Medium glass
      case 17:
        return '\u{1F4A7}'; // Water droplet
      case 32:
        return '\u{1FAD7}'; // Large bottle (pouring liquid)
      default:
        return '\u{1F4A7}'; // Water droplet
    }
  }

  static String getLabel(int oz) {
    switch (oz) {
      case 8:
        return 'Cup';
      case 12:
        return 'Glass';
      case 17:
        return 'Bottle';
      case 32:
        return 'Large';
      default:
        return '';
    }
  }
}
