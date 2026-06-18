import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/in_progress_workout.dart';
import '../models/saved_exercise.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'today_tab.dart';
import 'progress_tab.dart';
import 'tools_tab.dart';
import 'workout_tab.dart';
import 'settings_tab.dart';
import 'workout_session_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const TodayTab(),
    const ProgressTab(),
    const ToolsTab(),
    const WorkoutTab(),
    const SettingsTab(),
  ];

  bool _recoveryChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForRecovery());
  }

  Future<void> _checkForRecovery() async {
    if (_recoveryChecked || !mounted) return;
    _recoveryChecked = true;
    final storage = context.read<StorageService>();
    final snapshot = storage.getInProgressWorkout();
    if (snapshot == null) return;
    if (!mounted) return;
    await _showRecoveryDialog(storage, snapshot);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNavItem(0, Icons.today_outlined, Icons.today, 'Today'),
                _buildNavItem(1, Icons.show_chart_outlined, Icons.show_chart, 'Progress'),
                _buildNavItem(2, Icons.build_outlined, Icons.build, 'Tools'),
                _buildNavItem(3, Icons.fitness_center_outlined, Icons.fitness_center, 'Workout'),
                _buildNavItem(4, Icons.settings_outlined, Icons.settings, 'Settings'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _ageLabel(DateTime start) {
    final diff = DateTime.now().difference(start);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
  }

  Future<void> _showRecoveryDialog(
      StorageService storage, InProgressWorkout snapshot) async {
    final logged = snapshot.loggedExerciseCount;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Unfinished workout'),
        content: Text(
          '${snapshot.routineName} - started ${_ageLabel(snapshot.startTime)}, '
          '$logged exercise${logged == 1 ? '' : 's'} logged.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await storage.clearInProgressWorkout();
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Discard'),
          ),
          // Nothing to save if no sets were logged - leave only Resume/Discard.
          TextButton(
            onPressed: logged == 0
                ? null
                : () async {
                    await storage.saveWorkoutSession(
                      workoutName: snapshot.routineName,
                      workoutType: snapshot.routineName,
                      exercises: snapshot.toExercises(),
                      durationMinutes: snapshot.lastSaved
                          .difference(snapshot.startTime)
                          .inMinutes,
                      routineId: snapshot.routineId,
                      date: snapshot.startTime,
                    );
                    await storage.clearInProgressWorkout();
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                  },
            child: const Text('Save what I logged'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _resumeWorkout(storage, snapshot);
            },
            child: const Text('Resume'),
          ),
        ],
      ),
    );
  }

  void _resumeWorkout(StorageService storage, InProgressWorkout snapshot) {
    final exercises = snapshot.exercises.map((ie) {
      final saved = ie.savedExerciseId == null
          ? null
          : storage.getSavedExerciseById(ie.savedExerciseId!);
      if (saved != null) return saved;
      // Saved exercise was deleted - synthesize a stand-in from the snapshot.
      final parts = ie.targetReps.split('-');
      final minReps =
          int.tryParse(parts.first.replaceAll(RegExp(r'[^0-9]'), '')) ?? 8;
      final maxReps = parts.length > 1
          ? (int.tryParse(parts.last.replaceAll(RegExp(r'[^0-9]'), '')) ?? minReps)
          : minReps;
      return SavedExercise(
        id: ie.savedExerciseId ?? ie.name,
        name: ie.name,
        defaultSets: ie.targetSets,
        defaultMinReps: minReps,
        defaultMaxReps: maxReps,
        youtubeUrl: ie.youtubeUrl,
      );
    }).toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkoutSessionScreen(
          routineName: snapshot.routineName,
          routineId: snapshot.routineId,
          exercises: exercises,
          resumeFrom: snapshot,
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label) {
    bool isSelected = _currentIndex == index;
    
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _currentIndex = index),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryColor.withOpacity(0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? activeIcon : icon,
                color: isSelected ? AppTheme.primaryColor : AppTheme.textTertiary,
                size: 24,
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? AppTheme.primaryColor : AppTheme.textTertiary,
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
