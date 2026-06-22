# Rotation Suggestion by Most-Overdue Routine

**Date:** 2026-06-21
**Status:** Design approved, pending spec review
**Area:** Workout rotation suggestion logic (`StorageService`)

## Problem

The "Today is ..." workout suggestion (and the next-3 routine preview) currently
picks the routine that comes **immediately after your single most recent workout**
in the saved rotation order. It tracks position with a stored pointer
(`last_completed_rotation_index`) plus a history-derived fallback.

This breaks as soon as you train out of order. Concrete case reported by the user:

- Recent history: push pull upper body (16th), full body lift and carry (10th),
  full body lift and carry (3rd).
- App suggested: full body lift and carry (the entry after push pull in the list).
- Expected: leg day -- the routine that had not been done.

The app reasons about *list position*, not *what is actually due*. If you do
push pull -> full body -> push pull, the obvious next routine is legs (you have not
done it), but the current logic just returns "whatever follows push pull in the list."

## Goal

Suggest the routine that is **most overdue** -- the one you completed longest ago --
so the suggestion self-corrects regardless of the order you actually trained in.

## The Rule (approved)

Produce an ordered list of the rotation's routines, **most overdue first**:

1. Start from the configured rotation order (the list of routine IDs in
   Settings -> Workout Rotation).
2. For each routine, find the date of its **most recent completed workout** (a
   workout in history with `isCompleted == true` whose `routineId` matches). A
   routine with no such workout is treated as **never done = most overdue**.
3. Sort: never-done routines first; then by "last done" date, oldest first.
4. **Tie-break** (same date, or several never-done): preserve **rotation list order**
   (stable sort by the routine's position in the configured order).

Consumers:

- **"Today is ..." suggestion** = first routine in the ranked list.
- **Next-3 preview** (rotation circles) = first three routines in the ranked list.

### Worked examples

Rotation = {push pull, full body, legs}.

- Trained push pull -> full body -> push pull:
  - push pull: last done most recently
  - full body: done once, earlier
  - legs: never done -> ranks first -> **suggested.** Correct.

- Clean in-order rotation (push pull -> legs -> full body, repeating) still cycles
  correctly: after each session the routine just completed becomes most-recent, so
  the longest-untrained routine is always next.

- Fresh rotation, nothing done yet: all never-done -> tie -> rotation list order ->
  suggests the first routine (matches today's behavior).

## Implementation

All changes are in `lib/services/storage_service.dart`. No Hive model or `typeId`
changes, so **no `build_runner` run is required** and existing user data is
untouched (we simply stop reading/writing one `_appDataBox` key).

### New private helper

```
List<String> _rotationByMostOverdue()
```

- Reads the rotation order via `getWorkoutRotationOrder()`. Empty -> returns `[]`.
- Builds a map `routineId -> most recent completed workout date` by scanning
  `getAllWorkouts()` (already sorted newest-first) for workouts where
  `isCompleted == true` and `routineId` is present in the rotation order.
- Returns the rotation order sorted most-overdue-first per The Rule above, using a
  **stable** sort so ties fall back to the routine's index in the configured order.

### Rewired public methods (signatures unchanged)

- `getNextInRotation()` -> returns `_rotationByMostOverdue().firstOrNull`
  (empty rotation -> `null`, contract unchanged).
- `getRotationCircles()` -> returns `_rotationByMostOverdue().take(3).toList()`.

### Removed (now-dead) pointer machinery

Single source of truth becomes workout history, so remove:

- `saveLastCompletedRotationIndex(int)` and `getLastCompletedRotationIndex()`.
- `_resolveLastCompletedRotationIndex()`.
- The pointer-write block in `completeWorkout` (~`storage_service.dart:278-285`).
- The pointer-reset line in `saveWorkoutRotationOrder` (~`:895`).

The `last_completed_rotation_index` Hive key is simply left unread; no migration
needed.

### Callers

`lib/screens/workout_tab.dart` continues calling `getNextInRotation()` and
`getRotationCircles()` unchanged -- same signatures, smarter results. The
"Today was X" completed-state display path is not touched.

## Edge Cases

| Case | Behavior |
|------|----------|
| Empty rotation | `getNextInRotation()` -> `null`; circles -> `[]`. Existing "set up your rotation" UI shows. |
| Nothing ever completed | All never-done -> rotation list order -> suggests first routine. |
| Routine ID in rotation but routine deleted | Still ranked; `workout_tab` already maps unknown IDs to no name (pre-existing behavior). |
| Cardio / non-routine workouts | Have no rotation `routineId`, so never affect the ranking. |
| Two routines completed same day | Tie -> rotation list order decides. |

## Testing (TDD)

Pure logic on `StorageService`, unit-testable without Flutter UI. Cases:

1. push pull -> full body -> push pull, then expect **legs** suggested (the reported bug).
2. Clean in-order rotation continues to cycle in order.
3. A never-done routine jumps ahead of all done routines.
4. Same-day completion tie respects rotation list order.
5. Empty rotation -> `null` suggestion, empty circles.
6. Nothing done yet -> suggests first routine in the order.
7. `getRotationCircles()` returns the 3 most-overdue, in order.

## Out of Scope

- No UI/visual changes to the suggestion card or circles widget.
- No changes to how rotations are configured in Settings.
- No Hive schema or data-migration work.
