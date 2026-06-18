# Workout Session Autosave & Recovery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Persist an in-progress workout so an accidentally-closed session can be recovered (resume, save-what-was-logged, or discard) on next app launch.

**Architecture:** A pure Dart `InProgressWorkout` value-object (no Hive) serializes the live session to JSON. `StorageService` stores that JSON string under one key in the existing `app_data` Hive box. `WorkoutSessionScreen` autosaves on edits / navigation / app-background (via `WidgetsBindingObserver`) and clears on completion/cancel. `HomeScreen` checks for a saved session on launch and shows a Resume / Save / Discard dialog.

**Tech Stack:** Flutter, Provider, Hive, `dart:convert` (JSON), `uuid`.

**Toolchain note:** The Flutter SDK on the dev machine is a Windows install (`/mnt/c/flutter`) whose CRLF shell scripts cannot run under WSL. All `flutter test`, `flutter analyze`, and `flutter build` commands in this plan MUST be run from a Windows shell (PowerShell/cmd) in the project directory. Whoever executes a step must state explicitly whether the command was actually run or skipped.

**Spec:** `docs/superpowers/specs/2026-06-17-workout-session-autosave-recovery-design.md`

---

## File Structure

- **Create** `lib/models/in_progress_workout.dart` — pure Dart value objects (`InProgressWorkout`, `InProgressExercise`, `InProgressSet`) with JSON (de)serialization, a safe `tryParse`, a `toExercises()` reconstruction, and a `loggedExerciseCount`. No Hive, no Flutter imports — fully unit-testable.
- **Create** `test/in_progress_workout_test.dart` — unit tests for the model.
- **Modify** `lib/services/storage_service.dart` — add `saveInProgressWorkout` / `getInProgressWorkout` / `clearInProgressWorkout`; add optional `date` param to `saveWorkoutSession`.
- **Modify** `lib/screens/workout_session_screen.dart` — `resumeFrom` constructor param + restore, `_snapshot()`, autosave hooks, `WidgetsBindingObserver`, clear-on-complete/cancel.
- **Modify** `lib/screens/home_screen.dart` — launch-time recovery check + dialog + navigation/save.

---

## Task 1: Pure `InProgressWorkout` model + tests

**Files:**
- Create: `lib/models/in_progress_workout.dart`
- Test: `test/in_progress_workout_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/in_progress_workout_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:health_tracker/models/in_progress_workout.dart';

void main() {
  InProgressWorkout sample() => InProgressWorkout(
        routineId: 'r1',
        routineName: 'Leg Day',
        startTime: DateTime(2026, 6, 17, 18, 30),
        lastSaved: DateTime(2026, 6, 17, 18, 52),
        currentExerciseIndex: 1,
        exercises: const [
          InProgressExercise(
            savedExerciseId: 'e1',
            name: 'Back Squat',
            targetSets: 3,
            targetReps: '8-12',
            youtubeUrl: null,
            sets: [
              InProgressSet(weight: 135, reps: 8),
              InProgressSet(weight: 135, reps: 8),
              InProgressSet(weight: 0, reps: 0),
            ],
          ),
          InProgressExercise(
            savedExerciseId: 'e2',
            name: 'Leg Press',
            targetSets: 3,
            targetReps: '10-15',
            youtubeUrl: null,
            sets: [InProgressSet(weight: 0, reps: 0)],
          ),
        ],
      );

  test('round-trips through JSON', () {
    final original = sample();
    final restored = InProgressWorkout.tryParse(original.toJsonString());
    expect(restored, isNotNull);
    expect(restored!.routineId, 'r1');
    expect(restored.routineName, 'Leg Day');
    expect(restored.startTime, DateTime(2026, 6, 17, 18, 30));
    expect(restored.currentExerciseIndex, 1);
    expect(restored.exercises.length, 2);
    expect(restored.exercises.first.name, 'Back Squat');
    expect(restored.exercises.first.sets.length, 3);
    expect(restored.exercises.first.sets[0].weight, 135);
    expect(restored.exercises.first.sets[0].reps, 8);
  });

  test('tryParse returns null on malformed JSON', () {
    expect(InProgressWorkout.tryParse('not json'), isNull);
    expect(InProgressWorkout.tryParse('{}'), isNull);
  });

  test('tryParse returns null on version mismatch', () {
    final bad = sample().toJsonString().replaceFirst('"version":1', '"version":999');
    expect(InProgressWorkout.tryParse(bad), isNull);
  });

  test('loggedExerciseCount counts only exercises with a non-empty set', () {
    // Back Squat has real sets; Leg Press has only an empty set.
    expect(sample().loggedExerciseCount, 1);
  });

  test('toExercises drops empty sets and empty exercises and renumbers', () {
    final exercises = sample().toExercises();
    expect(exercises.length, 1); // Leg Press dropped (no real sets)
    final squat = exercises.first;
    expect(squat.name, 'Back Squat');
    expect(squat.savedExerciseId, 'e1');
    expect(squat.targetReps, '8-12');
    expect(squat.isCompleted, true);
    expect(squat.completedSets.length, 2); // empty 3rd set dropped
    expect(squat.completedSets[0].setNumber, 1);
    expect(squat.completedSets[1].setNumber, 2);
    expect(squat.completedSets[0].weight, 135);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run (Windows shell): `flutter test test/in_progress_workout_test.dart`
Expected: FAIL — `in_progress_workout.dart` does not exist / `InProgressWorkout` undefined.

- [ ] **Step 3: Write the model**

Create `lib/models/in_progress_workout.dart`:

```dart
import 'dart:convert';

import 'package:uuid/uuid.dart';

import 'workout.dart';

/// One logged set inside an in-progress exercise. `weight`/`reps` are the raw
/// values the user typed (0 means blank).
class InProgressSet {
  final double weight;
  final int reps;

  const InProgressSet({required this.weight, required this.reps});

  /// A set the user never filled in.
  bool get isEmpty => weight <= 0 && reps <= 0;

  Map<String, dynamic> toJson() => {'weight': weight, 'reps': reps};

  factory InProgressSet.fromJson(Map<String, dynamic> j) => InProgressSet(
        weight: (j['weight'] as num?)?.toDouble() ?? 0,
        reps: (j['reps'] as num?)?.toInt() ?? 0,
      );
}

/// One exercise inside an in-progress workout. Stores enough to both restore
/// the live session and reconstruct a completed [Exercise].
class InProgressExercise {
  final String? savedExerciseId;
  final String name;
  final int targetSets;
  final String targetReps;
  final String? youtubeUrl;
  final List<InProgressSet> sets;

  const InProgressExercise({
    required this.savedExerciseId,
    required this.name,
    required this.targetSets,
    required this.targetReps,
    required this.youtubeUrl,
    required this.sets,
  });

  Map<String, dynamic> toJson() => {
        'savedExerciseId': savedExerciseId,
        'name': name,
        'targetSets': targetSets,
        'targetReps': targetReps,
        'youtubeUrl': youtubeUrl,
        'sets': sets.map((s) => s.toJson()).toList(),
      };

  factory InProgressExercise.fromJson(Map<String, dynamic> j) =>
      InProgressExercise(
        savedExerciseId: j['savedExerciseId'] as String?,
        name: j['name'] as String? ?? 'Exercise',
        targetSets: (j['targetSets'] as num?)?.toInt() ?? 3,
        targetReps: j['targetReps'] as String? ?? '8-12',
        youtubeUrl: j['youtubeUrl'] as String?,
        sets: ((j['sets'] as List?) ?? [])
            .map((e) => InProgressSet.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

/// A snapshot of an in-progress workout session, serializable to JSON for
/// persistence in the app-data box. Pure Dart - no Hive, no Flutter.
class InProgressWorkout {
  static const int currentVersion = 1;

  final String routineId;
  final String routineName;
  final DateTime startTime;
  final DateTime lastSaved;
  final int currentExerciseIndex;
  final List<InProgressExercise> exercises;

  const InProgressWorkout({
    required this.routineId,
    required this.routineName,
    required this.startTime,
    required this.lastSaved,
    required this.currentExerciseIndex,
    required this.exercises,
  });

  /// Number of exercises that have at least one filled-in set.
  int get loggedExerciseCount =>
      exercises.where((e) => e.sets.any((s) => !s.isEmpty)).length;

  Map<String, dynamic> toJson() => {
        'version': currentVersion,
        'routineId': routineId,
        'routineName': routineName,
        'startTime': startTime.toIso8601String(),
        'lastSaved': lastSaved.toIso8601String(),
        'currentExerciseIndex': currentExerciseIndex,
        'exercises': exercises.map((e) => e.toJson()).toList(),
      };

  String toJsonString() => jsonEncode(toJson());

  /// Parses a stored JSON string. Returns null on any malformed input or a
  /// version mismatch, so a bad record can never wedge the app.
  static InProgressWorkout? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = Map<String, dynamic>.from(jsonDecode(raw));
      if ((map['version'] as num?)?.toInt() != currentVersion) return null;
      final routineId = map['routineId'] as String?;
      final startTime = DateTime.tryParse(map['startTime'] as String? ?? '');
      if (routineId == null || startTime == null) return null;
      return InProgressWorkout(
        routineId: routineId,
        routineName: map['routineName'] as String? ?? 'Workout',
        startTime: startTime,
        lastSaved: DateTime.tryParse(map['lastSaved'] as String? ?? '') ??
            startTime,
        currentExerciseIndex:
            (map['currentExerciseIndex'] as num?)?.toInt() ?? 0,
        exercises: ((map['exercises'] as List?) ?? [])
            .map((e) => InProgressExercise.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Reconstructs completed [Exercise]s, dropping empty sets and any exercise
  /// left with no real sets. Set numbers are renumbered from 1.
  List<Exercise> toExercises() {
    final result = <Exercise>[];
    for (final ex in exercises) {
      final sets = <ExerciseSet>[];
      var n = 1;
      for (final s in ex.sets) {
        if (!s.isEmpty) {
          sets.add(ExerciseSet(setNumber: n++, weight: s.weight, reps: s.reps));
        }
      }
      if (sets.isNotEmpty) {
        result.add(Exercise(
          id: const Uuid().v4(),
          name: ex.name,
          targetSets: ex.targetSets,
          targetReps: ex.targetReps,
          completedSets: sets,
          youtubeUrl: ex.youtubeUrl,
          isCompleted: true,
          savedExerciseId: ex.savedExerciseId,
        ));
      }
    }
    return result;
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run (Windows shell): `flutter test test/in_progress_workout_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/models/in_progress_workout.dart test/in_progress_workout_test.dart
git commit -m "feat: add InProgressWorkout snapshot model with JSON + tests"
```

---

## Task 2: StorageService persistence + dated save

**Files:**
- Modify: `lib/services/storage_service.dart`

- [ ] **Step 1: Add the import**

At the top of `lib/services/storage_service.dart`, add to the model imports (near the other `import '../models/...';` lines):

```dart
import '../models/in_progress_workout.dart';
```

- [ ] **Step 2: Add the in-progress API**

Immediately after the `getStretchRoutineOrder()` method (the `// ============ STRETCH ROUTINE ORDER ============` block, around line 863) add a new section:

```dart
  // ============ IN-PROGRESS WORKOUT (autosave / recovery) ============
  static const String _inProgressWorkoutKey = 'in_progress_workout';

  Future<void> saveInProgressWorkout(InProgressWorkout snapshot) async {
    await _appDataBox.put(_inProgressWorkoutKey, snapshot.toJsonString());
  }

  /// Returns the saved in-progress workout, or null if none / unparseable.
  /// A corrupt record is cleared so it cannot block recovery again.
  InProgressWorkout? getInProgressWorkout() {
    final raw = _appDataBox.get(_inProgressWorkoutKey) as String?;
    if (raw == null) return null;
    final parsed = InProgressWorkout.tryParse(raw);
    if (parsed == null) {
      _appDataBox.delete(_inProgressWorkoutKey);
      return null;
    }
    return parsed;
  }

  Future<void> clearInProgressWorkout() async {
    await _appDataBox.delete(_inProgressWorkoutKey);
  }
```

Note: `saveInProgressWorkout`/`clearInProgressWorkout` deliberately do NOT call
`notifyListeners()` - autosave must not rebuild listening widgets.

- [ ] **Step 3: Add optional `date` to `saveWorkoutSession`**

In `saveWorkoutSession` (around line 255), add a `DateTime? date` parameter and use it for the workout date. Replace the method signature and the `date:` line:

Change the parameter list from:

```dart
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
```

to:

```dart
  Future<void> saveWorkoutSession({
    required String workoutName,
    required String workoutType,
    required List<Exercise> exercises,
    required int durationMinutes,
    String? routineId,
    String? notes,
    DateTime? date,
  }) async {
    final workout = Workout(
      id: const Uuid().v4(),
      name: workoutName,
      type: workoutType,
      date: date ?? DateTime.now(),
```

(The rest of the method - `saveWorkout(workout)` and the rotation-pointer update - is unchanged.)

- [ ] **Step 4: Verify it compiles**

Run (Windows shell): `flutter analyze lib/services/storage_service.dart`
Expected: No errors (warnings about pre-existing issues elsewhere are acceptable).

- [ ] **Step 5: Commit**

```bash
git add lib/services/storage_service.dart
git commit -m "feat: add in-progress workout persistence + dated saveWorkoutSession"
```

---

## Task 3: Autosave from WorkoutSessionScreen

**Files:**
- Modify: `lib/screens/workout_session_screen.dart`

- [ ] **Step 1: Add imports and observer mixin**

At the top of `lib/screens/workout_session_screen.dart`, add:

```dart
import 'dart:async';
```

and add the model import alongside the others:

```dart
import '../models/in_progress_workout.dart';
```

Change the State class declaration (line 34) from:

```dart
class _WorkoutSessionScreenState extends State<WorkoutSessionScreen> {
```

to:

```dart
class _WorkoutSessionScreenState extends State<WorkoutSessionScreen>
    with WidgetsBindingObserver {
```

- [ ] **Step 2: Make `_startTime` assignable and add a debounce field**

Change the field (line 44) from:

```dart
  final DateTime _startTime = DateTime.now();
```

to:

```dart
  late DateTime _startTime = DateTime.now();
  Timer? _autosaveDebounce;
```

- [ ] **Step 3: Register/unregister the lifecycle observer**

In `initState` (around line 46), add observer registration after `super.initState();`:

```dart
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _exercises = List.from(widget.exercises);
    _initializeSets();
    _loadHistory();
  }
```

In `dispose` (around line 94), cancel the debounce and remove the observer. Change:

```dart
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
```

to:

```dart
  @override
  void dispose() {
    _autosaveDebounce?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    for (var controllers in _weightControllers.values) {
      for (var c in controllers) c.dispose();
    }
    for (var controllers in _repControllers.values) {
      for (var c in controllers) c.dispose();
    }
    super.dispose();
  }
```

- [ ] **Step 4: Add snapshot + autosave + lifecycle methods**

Add these methods inside the State class (e.g. right after `dispose`):

```dart
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _autosave();
    }
  }

  /// Build a serializable snapshot of the live session from the controllers.
  InProgressWorkout _snapshot() {
    final exercises = <InProgressExercise>[];
    for (int i = 0; i < _exercises.length; i++) {
      final ex = _exercises[i];
      final weightCs = _weightControllers[i] ?? const [];
      final repCs = _repControllers[i] ?? const [];
      final sets = <InProgressSet>[];
      for (int s = 0; s < weightCs.length; s++) {
        final weight = double.tryParse(weightCs[s].text) ?? 0;
        final reps =
            s < repCs.length ? (int.tryParse(repCs[s].text) ?? 0) : 0;
        sets.add(InProgressSet(weight: weight, reps: reps));
      }
      exercises.add(InProgressExercise(
        savedExerciseId: ex.id,
        name: ex.name,
        targetSets: ex.defaultSets,
        targetReps: ex.repsDisplay,
        youtubeUrl: ex.youtubeUrl,
        sets: sets,
      ));
    }
    return InProgressWorkout(
      routineId: widget.routineId,
      routineName: widget.routineName,
      startTime: _startTime,
      lastSaved: DateTime.now(),
      currentExerciseIndex: _currentExerciseIndex,
      exercises: exercises,
    );
  }

  void _autosave() {
    if (!mounted) return;
    context.read<StorageService>().saveInProgressWorkout(_snapshot());
  }

  void _scheduleAutosave() {
    _autosaveDebounce?.cancel();
    _autosaveDebounce =
        Timer(const Duration(seconds: 1), _autosave);
  }
```

- [ ] **Step 5: Hook autosave into edits and navigation**

In `_buildSetRow` (the weight field `onChanged` around line 378), append `_scheduleAutosave();`:

```dart
                    onChanged: (v) {
                      final weight = double.tryParse(v) ?? 0;
                      setState(() => currentSets[index] = ExerciseSet(setNumber: set.setNumber, weight: weight, reps: set.reps));
                      _scheduleAutosave();
                    },
```

In the reps field `onChanged` (around line 397), append `_scheduleAutosave();`:

```dart
                    onChanged: (v) {
                      final reps = int.tryParse(v) ?? 0;
                      setState(() => currentSets[index] = ExerciseSet(setNumber: set.setNumber, weight: set.weight, reps: reps));
                      _scheduleAutosave();
                    },
```

In `_previousExercise` and `_nextExercise` (around line 666-674), add an autosave after the index change. Change:

```dart
  void _previousExercise() {
    _saveCurrentExercise();
    setState(() => _currentExerciseIndex--);
  }

  void _nextExercise() {
    _saveCurrentExercise();
    setState(() => _currentExerciseIndex++);
  }
```

to:

```dart
  void _previousExercise() {
    _saveCurrentExercise();
    setState(() => _currentExerciseIndex--);
    _autosave();
  }

  void _nextExercise() {
    _saveCurrentExercise();
    setState(() => _currentExerciseIndex++);
    _autosave();
  }
```

In `_removeSet` (around line 656-664, the method that disposes/removes a set's controllers) add `_autosave();` at the end of its `setState`/method body. Locate the method:

```dart
  void _removeSet(int index) {
    setState(() {
      _exerciseSets[_currentExerciseIndex]!.removeAt(index);
      _weightControllers[_currentExerciseIndex]![index].dispose();
      _weightControllers[_currentExerciseIndex]!.removeAt(index);
      _repControllers[_currentExerciseIndex]![index].dispose();
      _repControllers[_currentExerciseIndex]!.removeAt(index);
    });
  }
```

and add `_autosave();` after the `setState` closes:

```dart
  void _removeSet(int index) {
    setState(() {
      _exerciseSets[_currentExerciseIndex]!.removeAt(index);
      _weightControllers[_currentExerciseIndex]![index].dispose();
      _weightControllers[_currentExerciseIndex]!.removeAt(index);
      _repControllers[_currentExerciseIndex]![index].dispose();
      _repControllers[_currentExerciseIndex]!.removeAt(index);
    });
    _autosave();
  }
```

If there is an "add set" method nearby (the `+`/add-set handler that appends controllers), append `_autosave();` to it the same way. (If none exists, skip.)

- [ ] **Step 6: Clear the snapshot on completion and on cancel**

In `_completeWorkout` (around line 731), after the `await storage.saveWorkoutSession(...)` call and before `if (mounted) _showCompletionDialog(duration);`, add a clear:

```dart
    await storage.saveWorkoutSession(
      workoutName: widget.routineName,
      workoutType: widget.routineName,
      exercises: _completedExercises,
      durationMinutes: duration.inMinutes,
      routineId: widget.routineId,
    );
    await storage.clearInProgressWorkout();

    if (mounted) _showCompletionDialog(duration);
```

In `_confirmExit` (around line 851), clear the snapshot when the user confirms cancellation. Change the "Cancel Workout" button's `onPressed`:

```dart
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
```

to:

```dart
          FilledButton(
            onPressed: () {
              context.read<StorageService>().clearInProgressWorkout();
              Navigator.pop(context);
              Navigator.pop(context);
            },
```

- [ ] **Step 7: Verify it compiles**

Run (Windows shell): `flutter analyze lib/screens/workout_session_screen.dart`
Expected: No new errors.

- [ ] **Step 8: Commit**

```bash
git add lib/screens/workout_session_screen.dart
git commit -m "feat: autosave in-progress workout on edit/nav/background"
```

---

## Task 4: Resume restore in WorkoutSessionScreen

**Files:**
- Modify: `lib/screens/workout_session_screen.dart`

- [ ] **Step 1: Add the `resumeFrom` constructor parameter**

Change the widget definition (lines 18-28) from:

```dart
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
```

to:

```dart
class WorkoutSessionScreen extends StatefulWidget {
  final String routineName;
  final String routineId;
  final List<SavedExercise> exercises;
  final InProgressWorkout? resumeFrom;

  const WorkoutSessionScreen({
    super.key,
    required this.routineName,
    required this.routineId,
    required this.exercises,
    this.resumeFrom,
  });
```

- [ ] **Step 2: Restore state in initState**

Change `initState` to restore from `widget.resumeFrom` after sets are initialized:

```dart
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _exercises = List.from(widget.exercises);
    _initializeSets();
    if (widget.resumeFrom != null) {
      _restoreFrom(widget.resumeFrom!);
    }
    _loadHistory();
  }
```

- [ ] **Step 3: Add the `_restoreFrom` method**

Add this method inside the State class (e.g. right after `_initializeSets`):

```dart
  /// Re-hydrate controllers, set lists, and position from a saved snapshot.
  /// Matches by exercise index (the resumed exercise list is reconstructed in
  /// the same order). Resizes each exercise's set lists to the saved counts.
  void _restoreFrom(InProgressWorkout snapshot) {
    _startTime = snapshot.startTime;
    final count =
        _exercises.length < snapshot.exercises.length
            ? _exercises.length
            : snapshot.exercises.length;
    for (int i = 0; i < count; i++) {
      final savedSets = snapshot.exercises[i].sets;
      // Dispose the default controllers for this exercise.
      for (final c in _weightControllers[i] ?? const <TextEditingController>[]) {
        c.dispose();
      }
      for (final c in _repControllers[i] ?? const <TextEditingController>[]) {
        c.dispose();
      }
      // Rebuild sets + controllers from the snapshot.
      _exerciseSets[i] = [
        for (int s = 0; s < savedSets.length; s++)
          ExerciseSet(
            setNumber: s + 1,
            weight: savedSets[s].weight,
            reps: savedSets[s].reps,
          ),
      ];
      _weightControllers[i] = [
        for (final s in savedSets)
          TextEditingController(
              text: s.weight > 0 ? s.weight.toStringAsFixed(0) : ''),
      ];
      _repControllers[i] = [
        for (final s in savedSets)
          TextEditingController(text: s.reps > 0 ? '${s.reps}' : ''),
      ];
    }
    _currentExerciseIndex =
        snapshot.currentExerciseIndex.clamp(0, _exercises.length - 1);
  }
```

Note on `_loadHistory`: it pre-fills weight controllers from history only when
`weightToUse > 0`. On resume this can overwrite a restored blank weight with a
suggested weight, which is acceptable (it is a suggestion, and reps are
preserved). No change required.

- [ ] **Step 4: Verify it compiles**

Run (Windows shell): `flutter analyze lib/screens/workout_session_screen.dart`
Expected: No new errors.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/workout_session_screen.dart
git commit -m "feat: restore WorkoutSessionScreen from a saved snapshot on resume"
```

---

## Task 5: Launch-time recovery dialog in HomeScreen

**Files:**
- Modify: `lib/screens/home_screen.dart`

- [ ] **Step 1: Add imports**

At the top of `lib/screens/home_screen.dart`, add:

```dart
import 'package:provider/provider.dart';

import '../models/in_progress_workout.dart';
import '../models/saved_exercise.dart';
import '../services/storage_service.dart';
import 'workout_session_screen.dart';
```

- [ ] **Step 2: Add an initState that checks for a saved session**

Change `_HomeScreenState` (line 16) to add `initState` and a recovery-check guard. Insert after the `_currentIndex` / `_screens` fields and before `build`:

```dart
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
```

- [ ] **Step 3: Add the recovery dialog + helpers**

Add these methods inside `_HomeScreenState` (e.g. after `_checkForRecovery`):

```dart
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
            onPressed: () {
              storage.clearInProgressWorkout();
              Navigator.pop(dialogContext);
            },
            child: const Text('Discard'),
          ),
          TextButton(
            onPressed: () async {
              await storage.saveWorkoutSession(
                workoutName: snapshot.routineName,
                workoutType: snapshot.routineName,
                exercises: snapshot.toExercises(),
                durationMinutes:
                    snapshot.lastSaved.difference(snapshot.startTime).inMinutes,
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
      final minReps = int.tryParse(parts.first.replaceAll(RegExp(r'[^0-9]'), '')) ?? 8;
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
```

Note: `getSavedExerciseById` already exists on `StorageService` (used by
`workout_tab.dart:3980`).

- [ ] **Step 4: Verify it compiles**

Run (Windows shell): `flutter analyze lib/screens/home_screen.dart`
Expected: No new errors.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/home_screen.dart
git commit -m "feat: recover interrupted workout on launch (resume/save/discard)"
```

---

## Task 6: Full verification (Windows shell)

**Files:** none (verification only)

- [ ] **Step 1: Analyze the whole project**

Run (Windows shell): `flutter analyze`
Expected: No new errors introduced by this work.

- [ ] **Step 2: Run the full test suite**

Run (Windows shell): `flutter test`
Expected: The `in_progress_workout_test.dart` tests pass. (The stale default
`widget_test.dart` may already fail for unrelated reasons - note it, don't fix
it as part of this work.)

- [ ] **Step 3: Manual device verification**

On a device/emulator (`flutter run`), verify each behavior and check the box only after observing it:
  - [ ] Start a workout, log a couple of sets, background the app (Home button), force-kill it, reopen -> recovery dialog appears naming the routine and showing the logged-exercise count.
  - [ ] **Resume** -> session reopens on the same exercise with the logged weights/reps restored.
  - [ ] Repeat; choose **Save what I logged** -> a completed workout appears in history dated to when it was started; recovery dialog does not reappear on next launch.
  - [ ] Repeat; choose **Discard** -> nothing saved; dialog does not reappear on next launch.
  - [ ] Complete a workout normally with **Finish** -> no recovery dialog on next launch.
  - [ ] Start a workout and **Cancel Workout** -> no recovery dialog on next launch.

- [ ] **Step 4: Final commit (if any manual-fix tweaks were needed)**

```bash
git add -A
git commit -m "chore: workout autosave/recovery verification fixes"
```

---

## Notes for the implementer

- DRY: all JSON logic lives in `InProgressWorkout`; screens never touch JSON directly.
- YAGNI: only one in-progress workout is stored; stretch sessions are out of scope.
- The autosave methods intentionally avoid `notifyListeners()` so background saves don't trigger widget rebuilds.
- Non-ASCII is forbidden in Dart files (see CLAUDE.md). All strings above are ASCII; keep it that way (use `\u{...}` escapes if a special character is ever needed).
