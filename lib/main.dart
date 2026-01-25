import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'models/workout.dart';
import 'models/weight_entry.dart';
import 'models/food_entry.dart';
import 'models/checklist_item.dart';
import 'models/user_settings.dart';
import 'models/workout_history.dart';
import 'models/saved_exercise.dart';
import 'models/workout_routine.dart';
import 'models/cardio_workout.dart';
import 'models/water_entry.dart';
import 'models/food_library_item.dart';

// Stretch models
import 'models/saved_stretch.dart';
import 'models/stretch_routine.dart';

import 'services/storage_service.dart';
import 'services/step_tracking_service.dart';
import 'services/notification_service.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  await Hive.initFlutter();

  // Register Hive adapters

  // Workout related (typeId 0, 1, 2)
  Hive.registerAdapter(WorkoutAdapter());
  Hive.registerAdapter(ExerciseAdapter());
  Hive.registerAdapter(ExerciseSetAdapter());

  // Weight entry (typeId 3)
  Hive.registerAdapter(WeightEntryAdapter());

  // Food entry (typeId 4)
  Hive.registerAdapter(FoodEntryAdapter());

  // Checklist item (typeId 5)
  Hive.registerAdapter(ChecklistItemAdapter());

  // User settings (typeId 6)
  Hive.registerAdapter(UserSettingsAdapter());

  // Workout history (typeId 7, 8)
  Hive.registerAdapter(WorkoutHistoryAdapter());
  Hive.registerAdapter(ExerciseHistoryAdapter());

  // Saved exercise (typeId 9)
  Hive.registerAdapter(SavedExerciseAdapter());

  // Workout routine (typeId 10, 11)
  Hive.registerAdapter(WorkoutRoutineAdapter());
  Hive.registerAdapter(RoutineExerciseAdapter());

  // Cardio workout (typeId 12, 13)
  Hive.registerAdapter(CardioTypeAdapter());
  Hive.registerAdapter(CardioWorkoutAdapter());

  // Water entry (typeId 14)
  Hive.registerAdapter(WaterEntryAdapter());

  // Food library item (typeId 15)
  Hive.registerAdapter(FoodLibraryItemAdapter());

  // Stretch models (typeId 18, 19, 20)
  Hive.registerAdapter(SavedStretchAdapter());
  Hive.registerAdapter(StretchRoutineAdapter());
  Hive.registerAdapter(RoutineStretchAdapter());

  // Open Hive boxes
  await Hive.openBox<Workout>('workouts');
  await Hive.openBox<WeightEntry>('weight_entries');
  await Hive.openBox<FoodEntry>('food_entries');
  await Hive.openBox<ChecklistItem>('checklist_items');
  await Hive.openBox('daily_checklist_status');
  await Hive.openBox<UserSettings>('user_settings');
  await Hive.openBox<WorkoutHistory>('workout_history');
  await Hive.openBox<SavedExercise>('saved_exercises');
  await Hive.openBox<WorkoutRoutine>('workout_routines');
  await Hive.openBox<CardioWorkout>('cardio_workouts');
  await Hive.openBox<WaterEntry>('water_entries');
  await Hive.openBox<FoodLibraryItem>('food_library');
  await Hive.openBox('app_data');

  // Open stretch boxes
  await Hive.openBox<SavedStretch>('saved_stretches');
  await Hive.openBox<StretchRoutine>('stretch_routines');

  // Initialize notification service
  await NotificationService().initialize();

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const HealthTrackerApp());
}

class HealthTrackerApp extends StatelessWidget {
  const HealthTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => StorageService()),
        ChangeNotifierProvider(create: (_) => StepTrackingService()),
        ChangeNotifierProvider(create: (_) => NotificationService()),
      ],
      child: MaterialApp(
        title: 'Health Tracker',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const HomeScreen(),
      ),
    );
  }
}
