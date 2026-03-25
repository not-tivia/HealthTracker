import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/workout.dart';
import '../models/weight_entry.dart';
import '../models/food_entry.dart';
import '../models/checklist_item.dart';
import '../models/user_settings.dart';
import '../models/workout_history.dart';
import '../models/saved_exercise.dart';
import '../models/workout_routine.dart';
import '../models/cardio_workout.dart';
import '../models/water_entry.dart';
import '../models/food_library_item.dart';

// NEW: Import stretch models
import '../models/saved_stretch.dart';
import '../models/stretch_routine.dart';
import '../models/default_exercises.dart';

class StorageService extends ChangeNotifier {
  late Box<Workout> _workoutsBox;
  late Box<WeightEntry> _weightEntriesBox;
  late Box<FoodEntry> _foodEntriesBox;
  late Box<ChecklistItem> _checklistItemsBox;
  late Box _dailyChecklistStatusBox;
  late Box<UserSettings> _userSettingsBox;
  late Box<WorkoutHistory> _workoutHistoryBox;
  late Box<SavedExercise> _savedExercisesBox;
  late Box<WorkoutRoutine> _workoutRoutinesBox;
  late Box<CardioWorkout> _cardioWorkoutsBox;
  late Box<WaterEntry> _waterEntriesBox;
  late Box<FoodLibraryItem> _foodLibraryBox;
  late Box _appDataBox;

  // NEW: Boxes for stretches
  late Box<SavedStretch> _savedStretchesBox;
  late Box<StretchRoutine> _stretchRoutinesBox;

  UserSettings _settings = UserSettings();
  bool _isInitialized = false;

  UserSettings get settings => _settings;
  bool get isInitialized => _isInitialized;

  StorageService() {
    _initializeBoxes();
  }

  Future<void> _initializeBoxes() async {
    _workoutsBox = Hive.box<Workout>('workouts');
    _weightEntriesBox = Hive.box<WeightEntry>('weight_entries');
    _foodEntriesBox = Hive.box<FoodEntry>('food_entries');
    _checklistItemsBox = Hive.box<ChecklistItem>('checklist_items');
    _dailyChecklistStatusBox = Hive.box('daily_checklist_status');
    _userSettingsBox = Hive.box<UserSettings>('user_settings');
    _workoutHistoryBox = Hive.box<WorkoutHistory>('workout_history');
    _savedExercisesBox = Hive.box<SavedExercise>('saved_exercises');
    _workoutRoutinesBox = Hive.box<WorkoutRoutine>('workout_routines');
    _cardioWorkoutsBox = Hive.box<CardioWorkout>('cardio_workouts');
    _waterEntriesBox = Hive.box<WaterEntry>('water_entries');
    _foodLibraryBox = Hive.box<FoodLibraryItem>('food_library');
    _appDataBox = Hive.box('app_data');

    // NEW: Initialize stretch boxes
    _savedStretchesBox = Hive.box<SavedStretch>('saved_stretches');
    _stretchRoutinesBox = Hive.box<StretchRoutine>('stretch_routines');

    // Load or create settings
    if (_userSettingsBox.isEmpty) {
      _settings = UserSettings();
      await _userSettingsBox.put('settings', _settings);
    } else {
      _settings = _userSettingsBox.get('settings') ?? UserSettings();
    }

    // Initialize default checklist items if empty
    if (_checklistItemsBox.isEmpty) {
      for (var item in DefaultChecklistItems.items) {
        await _checklistItemsBox.put(item.id, item);
      }
    }

    // Seed default exercises — only adds ones that don't already exist by name
    await _seedDefaultExercises();

    _isInitialized = true;
    notifyListeners();
  }

  Future<void> _seedDefaultExercises() async {
    final existingNames = _savedExercisesBox.values
        .map((e) => e.name.toLowerCase())
        .toSet();

    for (final exercise in DefaultExercises.all) {
      if (!existingNames.contains(exercise.name.toLowerCase())) {
        await _savedExercisesBox.put(exercise.id, exercise);
      }
    }
  }

  // ============ USER SETTINGS ============
  Future<void> updateSettings(UserSettings newSettings) async {
    _settings = newSettings;
    await _userSettingsBox.put('settings', newSettings);
    notifyListeners();
  }

  Future<UserSettings?> getUserSettings() async {
    return _userSettingsBox.get('settings');
  }

  Future<void> saveUserSettings(UserSettings settings) async {
    _settings = settings;
    await _userSettingsBox.put('settings', settings);
    notifyListeners();
  }

  Future<void> updateWaterGoalForGender(String? gender) async {
    int newGoal = gender == 'male' ? 124 : 92;
    _settings = _settings.copyWith(gender: gender, dailyWaterGoalOz: newGoal);
    await _userSettingsBox.put('settings', _settings);
    notifyListeners();
  }

  // ============ SAVED EXERCISES ============
  Future<void> saveSavedExercise(SavedExercise exercise) async {
    await _savedExercisesBox.put(exercise.id, exercise);
    notifyListeners();
  }

  Future<void> deleteSavedExercise(String id) async {
    await _savedExercisesBox.delete(id);
    notifyListeners();
  }

  List<SavedExercise> getAllSavedExercises() {
    return _savedExercisesBox.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  // Get saved exercise by ID
  SavedExercise? getSavedExerciseById(String id) {
    return _savedExercisesBox.get(id);
  }

  // Increment exercise usage count
  Future<void> incrementExerciseUsage(String id) async {
    final exercise = _savedExercisesBox.get(id);
    if (exercise != null) {
      final updated = exercise.copyWith(timesUsed: exercise.timesUsed + 1);
      await _savedExercisesBox.put(id, updated);
      notifyListeners();
    }
  }

  // ============ WORKOUT ROUTINES ============
  Future<void> saveWorkoutRoutine(WorkoutRoutine routine) async {
    await _workoutRoutinesBox.put(routine.id, routine);
    notifyListeners();
  }

  Future<void> deleteWorkoutRoutine(String id) async {
    await _workoutRoutinesBox.delete(id);
    notifyListeners();
  }

  List<WorkoutRoutine> getAllWorkoutRoutines() {
    return _workoutRoutinesBox.values.toList()
      ..sort((a, b) => (b.lastUsed ?? DateTime(1900)).compareTo(a.lastUsed ?? DateTime(1900)));
  }

  // Get workout routine by ID
  WorkoutRoutine? getWorkoutRoutineById(String id) {
    return _workoutRoutinesBox.get(id);
  }

  // ============ SAVED STRETCHES ============
  Future<void> saveSavedStretch(SavedStretch stretch) async {
    await _savedStretchesBox.put(stretch.id, stretch);
    notifyListeners();
  }

  Future<void> deleteSavedStretch(String id) async {
    await _savedStretchesBox.delete(id);
    notifyListeners();
  }

  List<SavedStretch> getAllSavedStretches() {
    return _savedStretchesBox.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  // ============ STRETCH ROUTINES ============
  Future<void> saveStretchRoutine(StretchRoutine routine) async {
    await _stretchRoutinesBox.put(routine.id, routine);
    notifyListeners();
  }

  Future<void> deleteStretchRoutine(String id) async {
    await _stretchRoutinesBox.delete(id);
    notifyListeners();
  }

  List<StretchRoutine> getAllStretchRoutines() {
    return _stretchRoutinesBox.values.toList()
      ..sort((a, b) => (b.lastUsed ?? DateTime(1900)).compareTo(a.lastUsed ?? DateTime(1900)));
  }

  // ============ WORKOUTS ============
  Future<void> saveWorkout(Workout workout) async {
    await _workoutsBox.put(workout.id, workout);
    notifyListeners();
  }

  Future<void> deleteWorkout(String id) async {
    await _workoutsBox.delete(id);
    notifyListeners();
  }

  List<Workout> getAllWorkouts() {
    return _workoutsBox.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  List<Workout> getWorkoutsForDate(DateTime date) {
    String dateKey = DateFormat('yyyy-MM-dd').format(date);
    return _workoutsBox.values
        .where((w) => DateFormat('yyyy-MM-dd').format(w.date) == dateKey)
        .toList();
  }

  List<Workout> getWorkoutsThisWeek() {
    DateTime now = DateTime.now();
    DateTime startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    startOfWeek = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    
    return _workoutsBox.values
        .where((w) => w.date.isAfter(startOfWeek.subtract(const Duration(days: 1))))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  int getTotalWorkoutMinutesThisWeek() {
    return getWorkoutsThisWeek()
        .fold(0, (sum, w) => sum + w.durationMinutes);
  }

  // Save a complete workout session
  Future<void> saveWorkoutSession({
    required String workoutName,
    required String workoutType,
    required List<Exercise> exercises,
    required int durationMinutes,
    String? routineId,
    String? notes,
  }) async {
    final workout = Workout(
      id: const Uuid().v4(),
      name: workoutName,
      type: workoutType,
      date: DateTime.now(),
      exercises: exercises,
      isCompleted: true,
      durationMinutes: durationMinutes,
      routineId: routineId,
      notes: notes,
    );
    await saveWorkout(workout);
  }

  // ============ WORKOUT HISTORY ============
  Future<void> saveWorkoutHistory(WorkoutHistory history) async {
    await _workoutHistoryBox.put(history.id, history);
    notifyListeners();
  }

  Future<void> deleteWorkoutHistory(String id) async {
    await _workoutHistoryBox.delete(id);
    notifyListeners();
  }

  List<WorkoutHistory> getAllWorkoutHistory() {
    return _workoutHistoryBox.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  List<WorkoutHistory> getRecentWorkouts(int count) {
    return getAllWorkoutHistory().take(count).toList();
  }

  Map<String, ExerciseHistory> getExerciseHistory() {
    final Map<String, ExerciseHistory> historyMap = {};
    
    // Get all workouts sorted by date (newest first)
    final workouts = getAllWorkouts();
    
    // Build history for each exercise by going through workouts from oldest to newest
    // so we can track progression correctly
    final sortedWorkouts = workouts.reversed.toList(); // oldest first
    
    for (final workout in sortedWorkouts) {
      for (final exercise in workout.exercises) {
        if (exercise.completedSets.isEmpty) continue;
        
        final exerciseName = exercise.name;
        final weights = exercise.completedSets.map((s) => s.weight).toList();
        final reps = exercise.completedSets.map((s) => s.reps).toList();
        
        // Calculate if all sets were completed and if rep goal was met
        final completedAllSets = exercise.completedSets.length >= exercise.targetSets;
        final maxTargetReps = exercise.maxReps;
        final metRepGoal = completedAllSets && reps.every((r) => r >= maxTargetReps);
        
        if (historyMap.containsKey(exerciseName)) {
          // Update existing history
          final existing = historyMap[exerciseName]!;
          final newConsecutiveGoalsMet = metRepGoal 
              ? existing.consecutiveGoalsMet + 1 
              : 0; // Reset if goal not met
          
          historyMap[exerciseName] = ExerciseHistory(
            exerciseName: exerciseName,
            reps: reps,
            weights: weights,
            completedAllSets: completedAllSets,
            metRepGoal: metRepGoal,
            sessionCount: existing.sessionCount + 1,
            lastWeight: weights.isNotEmpty ? weights.reduce((a, b) => a > b ? a : b) : 0,
            lastReps: reps.isNotEmpty ? reps.reduce((a, b) => a > b ? a : b) : 0,
            consecutiveGoalsMet: newConsecutiveGoalsMet,
          );
        } else {
          // Create new history entry
          historyMap[exerciseName] = ExerciseHistory(
            exerciseName: exerciseName,
            reps: reps,
            weights: weights,
            completedAllSets: completedAllSets,
            metRepGoal: metRepGoal,
            sessionCount: 1,
            lastWeight: weights.isNotEmpty ? weights.reduce((a, b) => a > b ? a : b) : 0,
            lastReps: reps.isNotEmpty ? reps.reduce((a, b) => a > b ? a : b) : 0,
            consecutiveGoalsMet: metRepGoal ? 1 : 0,
          );
        }
      }
    }
    
    return historyMap;
  }

  // Calculate workout streak from List<Workout>
  int calculateStreak(List<Workout> workouts) {
    if (workouts.isEmpty) return 0;
    
    int streak = 0;
    DateTime checkDate = DateTime.now();
    checkDate = DateTime(checkDate.year, checkDate.month, checkDate.day);
    
    // Get unique workout dates
    Set<String> workoutDates = {};
    for (var workout in workouts) {
      workoutDates.add(DateFormat('yyyy-MM-dd').format(workout.date));
    }
    
    // Check if worked out today or yesterday to start the streak
    String todayKey = DateFormat('yyyy-MM-dd').format(checkDate);
    String yesterdayKey = DateFormat('yyyy-MM-dd').format(checkDate.subtract(const Duration(days: 1)));
    
    if (!workoutDates.contains(todayKey) && !workoutDates.contains(yesterdayKey)) {
      return 0;
    }
    
    // If didn't work out today, start from yesterday
    if (!workoutDates.contains(todayKey)) {
      checkDate = checkDate.subtract(const Duration(days: 1));
    }
    
    // Count consecutive days
    while (workoutDates.contains(DateFormat('yyyy-MM-dd').format(checkDate))) {
      streak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }
    
    return streak;
  }

  // Calculate workout streak from List<WorkoutHistory>
  int calculateStreakFromHistory(List<WorkoutHistory> history) {
    if (history.isEmpty) return 0;
    
    int streak = 0;
    DateTime checkDate = DateTime.now();
    checkDate = DateTime(checkDate.year, checkDate.month, checkDate.day);
    
    // Get unique workout dates
    Set<String> workoutDates = {};
    for (var workout in history) {
      workoutDates.add(DateFormat('yyyy-MM-dd').format(workout.date));
    }
    
    // Check if worked out today or yesterday to start the streak
    String todayKey = DateFormat('yyyy-MM-dd').format(checkDate);
    String yesterdayKey = DateFormat('yyyy-MM-dd').format(checkDate.subtract(const Duration(days: 1)));
    
    if (!workoutDates.contains(todayKey) && !workoutDates.contains(yesterdayKey)) {
      return 0;
    }
    
    // If didn't work out today, start from yesterday
    if (!workoutDates.contains(todayKey)) {
      checkDate = checkDate.subtract(const Duration(days: 1));
    }
    
    // Count consecutive days
    while (workoutDates.contains(DateFormat('yyyy-MM-dd').format(checkDate))) {
      streak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }
    
    return streak;
  }

  // ============ WEIGHT ENTRIES ============
  Future<void> saveWeightEntry(WeightEntry entry) async {
    await _weightEntriesBox.put(entry.id, entry);
    notifyListeners();
  }

  Future<void> deleteWeightEntry(String id) async {
    await _weightEntriesBox.delete(id);
    notifyListeners();
  }

  List<WeightEntry> getAllWeightEntries() {
    return _weightEntriesBox.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  // Alias for getAllWeightEntries
  List<WeightEntry> getWeightEntries() {
    return getAllWeightEntries();
  }

  WeightEntry? getLatestWeightEntry() {
    if (_weightEntriesBox.isEmpty) return null;
    return getAllWeightEntries().first;
  }

  List<WeightEntry> getWeightEntriesThisWeek() {
    DateTime now = DateTime.now();
    DateTime startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    startOfWeek = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    
    return _weightEntriesBox.values
        .where((e) => e.date.isAfter(startOfWeek.subtract(const Duration(days: 1))))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  // ============ FOOD ENTRIES ============
  Future<void> saveFoodEntry(FoodEntry entry) async {
    await _foodEntriesBox.put(entry.id, entry);
    notifyListeners();
  }

  Future<void> deleteFoodEntry(String id) async {
    await _foodEntriesBox.delete(id);
    notifyListeners();
  }

  List<FoodEntry> getAllFoodEntries() {
    return _foodEntriesBox.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  List<FoodEntry> getFoodEntriesForDate(DateTime date) {
    String dateKey = DateFormat('yyyy-MM-dd').format(date);
    return _foodEntriesBox.values
        .where((e) => DateFormat('yyyy-MM-dd').format(e.date) == dateKey)
        .toList();
  }

  int getTotalCaloriesForDate(DateTime date) {
    return getFoodEntriesForDate(date)
        .fold(0, (sum, e) => sum + e.calories.toInt());
  }

  // Get daily nutrition summary
  DailyNutrition getDailyNutrition(DateTime date) {
    final entries = getFoodEntriesForDate(date);
    return DailyNutrition.fromEntries(date, entries);
  }

  // Get frequently used foods (last 6 unique foods)
  List<FoodEntry> getFrequentFoods() {
    final allEntries = getAllFoodEntries();
    final Map<String, FoodEntry> uniqueFoods = {};
    
    for (var entry in allEntries) {
      if (!uniqueFoods.containsKey(entry.name.toLowerCase())) {
        uniqueFoods[entry.name.toLowerCase()] = entry;
      }
      if (uniqueFoods.length >= 6) break;
    }
    
    return uniqueFoods.values.toList();
  }

  // ============ FOOD LIBRARY ============
  Future<void> saveFoodLibraryItem(FoodLibraryItem item) async {
    await _foodLibraryBox.put(item.id, item);
    notifyListeners();
  }

  Future<void> deleteFoodLibraryItem(String id) async {
    await _foodLibraryBox.delete(id);
    notifyListeners();
  }

  List<FoodLibraryItem> getAllFoodLibraryItems() {
    return _foodLibraryBox.values.toList()
      ..sort((a, b) => b.lastUsed.compareTo(a.lastUsed));
  }

  // Alias for getAllFoodLibraryItems
  List<FoodLibraryItem> getFoodLibrary() {
    return getAllFoodLibraryItems();
  }

  // Add item to food library (or update existing)
  Future<void> addToFoodLibrary({
    required String name,
    required double calories,
    double protein = 0,
    double carbs = 0,
    double fats = 0,
    double servingSize = 1,
    String servingUnit = 'serving',
  }) async {
    // Check if item already exists by name
    final existing = _foodLibraryBox.values.cast<FoodLibraryItem?>().firstWhere(
      (item) => item?.name.toLowerCase() == name.toLowerCase(),
      orElse: () => null,
    );

    if (existing != null) {
      // Update existing item
      final updated = existing.copyWith(
        calories: calories,
        protein: protein,
        carbs: carbs,
        fats: fats,
        servingSize: servingSize,
        servingUnit: servingUnit,
      );
      updated.lastUsed = DateTime.now();
      updated.useCount++;
      await _foodLibraryBox.put(existing.id, updated);
    } else {
      // Create new item
      final item = FoodLibraryItem(
        id: const Uuid().v4(),
        name: name,
        calories: calories,
        protein: protein,
        carbs: carbs,
        fats: fats,
        servingSize: servingSize,
        servingUnit: servingUnit,
      );
      await _foodLibraryBox.put(item.id, item);
    }
    notifyListeners();
  }

  // Mark food library item as used (update lastUsed and useCount)
  Future<void> markFoodLibraryItemUsed(String name) async {
    final item = _foodLibraryBox.values.cast<FoodLibraryItem?>().firstWhere(
      (i) => i?.name.toLowerCase() == name.toLowerCase(),
      orElse: () => null,
    );
    
    if (item != null) {
      item.lastUsed = DateTime.now();
      item.useCount++;
      await _foodLibraryBox.put(item.id, item);
      notifyListeners();
    }
  }

  // Reset food use count
  Future<void> resetFoodUseCount(String name) async {
    final item = _foodLibraryBox.values.cast<FoodLibraryItem?>().firstWhere(
      (i) => i?.name.toLowerCase() == name.toLowerCase(),
      orElse: () => null,
    );
    
    if (item != null) {
      item.useCount = 0;
      await _foodLibraryBox.put(item.id, item);
      notifyListeners();
    }
  }

  // ============ WATER ENTRIES ============
  Future<void> saveWaterEntry(WaterEntry entry) async {
    await _waterEntriesBox.put(entry.id, entry);
    notifyListeners();
  }

  Future<void> deleteWaterEntry(String id) async {
    await _waterEntriesBox.delete(id);
    notifyListeners();
  }

  List<WaterEntry> getWaterEntriesForDate(DateTime date) {
    String dateKey = DateFormat('yyyy-MM-dd').format(date);
    return _waterEntriesBox.values
        .where((e) => DateFormat('yyyy-MM-dd').format(e.date) == dateKey)
        .toList();
  }

  int getTotalWaterForDate(DateTime date) {
    return getWaterEntriesForDate(date)
        .fold(0, (sum, e) => sum + e.amountOz);
  }

  // Get daily water intake summary
  DailyWaterIntake getDailyWaterIntake(DateTime date) {
    final entries = getWaterEntriesForDate(date);
    final totalOz = entries.fold(0, (sum, e) => sum + e.amountOz);
    final goalOz = _settings.dailyWaterGoalOz;
    
    return DailyWaterIntake(
      date: date,
      totalOz: totalOz,
      goalOz: goalOz,
      entries: entries,
    );
  }

  // Quick add water entry
  Future<void> quickAddWater(int oz) async {
    final entry = WaterEntry(
      id: const Uuid().v4(),
      date: DateTime.now(),
      amountOz: oz,
    );
    await saveWaterEntry(entry);
  }

  // Clear water entries for a specific date
  Future<void> clearWaterEntriesForDate(DateTime date) async {
    String dateKey = DateFormat('yyyy-MM-dd').format(date);
    final entriesToDelete = _waterEntriesBox.values
        .where((e) => DateFormat('yyyy-MM-dd').format(e.date) == dateKey)
        .toList();
    
    for (var entry in entriesToDelete) {
      await _waterEntriesBox.delete(entry.id);
    }
    notifyListeners();
  }

  // ============ CHECKLIST ============
  List<ChecklistItem> getChecklistItems() {
    return _checklistItemsBox.values.toList()
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  // Save checklist item
  Future<void> saveChecklistItem(ChecklistItem item) async {
    await _checklistItemsBox.put(item.id, item);
    notifyListeners();
  }

  // Delete checklist item
  Future<void> deleteChecklistItem(String id) async {
    await _checklistItemsBox.delete(id);
    // Also delete any completion status for this item
    for (var key in _dailyChecklistStatusBox.keys) {
      Map<dynamic, dynamic>? dayStatus = _dailyChecklistStatusBox.get(key);
      if (dayStatus != null && dayStatus.containsKey(id)) {
        dayStatus.remove(id);
        await _dailyChecklistStatusBox.put(key, dayStatus);
      }
    }
    notifyListeners();
  }

  // Check if a specific checklist item is completed for a date
  bool isChecklistItemCompleted(String itemId, DateTime date) {
    String dateKey = _getDateKey(date);
    Map<dynamic, dynamic>? dayStatus = _dailyChecklistStatusBox.get(dateKey);
    if (dayStatus == null) return false;
    return dayStatus[itemId] == true;
  }

  Future<void> toggleChecklistItem(String itemId, DateTime date) async {
    String dateKey = _getDateKey(date);
    Map<dynamic, dynamic> dayStatus = Map<dynamic, dynamic>.from(_dailyChecklistStatusBox.get(dateKey) ?? {});
    dayStatus[itemId] = !(dayStatus[itemId] ?? false);
    await _dailyChecklistStatusBox.put(dateKey, dayStatus);
    notifyListeners();
  }

  int getCompletedChecklistCount(DateTime date) {
    String dateKey = _getDateKey(date);
    Map<dynamic, dynamic>? dayStatus = _dailyChecklistStatusBox.get(dateKey);
    if (dayStatus == null) return 0;
    return dayStatus.values.where((v) => v == true).length;
  }

  // ============ PHOTOS ============
  Future<String> savePhoto(File photo, String prefix) async {
    final directory = await getApplicationDocumentsDirectory();
    final photosDir = Directory('${directory.path}/photos');

    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }
    String fileName = '${prefix}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    String newPath = '${photosDir.path}/$fileName';
    await photo.copy(newPath);
    return newPath;
  }

  Future<void> deletePhoto(String path) async {
    try {
      File file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error deleting photo: $e');
    }
  }

  // ============ APP DATA ============
  Future<void> saveAppData(String key, dynamic value) async {
    await _appDataBox.put(key, value);
  }

  dynamic getAppData(String key) {
    return _appDataBox.get(key);
  }

  // ============ STEPS DATA ============
  Future<void> saveStepsData(DateTime date, int steps) async {
    String dateKey = _getDateKey(date);
    await _appDataBox.put('steps_$dateKey', steps);
    notifyListeners();
  }

  int? getStepsData(DateTime date) {
    String dateKey = _getDateKey(date);
    return _appDataBox.get('steps_$dateKey');
  }

  // ============ DATA MANAGEMENT ============
  Future<void> clearFoodHistory() async {
    await _foodEntriesBox.clear();
    notifyListeners();
  }

  Future<void> clearAllData() async {
    await _workoutsBox.clear();
    await _weightEntriesBox.clear();
    await _foodEntriesBox.clear();
    await _dailyChecklistStatusBox.clear();
    await _workoutHistoryBox.clear();
    await _savedExercisesBox.clear();
    await _workoutRoutinesBox.clear();
    await _cardioWorkoutsBox.clear();
    await _waterEntriesBox.clear();
    await _foodLibraryBox.clear();
    await _appDataBox.clear();

    // Clear stretch data
    await _savedStretchesBox.clear();
    await _stretchRoutinesBox.clear();

    _settings = UserSettings();
    await _userSettingsBox.put('settings', _settings);

    notifyListeners();
  }

  // ============ CARDIO WORKOUTS ============
  Future<void> saveCardioWorkout(CardioWorkout workout) async {
    await _cardioWorkoutsBox.put(workout.id, workout);
    notifyListeners();
  }

  Future<void> deleteCardioWorkout(String id) async {
    await _cardioWorkoutsBox.delete(id);
    notifyListeners();
  }

  List<CardioWorkout> getAllCardioWorkouts() {
    return _cardioWorkoutsBox.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  List<CardioWorkout> getCardioWorkoutsForDate(DateTime date) {
    String dateKey = DateFormat('yyyy-MM-dd').format(date);
    return _cardioWorkoutsBox.values
        .where((w) => DateFormat('yyyy-MM-dd').format(w.date) == dateKey)
        .toList();
  }

  List<CardioWorkout> getCardioWorkoutsThisWeek() {
    DateTime now = DateTime.now();
    DateTime startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    startOfWeek = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    
    return _cardioWorkoutsBox.values
        .where((w) => w.date.isAfter(startOfWeek.subtract(const Duration(days: 1))))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  int getTotalCardioCaloriesThisWeek() {
    return getCardioWorkoutsThisWeek()
        .fold(0, (sum, w) => sum + w.estimatedCalories);
  }

  int getTotalCardioMinutesThisWeek() {
    return getCardioWorkoutsThisWeek()
        .fold(0, (sum, w) => sum + w.durationMinutes);
  }

  CardioWorkout? getCardioWorkoutById(String id) {
    return _cardioWorkoutsBox.get(id);
  }

  // ============ STRETCH ROUTINE ORDER ============
  Future<void> saveStretchRoutineOrder(List<String> order) async {
    await _appDataBox.put('stretch_routine_order', order);
    notifyListeners();
  }

  List<String> getStretchRoutineOrder() {
    final order = _appDataBox.get('stretch_routine_order');
    if (order == null) return [];
    return List<String>.from(order);
  }

  // ============ WORKOUT ROTATION ORDER ============
  Future<void> saveWorkoutRotationOrder(List<String> order) async {
    await _appDataBox.put('workout_rotation_order', order);
    notifyListeners();
  }

  List<String> getWorkoutRotationOrder() {
    final order = _appDataBox.get('workout_rotation_order');
    if (order == null) return [];
    return List<String>.from(order);
  }

  /// Returns the next routine ID in the rotation after [lastRoutineId].
  /// Returns null if rotation is empty.
  String? getNextInRotation({required String? lastRoutineId}) {
    final order = getWorkoutRotationOrder();
    if (order.isEmpty) return null;
    if (lastRoutineId == null) return order.first;

    final index = order.indexOf(lastRoutineId);
    if (index == -1) return order.first;
    return order[(index + 1) % order.length];
  }

  /// Returns up to 3 routine IDs starting from the next in rotation.
  List<String> getRotationCircles({required String? lastRoutineId}) {
    final order = getWorkoutRotationOrder();
    if (order.isEmpty) return [];

    final nextId = getNextInRotation(lastRoutineId: lastRoutineId);
    if (nextId == null) return [];

    final startIndex = order.indexOf(nextId);
    final count = order.length.clamp(0, 3);
    final result = <String>[];
    for (int i = 0; i < count; i++) {
      result.add(order[(startIndex + i) % order.length]);
    }
    return result;
  }

  // Stretch-workout pairings
  Future<void> saveStretchPairing(String workoutRoutineId, {String? warmUpId, String? warmDownId}) async {
    final pairings = Map<String, dynamic>.from(_appDataBox.get('stretch_pairings') ?? {});
    pairings[workoutRoutineId] = {
      'warmUp': warmUpId,
      'warmDown': warmDownId,
    };
    await _appDataBox.put('stretch_pairings', pairings);
    notifyListeners();
  }

  Map<String, String?>? getStretchPairing(String workoutRoutineId) {
    final pairings = _appDataBox.get('stretch_pairings');
    if (pairings == null) return null;
    final map = Map<String, dynamic>.from(pairings);
    if (!map.containsKey(workoutRoutineId)) return null;
    final entry = Map<String, dynamic>.from(map[workoutRoutineId]);
    return {
      'warmUp': entry['warmUp'] as String?,
      'warmDown': entry['warmDown'] as String?,
    };
  }

  Future<void> removeStretchPairing(String workoutRoutineId) async {
    final pairings = Map<String, dynamic>.from(_appDataBox.get('stretch_pairings') ?? {});
    pairings.remove(workoutRoutineId);
    await _appDataBox.put('stretch_pairings', pairings);
    notifyListeners();
  }

  /// Checks if a stretch routine name matches a workout routine name using shared prefix logic.
  /// Matches workout and stretch names by finding a shared word prefix
  /// of at least 2 words. E.g., "Full Body Lift and Carry" and
  /// "Full Body Pre-Workout Warm-up" share "Full Body" (2 words).
  static bool stretchNameMatchesWorkout({
    required String workoutName,
    required String stretchName,
  }) {
    final workoutWords = workoutName.toLowerCase().trim().split(RegExp(r'\s+'));
    final stretchWords = stretchName.toLowerCase().trim().split(RegExp(r'\s+'));

    // Count shared prefix words
    int sharedWords = 0;
    bool hasCompoundWord = false;
    for (int i = 0; i < workoutWords.length && i < stretchWords.length; i++) {
      if (workoutWords[i] == stretchWords[i]) {
        sharedWords++;
        // Words with / or - are compound terms (e.g., "push/pull")
        if (workoutWords[i].contains('/') || workoutWords[i].contains('-')) {
          hasCompoundWord = true;
        }
      } else {
        break;
      }
    }

    // Require at least 2 shared prefix words, OR 1 if:
    // - the workout name is only 1 word, or
    // - the shared word is a compound term (contains / or -)
    return sharedWords >= 2 ||
        (sharedWords == 1 && (workoutWords.length == 1 || hasCompoundWord));
  }

  /// Finds the best matching warm-down stretch for a workout routine.
  /// Checks explicit pairings first, then falls back to name matching.
  String? findWarmDownStretch(String workoutRoutineId) {
    // Check explicit pairing first
    final pairing = getStretchPairing(workoutRoutineId);
    if (pairing != null && pairing['warmDown'] != null) {
      return pairing['warmDown'];
    }

    // Fall back to name matching
    final routines = getAllWorkoutRoutines();
    final workoutRoutine = routines.where((r) => r.id == workoutRoutineId).firstOrNull;
    if (workoutRoutine == null) return null;

    final stretches = getAllStretchRoutines();
    for (final stretch in stretches) {
      if (stretchNameMatchesWorkout(workoutName: workoutRoutine.name, stretchName: stretch.name)) {
        final nameLower = stretch.name.toLowerCase();
        if (nameLower.contains('warm down') || nameLower.contains('cooldown') || nameLower.contains('cool down') || nameLower.contains('cool-down') || nameLower.contains('post-workout')) {
          return stretch.id;
        }
      }
    }

    // If no warm-down found, return any name match
    for (final stretch in stretches) {
      if (stretchNameMatchesWorkout(workoutName: workoutRoutine.name, stretchName: stretch.name)) {
        return stretch.id;
      }
    }

    return null;
  }

  // Helper method
  String _getDateKey(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }
}
