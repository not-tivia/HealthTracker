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

    _isInitialized = true;
    notifyListeners();
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

  // ============ SAVED STRETCHES ============ (NEW)
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

  // ============ STRETCH ROUTINES ============ (NEW)
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

  /// Get exercise history by analyzing all completed workouts
  /// Returns a map of exercise name -> ExerciseHistory with stats
  /// Checks BOTH Workout box AND WorkoutHistory box for comprehensive data
  Map<String, ExerciseHistory> getExerciseHistory() {
    final Map<String, ExerciseHistory> historyMap = {};
    final Map<String, List<_ExerciseSessionData>> sessionsByExercise = {};
    
    // ===== PART 1: Check WorkoutHistory box (older storage format) =====
    final workoutHistories = getAllWorkoutHistory();
    for (final history in workoutHistories) {
      for (final exercise in history.exercises) {
        if (exercise.weights.isEmpty || exercise.reps.isEmpty) continue;
        
        final name = exercise.exerciseName;
        sessionsByExercise.putIfAbsent(name, () => []);
        
        final nonZeroWeights = exercise.weights.where((w) => w > 0).toList();
        if (nonZeroWeights.isEmpty) continue;
        
        final avgWeight = nonZeroWeights.reduce((a, b) => a + b) / nonZeroWeights.length;
        final avgReps = exercise.reps.isNotEmpty 
            ? exercise.reps.reduce((a, b) => a + b) / exercise.reps.length 
            : 0.0;
        
        // Default to 8 if we can't determine target
        final minTargetReps = 8;
        final metGoal = avgReps >= minTargetReps && exercise.completedAllSets;
        
        sessionsByExercise[name]!.add(_ExerciseSessionData(
          date: history.date,
          weights: exercise.weights,
          reps: exercise.reps,
          avgWeight: avgWeight,
          avgReps: avgReps,
          metGoal: metGoal,
          minTargetReps: minTargetReps,
        ));
      }
    }
    
    // ===== PART 2: Check Workout box (newer storage format) =====
    final workouts = getAllWorkouts();
    for (final workout in workouts) {
      for (final exercise in workout.exercises) {
        if (exercise.completedSets.isEmpty) continue;
        
        final name = exercise.name;
        sessionsByExercise.putIfAbsent(name, () => []);
        
        // Calculate stats for this session
        final weights = exercise.completedSets.map((s) => s.weight).toList();
        final reps = exercise.completedSets.map((s) => s.reps).toList();
        final nonZeroWeights = weights.where((w) => w > 0).toList();
        
        if (nonZeroWeights.isEmpty) continue;
        
        final avgWeight = nonZeroWeights.reduce((a, b) => a + b) / nonZeroWeights.length;
        final avgReps = reps.isNotEmpty ? reps.reduce((a, b) => a + b) / reps.length : 0.0;
        final minTargetReps = exercise.minReps;
        
        // Session met goal if average reps >= minimum target reps
        final metGoal = avgReps >= minTargetReps;
        
        sessionsByExercise[name]!.add(_ExerciseSessionData(
          date: workout.date,
          weights: weights.map((w) => w).toList(),
          reps: reps,
          avgWeight: avgWeight,
          avgReps: avgReps,
          metGoal: metGoal,
          minTargetReps: minTargetReps,
        ));
      }
    }
    
    // ===== PART 3: Build ExerciseHistory for each exercise =====
    for (final entry in sessionsByExercise.entries) {
      final name = entry.key;
      final sessions = entry.value;
      
      if (sessions.isEmpty) continue;
      
      // Sort sessions by date (newest first)
      sessions.sort((a, b) => b.date.compareTo(a.date));
      
      final latestSession = sessions.first;
      
      // Count consecutive goals met (from most recent going backwards)
      int consecutiveGoalsMet = 0;
      for (final session in sessions) {
        if (session.metGoal) {
          consecutiveGoalsMet++;
        } else {
          break; // Stop counting at first failure
        }
      }
      
      // Get the weight to use (max weight from latest session)
      final latestWeights = latestSession.weights.where((w) => w > 0).toList();
      final lastWeight = latestWeights.isNotEmpty 
          ? latestWeights.reduce((a, b) => a > b ? a : b) 
          : 0.0;
      
      historyMap[name] = ExerciseHistory(
        exerciseName: name,
        reps: latestSession.reps,
        weights: latestSession.weights,
        completedAllSets: true,
        metRepGoal: latestSession.metGoal,
        sessionCount: sessions.length,
        lastWeight: lastWeight,
        lastReps: latestSession.avgReps.round(),
        consecutiveGoalsMet: consecutiveGoalsMet,
      );
    }
    
    return historyMap;
  }
  
  /// Find exercise history with case-insensitive name matching
  /// Use this if exact name matching fails
  ExerciseHistory? findExerciseHistory(String exerciseName) {
    final allHistory = getExerciseHistory();
    
    // Try exact match first
    if (allHistory.containsKey(exerciseName)) {
      return allHistory[exerciseName];
    }
    
    // Try case-insensitive match
    final lowerName = exerciseName.toLowerCase();
    for (final entry in allHistory.entries) {
      if (entry.key.toLowerCase() == lowerName) {
        return entry.value;
      }
    }
    
    // Try partial match (for variations like "Bench Press" vs "Barbell Bench Press")
    for (final entry in allHistory.entries) {
      if (entry.key.toLowerCase().contains(lowerName) || 
          lowerName.contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }
    
    return null;
  }
  
  /// Debug method: Get all exercise names in history
  List<String> getExerciseHistoryNames() {
    return getExerciseHistory().keys.toList();
  }
  
  /// Get weight entries sorted by date (newest first)
  List<WeightEntry> getWeightEntries() {
    return _weightEntriesBox.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
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
        .fold(0.0, (sum, e) => sum + e.calories).toInt();
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
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
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

  // ============ CHECKLIST ============
  List<ChecklistItem> getChecklistItems() {
    return _checklistItemsBox.values.toList()
      ..sort((a, b) => a.order.compareTo(b.order));
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

    // NEW: Clear stretch data
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

  // Helper method (assuming it's defined somewhere; included for completeness)
  String _getDateKey(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  // ============ MISSING WATER METHODS ============
  
  /// Get daily water intake with all stats
  DailyWaterIntake getDailyWaterIntake(DateTime date) {
    final entries = getWaterEntriesForDate(date);
    final totalOz = entries.fold(0, (sum, e) => sum + e.amountOz);
    return DailyWaterIntake(
      date: date,
      totalOz: totalOz,
      goalOz: _settings.dailyWaterGoalOz,
      entries: entries,
    );
  }

  /// Quick add water entry
  Future<void> quickAddWater(int oz) async {
    final entry = WaterEntry(
      id: const Uuid().v4(),
      date: DateTime.now(),
      amountOz: oz,
    );
    await saveWaterEntry(entry);
  }

  /// Clear water entries for a specific date
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

  // ============ MISSING CHECKLIST METHODS ============

  /// Save checklist item
  Future<void> saveChecklistItem(ChecklistItem item) async {
    await _checklistItemsBox.put(item.id, item);
    notifyListeners();
  }

  /// Delete checklist item
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

  /// Check if a specific checklist item is completed for a date
  bool isChecklistItemCompleted(String itemId, DateTime date) {
    String dateKey = _getDateKey(date);
    Map<dynamic, dynamic>? dayStatus = _dailyChecklistStatusBox.get(dateKey);
    if (dayStatus == null) return false;
    return dayStatus[itemId] == true;
  }

  // ============ MISSING FOOD/NUTRITION METHODS ============

  /// Get daily nutrition totals
  DailyNutrition getDailyNutrition(DateTime date) {
    final entries = getFoodEntriesForDate(date);
    return DailyNutrition.fromEntries(date, entries);
  }

  /// Get frequent foods sorted by usage
  List<FoodEntry> getFrequentFoods() {
    final entries = getAllFoodEntries();
    // Sort by useCount descending, take top 10
    entries.sort((a, b) => b.useCount.compareTo(a.useCount));
    return entries.take(10).toList();
  }

  /// Add to food library (or update if exists)
  Future<void> addToFoodLibrary({
    required String name,
    required double calories,
    double protein = 0,
    double carbs = 0,
    double fats = 0,
    double servingSize = 1,
    String servingUnit = 'serving',
  }) async {
    // Check if item already exists
    FoodLibraryItem? existing;
    try {
      existing = _foodLibraryBox.values.firstWhere(
        (item) => item.name.toLowerCase() == name.toLowerCase(),
      );
    } catch (_) {
      existing = null;
    }

    if (existing != null) {
      // Update existing item
      existing.lastUsed = DateTime.now();
      existing.useCount++;
      await existing.save();
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

  /// Get food library sorted by recent use
  List<FoodLibraryItem> getFoodLibrary() {
    return _foodLibraryBox.values.toList()
      ..sort((a, b) {
        // Sort by useCount first, then by lastUsed
        if (b.useCount != a.useCount) {
          return b.useCount.compareTo(a.useCount);
        }
        return b.lastUsed.compareTo(a.lastUsed);
      });
  }

  /// Mark a food library item as used
  Future<void> markFoodLibraryItemUsed(String name) async {
    try {
      final item = _foodLibraryBox.values.firstWhere(
        (item) => item.name.toLowerCase() == name.toLowerCase(),
      );
      item.lastUsed = DateTime.now();
      item.useCount++;
      await item.save();
      notifyListeners();
    } catch (_) {
      // Item not found, ignore
    }
  }

  /// Reset food use count (for removing from quick-add)
  Future<void> resetFoodUseCount(String name) async {
    try {
      final item = _foodLibraryBox.values.firstWhere(
        (item) => item.name.toLowerCase() == name.toLowerCase(),
      );
      item.useCount = 0;
      await item.save();
      notifyListeners();
    } catch (_) {
      // Item not found, ignore
    }
  }

  // ============ MISSING EXERCISE/WORKOUT METHODS ============

  /// Get saved exercise by ID
  SavedExercise? getSavedExerciseById(String id) {
    return _savedExercisesBox.get(id);
  }

  /// Increment exercise usage count
  Future<void> incrementExerciseUsage(String id) async {
    final exercise = _savedExercisesBox.get(id);
    if (exercise != null) {
      final updated = exercise.copyWith(timesUsed: exercise.timesUsed + 1);
      await _savedExercisesBox.put(id, updated);
      notifyListeners();
    }
  }

  /// Get workout routine by ID
  WorkoutRoutine? getWorkoutRoutineById(String id) {
    return _workoutRoutinesBox.get(id);
  }

  /// Save a complete workout session
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

  /// Calculate workout streak from List<Workout>
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
}

/// Helper class for tracking exercise session data during history calculation
class _ExerciseSessionData {
  final DateTime date;
  final List<double> weights;
  final List<int> reps;
  final double avgWeight;
  final double avgReps;
  final bool metGoal;
  final int minTargetReps;
  
  _ExerciseSessionData({
    required this.date,
    required this.weights,
    required this.reps,
    required this.avgWeight,
    required this.avgReps,
    required this.metGoal,
    required this.minTargetReps,
  });
}