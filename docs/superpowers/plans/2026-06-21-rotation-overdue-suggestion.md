# Rotation Most-Overdue Suggestion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the workout rotation suggest the routine you completed longest ago (never-done = most overdue), so suggestions self-correct when you train out of order.

**Architecture:** Extract the ranking rule into a pure, Hive-free function (`rotation_planner.dart`) that is fully unit-tested. `StorageService.getNextInRotation()` and `getRotationCircles()` become thin adapters that gather data from Hive and delegate to that function. The fragile stored rotation pointer is deleted; workout history becomes the single source of truth.

**Tech Stack:** Flutter / Dart, Hive (storage), `flutter_test` (testing).

## Global Constraints

- **No non-ASCII characters in Dart files.** Use `\u{XXXX}` escapes if ever needed (this change needs none). Enforced by a pre-commit hook.
- **Toolchain:** `flutter` / `dart` CANNOT run from the WSL shell (CRLF launchers). All `flutter test` / `flutter analyze` commands in this plan are run by the user on the **Windows** side. State explicitly what was and was not actually run.
- **No Hive schema changes.** No new models or `typeId`s; no `build_runner` run required. The obsolete `last_completed_rotation_index` key is simply left unread (no migration).
- Follow existing patterns: pure logic is unit-tested without Hive (see `test/in_progress_workout_test.dart`, `test/weight_entry_test.dart`).

---

### Task 1: Pure ranking function `rotation_planner.dart`

**Files:**
- Create: `lib/services/rotation_planner.dart`
- Test: `test/rotation_planner_test.dart`

**Interfaces:**
- Consumes: nothing (pure Dart, no imports beyond `dart:core`).
- Produces:
  ```dart
  List<String> rankRotationByMostOverdue(
    List<String> order,
    Map<String, DateTime> lastDoneById,
  )
  ```
  Returns the routine IDs from `order` reordered most-overdue-first. A routine ID
  absent from `lastDoneById` is "never done" and ranks ahead of any done routine.
  Among done routines, older `lastDoneById` date ranks first. Ties (both never-done,
  or equal dates) preserve the routine's index in `order`.

- [ ] **Step 1: Write the failing tests**

Create `test/rotation_planner_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:health_tracker/services/rotation_planner.dart';

void main() {
  test('reported bug: pp -> full body -> pp, legs never done -> legs first', () {
    final order = ['pp', 'fb', 'legs'];
    final lastDone = {
      'pp': DateTime(2026, 6, 16),
      'fb': DateTime(2026, 6, 10),
      // legs absent -> never done
    };
    expect(rankRotationByMostOverdue(order, lastDone), ['legs', 'fb', 'pp']);
  });

  test('clean in-order rotation keeps cycling oldest-first', () {
    final order = ['pp', 'legs', 'fb'];
    final lastDone = {
      'pp': DateTime(2026, 6, 1),
      'legs': DateTime(2026, 6, 2),
      'fb': DateTime(2026, 6, 3),
    };
    // Oldest done = pp -> suggested next.
    expect(rankRotationByMostOverdue(order, lastDone).first, 'pp');
  });

  test('never-done routine jumps ahead of all done routines', () {
    final order = ['a', 'b', 'c'];
    final lastDone = {
      'a': DateTime(2026, 6, 20),
      'b': DateTime(2026, 6, 5),
      // c never done
    };
    expect(rankRotationByMostOverdue(order, lastDone), ['c', 'b', 'a']);
  });

  test('same-day tie preserves rotation list order', () {
    final order = ['a', 'b'];
    final d = DateTime(2026, 6, 10);
    final lastDone = {'a': d, 'b': d};
    expect(rankRotationByMostOverdue(order, lastDone), ['a', 'b']);
  });

  test('nothing done yet -> rotation list order unchanged', () {
    final order = ['a', 'b', 'c'];
    expect(rankRotationByMostOverdue(order, {}), ['a', 'b', 'c']);
  });

  test('empty rotation -> empty list', () {
    expect(rankRotationByMostOverdue([], {}), isEmpty);
  });

  test('multiple never-done routines preserve list order among themselves', () {
    final order = ['a', 'b', 'c', 'd'];
    final lastDone = {'b': DateTime(2026, 6, 9)};
    // never-done a, c, d first (in list order), then b.
    expect(rankRotationByMostOverdue(order, lastDone), ['a', 'c', 'd', 'b']);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run (on Windows): `flutter test test/rotation_planner_test.dart`
Expected: FAIL -- `Error: Couldn't resolve the package 'health_tracker' ... rotation_planner.dart` / "rankRotationByMostOverdue isn't defined".

- [ ] **Step 3: Write the implementation**

Create `lib/services/rotation_planner.dart`:

```dart
/// Ranks the routine IDs in [order] so the most "overdue" routine comes first.
///
/// [order] is the configured rotation (a list of routine IDs).
/// [lastDoneById] maps a routine ID to the date of its most recent completed
/// workout. A routine ID absent from the map has never been completed and is
/// treated as the most overdue.
///
/// Ranking: never-done routines first, then by last-done date oldest-first.
/// Ties (both never-done, or equal dates) preserve the routine's position in
/// [order].
List<String> rankRotationByMostOverdue(
  List<String> order,
  Map<String, DateTime> lastDoneById,
) {
  // Pair each routine with its original index so ties resolve to list order
  // regardless of the sort algorithm's stability.
  final indexed = <MapEntry<int, String>>[
    for (var i = 0; i < order.length; i++) MapEntry(i, order[i]),
  ];

  indexed.sort((a, b) {
    final da = lastDoneById[a.value];
    final db = lastDoneById[b.value];

    if (da == null && db == null) return a.key.compareTo(b.key);
    if (da == null) return -1; // a never done -> most overdue -> first
    if (db == null) return 1; // b never done -> most overdue -> first

    final byDate = da.compareTo(db); // older date first
    if (byDate != 0) return byDate;
    return a.key.compareTo(b.key); // same date -> list order
  });

  return [for (final entry in indexed) entry.value];
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run (on Windows): `flutter test test/rotation_planner_test.dart`
Expected: PASS (7 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/services/rotation_planner.dart test/rotation_planner_test.dart
git commit -m "feat: add pure most-overdue rotation ranking"
```

---

### Task 2: Wire `StorageService` to the ranking function and remove the pointer

**Files:**
- Modify: `lib/services/storage_service.dart`
  - add import; replace `getNextInRotation` and `getRotationCircles`; add
    `_lastDoneByRoutineId`; delete pointer methods + pointer write/reset.

**Interfaces:**
- Consumes (from Task 1): `rankRotationByMostOverdue(List<String>, Map<String, DateTime>)`.
- Produces (signatures unchanged, callers in `workout_tab.dart` untouched):
  - `String? getNextInRotation()`
  - `List<String> getRotationCircles()`

- [ ] **Step 1: Add the import**

At the top of `lib/services/storage_service.dart`, with the other relative imports
(after `import '../models/in_progress_workout.dart';`), add:

```dart
import 'rotation_planner.dart';
```

- [ ] **Step 2: Remove the rotation-pointer write in `completeWorkout`**

In `completeWorkout` (around `storage_service.dart:276-286`), delete the pointer
block so it reads:

```dart
    await saveWorkout(workout);
  }
```

Delete exactly this block (the `await saveWorkout(workout);` line stays):

```dart
    // Update rotation pointer if this workout is in the rotation
    if (routineId != null) {
      final rotationOrder = getWorkoutRotationOrder();
      final rotationIndex = rotationOrder.indexOf(routineId);
      if (rotationIndex != -1) {
        await saveLastCompletedRotationIndex(rotationIndex);
      }
    }
```

- [ ] **Step 3: Remove the pointer reset in `saveWorkoutRotationOrder`**

In `saveWorkoutRotationOrder` (around `:892-897`), delete the reset so it reads:

```dart
  Future<void> saveWorkoutRotationOrder(List<String> order) async {
    await _appDataBox.put('workout_rotation_order', order);
    notifyListeners();
  }
```

(Removed lines: the `// Reset rotation pointer when order changes` comment and
`await _appDataBox.delete('last_completed_rotation_index');`.)

- [ ] **Step 4: Delete the obsolete pointer + resolver methods**

Delete these three methods in full (around `:905-936`):
- `Future<void> saveLastCompletedRotationIndex(int index)`
- `int? getLastCompletedRotationIndex()`
- `int? _resolveLastCompletedRotationIndex()`

- [ ] **Step 5: Replace `getNextInRotation` and `getRotationCircles`, add helper**

Replace the existing `getNextInRotation()` and `getRotationCircles()` bodies (around
`:938-965`) with:

```dart
  /// Most recent completion date per rotation routine, derived from real workout
  /// history. Only completed workouts whose routine is still in the rotation
  /// count. getAllWorkouts() is newest-first, so the first hit per ID is its most
  /// recent completion.
  Map<String, DateTime> _lastDoneByRoutineId(Set<String> rotationIds) {
    final result = <String, DateTime>{};
    for (final workout in getAllWorkouts()) {
      final id = workout.routineId;
      if (id == null || !workout.isCompleted || !rotationIds.contains(id)) {
        continue;
      }
      result.putIfAbsent(id, () => workout.date);
    }
    return result;
  }

  /// Returns the next routine ID to suggest: the rotation routine completed
  /// longest ago (never-done routines first; ties broken by rotation order).
  /// Returns null only if the rotation is empty.
  String? getNextInRotation() {
    final order = getWorkoutRotationOrder();
    if (order.isEmpty) return null;
    final ranked =
        rankRotationByMostOverdue(order, _lastDoneByRoutineId(order.toSet()));
    return ranked.isEmpty ? null : ranked.first;
  }

  /// Returns up to 3 routine IDs, most-overdue first.
  List<String> getRotationCircles() {
    final order = getWorkoutRotationOrder();
    if (order.isEmpty) return [];
    final ranked =
        rankRotationByMostOverdue(order, _lastDoneByRoutineId(order.toSet()));
    return ranked.take(3).toList();
  }
```

- [ ] **Step 6: Verify no remaining references to deleted symbols**

Run (in WSL is fine -- this is grep, not flutter):

```bash
cd ~/HealthTracker && grep -rn "saveLastCompletedRotationIndex\|getLastCompletedRotationIndex\|_resolveLastCompletedRotationIndex\|last_completed_rotation_index" lib/
```

Expected: no output (all references removed).

- [ ] **Step 7: Static analysis**

Run (on Windows): `flutter analyze lib/services/storage_service.dart lib/services/rotation_planner.dart`
Expected: "No issues found!" (or no new issues vs. baseline).

- [ ] **Step 8: Full test + analyze pass**

Run (on Windows): `flutter test` and `flutter analyze`
Expected: all tests pass (including the 7 new ones); no new analyzer issues.

- [ ] **Step 9: Commit**

```bash
git add lib/services/storage_service.dart
git commit -m "feat: rotation suggestion uses most-overdue routine, drop stored pointer"
```

---

## Manual Verification (after both tasks, on device/Windows)

Reproduce the original report and confirm the fix:
1. In Settings -> Workout Rotation, confirm push pull, full body, and legs are all in the rotation.
2. With recent history of push pull (most recent), full body, full body, open the Workout tab.
3. Expect "Today is leg day" (legs is the never-done / longest-ago routine), and the
   next-3 preview to lead with legs.
4. Complete legs; confirm the suggestion advances to the next most-overdue routine.

## Notes for the executor

- I (in WSL) cannot run `flutter test` / `flutter analyze`; those steps must be run on
  the Windows side. Report exactly which steps were actually executed vs. deferred to
  the user.
- No `build_runner` is needed -- no Hive models changed.
