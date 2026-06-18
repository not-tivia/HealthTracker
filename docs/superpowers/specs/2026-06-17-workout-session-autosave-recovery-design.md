# Workout Session Autosave & Recovery - Design

**Date:** 2026-06-17
**Status:** Approved, ready for implementation planning

## Problem

Workout sessions are held entirely in memory and only persist to the database
when the user taps **Finish** (`_completeWorkout` in
`lib/screens/workout_session_screen.dart`). If the user accidentally closes the
app, switches away, or the OS kills the process mid-workout, all logged sets are
discarded - `_confirmExit` explicitly warns "Your progress will be lost." There
is no autosave and no app-lifecycle handling (`main.dart` has no
`WidgetsBindingObserver`).

This is the root cause of the user-reported symptom "workout stats not being
recorded - it's June but recent history only shows May": the missing workouts
are the ones that were interrupted and never finalized, so they were never
written to the database at all. (The in-workout history panel rebuilds fresh
from the database on every session open, so a stale in-memory snapshot is *not*
the cause.)

## Goal

If a workout session is interrupted, the user can recover it on next app launch -
either resuming exactly where they left off or saving what they had already
logged - so workout data is never silently lost.

**Scope:** Strength workout sessions only (`WorkoutSessionScreen`). Stretch
sessions are short warm-ups and are explicitly out of scope.

## Approach

### Storage: JSON blob in the existing app-data box (no new Hive model)

Rather than introduce a new Hive `@HiveType` (which would require a unique
typeId, `build_runner` regeneration, and carries a small risk to existing user
data), the in-progress session is serialized to a JSON string and stored under a
single key in the existing `_appDataBox`:

- Key: `in_progress_workout`
- Value: a JSON string (one record - there is only ever one active workout)

Rationale: simpler, no code generation, cannot corrupt existing typed boxes, and
the record is transient and fully owned by this feature. The cost (not
strongly typed) is acceptable for a single self-contained record.

### Serialized snapshot shape

```json
{
  "version": 1,
  "routineId": "<routine uuid>",
  "routineName": "Leg Day",
  "startTime": "2026-06-17T18:30:00.000",
  "lastSaved": "2026-06-17T18:52:10.000",
  "currentExerciseIndex": 2,
  "exercises": [
    {
      "savedExerciseId": "<saved exercise uuid>",
      "name": "Back Squat",
      "sets": [
        { "weight": 135.0, "reps": 8 },
        { "weight": 135.0, "reps": 8 },
        { "weight": 0.0,   "reps": 5 }
      ]
    }
  ]
}
```

Notes:
- `startTime` is preserved so a recovered "Save what I logged" workout is dated
  to when it actually happened, not when the app was reopened.
- `name` is stored alongside `savedExerciseId` so the session can still be
  displayed/recovered if that saved exercise was later deleted from the library.
- `sets` mirrors the live `_weightControllers` / `_repControllers` text for each
  exercise, including partially-filled sets (blank weight stored as `0.0`).

### StorageService API additions

```dart
Future<void> saveInProgressWorkout(Map<String, dynamic> snapshot);
Map<String, dynamic>? getInProgressWorkout(); // decoded, or null
Future<void> clearInProgressWorkout();
```

These wrap `_appDataBox` with `jsonEncode` / `jsonDecode`. A malformed/incompatible
blob (e.g. wrong `version`) is treated as "no in-progress workout" and cleared,
so a bad record can never wedge the app.

`saveWorkoutSession` gains an optional `DateTime? date` parameter (defaulting to
`DateTime.now()`) so the recovery "Save what I logged" path can persist the
workout dated to its original `startTime`.

## Autosave triggers (WorkoutSessionScreen)

The session screen builds a snapshot via a private `_snapshot()` method and
writes it through `storage.saveInProgressWorkout`. Autosave fires on:

1. **Weight/rep field changes** - debounced ~1s (catches a hard process kill
   after recent typing).
2. **Exercise navigation** - `_nextExercise` / `_previousExercise` (which already
   call `_saveCurrentExercise`).
3. **Add/remove set.**
4. **App lifecycle pause** - the screen registers a `WidgetsBindingObserver`;
   on `AppLifecycleState.paused` / `inactive` / `hidden` it runs
   `_saveCurrentExercise()` then writes a snapshot. This is the primary catch for
   "accidentally closed the app."

The blob is **cleared** when:
- The workout is properly completed (`_completeWorkout`, after a successful
  `saveWorkoutSession`).
- The user taps **Cancel Workout** in `_confirmExit`.

The observer is unregistered in `dispose`.

## Recovery on launch (HomeScreen)

`_HomeScreenState` gains an `initState` that, after the first frame, checks
`storage.getInProgressWorkout()`. If a record exists and no recovery dialog is
already showing, it presents a dialog:

```
Unfinished workout
Leg Day - started 2 hours ago, 3 exercises logged
[ Resume ]   [ Save what I logged ]   [ Discard ]
```

- **Resume** -> push `WorkoutSessionScreen` with an optional `resumeFrom`
  parameter (the decoded snapshot). `initState` restores `_currentExerciseIndex`,
  rebuilds `_exerciseSets` / `_weightControllers` / `_repControllers` from the
  saved set data, and reuses the saved `startTime` as `_startTime`.
- **Save what I logged** -> reconstruct `List<Exercise>` from the snapshot
  (dropping fully-empty sets), call `saveWorkoutSession(..., date: startTime)`,
  then `clearInProgressWorkout()`.
- **Discard** -> `clearInProgressWorkout()` (the exercise-logged count is shown
  in the dialog so the user knows what they are tossing).

The "started N ago" line shows the true age regardless of how old it is; the
user decides what to do with stale records.

### WorkoutSessionScreen constructor change

Add an optional `Map<String, dynamic>? resumeFrom`. When non-null, `initState`
restores from it instead of initializing empty sets. When null, behavior is
unchanged.

## Edge cases

- **Only one in-progress workout** is retained. Starting a fresh workout
  overwrites any existing blob (the launch prompt is the normal recovery path,
  so an orphaned blob is the abnormal case).
- **Deleted saved exercise:** recovery falls back to the stored `name`; sets are
  still restored.
- **Malformed/old-version blob:** treated as absent and cleared - never blocks
  the app.
- **Set count changed** (user added/removed sets before interruption): the
  snapshot stores the actual per-exercise set list, so restore reproduces the
  exact count.

## Testing & verification

- **Unit tests** (Dart, `flutter_test`) for the pure logic:
  - snapshot serialize -> `saveInProgressWorkout` -> `getInProgressWorkout`
    round-trips faithfully.
  - "Save what I logged" reconstruction builds the expected `Workout` with the
    original `startTime` and drops empty sets.
  - malformed blob -> `getInProgressWorkout()` returns null and clears the key.
- **Lifecycle/UI behavior** (observer firing, dialog flow) is verified manually
  on device.

**Toolchain limitation:** the Flutter SDK on this machine is a Windows install
(`/mnt/c/flutter`) whose CRLF shell scripts cannot run under this WSL shell.
Tests will be written but **must be run on the Windows side** (`flutter test`),
along with `flutter analyze` and the APK build. The implementer will state
explicitly which checks were and were not run here.

## Files touched

- `lib/services/storage_service.dart` - add in-progress API; optional `date` on
  `saveWorkoutSession`.
- `lib/screens/workout_session_screen.dart` - `_snapshot()`, autosave hooks,
  `WidgetsBindingObserver`, `resumeFrom` restore, clear-on-complete/cancel.
- `lib/screens/home_screen.dart` - launch-time recovery check + dialog.
- `test/` - new unit tests for the storage/recovery logic.

## Out of scope

- Stretch session recovery.
- Auto-finalizing interrupted workouts without asking.
- Multiple concurrent in-progress workouts.
