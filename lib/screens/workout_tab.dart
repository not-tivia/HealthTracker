import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:path_provider/path_provider.dart';

import '../models/workout.dart';
import '../models/user_settings.dart';
import '../models/saved_exercise.dart';
import '../models/workout_routine.dart';
import '../models/workout_history.dart';
import '../models/cardio_workout.dart';
import '../services/storage_service.dart';
import '../services/routine_import_export_service.dart';
import '../theme/app_theme.dart';
import '../widgets/cardio_tracking_dialog.dart';
import 'workout_session_screen.dart';
import '../models/saved_stretch.dart';
import '../models/stretch_routine.dart';
import 'stretch_session_screen.dart';


/// Unified activity item that can be either a strength workout or cardio
class ActivityItem {
  final DateTime date;
  final bool isCardio;
  final Workout? workout;
  final CardioWorkout? cardioWorkout;

  ActivityItem.workout(this.workout)
      : date = workout!.date,
        isCardio = false,
        cardioWorkout = null;

  ActivityItem.cardio(this.cardioWorkout)
      : date = cardioWorkout!.date,
        isCardio = true,
        workout = null;

  String get displayName =>
      isCardio ? cardioWorkout!.type.displayName : workout!.name;

  int get durationMinutes =>
      isCardio ? cardioWorkout!.durationMinutes : workout!.durationMinutes;
}

class WorkoutTab extends StatefulWidget {
  const WorkoutTab({super.key});

  @override
  State<WorkoutTab> createState() => _WorkoutTabState();
}

class _WorkoutTabState extends State<WorkoutTab> {
  List<SavedStretch> _stretches = [];
  List<StretchRoutine> _stretchRoutines = [];

  List<Workout> _workouts = [];
  List<WorkoutRoutine> _routines = [];
  List<SavedExercise> _exercises = [];
  List<CardioWorkout> _cardioWorkouts = [];
  UserSettings? _settings;
  Map<String, ExerciseHistory>? _exerciseHistory;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final storage = context.read<StorageService>();

      int retries = 0;
      while (!storage.isInitialized && retries < 10) {
        await Future.delayed(const Duration(milliseconds: 200));
        retries++;
      }

      if (!storage.isInitialized) {
        throw Exception('Storage service not initialized');
      }

      List<Workout> workouts = [];
      List<WorkoutRoutine> routines = [];
      List<SavedExercise> exercises = [];
      List<SavedStretch> stretches = [];
      List<StretchRoutine> stretchRoutines = [];
      Map<String, ExerciseHistory> history = {};
      UserSettings? settings;
      List<CardioWorkout> cardioWorkouts = [];

      try {
        workouts = storage.getAllWorkouts();
      } catch (e) {
        debugPrint('Error loading workouts: $e');
      }

      try {
        settings = await storage.getUserSettings();
      } catch (e) {
        debugPrint('Error loading settings: $e');
        settings = UserSettings();
      }

      try {
        routines = storage.getAllWorkoutRoutines();
      } catch (e) {
        debugPrint('Error loading routines: $e');
      }

      try {
        exercises = storage.getAllSavedExercises();
      } catch (e) {
        debugPrint('Error loading exercises: $e');
      }

      try {
        stretches = storage.getAllSavedStretches();
      } catch (e) {
        debugPrint('Error loading stretches: $e');
      }

      try {
        stretchRoutines = storage.getAllStretchRoutines();
      } catch (e) {
        debugPrint('Error loading stretch routines: $e');
      }

      try {
        history = await storage.getExerciseHistory();
      } catch (e) {
        debugPrint('Error loading history: $e');
      }

      try {
        cardioWorkouts = storage.getAllCardioWorkouts();
      } catch (e) {
        debugPrint('Error loading cardio workouts: $e');
      }

      if (mounted) {
        setState(() {
          _workouts = workouts;
          _settings = settings ?? UserSettings();
          _routines = routines;
          _exercises = exercises;
          _stretches = stretches;
          _stretchRoutines = stretchRoutines;
          _exerciseHistory = history;
          _cardioWorkouts = cardioWorkouts;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error in _loadData: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
          _settings = UserSettings();
        });
      }
    }
  }

  /// Weekly workout count - only strength workouts, NOT cardio
  int get _weeklyWorkoutCount {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startDate =
        DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    return _workouts.where((w) => w.date.isAfter(startDate)).length;
  }

  /// Weekday completions - only strength workouts, NOT cardio
  Map<int, bool> get _weekdayCompletions {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final completions = <int, bool>{};
    for (int i = 1; i <= 7; i++) {
      final day = DateTime(
          startOfWeek.year, startOfWeek.month, startOfWeek.day + i - 1);
      completions[i] = _workouts.any((w) =>
          w.date.year == day.year &&
          w.date.month == day.month &&
          w.date.day == day.day);
    }
    return completions;
  }

  /// Recent activities - combined strength workouts AND cardio, sorted by date
  List<ActivityItem> get _recentActivities {
    final activities = <ActivityItem>[];

    for (final workout in _workouts) {
      activities.add(ActivityItem.workout(workout));
    }

    for (final cardio in _cardioWorkouts) {
      activities.add(ActivityItem.cardio(cardio));
    }

    activities.sort((a, b) => b.date.compareTo(a.date));
    return activities.take(10).toList();
  }

  SavedStretch? _getStretchById(String id) {
    try {
      return _stretches.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return _buildErrorView();
    }

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadData,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: constraints.maxWidth > 600 ? 24 : 16,
                vertical: 16,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    _buildWeeklyGoalCard(constraints),
                    const SizedBox(height: 20),
                    _buildThisWeekCard(),
                    const SizedBox(height: 20),
                    _buildStartWorkoutButton(),
                    const SizedBox(height: 12),
                    _buildImportExportButtons(),
                    const SizedBox(height: 24),
                    _buildWarmupStretchesSection(),  // â† ADD THIS
                    const SizedBox(height: 24),       // â† ADD THIS
                    _buildMyRoutinesSection(),
                    const SizedBox(height: 24),
                    _buildMyExercisesSection(),
                    const SizedBox(height: 24),
                    _buildRecentActivitiesSection(),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
              const SizedBox(height: 16),
              Text('Error loading workouts',
                  style: TextStyle(color: Colors.grey.shade400)),
              const SizedBox(height: 4),
              Flexible(
                child: Text(
                  _errorMessage ?? 'Unknown error',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                children: [
                  TextButton(onPressed: _loadData, child: const Text('Retry')),
                  TextButton(
                    onPressed: _showClearCacheDialog,
                    style:
                        TextButton.styleFrom(foregroundColor: Colors.orange),
                    child: const Text('Clear Cache'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeeklyGoalCard(BoxConstraints constraints) {
    final weeklyGoal = _settings?.weeklyWorkoutGoal ?? 4;
    final progress = _weeklyWorkoutCount / weeklyGoal;
    final bestStreak = _settings?.bestStreak ?? 0;
    final currentStreak = context.read<StorageService>().calculateStreak(_workouts);
    final isCompact = constraints.maxWidth < 360;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(isCompact ? 12 : 20),
        child: isCompact
            ? Column(
                children: [
                  _buildProgressIndicator(weeklyGoal, progress),
                  const SizedBox(height: 16),
                  _buildGoalInfo(weeklyGoal, progress, currentStreak, bestStreak),
                ],
              )
            : Row(
                children: [
                  GestureDetector(
                    onTap: _showEditGoalDialog,
                    child: _buildProgressIndicator(weeklyGoal, progress),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: _buildGoalInfo(
                        weeklyGoal, progress, currentStreak, bestStreak),
                  ),
                  IconButton(
                    onPressed: _showEditGoalDialog,
                    icon: Icon(Icons.edit, color: Colors.grey.shade500),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildProgressIndicator(int weeklyGoal, double progress) {
    return CircularPercentIndicator(
      radius: 50,
      lineWidth: 10,
      percent: progress.clamp(0, 1),
      center: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$_weeklyWorkoutCount/$weeklyGoal',
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text('this week',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
        ],
      ),
      progressColor: AppTheme.primaryColor,
      backgroundColor: Colors.grey.shade800,
      circularStrokeCap: CircularStrokeCap.round,
    );
  }

  Widget _buildGoalInfo(
    int weeklyGoal, double progress, int currentStreak, int bestStreak) {
  final remaining = weeklyGoal - _weeklyWorkoutCount;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        'Weekly Goal',
        style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      ),
      const SizedBox(height: 4),

      // âœ… FIXED TEXT
      Text(
        progress >= 1
            ? '\u{1F389} Goal achieved!'
            : remaining == 1
                ? '1 more to go!'
                : '$remaining more to go!',
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        maxLines: 2,           // âœ… allow wrap
        softWrap: true,        // âœ… allow wrap
      ),

      const SizedBox(height: 10),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          _buildStreakBadge('\u{1F525}', currentStreak, 'Current'),
          _buildStreakBadge('\u{1F3C6}', bestStreak, 'Best'),
        ],
      ),
    ],
  );
}

  Widget _buildStreakBadge(String emoji, int value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: Colors.grey.shade800, borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 3),
          Text('$value', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildThisWeekCard() {
    final weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final completions = _weekdayCompletions;
    final today = DateTime.now().weekday;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This Week',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = (constraints.maxWidth - 48) / 7;
                final circleSize = itemWidth.clamp(28.0, 36.0);

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(7, (index) {
                    final dayNum = index + 1;
                    final isCompleted = completions[dayNum] ?? false;
                    final isToday = dayNum == today;
                    return Column(
                      children: [
                        Text(weekdays[index],
                            style: TextStyle(
                                color: isToday
                                    ? AppTheme.primaryColor
                                    : Colors.grey.shade500,
                                fontWeight:
                                    isToday ? FontWeight.bold : FontWeight.normal,
                                fontSize: 12)),
                        const SizedBox(height: 8),
                        Container(
                          width: circleSize,
                          height: circleSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isCompleted
                                ? AppTheme.primaryColor
                                : Colors.grey.shade800,
                            border: isToday && !isCompleted
                                ? Border.all(color: AppTheme.primaryColor, width: 2)
                                : null,
                          ),
                          child: isCompleted
                              ? Icon(Icons.check, size: circleSize * 0.55, color: Colors.white)
                              : null,
                        ),
                      ],
                    );
                  }),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStartWorkoutButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _showStartWorkoutOptions,
        icon: const Icon(Icons.add, size: 28),
        label: const Text('Start New Workout',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  Widget _buildImportExportButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _showImportDialog,
            icon: const Icon(Icons.download, size: 20),
            label: const Text('Import Routine'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey.shade300,
              side: BorderSide(color: Colors.grey.shade700),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _showExportDialog,
            icon: const Icon(Icons.upload, size: 20),
            label: const Text('Export Routine'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey.shade300,
              side: BorderSide(color: Colors.grey.shade700),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  // ============ IMPORT/EXPORT METHODS ============

  void _showImportDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Import Routine',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.folder_open, color: AppTheme.primaryColor),
                ),
                title: const Text('Choose File'),
                subtitle: const Text('Select a .json file'),
                onTap: () async {
                  Navigator.pop(context);
                  await _importFromFile();
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.content_paste, color: Colors.blue),
                ),
                title: const Text('Paste JSON'),
                subtitle: const Text('Paste routine data'),
                onTap: () {
                  Navigator.pop(context);
                  _showPasteJsonDialog();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _importFromFile() async {
    final jsonString = await RoutineImportExportService.pickJsonFile();
    if (jsonString == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No file selected')),
        );
      }
      return;
    }
    await _processImportJson(jsonString);
  }

  void _showPasteJsonDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Paste Routine JSON'),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: controller,
            maxLines: 10,
            decoration: InputDecoration(
              hintText: 'Paste your routine JSON here...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              if (controller.text.trim().isNotEmpty) {
                _processImportJson(controller.text.trim());
              }
            },
            child: const Text('Import'),
          ),
        ],
      ),
    );
  }

  Future<void> _processImportJson(String jsonString) async {
    final storage = context.read<StorageService>();
    final preview = RoutineImportExportService.parseImportJson(
      jsonString,
      _exercises,
      _stretches,
    );

    if (preview.hasError) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(preview.error!),
            backgroundColor: Colors.red.shade400,
          ),
        );
      }
      return;
    }

    if (mounted) {
      _showImportPreviewDialog(preview, storage);
    }
  }

  void _showImportPreviewDialog(ImportPreview preview, StorageService storage) {
    final nameController = TextEditingController(text: preview.routineName);
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            preview.isWorkoutRoutine ? 'Import Workout Routine' : 'Import Stretch Routine',
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Routine Name:', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (preview.isWorkoutRoutine) ...[
                    Text(
                      '${preview.exercises.length} exercises:',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    ...preview.exercises.map((e) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Icon(
                            e.existsLocally ? Icons.check_circle : Icons.add_circle,
                            size: 16,
                            color: e.existsLocally ? Colors.green : AppTheme.primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              e.name,
                              style: TextStyle(
                                color: e.existsLocally ? Colors.grey.shade400 : Colors.white,
                              ),
                            ),
                          ),
                          if (!e.existsLocally)
                            Text(
                              '(new)',
                              style: TextStyle(color: AppTheme.primaryColor, fontSize: 12),
                            ),
                        ],
                      ),
                    )),
                    const SizedBox(height: 12),
                    if (preview.existingExerciseCount > 0)
                      Text(
                        '${preview.existingExerciseCount} exercises already exist and will use your existing data.',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                      ),
                    if (preview.newExerciseCount > 0)
                      Text(
                        '${preview.newExerciseCount} new exercises will be created.',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                      ),
                  ] else ...[
                    Text(
                      '${preview.stretches.length} stretches:',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    ...preview.stretches.map((s) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Icon(
                            s.existsLocally ? Icons.check_circle : Icons.add_circle,
                            size: 16,
                            color: s.existsLocally ? Colors.green : AppTheme.primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              s.name,
                              style: TextStyle(
                                color: s.existsLocally ? Colors.grey.shade400 : Colors.white,
                              ),
                            ),
                          ),
                          if (!s.existsLocally)
                            Text(
                              '(new)',
                              style: TextStyle(color: AppTheme.primaryColor, fontSize: 12),
                            ),
                        ],
                      ),
                    )),
                    const SizedBox(height: 12),
                    if (preview.existingStretchCount > 0)
                      Text(
                        '${preview.existingStretchCount} stretches already exist and will use your existing data.',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                      ),
                    if (preview.newStretchCount > 0)
                      Text(
                        '${preview.newStretchCount} new stretches will be created.',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                      ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(context);
                final error = await RoutineImportExportService.executeImport(
                  preview,
                  nameController.text.trim(),
                  storage,
                );
                if (mounted) {
                  if (error == null) {
                    final newCount = preview.isWorkoutRoutine
                        ? preview.newExerciseCount
                        : preview.newStretchCount;
                    final itemType = preview.isWorkoutRoutine ? 'exercises' : 'stretches';
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Imported "${nameController.text.trim()}" with $newCount new $itemType',
                        ),
                        backgroundColor: Colors.green.shade400,
                      ),
                    );
                    _loadData();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(error), backgroundColor: Colors.red.shade400),
                    );
                  }
                }
              },
              child: const Text('Import'),
            ),
          ],
        ),
      ),
    );
  }

  void _showExportDialog() {
    if (_routines.isEmpty && _stretchRoutines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No routines to export')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Routine to Export',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: [
                      if (_routines.isNotEmpty) ...[
                        Text(
                          'WORKOUT ROUTINES',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ..._routines.map((routine) => ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: routine.colorHex != null
                                  ? Color(int.parse('FF${routine.colorHex}', radix: 16)).withOpacity(0.2)
                                  : AppTheme.primaryColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.fitness_center, size: 20),
                          ),
                          title: Text(routine.name),
                          subtitle: Text('${routine.exercises.length} exercises'),
                          onTap: () {
                            Navigator.pop(context);
                            _showExportOptionsDialog(
                              routineName: routine.name,
                              jsonString: RoutineImportExportService.exportWorkoutRoutine(routine, _exercises),
                            );
                          },
                        )),
                        const SizedBox(height: 16),
                      ],
                      if (_stretchRoutines.isNotEmpty) ...[
                        Text(
                          'STRETCH ROUTINES',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ..._stretchRoutines.map((routine) => ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: routine.colorHex != null
                                  ? Color(int.parse('FF${routine.colorHex}', radix: 16)).withOpacity(0.2)
                                  : Colors.teal.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.self_improvement, size: 20),
                          ),
                          title: Text(routine.name),
                          subtitle: Text('${routine.stretches.length} stretches'),
                          onTap: () {
                            Navigator.pop(context);
                            _showExportOptionsDialog(
                              routineName: routine.name,
                              jsonString: RoutineImportExportService.exportStretchRoutine(routine, _stretches),
                            );
                          },
                        )),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showExportOptionsDialog({
    required String routineName,
    required String jsonString,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Export "$routineName"',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.share, color: Colors.blue),
                ),
                title: const Text('Share'),
                subtitle: const Text('Send via apps'),
                onTap: () async {
                  Navigator.pop(context);
                  await RoutineImportExportService.shareJson(jsonString, routineName);
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.save_alt, color: Colors.green),
                ),
                title: const Text('Save to Downloads'),
                subtitle: const Text('Save as .json file'),
                onTap: () async {
                  Navigator.pop(context);
                  final path = await RoutineImportExportService.saveToDownloads(jsonString, routineName);
                  if (mounted) {
                    if (path != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Saved to: ${path.split('/').last}'),
                          backgroundColor: Colors.green.shade400,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Failed to save file'),
                          backgroundColor: Colors.red.shade400,
                        ),
                      );
                    }
                  }
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.copy, color: Colors.purple),
                ),
                title: const Text('Copy to Clipboard'),
                subtitle: const Text('Copy raw JSON'),
                onTap: () async {
                  Navigator.pop(context);
                  await RoutineImportExportService.copyToClipboard(jsonString);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Copied to clipboard'),
                        backgroundColor: Colors.green.shade400,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _exportRoutine(WorkoutRoutine routine) {
    final jsonString = RoutineImportExportService.exportWorkoutRoutine(routine, _exercises);
    _showExportOptionsDialog(routineName: routine.name, jsonString: jsonString);
  }

  Widget _buildMyRoutinesSection() {
    if (_routines.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Flexible(
              child: Text('My Routines',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis),
            ),
            Text('${_routines.length} routines',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 110, // Increased from 100 to give more room
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _routines.length,
            itemBuilder: (context, index) => _buildRoutineCard(_routines[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildRoutineCard(WorkoutRoutine routine) {
    final color = routine.colorHex != null
        ? Color(int.parse('FF${routine.colorHex}', radix: 16))
        : AppTheme.primaryColor;
    return GestureDetector(
      onTap: () => _startRoutine(routine),
      onLongPress: () => _showRoutineOptions(routine),
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(10), // Reduced padding from 12 to 10
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween, // Use spaceBetween instead of Spacer
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(5), // Reduced from 6
                decoration: BoxDecoration(
                    color: color.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.fitness_center, color: color, size: 14), // Reduced from 16
              ),
              const Spacer(),
              Icon(Icons.play_arrow, color: color, size: 18), // Reduced from 20
            ]),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(routine.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text('${routine.exercises.length} exercises',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyExercisesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Flexible(
              child: Text('My Exercises',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis),
            ),
            Text('${_exercises.length} exercises',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 12),
        if (_exercises.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(12)),
            child: Center(
              child: Column(children: [
                Icon(Icons.fitness_center, size: 48, color: Colors.grey.shade600),
                const SizedBox(height: 12),
                Text('No exercises yet',
                    style: TextStyle(color: Colors.grey.shade500)),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _showCreateExerciseDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Create Exercise'),
                ),
              ]),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ..._exercises.take(6).map((e) => _buildExerciseChip(e)),
              if (_exercises.length > 6) _buildSeeAllChip(),
            ],
          ),
      ],
    );
  }

  Widget _buildExerciseChip(SavedExercise exercise) {
    final history = _exerciseHistory?[exercise.name];
    final shouldIncrease = history != null && history.consecutiveGoalsMet >= 3;

    return GestureDetector(
      onTap: () => _showExerciseDetails(exercise),
      onLongPress: () => _showExerciseOptions(exercise),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: shouldIncrease
              ? AppTheme.successColor.withOpacity(0.15)
              : AppTheme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: shouldIncrease
                  ? AppTheme.successColor.withOpacity(0.5)
                  : AppTheme.cardColorLight),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (exercise.photoPath != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.file(File(exercise.photoPath!),
                    width: 24, height: 24, fit: BoxFit.cover),
              )
            else
              Icon(Icons.fitness_center, color: AppTheme.primaryColor, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(exercise.name,
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis),
            ),
            if (shouldIncrease) ...[
              const SizedBox(width: 4),
              Icon(Icons.trending_up, color: AppTheme.successColor, size: 14),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSeeAllChip() {
    return InkWell(
      onTap: _showAllExercises,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.arrow_forward, color: AppTheme.primaryColor, size: 18),
            const SizedBox(width: 4),
            Text('See All',
                style: TextStyle(fontSize: 13, color: AppTheme.primaryColor)),
          ],
        ),
      ),
    );
  }


  Widget _buildWarmupStretchesSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // FIXED: Use Expanded to prevent overflow in header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.self_improvement, color: Colors.teal, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Warmup Stretches',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Buttons in a constrained row
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 22),
                tooltip: 'Add Stretch',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                onPressed: () => _showCreateStretchDialog(),
              ),
              IconButton(
                icon: const Icon(Icons.playlist_add, size: 22),
                tooltip: 'Create Routine',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                onPressed: () => _showCreateStretchRoutineDialog(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_stretchRoutines.isEmpty && _stretches.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    Icon(Icons.self_improvement, size: 48, color: Colors.grey.shade600),
                    const SizedBox(height: 12),
                    Text(
                      'No warmup routines yet',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Create stretches and group them into routines',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () => _showCreateStretchDialog(),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add First Stretch'),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            // Show stretch routines
            if (_stretchRoutines.isNotEmpty) ...[
              ..._stretchRoutines.map((routine) {
                final color = Color(int.parse('FF${routine.colorHex ?? '26A69A'}', radix: 16));
                final totalDuration = routine.stretches.fold<int>(0, (sum, rs) {
                  final stretch = _getStretchById(rs.savedStretchId);
                  return sum + (rs.overrideDuration ?? stretch?.defaultDuration ?? 30);
                });

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    leading: CircleAvatar(
                      backgroundColor: color.withOpacity(0.2),
                      radius: 20,
                      child: Icon(Icons.self_improvement, color: color, size: 20),
                    ),
                    title: Text(
                      routine.name,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    subtitle: Text(
                      '${routine.stretches.length} stretches \u{2022} ${(totalDuration / 60).ceil()} min',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                    // FIXED: Simplified trailing to prevent overflow
                    trailing: SizedBox(
                      width: 80,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (routine.timesCompleted > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.teal.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${routine.timesCompleted}x',
                                style: const TextStyle(color: Colors.teal, fontSize: 11),
                              ),
                            ),
                          const SizedBox(width: 4),
                          SizedBox(
                            width: 32,
                            height: 32,
                            child: IconButton(
                              icon: const Icon(Icons.more_vert, size: 18),
                              padding: EdgeInsets.zero,
                              onPressed: () => _showStretchRoutineOptions(routine),
                            ),
                          ),
                        ],
                      ),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => StretchSessionScreen(routine: routine),
                        ),
                      ).then((_) => _loadData());
                    },
                  ),
                );
              }),
            ],

            // Show individual stretches
            if (_stretches.isNotEmpty) ...[
              const SizedBox(height: 8),
              ExpansionTile(
                title: Text(
                  'My Stretches (${_stretches.length})',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                ),
                initiallyExpanded: _stretchRoutines.isEmpty,
                children: _stretches.map((stretch) => Card(
                  margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    leading: stretch.photoPath != null
                        ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(stretch.photoPath!),
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.teal.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.accessibility_new, color: Colors.teal, size: 20),
                        ),
                      ),
                    )
                        : Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.accessibility_new, color: Colors.teal, size: 20),
                    ),
                    title: Text(
                      stretch.name,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    subtitle: Text(
                      '${stretch.defaultDuration}s \u{2022} ${stretch.muscleGroup ?? "General"}',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: SizedBox(
                      width: 32,
                      height: 32,
                      child: IconButton(
                        icon: const Icon(Icons.more_vert, size: 18),
                        padding: EdgeInsets.zero,
                        onPressed: () => _showStretchOptions(stretch),
                      ),
                    ),
                    onTap: () => _showStretchOptions(stretch),
                  ),
                )).toList(),
              ),
            ],
          ],
        ],
      ),
    );
  }








// ============================================================
// SECTION 5: CREATE STRETCH DIALOG
// ============================================================

  void _showCreateStretchDialog({SavedStretch? existingStretch}) {
    final nameController = TextEditingController(text: existingStretch?.name ?? '');
    final notesController = TextEditingController(text: existingStretch?.notes ?? '');
    final youtubeController = TextEditingController(text: existingStretch?.youtubeUrl ?? '');
    String? selectedMuscleGroup = existingStretch?.muscleGroup;
    File? selectedPhoto;
    String? existingPhotoPath = existingStretch?.photoPath;
    int duration = existingStretch?.defaultDuration ?? 30;
    final isEditing = existingStretch != null;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: SafeArea(
            child: Container(
              height: MediaQuery.of(context).size.height * 0.85,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          isEditing ? 'Edit Stretch' : 'Create Stretch',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: nameController,
                            decoration: const InputDecoration(
                              labelText: 'Stretch Name *',
                              hintText: 'e.g., Hamstring Stretch',
                            ),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: selectedMuscleGroup,
                            decoration: const InputDecoration(labelText: 'Target Area'),
                            items: StretchMuscleGroups.all
                                .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                                .toList(),
                            onChanged: (v) => setDialogState(() => selectedMuscleGroup = v),
                          ),
                          const SizedBox(height: 16),
                          Text('Photo (optional)', style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
                          const SizedBox(height: 8),
                          if (selectedPhoto != null || existingPhotoPath != null)
                            Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: selectedPhoto != null
                                      ? Image.file(selectedPhoto!, width: double.infinity, height: 150, fit: BoxFit.cover)
                                      : Image.file(File(existingPhotoPath!), width: double.infinity, height: 150, fit: BoxFit.cover),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: IconButton(
                                    onPressed: () => setDialogState(() {
                                      selectedPhoto = null;
                                      existingPhotoPath = null;
                                    }),
                                    icon: const Icon(Icons.close),
                                    style: IconButton.styleFrom(backgroundColor: Colors.black54),
                                  ),
                                ),
                              ],
                            )
                          else
                            InkWell(
                              onTap: () async {
                                final image = await ImagePicker().pickImage(
                                  source: ImageSource.gallery,
                                  maxWidth: 800,
                                  maxHeight: 800,
                                );
                                if (image != null) {
                                  setDialogState(() => selectedPhoto = File(image.path));
                                }
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                height: 100,
                                decoration: BoxDecoration(
                                  color: AppTheme.cardColor,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppTheme.cardColorLight),
                                ),
                                child: const Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.add_photo_alternate, size: 32),
                                      SizedBox(height: 8),
                                      Text('Add Photo'),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: youtubeController,
                            decoration: const InputDecoration(
                              labelText: 'YouTube Tutorial Link (optional)',
                              hintText: 'https://youtube.com/...',
                              prefixIcon: Icon(Icons.play_circle_outline),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text('Hold Duration', style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                onPressed: duration > 5 ? () => setDialogState(() => duration -= 5) : null,
                                icon: const Icon(Icons.remove_circle_outline, size: 32),
                              ),
                              const SizedBox(width: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                decoration: BoxDecoration(
                                  color: AppTheme.cardColor,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${duration}s',
                                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 16),
                              IconButton(
                                onPressed: () => setDialogState(() => duration += 5),
                                icon: const Icon(Icons.add_circle_outline, size: 32),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Center(
                            child: Wrap(
                              spacing: 8,
                              children: [15, 30, 45, 60].map((d) => ChoiceChip(
                                label: Text('${d}s'),
                                selected: duration == d,
                                onSelected: (selected) {
                                  if (selected) setDialogState(() => duration = d);
                                },
                              )).toList(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: notesController,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Notes (optional)',
                              hintText: 'Form cues, modifications, etc.',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (nameController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter stretch name')),
                          );
                          return;
                        }

                        final storage = context.read<StorageService>();
                        String? photoPath = existingPhotoPath;

                        if (selectedPhoto != null) {
                          final dir = await getApplicationDocumentsDirectory();
                          final fileName = '${const Uuid().v4()}.jpg';
                          photoPath = '${dir.path}/$fileName';
                          await selectedPhoto!.copy(photoPath);
                        }

                        final stretch = SavedStretch(
                          id: existingStretch?.id ?? const Uuid().v4(),
                          name: nameController.text.trim(),
                          muscleGroup: selectedMuscleGroup,
                          defaultDuration: duration,
                          notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                          photoPath: photoPath,
                          youtubeUrl: youtubeController.text.trim().isEmpty ? null : youtubeController.text.trim(),
                          timesUsed: existingStretch?.timesUsed ?? 0,
                          createdAt: existingStretch?.createdAt ?? DateTime.now(),
                        );

                        await storage.saveSavedStretch(stretch);
                        _loadData();
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${stretch.name} ${isEditing ? "updated" : "created"}!')),
                        );
                      },
                      child: Text(isEditing ? 'Save Changes' : 'Create Stretch'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

// ============================================================
// SECTION 6: CREATE STRETCH ROUTINE DIALOG
// ============================================================

  void _showCreateStretchRoutineDialog({StretchRoutine? existingRoutine}) {
    if (_stretches.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('No Stretches'),
          content: const Text('You need to create some stretches first before making a routine.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                _showCreateStretchDialog();
              },
              child: const Text('Create Stretch'),
            ),
          ],
        ),
      );
      return;
    }

    final isEditing = existingRoutine != null;
    final nameController = TextEditingController(text: existingRoutine?.name ?? '');
    final descController = TextEditingController(text: existingRoutine?.description ?? '');
    List<SavedStretch> selectedStretches = [];

    if (existingRoutine != null) {
      for (final rs in existingRoutine.stretches) {
        final stretch = _getStretchById(rs.savedStretchId);
        if (stretch != null) selectedStretches.add(stretch);
      }
    }

    String selectedColor = existingRoutine?.colorHex ?? StretchRoutineColors.all.first;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: SafeArea(
            child: Container(
              height: MediaQuery.of(context).size.height * 0.85,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          isEditing ? 'Edit Warmup Routine' : 'Create Warmup Routine',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: nameController,
                            decoration: const InputDecoration(
                              labelText: 'Routine Name *',
                              hintText: 'e.g., Full Body Warmup',
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: descController,
                            decoration: const InputDecoration(
                              labelText: 'Description (optional)',
                              hintText: 'Pre-workout stretch routine',
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text('Color', style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: StretchRoutineColors.all.map((colorHex) {
                              final color = Color(int.parse('FF$colorHex', radix: 16));
                              final isSelected = selectedColor == colorHex;
                              return GestureDetector(
                                onTap: () => setDialogState(() => selectedColor = colorHex),
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                                  ),
                                  child: isSelected ? const Icon(Icons.check, color: Colors.white) : null,
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Stretches (${selectedStretches.length})',
                                      style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                                    ),
                                    if (selectedStretches.isNotEmpty)
                                      Text(
                                        'Total: ${selectedStretches.fold<int>(0, (sum, s) => sum + s.defaultDuration)}s',
                                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                      ),
                                  ],
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () => _showStretchSelector(
                                  selectedStretches,
                                      (stretches) => setDialogState(() => selectedStretches = stretches),
                                ),
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Add'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (selectedStretches.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: AppTheme.cardColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  'Tap "Add" to select stretches',
                                  style: TextStyle(color: Colors.grey.shade500),
                                ),
                              ),
                            )
                          else
                            ReorderableListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: selectedStretches.length,
                              onReorder: (oldIndex, newIndex) {
                                setDialogState(() {
                                  if (newIndex > oldIndex) newIndex--;
                                  final item = selectedStretches.removeAt(oldIndex);
                                  selectedStretches.insert(newIndex, item);
                                });
                              },
                              itemBuilder: (context, index) {
                                final stretch = selectedStretches[index];
                                return Card(
                                  key: Key('${stretch.id}_$index'),
                                  margin: const EdgeInsets.only(bottom: 4),
                                  child: ListTile(
                                    leading: ReorderableDragStartListener(
                                      index: index,
                                      child: const Icon(Icons.drag_handle),
                                    ),
                                    title: Text(stretch.name, overflow: TextOverflow.ellipsis),
                                    subtitle: Text(
                                      '${stretch.defaultDuration}s \u{2022} ${stretch.muscleGroup ?? "General"}',
                                      style: TextStyle(color: Colors.grey.shade500),
                                    ),
                                    trailing: IconButton(
                                      onPressed: () => setDialogState(() => selectedStretches.removeAt(index)),
                                      icon: Icon(Icons.remove_circle, color: Colors.red.shade400),
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (nameController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter routine name')),
                          );
                          return;
                        }
                        if (selectedStretches.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please add at least one stretch')),
                          );
                          return;
                        }

                        final storage = context.read<StorageService>();
                        final routineStretches = selectedStretches.asMap().entries.map((e) =>
                            RoutineStretch(
                              savedStretchId: e.value.id,
                              order: e.key,
                            ),
                        ).toList();

                        final routine = StretchRoutine(
                          id: existingRoutine?.id ?? const Uuid().v4(),
                          name: nameController.text.trim(),
                          description: descController.text.trim().isEmpty ? null : descController.text.trim(),
                          stretches: routineStretches,
                          colorHex: selectedColor,
                          timesCompleted: existingRoutine?.timesCompleted ?? 0,
                          createdAt: existingRoutine?.createdAt ?? DateTime.now(),
                          lastUsed: existingRoutine?.lastUsed,
                        );

                        await storage.saveStretchRoutine(routine);
                        _loadData();
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${routine.name} ${isEditing ? "updated" : "created"}!')),
                        );
                      },
                      child: Text(isEditing ? 'Save Changes' : 'Create Routine'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

// ============================================================
// SECTION 7: STRETCH SELECTOR DIALOG
// ============================================================

  void _showStretchSelector(List<SavedStretch> currentSelection, Function(List<SavedStretch>) onConfirm) {
    List<SavedStretch> selection = List.from(currentSelection);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => SafeArea(
          child: Container(
            height: MediaQuery.of(context).size.height * 0.7,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Flexible(
                      child: Text(
                        'Select Stretches',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        onConfirm(selection);
                        Navigator.pop(context);
                      },
                      child: Text('Done (${selection.length})'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap to add, tap again to add another',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: _stretches.length,
                    itemBuilder: (context, index) {
                      final stretch = _stretches[index];
                      final count = selection.where((s) => s.id == stretch.id).length;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 4),
                        child: ListTile(
                          leading: stretch.photoPath != null
                              ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(stretch.photoPath!),
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                            ),
                          )
                              : Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.teal.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.accessibility_new, color: Colors.teal),
                          ),
                          title: Text(stretch.name, overflow: TextOverflow.ellipsis),
                          subtitle: Text(
                            '${stretch.defaultDuration}s \u{2022} ${stretch.muscleGroup ?? "General"}',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (count > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.teal.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '$count',
                                    style: const TextStyle(
                                      color: Colors.teal,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              if (count > 0)
                                IconButton(
                                  icon: Icon(Icons.remove_circle_outline, color: Colors.red.shade400),
                                  onPressed: () {
                                    setDialogState(() {
                                      final idx = selection.lastIndexWhere((s) => s.id == stretch.id);
                                      if (idx >= 0) selection.removeAt(idx);
                                    });
                                  },
                                ),
                            ],
                          ),
                          onTap: () => setDialogState(() => selection.add(stretch)),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

// ============================================================
// SECTION 8: STRETCH OPTIONS MENUS
// ============================================================

  void _showStretchOptions(SavedStretch stretch) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit Stretch'),
                onTap: () {
                  Navigator.pop(context);
                  _showCreateStretchDialog(existingStretch: stretch);
                },
              ),
              if (stretch.youtubeUrl != null && stretch.youtubeUrl!.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.play_circle_outline, color: Colors.red),
                  title: const Text('Watch Tutorial'),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Opening: ${stretch.youtubeUrl}')),
                    );
                  },
                ),
              ListTile(
                leading: Icon(Icons.delete, color: Colors.red.shade400),
                title: Text('Delete', style: TextStyle(color: Colors.red.shade400)),
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete Stretch?'),
                      content: Text('This will remove "${stretch.name}" from your library.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: FilledButton.styleFrom(backgroundColor: Colors.red.shade400),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    Navigator.pop(context);
                    await context.read<StorageService>().deleteSavedStretch(stretch.id);
                    _loadData();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showStretchRoutineOptions(StretchRoutine routine) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.play_arrow, color: Colors.teal),
                title: const Text('Start Warmup'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StretchSessionScreen(routine: routine),
                    ),
                  ).then((_) => _loadData());
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit Routine'),
                onTap: () {
                  Navigator.pop(context);
                  _showCreateStretchRoutineDialog(existingRoutine: routine);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete, color: Colors.red.shade400),
                title: Text('Delete', style: TextStyle(color: Colors.red.shade400)),
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete Routine?'),
                      content: Text('This will remove "${routine.name}" from your warmup routines.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: FilledButton.styleFrom(backgroundColor: Colors.red.shade400),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    Navigator.pop(context);
                    await context.read<StorageService>().deleteStretchRoutine(routine.id);
                    _loadData();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
  /// Combined recent activities section - includes both workouts AND cardio
  Widget _buildRecentActivitiesSection() {
    final activities = _recentActivities;
    if (activities.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Flexible(
              child: Text('Recent Activity',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis),
            ),
            TextButton(onPressed: _showAllActivities, child: const Text('See All')),
          ],
        ),
        const SizedBox(height: 12),
        ...activities.take(5).map((activity) => _buildActivityTile(activity)),
      ],
    );
  }

  Widget _buildActivityTile(ActivityItem activity) {
    if (activity.isCardio) {
      return _buildCardioTile(activity.cardioWorkout!);
    } else {
      return _buildWorkoutTile(activity.workout!);
    }
  }

  Widget _buildWorkoutTile(Workout workout) {
    final exerciseNames = workout.exercises.take(3).map((e) => e.name).join(', ');
    final moreCount = workout.exercises.length > 3
        ? ' +${workout.exercises.length - 3} more'
        : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _showWorkoutDetails(workout),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.fitness_center, color: AppTheme.primaryColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(
                        child: Text(workout.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 8),
                      Text('${workout.durationMinutes} min',
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 12)),
                    ]),
                    const SizedBox(height: 4),
                    Text(
                      '$exerciseNames$moreCount',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(DateFormat('MMM d').format(workout.date),
                      style:
                          TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                  Text('${workout.exercises.length} ex',
                      style:
                          TextStyle(color: AppTheme.primaryColor, fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardioTile(CardioWorkout cardio) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _showCardioDetails(cardio),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                    child: Text(cardio.type.icon,
                        style: const TextStyle(fontSize: 24))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(
                        child: Text(cardio.type.displayName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 8),
                      Text('${cardio.durationMinutes} min',
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 12)),
                    ]),
                    const SizedBox(height: 4),
                    Row(children: [
                      Text('${cardio.estimatedCalories} cal',
                          style: TextStyle(
                              color: AppTheme.warningColor, fontSize: 12)),
                      if (cardio.distanceMiles != null) ...[
                        Text(' â€¢ ',
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 12)),
                        Text(cardio.distanceDisplay ?? '',
                            style: TextStyle(
                                color: Colors.grey.shade400, fontSize: 12)),
                      ],
                    ]),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(DateFormat('MMM d').format(cardio.date),
                      style:
                          TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.warningColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('Cardio',
                        style: TextStyle(
                            color: AppTheme.warningColor, fontSize: 10)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCardioDetails(CardioWorkout cardio) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                      child: Text(cardio.type.icon,
                          style: const TextStyle(fontSize: 28))),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cardio.type.displayName,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      Text(DateFormat('EEEE, MMMM d, yyyy').format(cardio.date),
                          style: TextStyle(color: Colors.grey.shade400)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Cardio?'),
                        content: const Text('This action cannot be undone.'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel')),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: FilledButton.styleFrom(
                                backgroundColor: Colors.red.shade400),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await context
                          .read<StorageService>()
                          .deleteCardioWorkout(cardio.id);
                      Navigator.pop(context);
                      _loadData();
                    }
                  },
                  icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
                ),
              ]),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildDetailStat(
                      'Duration', cardio.durationDisplay, Icons.timer),
                  _buildDetailStat('Calories', '${cardio.estimatedCalories}',
                      Icons.local_fire_department),
                  if (cardio.distanceMiles != null)
                    _buildDetailStat(
                        'Distance', cardio.distanceDisplay ?? '', Icons.straighten),
                  if (cardio.paceDisplay != null)
                    _buildDetailStat(
                        'Pace', cardio.paceDisplay ?? '', Icons.speed),
                  if (cardio.avgHeartRate != null)
                    _buildDetailStat('Avg HR', '${cardio.avgHeartRate} bpm',
                        Icons.favorite),
                  if (cardio.perceivedExertion != null)
                    _buildDetailStat('Effort (RPE)',
                        '${cardio.perceivedExertion}/10', Icons.psychology),
                ],
              ),
              if (cardio.notes != null && cardio.notes!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Notes',
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(cardio.notes!),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailStat(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== DIALOGS & OPTIONS ====================

  void _showStartWorkoutOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Start Workout',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              _buildOptionTile(
                icon: Icons.play_arrow,
                color: AppTheme.primaryColor,
                title: 'Select a Routine',
                subtitle: _routines.isEmpty
                    ? 'No routines yet - create one first'
                    : '${_routines.length} saved routines',
                onTap: _routines.isEmpty
                    ? null
                    : () {
                        Navigator.pop(context);
                        _showSelectRoutineDialog();
                      },
              ),
              const SizedBox(height: 12),
              _buildOptionTile(
                icon: Icons.directions_run,
                color: AppTheme.warningColor,
                title: 'Log Cardio',
                subtitle: 'Running, cycling, treadmill & more',
                onTap: () {
                  Navigator.pop(context);
                  showCardioTrackingDialog(context).then((_) => _loadData());
                },
              ),
              const SizedBox(height: 12),
              _buildOptionTile(
                icon: Icons.folder_special,
                color: AppTheme.secondaryColor,
                title: 'Create New Routine',
                subtitle: 'Group exercises into a workout plan',
                onTap: () {
                  Navigator.pop(context);
                  _showCreateRoutineDialog();
                },
              ),
              const SizedBox(height: 12),
              _buildOptionTile(
                icon: Icons.add_circle,
                color: AppTheme.successColor,
                title: 'Create New Exercise',
                subtitle: 'Add a new exercise to your library',
                onTap: () {
                  Navigator.pop(context);
                  _showCreateExerciseDialog();
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    final isDisabled = onTap == null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Opacity(
        opacity: isDisabled ? 0.5 : 1.0,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: color.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(subtitle,
                        style:
                            TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                  ],
                ),
              ),
              if (!isDisabled)
                Icon(Icons.arrow_forward_ios, color: Colors.grey.shade500, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  void _showAllActivities() {
    final activities = _recentActivities;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade600,
                    borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(children: [
                const Text('All Activity',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text(
                    '${_workouts.length} workouts â€¢ ${_cardioWorkouts.length} cardio',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              ]),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: activities.length,
                itemBuilder: (context, index) {
                  final activity = activities[index];
                  if (activity.isCardio) {
                    return _buildCardioTile(activity.cardioWorkout!);
                  } else {
                    return _buildWorkoutTile(activity.workout!);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSelectRoutineDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade600,
                    borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(children: [
                const Text('Select Routine',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('${_routines.length} routines',
                    style: TextStyle(color: Colors.grey.shade500)),
              ]),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _routines.length,
                itemBuilder: (context, index) {
                  final routine = _routines[index];
                  final color = routine.colorHex != null
                      ? Color(int.parse('FF${routine.colorHex}', radix: 16))
                      : AppTheme.primaryColor;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      onTap: () {
                        Navigator.pop(context);
                        _startRoutine(routine);
                      },
                      onLongPress: () {
                        Navigator.pop(context);
                        _showRoutineOptions(routine);
                      },
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                            color: color.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12)),
                        child:
                            Icon(Icons.fitness_center, color: color, size: 24),
                      ),
                      title: Text(routine.name,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${routine.exercises.length} exercises',
                          style: TextStyle(color: Colors.grey.shade500)),
                      trailing:
                          Icon(Icons.play_arrow, color: color, size: 28),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAllExercises() {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.surfaceColor,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade600,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Text(
                  'All Exercises',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '${_exercises.length} total',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _exercises.length,
              itemBuilder: (context, index) {
                final exercise = _exercises[index];
                final history = _exerciseHistory?[exercise.name];
                final shouldIncrease =
                    history != null && history.consecutiveGoalsMet >= 3;

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    onTap: () {
                      Navigator.pop(context);
                      _showExerciseDetails(exercise);
                    },
                    onLongPress: () {
                      Navigator.pop(context);
                      _showExerciseOptions(exercise);
                    },
                    leading: exercise.photoPath != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(exercise.photoPath!),
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppTheme.cardColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.fitness_center),
                          ),
                    title: Row(
                      children: [
                        Flexible(
                          child: Text(
                            exercise.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (shouldIncrease) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.trending_up,
                            color: AppTheme.successColor,
                            size: 16,
                          ),
                        ],
                      ],
                    ),
                    subtitle: Text(
                      '${exercise.muscleGroup ?? "General"} '
                      '${exercise.defaultSets} sets '
                      '${exercise.repsDisplay}',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: Colors.grey.shade500,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}


  void _showWorkoutDetails(Workout workout) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child:
                      Icon(Icons.fitness_center, color: AppTheme.primaryColor),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(workout.name,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      Text(
                          DateFormat('EEEE, MMMM d, yyyy').format(workout.date),
                          style: TextStyle(color: Colors.grey.shade400)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Workout?'),
                        content: const Text('This action cannot be undone.'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel')),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: FilledButton.styleFrom(
                                backgroundColor: Colors.red.shade400),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await context
                          .read<StorageService>()
                          .deleteWorkout(workout.id);
                      Navigator.pop(context);
                      _loadData();
                    }
                  },
                  icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
                ),
              ]),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildDetailStat('Duration', '${workout.durationMinutes} min',
                      Icons.timer),
                  _buildDetailStat('Exercises', '${workout.exercises.length}',
                      Icons.fitness_center),
                ],
              ),
              const SizedBox(height: 24),
              Text('Exercises',
                  style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 14,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ...workout.exercises.map((e) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.cardColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(children: [
                      Icon(Icons.fitness_center,
                          color: AppTheme.primaryColor, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            Text(
                              '${e.sets.length} sets â€¢ ${e.sets.map((s) => '${s.weight}lb x ${s.reps}').join(', ')}',
                              style: TextStyle(
                                  color: Colors.grey.shade500, fontSize: 12),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ]),
                  )),
              if (workout.notes != null && workout.notes!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Notes',
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(workout.notes!),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ==================== HELPERS ====================

  void _startRoutine(WorkoutRoutine routine) {
    final storage = context.read<StorageService>();
    final exercises = routine.exercises
        .map((re) => storage.getSavedExerciseById(re.savedExerciseId))
        .whereType<SavedExercise>()
        .toList();
    if (exercises.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No exercises found')));
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WorkoutSessionScreen(
            routineName: routine.name,
            routineId: routine.id,
            exercises: exercises),
      ),
    ).then((_) => _loadData());
  }

  void _showEditGoalDialog() {
    int goal = _settings?.weeklyWorkoutGoal ?? 4;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Weekly Workout Goal'),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('How many workouts per week?',
                  style: TextStyle(color: Colors.grey.shade400)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                      onPressed:
                          goal > 1 ? () => setDialogState(() => goal--) : null,
                      icon: const Icon(Icons.remove_circle_outline)),
                  Container(
                    width: 60,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12)),
                    child: Text('$goal',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor)),
                  ),
                  IconButton(
                      onPressed:
                          goal < 7 ? () => setDialogState(() => goal++) : null,
                      icon: const Icon(Icons.add_circle_outline)),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final storage = context.read<StorageService>();
              final settings =
                  _settings ?? UserSettings(weeklyWorkoutGoal: goal);
              settings.weeklyWorkoutGoal = goal;
              await storage.saveUserSettings(settings);
              setState(() => _settings = settings);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Workout Cache?'),
        content: const Text(
          'This will clear cached workout data that may be corrupted. '
          'Your saved exercises and routines will remain, but workout history may be reset.\n\n'
          'Try this if the workout tab keeps showing errors.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() {
                _workouts = [];
                _cardioWorkouts = [];
                _exerciseHistory = {};
                _errorMessage = null;
                _isLoading = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cache cleared. Try refreshing.'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Clear Cache'),
          ),
        ],
      ),
    );
  }

  // ==================== CREATE EXERCISE ====================

  void _showCreateExerciseDialog({SavedExercise? existingExercise}) {
    final nameController = TextEditingController(text: existingExercise?.name ?? '');
    final notesController = TextEditingController(text: existingExercise?.notes ?? '');
    final youtubeController = TextEditingController(text: existingExercise?.youtubeUrl ?? '');
    String? selectedMuscleGroup = existingExercise?.muscleGroup;
    File? selectedPhoto;
    String? existingPhotoPath = existingExercise?.photoPath;
    int sets = existingExercise?.defaultSets ?? 3;
    int minReps = existingExercise?.defaultMinReps ?? 8;
    int maxReps = existingExercise?.defaultMaxReps ?? 12;
    final isEditing = existingExercise != null;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: SafeArea(
            child: Container(
              height: MediaQuery.of(context).size.height * 0.85,
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Flexible(child: Text(isEditing ? 'Edit Exercise' : 'Create Exercise', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ]),
                const SizedBox(height: 20),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Exercise Name *', hintText: 'e.g., Bench Press')),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: selectedMuscleGroup,
                        decoration: const InputDecoration(labelText: 'Muscle Group'),
                        items: MuscleGroups.all.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                        onChanged: (v) => setDialogState(() => selectedMuscleGroup = v),
                      ),
                      const SizedBox(height: 16),
                      Text('Photo (optional)', style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
                      const SizedBox(height: 8),
                      if (selectedPhoto != null || existingPhotoPath != null)
                        Stack(children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: selectedPhoto != null
                                ? Image.file(selectedPhoto!, width: double.infinity, height: 150, fit: BoxFit.cover)
                                : Image.file(File(existingPhotoPath!), width: double.infinity, height: 150, fit: BoxFit.cover),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: IconButton(
                              onPressed: () => setDialogState(() {
                                selectedPhoto = null;
                                existingPhotoPath = null;
                              }),
                              icon: const Icon(Icons.close),
                              style: IconButton.styleFrom(backgroundColor: Colors.black54),
                            ),
                          ),
                        ])
                      else
                        InkWell(
                          onTap: () async {
                            final image = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 800, maxHeight: 800);
                            if (image != null) setDialogState(() => selectedPhoto = File(image.path));
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            height: 100,
                            decoration: BoxDecoration(color: AppTheme.cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.cardColorLight)),
                            child: const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.add_photo_alternate, size: 32), SizedBox(height: 8), Text('Add Photo')])),
                          ),
                        ),
                      const SizedBox(height: 16),
                      TextField(controller: youtubeController, decoration: const InputDecoration(labelText: 'YouTube Tutorial Link (optional)', hintText: 'https://youtube.com/...', prefixIcon: Icon(Icons.play_circle_outline))),
                      const SizedBox(height: 20),
                      Text('Default Sets & Reps', style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
                      const SizedBox(height: 12),
                      // Always use Row but with tighter constraints to prevent overflow
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildNumberPicker('Sets', sets, (v) => setDialogState(() => sets = v), min: 1),
                          _buildNumberPicker('Min Reps', minReps, (v) => setDialogState(() => minReps = v), min: 1),
                          _buildNumberPicker('Max Reps', maxReps, (v) => setDialogState(() => maxReps = v), min: minReps),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(controller: notesController, maxLines: 3, decoration: const InputDecoration(labelText: 'Notes (optional)', hintText: 'Form cues, tips, etc.')),
                    ]),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (nameController.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter exercise name'))); return; }
                      final storage = context.read<StorageService>();
                      String? photoPath = existingPhotoPath;
                      if (selectedPhoto != null) {
                        final dir = await getApplicationDocumentsDirectory();
                        final fileName = '${const Uuid().v4()}.jpg';
                        photoPath = '${dir.path}/$fileName';
                        await selectedPhoto!.copy(photoPath);
                      }
                      final exercise = SavedExercise(
                        id: existingExercise?.id ?? const Uuid().v4(),
                        name: nameController.text.trim(),
                        muscleGroup: selectedMuscleGroup,
                        defaultSets: sets,
                        defaultMinReps: minReps,
                        defaultMaxReps: maxReps,
                        notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                        photoPath: photoPath,
                        youtubeUrl: youtubeController.text.trim().isEmpty ? null : youtubeController.text.trim(),
                        timesUsed: existingExercise?.timesUsed ?? 0,
                        createdAt: existingExercise?.createdAt ?? DateTime.now(),
                      );
                      await storage.saveSavedExercise(exercise);
                      _loadData();
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${exercise.name} ${isEditing ? "updated" : "created"}!')));
                    },
                    child: Text(isEditing ? 'Save Changes' : 'Create Exercise'),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNumberPicker(String label, int value, Function(int) onChanged, {int min = 1}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: IconButton(
                padding: EdgeInsets.zero,
                onPressed: value > min ? () => onChanged(value - 1) : null,
                icon: const Icon(Icons.remove_circle_outline, size: 24),
              ),
            ),
            SizedBox(
              width: 36,
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(
              width: 32,
              height: 32,
              child: IconButton(
                padding: EdgeInsets.zero,
                onPressed: () => onChanged(value + 1),
                icon: const Icon(Icons.add_circle_outline, size: 24),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ==================== CREATE/EDIT ROUTINE ====================

  void _showCreateRoutineDialog({WorkoutRoutine? existingRoutine}) {
    if (_exercises.isEmpty) {
      showDialog(context: context, builder: (context) => AlertDialog(
        title: const Text('No Exercises'),
        content: const Text('You need to create some exercises first.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () { Navigator.pop(context); _showCreateExerciseDialog(); }, child: const Text('Create Exercise')),
        ],
      ));
      return;
    }

    final isEditing = existingRoutine != null;
    final nameController = TextEditingController(text: existingRoutine?.name ?? '');
    List<SavedExercise> selectedExercises = [];
    if (existingRoutine != null) {
      final storage = context.read<StorageService>();
      for (final re in existingRoutine.exercises) {
        final ex = storage.getSavedExerciseById(re.savedExerciseId);
        if (ex != null) selectedExercises.add(ex);
      }
    }
    String selectedColor = existingRoutine?.colorHex ?? RoutineColors.all.first;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: SafeArea(
            child: Container(
              height: MediaQuery.of(context).size.height * 0.85,
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Flexible(child: Text(isEditing ? 'Edit Routine' : 'Create Routine', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ]),
                const SizedBox(height: 20),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Routine Name *', hintText: 'e.g., Push Day')),
                      const SizedBox(height: 16),
                      Text('Color', style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 8, children: RoutineColors.all.map((colorHex) {
                        final color = Color(int.parse('FF$colorHex', radix: 16));
                        final isSelected = selectedColor == colorHex;
                        return GestureDetector(
                          onTap: () => setDialogState(() => selectedColor = colorHex),
                          child: Container(width: 40, height: 40, decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: isSelected ? Border.all(color: Colors.white, width: 3) : null), child: isSelected ? const Icon(Icons.check, color: Colors.white) : null),
                        );
                      }).toList()),
                      const SizedBox(height: 20),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Flexible(child: Text('Exercises (${selectedExercises.length})', style: TextStyle(color: Colors.grey.shade400, fontSize: 14))),
                        TextButton.icon(onPressed: () => _showExerciseSelector(selectedExercises, (ex) => setDialogState(() => selectedExercises = ex)), icon: const Icon(Icons.add, size: 18), label: const Text('Add')),
                      ]),
                      if (selectedExercises.isEmpty)
                        Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: AppTheme.cardColor, borderRadius: BorderRadius.circular(12)), child: Center(child: Text('Tap "Add" to select exercises', style: TextStyle(color: Colors.grey.shade500))))
                      else
                        ReorderableListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: selectedExercises.length,
                          onReorder: (oldIndex, newIndex) { setDialogState(() { if (newIndex > oldIndex) newIndex--; final item = selectedExercises.removeAt(oldIndex); selectedExercises.insert(newIndex, item); }); },
                          itemBuilder: (context, index) {
                            final exercise = selectedExercises[index];
                            return Card(key: Key(exercise.id), margin: const EdgeInsets.only(bottom: 4), child: ListTile(
                              leading: ReorderableDragStartListener(index: index, child: const Icon(Icons.drag_handle)),
                              title: Text(exercise.name, overflow: TextOverflow.ellipsis),
                              subtitle: Text('${exercise.defaultSets} sets x ${exercise.repsDisplay}', style: TextStyle(color: Colors.grey.shade500)),
                              trailing: IconButton(onPressed: () => setDialogState(() => selectedExercises.removeAt(index)), icon: Icon(Icons.remove_circle, color: Colors.red.shade400)),
                            ));
                          },
                        ),
                    ]),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (nameController.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter routine name'))); return; }
                      if (selectedExercises.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add at least one exercise'))); return; }
                      final storage = context.read<StorageService>();
                      final routineExercises = selectedExercises.asMap().entries.map((e) => RoutineExercise(savedExerciseId: e.value.id, order: e.key)).toList();
                      final routine = WorkoutRoutine(
                        id: existingRoutine?.id ?? const Uuid().v4(),
                        name: nameController.text.trim(),
                        exercises: routineExercises,
                        colorHex: selectedColor,
                        timesCompleted: existingRoutine?.timesCompleted ?? 0,
                        createdAt: existingRoutine?.createdAt ?? DateTime.now(),
                        lastUsed: existingRoutine?.lastUsed,
                      );
                      await storage.saveWorkoutRoutine(routine);
                      _loadData();
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${routine.name} ${isEditing ? "updated" : "created"}!')));
                    },
                    child: Text(isEditing ? 'Save Changes' : 'Create Routine'),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  void _showExerciseSelector(List<SavedExercise> currentSelection, Function(List<SavedExercise>) onConfirm) {
    List<SavedExercise> selection = List.from(currentSelection);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => SafeArea(
          child: Container(
            height: MediaQuery.of(context).size.height * 0.7,
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Flexible(child: Text('Select Exercises', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                TextButton(onPressed: () { onConfirm(selection); Navigator.pop(context); }, child: Text('Done (${selection.length})')),
              ]),
              const SizedBox(height: 16),
              Expanded(child: ListView.builder(
                itemCount: _exercises.length,
                itemBuilder: (context, index) {
                  final exercise = _exercises[index];
                  final isSelected = selection.any((e) => e.id == exercise.id);
                  return Card(margin: const EdgeInsets.only(bottom: 4), child: CheckboxListTile(
                    value: isSelected,
                    onChanged: (v) => setDialogState(() { if (v == true) selection.add(exercise); else selection.removeWhere((e) => e.id == exercise.id); }),
                    title: Text(exercise.name, overflow: TextOverflow.ellipsis),
                    subtitle: Text('${exercise.muscleGroup ?? "General"} â€” ${exercise.defaultSets} sets', style: TextStyle(color: Colors.grey.shade500)),
                    secondary: exercise.photoPath != null
                        ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(exercise.photoPath!), width: 48, height: 48, fit: BoxFit.cover))
                        : Container(width: 48, height: 48, decoration: BoxDecoration(color: AppTheme.cardColor, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.fitness_center)),
                  ));
                },
              )),
            ]),
          ),
        ),
      ),
    );
  }

  // ==================== EXERCISE DETAILS & PROGRESS ====================

  void _showExerciseDetails(SavedExercise exercise) {
    final history = _exerciseHistory?[exercise.name];
    final shouldIncrease = history != null && history.consecutiveGoalsMet >= 3;
    final exerciseWorkouts = _workouts.where((w) => w.exercises.any((e) => e.name == exercise.name)).toList()..sort((a, b) => b.date.compareTo(a.date));
    
    final chartData = <FlSpot>[];
    final workoutDates = <String>[];
    for (int i = 0; i < exerciseWorkouts.length && i < 10; i++) {
      final workout = exerciseWorkouts[exerciseWorkouts.length - 1 - i];
      final ex = workout.exercises.firstWhere((e) => e.name == exercise.name);
      if (ex.completedSets.isNotEmpty) {
        final maxWeight = ex.completedSets.map((s) => s.weight).reduce((a, b) => a > b ? a : b);
        chartData.add(FlSpot(i.toDouble(), maxWeight));
        workoutDates.add(DateFormat('M/d').format(workout.date));
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(children: [
          Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade600, borderRadius: BorderRadius.circular(2))),
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  if (exercise.photoPath != null)
                    ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(File(exercise.photoPath!), width: 60, height: 60, fit: BoxFit.cover))
                  else
                    Container(width: 60, height: 60, decoration: BoxDecoration(color: AppTheme.cardColor, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.fitness_center, size: 30)),
                  const SizedBox(width: 16),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(exercise.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                    Text(exercise.muscleGroup ?? 'General', style: TextStyle(color: Colors.grey.shade400)),
                  ])),
                  IconButton(onPressed: () { Navigator.pop(context); _showCreateExerciseDialog(existingExercise: exercise); }, icon: const Icon(Icons.edit)),
                ]),
                const SizedBox(height: 20),
                
                if (shouldIncrease)
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: AppTheme.successColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.successColor.withOpacity(0.5)),
                    ),
                    child: Row(children: [
                      Icon(Icons.trending_up, color: AppTheme.successColor, size: 32),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Time to increase weight!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('You\'ve hit your rep target ${history!.consecutiveGoalsMet} sessions in a row', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                        if (history.lastWeight > 0)
                          Text('Try ${(history.lastWeight + 5).toStringAsFixed(0)} lbs next time', style: TextStyle(color: AppTheme.successColor, fontWeight: FontWeight.w500)),
                      ])),
                    ]),
                  ),
                
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildStatCard('Times Used', '${exercise.timesUsed}', Icons.repeat),
                    _buildStatCard('Last Weight', history?.lastWeight.toStringAsFixed(0) ?? '--', Icons.fitness_center, suffix: 'lbs'),
                    _buildStatCard('Last Reps', history?.lastReps.toString() ?? '--', Icons.format_list_numbered),
                  ],
                ),
                const SizedBox(height: 20),
                
                if (chartData.length >= 2) ...[
                  const Text('Weight Progress', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Container(
                    height: 200,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppTheme.cardColor, borderRadius: BorderRadius.circular(16)),
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 20, getDrawingHorizontalLine: (value) => FlLine(color: AppTheme.cardColorLight, strokeWidth: 1)),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (value, meta) => Text('${value.toInt()}', style: TextStyle(color: Colors.grey.shade500, fontSize: 10)))),
                          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index >= 0 && index < workoutDates.length) {
                              return Padding(padding: const EdgeInsets.only(top: 8), child: Text(workoutDates[index], style: TextStyle(color: Colors.grey.shade500, fontSize: 10)));
                            }
                            return const SizedBox.shrink();
                          })),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: chartData,
                            isCurved: true,
                            color: AppTheme.primaryColor,
                            barWidth: 3,
                            dotData: FlDotData(show: true, getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(radius: 4, color: AppTheme.primaryColor, strokeWidth: 2, strokeColor: Colors.white)),
                            belowBarData: BarAreaData(show: true, color: AppTheme.primaryColor.withOpacity(0.1)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                
                const Text('Recent History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ...exerciseWorkouts.take(5).map((workout) {
                  final ex = workout.exercises.firstWhere((e) => e.name == exercise.name);
                  final totalVolume = ex.completedSets.fold<double>(0, (sum, s) => sum + (s.weight * s.reps));
                  final maxWeight = ex.completedSets.isNotEmpty ? ex.completedSets.map((s) => s.weight).reduce((a, b) => a > b ? a : b) : 0.0;
                  final hitTarget = ex.completedSets.every((s) => s.reps >= exercise.defaultMaxReps);
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Flexible(child: Text(DateFormat('MMM d, yyyy').format(workout.date), style: const TextStyle(fontWeight: FontWeight.w500))),
                          const Spacer(),
                          if (hitTarget)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: AppTheme.successColor.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.check, color: AppTheme.successColor, size: 14),
                                const SizedBox(width: 4),
                                Text('Hit target', style: TextStyle(color: AppTheme.successColor, fontSize: 11)),
                              ]),
                            ),
                        ]),
                        const SizedBox(height: 8),
                        Wrap(spacing: 8, runSpacing: 4, children: ex.completedSets.map((set) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: AppTheme.cardColorLight, borderRadius: BorderRadius.circular(8)),
                            child: Text('${set.weight.toStringAsFixed(0)} lbs Ã— ${set.reps}', style: const TextStyle(fontSize: 12)),
                          );
                        }).toList()),
                        const SizedBox(height: 8),
                        Text('Max: ${maxWeight.toStringAsFixed(0)} lbs â€¢ Volume: ${totalVolume.toStringAsFixed(0)} lbs', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                      ]),
                    ),
                  );
                }),
                
                if (exercise.notes != null && exercise.notes!.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Text('Notes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppTheme.cardColor, borderRadius: BorderRadius.circular(12)),
                    child: Text(exercise.notes!, style: TextStyle(color: Colors.grey.shade300)),
                  ),
                ],
                
                const SizedBox(height: 20),
                Text('Default: ${exercise.defaultSets} sets Ã— ${exercise.repsDisplay}', style: TextStyle(color: Colors.grey.shade500)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, {String? suffix}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppTheme.cardColor, borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Icon(icon, color: AppTheme.primaryColor, size: 20),
        const SizedBox(height: 8),
        Row(mainAxisSize: MainAxisSize.min, children: [
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          if (suffix != null) Text(' $suffix', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
        ]),
        Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
      ]),
    );
  }

  // ==================== OPTIONS MENUS ====================

  void _showExerciseOptions(SavedExercise exercise) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: const Icon(Icons.visibility),
              title: const Text('View Progress'),
              onTap: () { Navigator.pop(context); _showExerciseDetails(exercise); },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Exercise'),
              onTap: () { Navigator.pop(context); _showCreateExerciseDialog(existingExercise: exercise); },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: Colors.red.shade400),
              title: Text('Delete', style: TextStyle(color: Colors.red.shade400)),
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Exercise?'),
                    content: Text('This will remove "${exercise.name}" from your library.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                      FilledButton(onPressed: () => Navigator.pop(context, true), style: FilledButton.styleFrom(backgroundColor: Colors.red.shade400), child: const Text('Delete')),
                    ],
                  ),
                );
                if (confirm == true) {
                  Navigator.pop(context);
                  await context.read<StorageService>().deleteSavedExercise(exercise.id);
                  _loadData();
                }
              },
            ),
          ]),
        ),
      ),
    );
  }

  void _showRoutineOptions(WorkoutRoutine routine) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: const Icon(Icons.play_arrow),
              title: const Text('Start Workout'),
              onTap: () { Navigator.pop(context); _startRoutine(routine); },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Routine'),
              onTap: () { Navigator.pop(context); _showCreateRoutineDialog(existingRoutine: routine); },
            ),
            ListTile(
              leading: const Icon(Icons.upload),
              title: const Text('Export'),
              onTap: () { Navigator.pop(context); _exportRoutine(routine); },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: Colors.red.shade400),
              title: Text('Delete', style: TextStyle(color: Colors.red.shade400)),
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Routine?'),
                    content: Text('This will remove "${routine.name}" from your routines.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                      FilledButton(onPressed: () => Navigator.pop(context, true), style: FilledButton.styleFrom(backgroundColor: Colors.red.shade400), child: const Text('Delete')),
                    ],
                  ),
                );
                if (confirm == true) {
                  Navigator.pop(context);
                  await context.read<StorageService>().deleteWorkoutRoutine(routine.id);
                  _loadData();
                }
              },
            ),
          ]),
        ),
      ),
    );
  }
}

// Constants for muscle groups and routine colors
class MuscleGroups {
  static const all = [
    'Chest', 'Back', 'Shoulders', 'Biceps', 'Triceps', 
    'Legs', 'Glutes', 'Core', 'Full Body', 'Other'
  ];
}

class RoutineColors {
  static const all = [
    '4CAF50', 'E91E63', '2196F3', 'FF9800', '9C27B0',
    '00BCD4', 'FFEB3B', '795548', '607D8B', 'F44336'
  ];
}

/// Muscle groups for stretches
class StretchMuscleGroups {
  static const List<String> all = [
    'Neck',
    'Shoulders',
    'Chest',
    'Back',
    'Arms',
    'Core',
    'Hips',
    'Glutes',
    'Hamstrings',
    'Quads',
    'Calves',
    'Full Body',
    'Other',
  ];
}

/// Colors for stretch routines (teal/green focused)
class StretchRoutineColors {
  static const List<String> all = [
    '26A69A', // Teal
    '00897B', // Dark Teal
    '43A047', // Green
    '7CB342', // Light Green
    '00ACC1', // Cyan
    '5C6BC0', // Indigo
    '8E24AA', // Purple
    'EC407A', // Pink
    'FF7043', // Deep Orange
    '78909C', // Blue Grey
  ];
}
