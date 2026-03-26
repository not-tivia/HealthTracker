import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/storage_service.dart';
import '../models/saved_exercise.dart';
import '../models/saved_stretch.dart';
import '../models/workout.dart';
import '../models/workout_history.dart';

class LibraryScreen extends StatefulWidget {
  final int initialTab; // 0 = exercises, 1 = stretches

  const LibraryScreen({super.key, this.initialTab = 0});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  String? _selectedMuscleGroup;
  final _searchController = TextEditingController();

  List<SavedExercise> _exercises = [];
  List<SavedStretch> _stretches = [];
  Map<String, ExerciseHistory> _exerciseHistory = {};
  List<String> _recentExerciseNames = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
    _tabController.addListener(() {
      // Clear filters when switching tabs
      setState(() {
        _searchQuery = '';
        _selectedMuscleGroup = null;
        _searchController.clear();
      });
    });
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _loadData() {
    final storage = context.read<StorageService>();
    final exercises = storage.getAllSavedExercises();
    final stretches = storage.getAllSavedStretches();
    final history = storage.getExerciseHistory();
    final workouts = storage.getAllWorkouts();

    // Build recent exercise names from last workouts
    final recentNames = <String>[];
    for (final workout in workouts) {
      for (final ex in workout.exercises) {
        if (!recentNames.contains(ex.name) && recentNames.length < 6) {
          recentNames.add(ex.name);
        }
      }
      if (recentNames.length >= 6) break;
    }

    setState(() {
      _exercises = exercises;
      _stretches = stretches;
      _exerciseHistory = history;
      _recentExerciseNames = recentNames;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        title: const Text('My Library'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryColor,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textTertiary,
          tabs: [
            Tab(text: 'Exercises (${_exercises.length})'),
            Tab(text: 'Stretches (${_stretches.length})'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: _tabController.index == 0 ? 'Search exercises...' : 'Search stretches...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: AppTheme.cardColor,
              ),
              onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
            ),
          ),
          // Muscle group filter chips
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: const Text('All'),
                    selected: _selectedMuscleGroup == null,
                    onSelected: (_) => setState(() => _selectedMuscleGroup = null),
                    selectedColor: AppTheme.primaryColor.withOpacity(0.3),
                    checkmarkColor: AppTheme.primaryColor,
                  ),
                ),
                ...MuscleGroups.all.map((group) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(group),
                    selected: _selectedMuscleGroup == group,
                    onSelected: (_) => setState(() =>
                      _selectedMuscleGroup = _selectedMuscleGroup == group ? null : group
                    ),
                    selectedColor: AppTheme.primaryColor.withOpacity(0.3),
                    checkmarkColor: AppTheme.primaryColor,
                  ),
                )),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildExerciseList(),
                _buildStretchList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============ EXERCISE TAB ============

  List<SavedExercise> _getFilteredExercises() {
    var filtered = _exercises.toList();
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((e) =>
        e.name.toLowerCase().contains(_searchQuery) ||
        (e.muscleGroup?.toLowerCase().contains(_searchQuery) ?? false)
      ).toList();
    }
    if (_selectedMuscleGroup != null) {
      filtered = filtered.where((e) => e.muscleGroup == _selectedMuscleGroup).toList();
    }
    return filtered;
  }

  Widget _buildExerciseList() {
    final filtered = _getFilteredExercises();
    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fitness_center, size: 48, color: Colors.grey.shade600),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty && _selectedMuscleGroup == null
                  ? 'No exercises yet'
                  : 'No exercises match your search',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    // Split into 3 sections
    final recent = <SavedExercise>[];
    final experienced = <SavedExercise>[];
    final unused = <SavedExercise>[];

    for (final ex in filtered) {
      if (_recentExerciseNames.contains(ex.name)) {
        recent.add(ex);
      } else if (ex.timesUsed > 0) {
        experienced.add(ex);
      } else {
        unused.add(ex);
      }
    }

    // Sort recent by the order they appear in _recentExerciseNames
    recent.sort((a, b) =>
      _recentExerciseNames.indexOf(a.name).compareTo(_recentExerciseNames.indexOf(b.name)));
    // Sort experienced and unused alphabetically
    experienced.sort((a, b) => a.name.compareTo(b.name));
    unused.sort((a, b) => a.name.compareTo(b.name));

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        if (recent.isNotEmpty) ...[
          _buildSectionHeader('Recent', recent.length),
          ...recent.map((e) => _buildExerciseTile(e)),
        ],
        if (experienced.isNotEmpty) ...[
          _buildSectionHeader('Used Before', experienced.length),
          ...experienced.map((e) => _buildExerciseTile(e)),
        ],
        if (unused.isNotEmpty) ...[
          _buildSectionHeader('Not Yet Used', unused.length),
          ...unused.map((e) => _buildExerciseTile(e)),
        ],
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildExerciseTile(SavedExercise exercise) {
    final history = _exerciseHistory[exercise.name];
    final shouldIncrease = history != null && history.consecutiveGoalsMet >= 3;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      color: shouldIncrease ? AppTheme.successColor.withOpacity(0.1) : AppTheme.cardColor,
      child: ListTile(
        onTap: () {
          // Return the exercise to caller (for detail view)
          Navigator.pop(context, {'type': 'exercise_tap', 'exercise': exercise});
        },
        onLongPress: () {
          Navigator.pop(context, {'type': 'exercise_long_press', 'exercise': exercise});
        },
        leading: exercise.photoPath != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(exercise.photoPath!),
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildDefaultIcon(Icons.fitness_center),
                ),
              )
            : _buildDefaultIcon(Icons.fitness_center),
        title: Row(
          children: [
            Flexible(
              child: Text(exercise.name, overflow: TextOverflow.ellipsis),
            ),
            if (shouldIncrease) ...[
              const SizedBox(width: 8),
              Icon(Icons.trending_up, color: AppTheme.successColor, size: 16),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${exercise.muscleGroup ?? "General"} \u2022 ${exercise.defaultSets} sets \u2022 ${exercise.repsDisplay}',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
            if (history != null)
              Text(
                'Last: ${history.lastWeight.toStringAsFixed(0)} lbs \u00D7 ${history.lastReps} reps \u2022 ${history.sessionCount} sessions',
                style: TextStyle(color: AppTheme.primaryColor.withOpacity(0.7), fontSize: 11),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (exercise.timesUsed > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${exercise.timesUsed}x',
                  style: TextStyle(color: AppTheme.primaryColor, fontSize: 11),
                ),
              ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: Colors.grey.shade500, size: 20),
          ],
        ),
      ),
    );
  }

  // ============ STRETCH TAB ============

  List<SavedStretch> _getFilteredStretches() {
    var filtered = _stretches.toList();
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((s) =>
        s.name.toLowerCase().contains(_searchQuery) ||
        (s.muscleGroup?.toLowerCase().contains(_searchQuery) ?? false)
      ).toList();
    }
    if (_selectedMuscleGroup != null) {
      filtered = filtered.where((s) => s.muscleGroup == _selectedMuscleGroup).toList();
    }
    filtered.sort((a, b) => a.name.compareTo(b.name));
    return filtered;
  }

  Widget _buildStretchList() {
    final filtered = _getFilteredStretches();
    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.self_improvement, size: 48, color: Colors.grey.shade600),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty && _selectedMuscleGroup == null
                  ? 'No stretches yet'
                  : 'No stretches match your search',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    // Group by muscle group for stretches
    final groups = <String, List<SavedStretch>>{};
    for (final s in filtered) {
      final group = s.muscleGroup ?? 'General';
      groups.putIfAbsent(group, () => []).add(s);
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        for (final entry in groups.entries) ...[
          _buildSectionHeader(entry.key, entry.value.length),
          ...entry.value.map((s) => _buildStretchTile(s)),
        ],
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildStretchTile(SavedStretch stretch) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      color: AppTheme.cardColor,
      child: ListTile(
        onTap: () {
          Navigator.pop(context, {'type': 'stretch_tap', 'stretch': stretch});
        },
        onLongPress: () {
          Navigator.pop(context, {'type': 'stretch_long_press', 'stretch': stretch});
        },
        leading: _buildDefaultIcon(Icons.self_improvement),
        title: Text(stretch.name, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${stretch.muscleGroup ?? "General"} \u2022 ${stretch.defaultDuration}s',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
        ),
        trailing: Icon(Icons.chevron_right, color: Colors.grey.shade500, size: 20),
      ),
    );
  }

  // ============ SHARED HELPERS ============

  Widget _buildSectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              color: AppTheme.textTertiary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: TextStyle(color: AppTheme.textTertiary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultIcon(IconData icon) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppTheme.cardColorLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: AppTheme.textTertiary, size: 24),
    );
  }
}
