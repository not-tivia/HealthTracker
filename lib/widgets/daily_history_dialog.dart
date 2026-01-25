import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import '../services/storage_service.dart';
import '../models/food_entry.dart';
import '../models/water_entry.dart';
import '../models/checklist_item.dart';
import '../models/weight_entry.dart';
import '../models/workout.dart';
import '../models/cardio_workout.dart';

/// Full-screen dialog showing daily history with compact week navigation
class DailyHistoryDialog extends StatefulWidget {
  final DateTime? initialDate;

  const DailyHistoryDialog({super.key, this.initialDate});

  @override
  State<DailyHistoryDialog> createState() => _DailyHistoryDialogState();
}

class _DailyHistoryDialogState extends State<DailyHistoryDialog> {
  late DateTime _selectedDate;
  
  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
    // Normalize to start of day
    _selectedDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
  }

  // Get 7 days centered around selected date (3 before, selected, 3 after)
  List<DateTime> _getWeekDays() {
    final today = DateTime.now();
    final todayNormalized = DateTime(today.year, today.month, today.day);
    
    List<DateTime> days = [];
    for (int i = -3; i <= 3; i++) {
      final day = _selectedDate.add(Duration(days: i));
      // Don't show future dates
      if (!day.isAfter(todayNormalized)) {
        days.add(day);
      }
    }
    
    // If we have less than 7 days (near today), pad with earlier dates
    while (days.length < 7) {
      final earliestDay = days.first.subtract(const Duration(days: 1));
      days.insert(0, earliestDay);
    }
    
    return days;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildCompactHeader(),
            _buildWeekStrip(),
            _buildSelectedDateHeader(),
            const Divider(height: 1),
            Expanded(
              child: _buildDailySummary(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text(
              'Daily History',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // Date picker button (green square from sketch)
          GestureDetector(
            onTap: () => _showDatePicker(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.calendar_today,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekStrip() {
    final storage = context.read<StorageService>();
    final weekDays = _getWeekDays();
    final today = DateTime.now();
    final todayNormalized = DateTime(today.year, today.month, today.day);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: weekDays.map((day) {
          final isSelected = _isSameDay(day, _selectedDate);
          final isToday = _isSameDay(day, todayNormalized);
          final hasData = _dateHasData(storage, day);
          
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedDate = day;
              });
            },
            child: Container(
              width: 40,
              height: 50,
              decoration: BoxDecoration(
                color: isSelected 
                    ? AppTheme.primaryColor 
                    : isToday 
                        ? AppTheme.primaryColor.withOpacity(0.2)
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.white : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Data indicator dot
                  if (hasData)
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : AppTheme.primaryColor,
                        shape: BoxShape.circle,
                      ),
                    )
                  else
                    const SizedBox(height: 6),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSelectedDateHeader() {
    final dayName = DateFormat('EEEE').format(_selectedDate);
    final datePart = DateFormat('MMM d, yyyy').format(_selectedDate);
    
    final today = DateTime.now();
    final isToday = _isSameDay(_selectedDate, today);
    final isYesterday = _isSameDay(_selectedDate, today.subtract(const Duration(days: 1)));
    
    String displayText;
    if (isToday) {
      displayText = 'Today, $datePart';
    } else if (isYesterday) {
      displayText = 'Yesterday, $datePart';
    } else {
      displayText = '$dayName, $datePart';
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(
            displayText,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _showDatePicker() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppTheme.primaryColor,
              surface: AppTheme.cardColor,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  bool _dateHasData(StorageService storage, DateTime date) {
    // Check steps
    final steps = storage.getStepsData(date);
    if (steps != null && steps > 0) return true;
    
    // Check water
    final water = storage.getWaterEntriesForDate(date);
    if (water.isNotEmpty) return true;
    
    // Check food
    final food = storage.getFoodEntriesForDate(date);
    if (food.isNotEmpty) return true;
    
    // Check workouts
    final workouts = storage.getWorkoutsForDate(date);
    if (workouts.isNotEmpty) return true;
    
    // Check cardio
    final cardio = storage.getCardioWorkoutsForDate(date);
    if (cardio.isNotEmpty) return true;
    
    // Check checklist completion
    final completed = storage.getCompletedChecklistCount(date);
    if (completed > 0) return true;
    
    // Check weight entry
    final entries = storage.getAllWeightEntries();
    final dateKey = DateFormat('yyyy-MM-dd').format(date);
    final hasWeight = entries.any((e) => DateFormat('yyyy-MM-dd').format(e.date) == dateKey);
    if (hasWeight) return true;
    
    return false;
  }

  bool _dateHasPhoto(StorageService storage, DateTime date) {
    final entries = storage.getAllWeightEntries();
    final dateKey = DateFormat('yyyy-MM-dd').format(date);
    
    return entries.any((e) => 
      DateFormat('yyyy-MM-dd').format(e.date) == dateKey && 
      e.photoPath != null && 
      e.photoPath!.isNotEmpty
    );
  }

  Widget _buildDailySummary() {
    final storage = context.watch<StorageService>();
    final settings = storage.settings;
    final useMetric = settings.useMetric;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Build sections conditionally
          ..._buildPhotoSection(storage),
          ..._buildWeightSection(storage, useMetric),
          ..._buildStepsSection(storage, settings.dailyStepGoal),
          ..._buildWaterSection(storage, settings.dailyWaterGoalOz, useMetric),
          ..._buildSelfCareSection(storage),
          ..._buildNutritionSection(storage, settings.dailyCalorieGoal),
          ..._buildWorkoutSection(storage),
          
          // Empty state
          if (!_dateHasData(storage, _selectedDate) && !_dateHasPhoto(storage, _selectedDate))
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 60),
                child: Column(
                  children: [
                    Icon(Icons.event_busy, size: 64, color: Colors.grey.shade600),
                    const SizedBox(height: 16),
                    Text(
                      'No data recorded',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Nothing was logged for this day',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  List<Widget> _buildPhotoSection(StorageService storage) {
    final entries = storage.getAllWeightEntries();
    final dateKey = DateFormat('yyyy-MM-dd').format(_selectedDate);
    
    final entryWithPhoto = entries.cast<WeightEntry?>().firstWhere(
      (e) => DateFormat('yyyy-MM-dd').format(e!.date) == dateKey && 
             e.photoPath != null && 
             e.photoPath!.isNotEmpty,
      orElse: () => null,
    );
    
    if (entryWithPhoto == null) return [];
    
    return [
      _buildSectionCard(
        icon: Icons.camera_alt,
        iconColor: Colors.orange,
        title: 'Progress Photo',
        child: GestureDetector(
          onTap: () => _showFullScreenPhoto(entryWithPhoto.photoPath!),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              File(entryWithPhoto.photoPath!),
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 200,
                color: Colors.grey.shade800,
                child: const Center(
                  child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
                ),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 16),
    ];
  }

  List<Widget> _buildWeightSection(StorageService storage, bool useMetric) {
    final entries = storage.getAllWeightEntries();
    final dateKey = DateFormat('yyyy-MM-dd').format(_selectedDate);
    
    final entry = entries.cast<WeightEntry?>().firstWhere(
      (e) => DateFormat('yyyy-MM-dd').format(e!.date) == dateKey,
      orElse: () => null,
    );
    
    if (entry == null) return [];
    
    final weight = useMetric ? entry.weightInKg : entry.weightInLbs;
    final unit = useMetric ? 'kg' : 'lbs';
    
    return [
      _buildSectionCard(
        icon: Icons.monitor_weight_outlined,
        iconColor: Colors.purple,
        title: 'Weight',
        child: Text(
          '${weight.toStringAsFixed(1)} $unit',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
      const SizedBox(height: 16),
    ];
  }

  List<Widget> _buildStepsSection(StorageService storage, int goal) {
    final steps = storage.getStepsData(_selectedDate);
    
    if (steps == null || steps == 0) return [];
    
    final progress = (steps / goal).clamp(0.0, 1.0);
    final goalReached = steps >= goal;
    
    return [
      _buildSectionCard(
        icon: Icons.directions_walk,
        iconColor: Colors.blue,
        title: 'Steps',
        trailing: goalReached 
            ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${NumberFormat('#,###').format(steps)} / ${NumberFormat('#,###').format(goal)}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: Colors.grey.shade800,
                valueColor: AlwaysStoppedAnimation(
                  goalReached ? Colors.green : AppTheme.primaryColor,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
    ];
  }

  List<Widget> _buildWaterSection(StorageService storage, int goalOz, bool useMetric) {
    final entries = storage.getWaterEntriesForDate(_selectedDate);
    
    if (entries.isEmpty) return [];
    
    final totalOz = entries.fold(0, (sum, e) => sum + e.amountOz);
    final progress = (totalOz / goalOz).clamp(0.0, 1.0);
    final goalReached = totalOz >= goalOz;
    
    String formatAmount(int oz) {
      if (useMetric) {
        return '${(oz * 29.5735).round()} ml';
      }
      return '$oz oz';
    }
    
    return [
      _buildSectionCard(
        icon: Icons.water_drop,
        iconColor: Colors.cyan,
        title: 'Water',
        trailing: goalReached 
            ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${formatAmount(totalOz)} / ${formatAmount(goalOz)}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: Colors.grey.shade800,
                valueColor: AlwaysStoppedAnimation(
                  goalReached ? Colors.green : Colors.cyan,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
    ];
  }

  List<Widget> _buildSelfCareSection(StorageService storage) {
    final items = storage.getChecklistItems();
    final completedCount = storage.getCompletedChecklistCount(_selectedDate);
    
    if (completedCount == 0) return [];
    
    final allCompleted = completedCount == items.length;
    
    return [
      _buildSectionCard(
        icon: Icons.checklist,
        iconColor: Colors.teal,
        title: 'Self-Care',
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$completedCount/${items.length}',
              style: TextStyle(
                color: allCompleted ? Colors.green : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (allCompleted) ...[
              const SizedBox(width: 8),
              const Icon(Icons.check_circle, color: Colors.green, size: 20),
            ],
          ],
        ),
        child: Column(
          children: items.map((item) {
            final isCompleted = storage.isChecklistItemCompleted(item.id, _selectedDate);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    isCompleted ? Icons.check_circle : Icons.circle_outlined,
                    color: isCompleted ? Colors.green : Colors.grey.shade600,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${item.icon ?? ''} ${item.name}',
                      style: TextStyle(
                        color: isCompleted ? null : Colors.grey.shade500,
                        decoration: isCompleted ? null : TextDecoration.lineThrough,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
      const SizedBox(height: 16),
    ];
  }

  List<Widget> _buildNutritionSection(StorageService storage, int calorieGoal) {
    final entries = storage.getFoodEntriesForDate(_selectedDate);
    
    if (entries.isEmpty) return [];
    
    final totalCalories = entries.fold(0.0, (sum, e) => sum + e.calories);
    final totalProtein = entries.fold(0.0, (sum, e) => sum + e.protein);
    final totalCarbs = entries.fold(0.0, (sum, e) => sum + e.carbs);
    final totalFats = entries.fold(0.0, (sum, e) => sum + e.fats);
    
    final isOver = totalCalories > calorieGoal;
    
    return [
      _buildSectionCard(
        icon: Icons.restaurant,
        iconColor: Colors.orange,
        title: 'Nutrition',
        trailing: Text(
          '${totalCalories.toInt()} / $calorieGoal cal',
          style: TextStyle(
            color: isOver ? Colors.orange : Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Macros summary
            Row(
              children: [
                _buildMacroChip('P', totalProtein, Colors.red),
                const SizedBox(width: 8),
                _buildMacroChip('C', totalCarbs, Colors.blue),
                const SizedBox(width: 8),
                _buildMacroChip('F', totalFats, Colors.amber),
              ],
            ),
            const SizedBox(height: 12),
            // Food list
            ...entries.take(10).map((entry) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.circle, size: 6, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${entry.calories.toInt()} cal',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ],
              ),
            )),
            if (entries.length > 10)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '+${entries.length - 10} more items',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 16),
    ];
  }

  Widget _buildMacroChip(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$label: ${value.toInt()}g',
        style: TextStyle(color: color, fontWeight: FontWeight.w500, fontSize: 12),
      ),
    );
  }

  List<Widget> _buildWorkoutSection(StorageService storage) {
    final workouts = storage.getWorkoutsForDate(_selectedDate);
    final cardioWorkouts = storage.getCardioWorkoutsForDate(_selectedDate);
    
    if (workouts.isEmpty && cardioWorkouts.isEmpty) return [];
    
    return [
      _buildSectionCard(
        icon: Icons.fitness_center,
        iconColor: Colors.green,
        title: 'Workouts',
        child: Column(
          children: [
            // Strength workouts
            ...workouts.map((workout) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.fitness_center, color: Colors.green, size: 16),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          workout.name,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${workout.exercises.length} exercises \u{2022} ${workout.durationMinutes} min',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )),
            // Cardio workouts
            ...cardioWorkouts.map((cardio) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.directions_run, color: Colors.red, size: 16),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cardio.type.displayName,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${cardio.durationMinutes} min \u{2022} ${cardio.estimatedCalories} cal',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
      const SizedBox(height: 16),
    ];
  }

  Widget _buildSectionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    Widget? trailing,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  void _showFullScreenPhoto(String photoPath) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          fit: StackFit.expand,
          children: [
            InteractiveViewer(
              child: Image.file(
                File(photoPath),
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image, size: 64, color: Colors.grey),
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
