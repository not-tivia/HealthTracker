import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../models/workout.dart';
import '../models/workout_history.dart';
import '../models/saved_exercise.dart';
import '../models/workout_routine.dart';
import '../services/storage_service.dart';
import '../widgets/rest_timer_widget.dart';
import '../widgets/post_workout_popup.dart';
import 'stretch_session_screen.dart';

class WorkoutSessionScreen extends StatefulWidget {
  final String routineName;
  final String routineId;
  final List<SavedExercise> exercises;

  const WorkoutSessionScreen({
    super.key,
    required this.routineName,
    required this.routineId,
    required this.exercises,
  });

  @override
  State<WorkoutSessionScreen> createState() => _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends State<WorkoutSessionScreen> {
  int _currentExerciseIndex = 0;
  final List<Exercise> _completedExercises = [];
  final Map<int, List<ExerciseSet>> _exerciseSets = {};
  final Map<int, List<TextEditingController>> _weightControllers = {};
  final Map<int, List<TextEditingController>> _repControllers = {};
  Map<String, ExerciseHistory>? _exerciseHistory;
  bool _isLoading = true;
  final DateTime _startTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _initializeSets();
    _loadHistory();
  }

  void _initializeSets() {
    for (int i = 0; i < widget.exercises.length; i++) {
      final exercise = widget.exercises[i];
      _exerciseSets[i] = List.generate(
        exercise.defaultSets,
        (setIndex) => ExerciseSet(setNumber: setIndex + 1, weight: 0, reps: exercise.defaultMinReps),
      );
      _weightControllers[i] = List.generate(exercise.defaultSets, (_) => TextEditingController());
      _repControllers[i] = List.generate(exercise.defaultSets, (_) => TextEditingController(text: '${exercise.defaultMinReps}'));
    }
  }

  Future<void> _loadHistory() async {
    final storage = context.read<StorageService>();
    final history = await storage.getExerciseHistory();
    setState(() {
      _exerciseHistory = history;
      _isLoading = false;
    });
    for (int i = 0; i < widget.exercises.length; i++) {
      final lastHistory = history[widget.exercises[i].name];
      if (lastHistory != null) {
        // Use minWeight to help users complete full sets
        // This is especially helpful when user couldn't complete all sets last time
        final weightToUse = lastHistory.minWeight > 0
            ? lastHistory.minWeight
            : lastHistory.lastWeight;
        if (weightToUse > 0) {
          for (var c in _weightControllers[i]!) {
            c.text = weightToUse.toStringAsFixed(0);
          }
        }
      }
    }
  }

  @override
  void dispose() {
    for (var controllers in _weightControllers.values) {
      for (var c in controllers) c.dispose();
    }
    for (var controllers in _repControllers.values) {
      for (var c in controllers) c.dispose();
    }
    super.dispose();
  }

  SavedExercise get _currentExercise => widget.exercises[_currentExerciseIndex];

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(widget.routineName),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(widget.routineName),
        ),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: _confirmExit),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text('${_currentExerciseIndex + 1}/${widget.exercises.length}',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 16)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: (_currentExerciseIndex + 1) / widget.exercises.length,
            backgroundColor: Colors.grey.shade800,
            minHeight: 3,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildExerciseHeader(),
                  const SizedBox(height: 16),
                  _buildExerciseImage(),
                  const SizedBox(height: 16),
                  if (_currentExercise.youtubeUrl != null && _currentExercise.youtubeUrl!.isNotEmpty)
                    _buildYouTubeButton(),
                  const SizedBox(height: 24),
                  _buildSetsSection(),
                  const SizedBox(height: 24),
                  _buildLastSessionInfo(),
                  if (_currentExercise.notes != null && _currentExercise.notes!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildNotesSection(),
                  ],
                ],
              ),
            ),
          ),
          _buildBottomNavigation(),
        ],
      ),
    );
  }


  Widget _buildExerciseHeader() {
    // Get progress indicator for consecutive goals met
    final history = _exerciseHistory?[_currentExercise.name];
    final consecutiveGoals = history?.consecutiveGoalsMet ?? 0;
    final progressText = '$consecutiveGoals/3';
    final isAtTarget = consecutiveGoals >= 3;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_currentExercise.name, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_currentExercise.defaultSets} sets \u{00D7} ${_currentExercise.repsDisplay}',
                style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w500),
              ),
            ),
            if (_currentExercise.muscleGroup != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: Colors.grey.shade800, borderRadius: BorderRadius.circular(20)),
                child: Text(_currentExercise.muscleGroup ?? '', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
              ),
            // Progress indicator showing consecutive goals met
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isAtTarget ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isAtTarget ? Icons.trending_up : Icons.flag_outlined,
                    size: 14,
                    color: isAtTarget ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    progressText,
                    style: TextStyle(
                      color: isAtTarget ? Colors.green : Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildExerciseImage() {
    final photoPath = _currentExercise.photoPath;
    if (photoPath != null && photoPath.isNotEmpty) {
      final file = File(photoPath);
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.file(file, height: 200, width: double.infinity, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildPlaceholderImage()),
      );
    }
    return _buildPlaceholderImage();
  }

  Widget _buildPlaceholderImage() {
    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(color: Colors.grey.shade800, borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.fitness_center, size: 64, color: Colors.grey.shade600),
          const SizedBox(height: 8),
          Text(_currentExercise.name, style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildYouTubeButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _launchYouTube(_currentExercise.youtubeUrl!),
        icon: const Icon(Icons.play_circle_outline, color: Colors.red),
        label: const Text('Watch Form Tutorial'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red,
          side: const BorderSide(color: Colors.red),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildNotesSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.grey.shade800.withOpacity(0.5), borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.notes, size: 18, color: Colors.grey.shade400),
          const SizedBox(width: 8),
          Expanded(child: Text(_currentExercise.notes!, style: TextStyle(color: Colors.grey.shade300, fontSize: 14))),
        ],
      ),
    );
  }

  Widget _buildSetsSection() {
    final sets = _exerciseSets[_currentExerciseIndex]!;
    final weightControllers = _weightControllers[_currentExerciseIndex]!;
    final repControllers = _repControllers[_currentExerciseIndex]!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Sets', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const Spacer(),
            // Rest Timer Button
            TextButton.icon(
              onPressed: () => showRestTimeSelector(context),
              icon: const Icon(Icons.timer, size: 18),
              label: const Text('Rest'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.orange,
              ),
            ),
            TextButton.icon(onPressed: _addSet, icon: const Icon(Icons.add, size: 18), label: const Text('Add Set')),
          ],
        ),
        const SizedBox(height: 12),
        ...List.generate(sets.length, (i) => _buildSetRow(i, sets[i], weightControllers[i], repControllers[i])),
      ],
    );
  }

  Widget _buildSetRow(int index, ExerciseSet set, TextEditingController weightC, TextEditingController repC) {
    final currentSets = _exerciseSets[_currentExerciseIndex]!;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text('${index + 1}',
                  style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: weightC,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      labelText: 'lbs',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    onChanged: (v) {
                      final weight = double.tryParse(v) ?? 0;
                      setState(() => currentSets[index] = ExerciseSet(setNumber: set.setNumber, weight: weight, reps: set.reps));
                    },
                  ),
                ),
                const SizedBox(width: 12),
                const Text('x', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: repC,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      labelText: 'reps',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    onChanged: (v) {
                      final reps = int.tryParse(v) ?? 0;
                      setState(() => currentSets[index] = ExerciseSet(setNumber: set.setNumber, weight: set.weight, reps: reps));
                    },
                  ),
                ),
              ],
            ),
          ),
          if (currentSets.length > _currentExercise.defaultSets)
            IconButton(
              onPressed: () => _removeSet(index),
              icon: Icon(Icons.remove_circle_outline, color: Colors.red.shade400),
            ),
        ],
      ),
    );
  }

  Widget _buildLastSessionInfo() {
    final history = _exerciseHistory?[_currentExercise.name];
    if (history == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade800.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade700),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history, size: 18, color: Colors.grey.shade400),
              const SizedBox(width: 8),
              Text('Last Session', style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildHistoryStat('Weight', '${history.lastWeight.toStringAsFixed(0)} lbs'),
              _buildHistoryStat('Reps', '${history.lastReps}'),
              _buildHistoryStat('Sessions', '${history.sessionCount}'),
            ],
          ),
          if (history.consecutiveGoalsMet >= 2)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    const Icon(Icons.trending_up, color: Colors.green, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${history.consecutiveGoalsMet} sessions hitting target - consider increasing weight!',
                        style: const TextStyle(color: Colors.green, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHistoryStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
      ],
    );
  }

  Widget _buildBottomNavigation() {
    final isFirst = _currentExerciseIndex == 0;
    final isLast = _currentExerciseIndex == widget.exercises.length - 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (!isFirst)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _previousExercise,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Previous'),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              )
            else
              const Expanded(child: SizedBox()),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: isLast ? _completeWorkout : _nextExercise,
                icon: Icon(isLast ? Icons.check : Icons.arrow_forward),
                label: Text(isLast ? 'Complete Workout' : 'Next Exercise'),
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addSet() {
    setState(() {
      final currentSets = _exerciseSets[_currentExerciseIndex]!;
      currentSets.add(ExerciseSet(setNumber: currentSets.length + 1, weight: 0, reps: _currentExercise.defaultMinReps));
      _weightControllers[_currentExerciseIndex]!.add(TextEditingController());
      _repControllers[_currentExerciseIndex]!.add(TextEditingController(text: '${_currentExercise.defaultMinReps}'));
    });
  }

  void _removeSet(int index) {
    setState(() {
      final currentSets = _exerciseSets[_currentExerciseIndex]!;
      if (currentSets.length <= _currentExercise.defaultSets) return;
      currentSets.removeAt(index);
      _weightControllers[_currentExerciseIndex]![index].dispose();
      _weightControllers[_currentExerciseIndex]!.removeAt(index);
      _repControllers[_currentExerciseIndex]![index].dispose();
      _repControllers[_currentExerciseIndex]!.removeAt(index);
    });
  }

  void _previousExercise() {
    _saveCurrentExercise();
    setState(() => _currentExerciseIndex--);
  }

  void _nextExercise() {
    _saveCurrentExercise();
    setState(() => _currentExerciseIndex++);
  }

  void _saveCurrentExercise() {
    final currentSets = _exerciseSets[_currentExerciseIndex]!;
    final savedSets = <ExerciseSet>[];
    for (int i = 0; i < currentSets.length; i++) {
      final weight = double.tryParse(_weightControllers[_currentExerciseIndex]![i].text) ?? 0;
      final reps = int.tryParse(_repControllers[_currentExerciseIndex]![i].text) ?? 0;
      savedSets.add(ExerciseSet(setNumber: i + 1, weight: weight, reps: reps));
    }
    if (savedSets.isNotEmpty) {
      final exercise = Exercise(
        id: const Uuid().v4(),
        name: _currentExercise.name,
        targetSets: _currentExercise.defaultSets,
        targetReps: _currentExercise.repsDisplay,
        completedSets: savedSets,
        youtubeUrl: _currentExercise.youtubeUrl,
        isCompleted: true,
        savedExerciseId: _currentExercise.id,
      );
      final existingIndex = _completedExercises.indexWhere((e) => e.name == exercise.name);
      if (existingIndex >= 0) {
        _completedExercises[existingIndex] = exercise;
      } else {
        _completedExercises.add(exercise);
      }
    }
  }

  void _completeWorkout() async {
    _saveCurrentExercise();
    if (_completedExercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete at least one exercise'), backgroundColor: Colors.orange),
      );
      return;
    }
    final duration = DateTime.now().difference(_startTime);
    final storage = context.read<StorageService>();

    // Update exercise usage counts
    for (final ex in widget.exercises) {
      await storage.incrementExerciseUsage(ex.id);
    }

    // Update routine usage
    final routine = storage.getWorkoutRoutineById(widget.routineId);
    if (routine != null) {
      routine.timesCompleted++;
      routine.lastUsed = DateTime.now();
      await storage.saveWorkoutRoutine(routine);
    }

    await storage.saveWorkoutSession(
      workoutName: widget.routineName,
      workoutType: widget.routineName,
      exercises: _completedExercises,
      durationMinutes: duration.inMinutes,
      routineId: widget.routineId,
    );

    if (mounted) _showCompletionDialog(duration);
  }

  void _showCompletionDialog(Duration duration) {
    final totalSets = _completedExercises.fold<int>(0, (sum, e) => sum + e.completedSets.length);
    final totalVolume = _completedExercises.fold<double>(
      0, (sum, e) => sum + e.completedSets.fold<double>(0, (s, set) => s + (set.weight * set.reps)));

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.check, color: Colors.green),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Workout Complete!',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildCompletionStat(Icons.timer, 'Duration', '${duration.inMinutes} min'),
            const SizedBox(height: 12),
            _buildCompletionStat(Icons.fitness_center, 'Exercises', '${_completedExercises.length}'),
            const SizedBox(height: 12),
            _buildCompletionStat(Icons.format_list_numbered, 'Total Sets', '$totalSets'),
            const SizedBox(height: 12),
            _buildCompletionStat(Icons.monitor_weight, 'Volume', '${totalVolume.toStringAsFixed(0)} lbs'),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () async {
              Navigator.pop(context); // Close completion dialog

              // Check for warm-down stretch suggestion
              final storage = context.read<StorageService>();
              String? warmDownStretchId;
              if (widget.routineId.isNotEmpty) {
                warmDownStretchId = storage.findWarmDownStretch(widget.routineId);
              }

              if (warmDownStretchId != null && mounted) {
                final stretchRoutines = storage.getAllStretchRoutines();
                final stretchRoutine = stretchRoutines
                    .where((s) => s.id == warmDownStretchId)
                    .firstOrNull;

                if (stretchRoutine != null && mounted) {
                  final wantStretch = await PostWorkoutPopup.show(
                    context,
                    stretchName: stretchRoutine.name,
                  );

                  if (wantStretch && mounted) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StretchSessionScreen(routine: stretchRoutine),
                      ),
                    );
                    return;
                  }
                }
              }

              if (mounted) Navigator.pop(context); // Pop workout session screen
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionStat(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade400),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label, 
            style: TextStyle(color: Colors.grey.shade400),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }

  void _launchYouTube(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _confirmExit() {
    if (_completedExercises.isEmpty && _currentExerciseIndex == 0) {
      Navigator.pop(context);
      return;
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Workout?'),
        content: const Text('Your progress will be lost.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Keep Going')),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade400),
            child: const Text('Cancel Workout'),
          ),
        ],
      ),
    );
  }
}
