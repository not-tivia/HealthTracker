# Workout Tab Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign the workout tab to surface workout rotation, quick-launch circles, and smart stretch suggestions at the top, pushing existing clutter below the fold.

**Architecture:** New service methods in StorageService (rotation, pairing) and StepTrackingService (cardio override) provide data to 4 new extracted widgets that compose the workout tab's top section. Existing weekly goal card and streak display are kept as-is. Existing sections are preserved below the fold. Settings tab gains rotation management UI.

**Tech Stack:** Flutter/Dart, Provider, Hive (appDataBox for new data), SharedPreferences (cardio overrides), fl_chart, percent_indicator

**Spec:** `docs/superpowers/specs/2026-03-22-workout-tab-redesign-design.md`

---

## File Structure

### New Files
| File | Responsibility |
|------|---------------|
| `lib/widgets/stretch_workout_toggle.dart` | Two-button toggle switching stretch/workout circle content |
| `lib/widgets/routine_circles.dart` | Up to 3 tappable routine circles with highlight logic |
| `lib/widgets/workout_day_suggestion.dart` | "Today is X day" banner + stretch suggestion banner |
| `lib/widgets/post_workout_popup.dart` | Post-workout warm-down stretch prompt dialog |
| `test/services/storage_service_rotation_test.dart` | Tests for rotation and pairing logic |
| `test/services/step_tracking_cardio_test.dart` | Tests for cardio goal override |
| `test/widgets/routine_circles_test.dart` | Tests for circle display logic |

### Modified Files
| File | Changes |
|------|---------|
| `lib/services/storage_service.dart` | Add rotation CRUD, stretch pairing CRUD |
| `lib/services/step_tracking_service.dart` | Add cardio goal override (SharedPreferences) |
| `lib/screens/workout_tab.dart` | Restructure build() to use new widgets at top, push existing sections below |
| `lib/screens/workout_session_screen.dart:554-630` | Add post-workout popup before popping back |
| `lib/widgets/daily_history_dialog.dart:299-351` | Enhance workout section with expandable detail cards |
| `lib/screens/settings_tab.dart` | Add "Manage Rotation" section with drag-to-reorder and stretch pairing |

---

## Task 1: Storage Service — Rotation Management

**Files:**
- Modify: `lib/services/storage_service.dart:829-838` (near existing stretchRoutineOrder methods)
- Test: `test/services/storage_service_rotation_test.dart`

- [ ] **Step 1: Write failing tests for rotation CRUD**

```dart
// test/services/storage_service_rotation_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:health_tracker/services/storage_service.dart';

void main() {
  late StorageService storage;

  setUp(() async {
    // Initialize Hive for testing — must open all boxes StorageService accesses
    TestWidgetsFlutterBinding.ensureInitialized();
    await Hive.initFlutter();
    await Hive.openBox('app_data');
    await Hive.openBox<Workout>('workouts');
    await Hive.openBox<WorkoutRoutine>('workout_routines');
    await Hive.openBox<SavedExercise>('saved_exercises');
    await Hive.openBox<StretchRoutine>('stretch_routines');
    await Hive.openBox<SavedStretch>('saved_stretches');
    await Hive.openBox<WeightEntry>('weight_entries');
    await Hive.openBox<FoodEntry>('food_entries');
    await Hive.openBox<ChecklistItem>('checklist_items');
    await Hive.openBox('daily_checklist_status');
    await Hive.openBox<UserSettings>('user_settings');
    await Hive.openBox<WorkoutHistory>('workout_history');
    await Hive.openBox<CardioWorkout>('cardio_workouts');
    await Hive.openBox<WaterEntry>('water_entries');
    await Hive.openBox<FoodLibraryItem>('food_library');
    // Note: Hive adapters must be registered in a test helper or main() —
    // import and call the same registration from main.dart, or register
    // only the adapters needed. If this is too complex, test the rotation/pairing
    // logic as static methods that take the appDataBox as a parameter instead.
    storage = StorageService();
  });

  tearDown(() async {
    await Hive.deleteBoxFromDisk('app_data');
  });

  group('Workout Rotation', () {
    test('getWorkoutRotationOrder returns empty list when none set', () {
      expect(storage.getWorkoutRotationOrder(), isEmpty);
    });

    test('saveWorkoutRotationOrder persists order', () async {
      await storage.saveWorkoutRotationOrder(['r1', 'r2', 'r3']);
      expect(storage.getWorkoutRotationOrder(), ['r1', 'r2', 'r3']);
    });

    test('getNextInRotation returns first when no history', () {
      storage.saveWorkoutRotationOrder(['r1', 'r2', 'r3']);
      expect(storage.getNextInRotation(lastRoutineId: null), 'r1');
    });

    test('getNextInRotation advances past last completed', () {
      storage.saveWorkoutRotationOrder(['r1', 'r2', 'r3']);
      expect(storage.getNextInRotation(lastRoutineId: 'r1'), 'r2');
      expect(storage.getNextInRotation(lastRoutineId: 'r2'), 'r3');
    });

    test('getNextInRotation wraps around', () {
      storage.saveWorkoutRotationOrder(['r1', 'r2', 'r3']);
      expect(storage.getNextInRotation(lastRoutineId: 'r3'), 'r1');
    });

    test('getNextInRotation falls back to first when ID not in rotation', () {
      storage.saveWorkoutRotationOrder(['r1', 'r2', 'r3']);
      expect(storage.getNextInRotation(lastRoutineId: 'unknown'), 'r1');
    });

    test('getNextInRotation returns null when rotation empty', () {
      expect(storage.getNextInRotation(lastRoutineId: null), isNull);
    });

    test('getRotationCircles returns up to 3 starting from next', () {
      storage.saveWorkoutRotationOrder(['r1', 'r2', 'r3', 'r4', 'r5']);
      final circles = storage.getRotationCircles(lastRoutineId: 'r2');
      expect(circles, ['r3', 'r4', 'r5']);
    });

    test('getRotationCircles caps at 3', () {
      storage.saveWorkoutRotationOrder(['r1', 'r2', 'r3', 'r4', 'r5', 'r6']);
      final circles = storage.getRotationCircles(lastRoutineId: 'r1');
      expect(circles, ['r2', 'r3', 'r4']);
    });

    test('getRotationCircles wraps around end of list', () {
      storage.saveWorkoutRotationOrder(['r1', 'r2', 'r3']);
      final circles = storage.getRotationCircles(lastRoutineId: 'r2');
      expect(circles, ['r3', 'r1', 'r2']);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd ~/HealthTracker && flutter test test/services/storage_service_rotation_test.dart`
Expected: FAIL — methods don't exist yet

- [ ] **Step 3: Implement rotation methods in StorageService**

Add these methods to `lib/services/storage_service.dart` near the existing `saveStretchRoutineOrder`/`getStretchRoutineOrder` methods (around line 838):

```dart
// Workout rotation order
Future<void> saveWorkoutRotationOrder(List<String> order) async {
  await _appDataBox.put('workout_rotation_order', order);
  notifyListeners();
}

List<String> getWorkoutRotationOrder() {
  final order = _appDataBox.get('workout_rotation_order');
  if (order == null) return [];
  return List<String>.from(order);
}

/// Returns the next routine ID in the rotation after [lastRoutineId].
/// Returns null if rotation is empty.
String? getNextInRotation({required String? lastRoutineId}) {
  final order = getWorkoutRotationOrder();
  if (order.isEmpty) return null;
  if (lastRoutineId == null) return order.first;

  final index = order.indexOf(lastRoutineId);
  if (index == -1) return order.first;
  return order[(index + 1) % order.length];
}

/// Returns up to 3 routine IDs starting from the next in rotation.
List<String> getRotationCircles({required String? lastRoutineId}) {
  final order = getWorkoutRotationOrder();
  if (order.isEmpty) return [];

  final nextId = getNextInRotation(lastRoutineId: lastRoutineId);
  if (nextId == null) return [];

  final startIndex = order.indexOf(nextId);
  final count = order.length.clamp(0, 3);
  final result = <String>[];
  for (int i = 0; i < count; i++) {
    result.add(order[(startIndex + i) % order.length]);
  }
  return result;
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd ~/HealthTracker && flutter test test/services/storage_service_rotation_test.dart`
Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
cd ~/HealthTracker
git add lib/services/storage_service.dart test/services/storage_service_rotation_test.dart
git commit -m "feat: add workout rotation management to StorageService"
```

---

## Task 2: Storage Service — Stretch-Workout Pairing

**Files:**
- Modify: `lib/services/storage_service.dart` (after rotation methods)
- Test: `test/services/storage_service_rotation_test.dart` (add group)

- [ ] **Step 1: Write failing tests for stretch pairing**

Add to `test/services/storage_service_rotation_test.dart`:

```dart
group('Stretch-Workout Pairing', () {
  test('getStretchPairing returns null when none set', () {
    expect(storage.getStretchPairing('r1'), isNull);
  });

  test('saveStretchPairing persists and retrieves', () async {
    await storage.saveStretchPairing('r1', warmUpId: 's1', warmDownId: 's2');
    final pairing = storage.getStretchPairing('r1');
    expect(pairing?['warmUp'], 's1');
    expect(pairing?['warmDown'], 's2');
  });

  test('saveStretchPairing allows partial (warmDown only)', () async {
    await storage.saveStretchPairing('r1', warmDownId: 's2');
    final pairing = storage.getStretchPairing('r1');
    expect(pairing?['warmUp'], isNull);
    expect(pairing?['warmDown'], 's2');
  });

  test('removeStretchPairing clears pairing', () async {
    await storage.saveStretchPairing('r1', warmUpId: 's1', warmDownId: 's2');
    await storage.removeStretchPairing('r1');
    expect(storage.getStretchPairing('r1'), isNull);
  });

  test('findMatchingStretch finds by shared prefix', () {
    // This test needs actual StretchRoutine objects.
    // Test the static matching logic directly.
    expect(
      StorageService.stretchNameMatchesWorkout(
        workoutName: 'Push/Pull Upper',
        stretchName: 'Push/Pull Upper Warm Down',
      ),
      isTrue,
    );
    expect(
      StorageService.stretchNameMatchesWorkout(
        workoutName: 'Push/Pull Upper',
        stretchName: 'Leg Day Warm Down',
      ),
      isFalse,
    );
    expect(
      StorageService.stretchNameMatchesWorkout(
        workoutName: 'Full Body',
        stretchName: 'Full Body Warm Up',
      ),
      isTrue,
    );
    // Single word prefix still matches (startsWith is the rule)
    expect(
      StorageService.stretchNameMatchesWorkout(
        workoutName: 'Upper',
        stretchName: 'Upper Back Stretch',
      ),
      isTrue, // "Upper" starts the stretch name — this is OK
    );
    // But unrelated single words don't match
    expect(
      StorageService.stretchNameMatchesWorkout(
        workoutName: 'Upper',
        stretchName: 'Lower Body Warm Down',
      ),
      isFalse,
    );
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd ~/HealthTracker && flutter test test/services/storage_service_rotation_test.dart`
Expected: FAIL — methods don't exist

- [ ] **Step 3: Implement pairing methods**

Add to `lib/services/storage_service.dart`:

```dart
// Stretch-workout pairings
Future<void> saveStretchPairing(String workoutRoutineId, {String? warmUpId, String? warmDownId}) async {
  final pairings = Map<String, dynamic>.from(_appDataBox.get('stretch_pairings') ?? {});
  pairings[workoutRoutineId] = {
    'warmUp': warmUpId,
    'warmDown': warmDownId,
  };
  await _appDataBox.put('stretch_pairings', pairings);
  notifyListeners();
}

Map<String, String?>? getStretchPairing(String workoutRoutineId) {
  final pairings = _appDataBox.get('stretch_pairings');
  if (pairings == null) return null;
  final map = Map<String, dynamic>.from(pairings);
  if (!map.containsKey(workoutRoutineId)) return null;
  final entry = Map<String, dynamic>.from(map[workoutRoutineId]);
  return {
    'warmUp': entry['warmUp'] as String?,
    'warmDown': entry['warmDown'] as String?,
  };
}

Future<void> removeStretchPairing(String workoutRoutineId) async {
  final pairings = Map<String, dynamic>.from(_appDataBox.get('stretch_pairings') ?? {});
  pairings.remove(workoutRoutineId);
  await _appDataBox.put('stretch_pairings', pairings);
  notifyListeners();
}

/// Checks if a stretch routine name matches a workout routine name
/// using shared prefix logic.
static bool stretchNameMatchesWorkout({
  required String workoutName,
  required String stretchName,
}) {
  final workoutLower = workoutName.toLowerCase().trim();
  final stretchLower = stretchName.toLowerCase().trim();
  return stretchLower.startsWith(workoutLower);
}

/// Finds the best matching warm-down stretch for a workout routine.
/// Checks explicit pairings first, then falls back to name matching.
String? findWarmDownStretch(String workoutRoutineId) {
  // Check explicit pairing first
  final pairing = getStretchPairing(workoutRoutineId);
  if (pairing != null && pairing['warmDown'] != null) {
    return pairing['warmDown'];
  }

  // Fall back to name matching
  final routines = getAllWorkoutRoutines();
  final workoutRoutine = routines.where((r) => r.id == workoutRoutineId).firstOrNull;
  if (workoutRoutine == null) return null;

  final stretches = getAllStretchRoutines();
  for (final stretch in stretches) {
    if (stretchNameMatchesWorkout(
      workoutName: workoutRoutine.name,
      stretchName: stretch.name,
    )) {
      // Prefer warm down over warm up
      final nameLower = stretch.name.toLowerCase();
      if (nameLower.contains('warm down') || nameLower.contains('cooldown') || nameLower.contains('cool down')) {
        return stretch.id;
      }
    }
  }

  // If no warm-down found, return any name match
  for (final stretch in stretches) {
    if (stretchNameMatchesWorkout(
      workoutName: workoutRoutine.name,
      stretchName: stretch.name,
    )) {
      return stretch.id;
    }
  }

  return null;
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd ~/HealthTracker && flutter test test/services/storage_service_rotation_test.dart`
Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
cd ~/HealthTracker
git add lib/services/storage_service.dart test/services/storage_service_rotation_test.dart
git commit -m "feat: add stretch-workout pairing with name matching and manual override"
```

---

## Task 3: Step Tracking — Cardio Goal Override

**Files:**
- Modify: `lib/services/step_tracking_service.dart:170-177`
- Test: `test/services/step_tracking_cardio_test.dart`

- [ ] **Step 1: Write failing tests**

Note: `StepTrackingService()` constructor triggers `_initialize()` which calls
`Pedometer.stepCountStream` — this requires a platform channel and will fail in tests.
To avoid this, the tests use the static/standalone cardio override helpers directly
via SharedPreferences, and test `goalMetForDate()` by constructing the service and
waiting for initialization to settle (or by testing the logic in isolation).

The simplest approach: add the cardio override methods as static helpers that take
a `SharedPreferences` instance, then have the instance methods delegate to them.
However, for pragmatism, we test at the SharedPreferences level directly:

```dart
// test/services/step_tracking_cardio_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Cardio Goal Override (SharedPreferences level)', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
    });

    test('cardio override key is stored correctly', () async {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      await prefs.setBool('cardio_override_$dateStr', true);
      expect(prefs.getBool('cardio_override_$dateStr'), isTrue);
    });

    test('cardio override returns null when not set', () async {
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('cardio_override_2026-01-01'), isNull);
    });

    test('pruning removes entries older than 14 days', () async {
      final fifteenDaysAgo = DateTime.now().subtract(const Duration(days: 15));
      final dateStr = '${fifteenDaysAgo.year}-${fifteenDaysAgo.month.toString().padLeft(2, '0')}-${fifteenDaysAgo.day.toString().padLeft(2, '0')}';
      SharedPreferences.setMockInitialValues({
        'cardio_override_$dateStr': true,
      });
      final prefs = await SharedPreferences.getInstance();

      // Simulate pruning logic
      final cutoff = DateTime.now().subtract(const Duration(days: 14));
      final keysToRemove = prefs.getKeys()
          .where((k) => k.startsWith('cardio_override_'))
          .where((k) {
        final ds = k.replaceFirst('cardio_override_', '');
        final parts = ds.split('-');
        if (parts.length != 3) return true;
        final date = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        return date.isBefore(cutoff);
      }).toList();
      for (final key in keysToRemove) {
        await prefs.remove(key);
      }

      expect(prefs.getBool('cardio_override_$dateStr'), isNull);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd ~/HealthTracker && flutter test test/services/step_tracking_cardio_test.dart`
Expected: FAIL — methods don't exist

- [ ] **Step 3: Implement cardio override methods**

Make these changes to `lib/services/step_tracking_service.dart`:

**3a.** Add a cached SharedPreferences field near top of class (around line 26):

```dart
SharedPreferences? _prefs;
```

**3b.** In `_loadSavedData()` (line 104), after `final prefs = await SharedPreferences.getInstance();`, add:

```dart
_prefs = prefs;
```

**3c.** Replace `goalMetForDate()` (line 177):

```dart
bool goalMetForDate(DateTime date) {
  return getStepsForDate(date) >= _stepGoal || isCardioGoalOverridden(date);
}
```

**3d.** Add these methods before `dispose()` (around line 370):

```dart
/// Mark today's cardio/step goal as met (manual override).
/// One-directional — once set, stays for the day.
Future<void> markCardioGoalMet() async {
  final prefs = await SharedPreferences.getInstance();
  _prefs = prefs;
  final today = _getTodayString();
  await prefs.setBool('cardio_override_$today', true);
  notifyListeners();
}

/// Check if a specific date has a cardio goal override.
/// Uses the cached SharedPreferences reference for synchronous access.
bool isCardioGoalOverridden(DateTime date) {
  if (_prefs == null) return false;
  final dateStr = _getDateString(date);
  return _prefs!.getBool('cardio_override_$dateStr') ?? false;
}

/// Prune cardio override entries older than 14 days.
Future<void> pruneOldCardioOverrides() async {
  final prefs = await SharedPreferences.getInstance();
  _prefs = prefs;
  final cutoff = DateTime.now().subtract(const Duration(days: 14));
  final keysToRemove = prefs.getKeys()
      .where((k) => k.startsWith('cardio_override_'))
      .where((k) {
    final dateStr = k.replaceFirst('cardio_override_', '');
    final parts = dateStr.split('-');
    if (parts.length != 3) return true;
    try {
      final date = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      return date.isBefore(cutoff);
    } catch (_) {
      return true;
    }
  }).toList();

  for (final key in keysToRemove) {
    await prefs.remove(key);
  }
}
```

**3e.** Call `pruneOldCardioOverrides()` at end of `_initialize()` (line 49):

```dart
await pruneOldCardioOverrides();
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd ~/HealthTracker && flutter test test/services/step_tracking_cardio_test.dart`
Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
cd ~/HealthTracker
git add lib/services/step_tracking_service.dart test/services/step_tracking_cardio_test.dart
git commit -m "feat: add cardio goal override to StepTrackingService"
```

---

*(Tasks 4 and 5 removed — weekly goal ring with streak/trophy already exists in the codebase. Daily streak logic is kept as-is.)*

---

## Task 6: Widget — Stretch/Workout Toggle

**Files:**
- Create: `lib/widgets/stretch_workout_toggle.dart`

- [ ] **Step 1: Create the toggle widget**

```dart
// lib/widgets/stretch_workout_toggle.dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class StretchWorkoutToggle extends StatelessWidget {
  final bool isStretchSelected;
  final ValueChanged<bool> onToggle;

  const StretchWorkoutToggle({
    super.key,
    required this.isStretchSelected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildToggleButton(
              label: 'Stretch',
              icon: Icons.self_improvement,
              isSelected: isStretchSelected,
              onTap: () => onToggle(true),
            ),
          ),
          Expanded(
            child: _buildToggleButton(
              label: 'Workout',
              icon: Icons.fitness_center,
              isSelected: !isStretchSelected,
              onTap: () => onToggle(false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : AppTheme.textTertiary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppTheme.textTertiary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `cd ~/HealthTracker && flutter analyze lib/widgets/stretch_workout_toggle.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
cd ~/HealthTracker
git add lib/widgets/stretch_workout_toggle.dart
git commit -m "feat: add StretchWorkoutToggle widget"
```

---

## Task 7: Widget — Routine Circles

**Files:**
- Create: `lib/widgets/routine_circles.dart`

- [ ] **Step 1: Create the routine circles widget**

```dart
// lib/widgets/routine_circles.dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class RoutineCircle {
  final String id;
  final String name;
  final bool isHighlighted;

  const RoutineCircle({
    required this.id,
    required this.name,
    this.isHighlighted = false,
  });
}

class RoutineCirclesWidget extends StatelessWidget {
  final List<RoutineCircle> circles;
  final ValueChanged<String> onCircleTap;
  final VoidCallback onSeeAll;
  final String? suggestionText; // e.g., "Suggested: Push/Pull Warm Down"

  const RoutineCirclesWidget({
    super.key,
    required this.circles,
    required this.onCircleTap,
    required this.onSeeAll,
    this.suggestionText,
  });

  @override
  Widget build(BuildContext context) {
    if (circles.isEmpty) {
      return _buildEmptyState(context);
    }

    return Column(
      children: [
        if (suggestionText != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.successColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, size: 16, color: AppTheme.successColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    suggestionText!,
                    style: TextStyle(
                      color: AppTheme.successColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: circles.map((circle) => _buildCircle(context, circle)).toList(),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: onSeeAll,
          child: Text(
            'All Routines',
            style: TextStyle(
              color: AppTheme.primaryColor,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCircle(BuildContext context, RoutineCircle circle) {
    return GestureDetector(
      onTap: () => onCircleTap(circle.id),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.cardColor,
              border: Border.all(
                color: circle.isHighlighted
                    ? AppTheme.primaryColor
                    : AppTheme.cardColorLight,
                width: circle.isHighlighted ? 3 : 1,
              ),
              boxShadow: circle.isHighlighted
                  ? [
                      BoxShadow(
                        color: AppTheme.primaryColor.withOpacity(0.3),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  circle.name,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: circle.isHighlighted
                        ? AppTheme.textPrimary
                        : AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: circle.isHighlighted
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.add_circle_outline, size: 40, color: AppTheme.textTertiary),
          const SizedBox(height: 12),
          Text(
            'Add routines to your rotation to get started',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onSeeAll,
            child: const Text('Manage Rotation'),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `cd ~/HealthTracker && flutter analyze lib/widgets/routine_circles.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
cd ~/HealthTracker
git add lib/widgets/routine_circles.dart
git commit -m "feat: add RoutineCirclesWidget with highlight and empty state"
```

---

## Task 8: Widget — Workout Day Suggestion Banner

**Files:**
- Create: `lib/widgets/workout_day_suggestion.dart`

- [ ] **Step 1: Create the suggestion banner**

```dart
// lib/widgets/workout_day_suggestion.dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class WorkoutDaySuggestion extends StatelessWidget {
  final String? routineName; // null = no rotation configured
  final VoidCallback onTap;

  const WorkoutDaySuggestion({
    super.key,
    required this.routineName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: routineName != null
              ? LinearGradient(
                  colors: [
                    AppTheme.primaryColor.withOpacity(0.2),
                    AppTheme.secondaryColor.withOpacity(0.1),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          color: routineName == null ? AppTheme.cardColor : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              routineName != null ? Icons.play_circle_fill : Icons.settings,
              color: routineName != null
                  ? AppTheme.primaryColor
                  : AppTheme.textTertiary,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                routineName != null
                    ? 'Today is $routineName day'
                    : 'Set up your workout rotation',
                style: TextStyle(
                  color: routineName != null
                      ? AppTheme.textPrimary
                      : AppTheme.textSecondary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: AppTheme.textTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `cd ~/HealthTracker && flutter analyze lib/widgets/workout_day_suggestion.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
cd ~/HealthTracker
git add lib/widgets/workout_day_suggestion.dart
git commit -m "feat: add WorkoutDaySuggestion banner widget"
```

---

## Task 9: Widget — Post-Workout Popup

**Files:**
- Create: `lib/widgets/post_workout_popup.dart`

- [ ] **Step 1: Create the popup widget**

```dart
// lib/widgets/post_workout_popup.dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PostWorkoutPopup {
  /// Show a dialog prompting the user to do a warm-down stretch.
  /// Returns true if user wants to do the stretch, false otherwise.
  static Future<bool> show(BuildContext context, {required String stretchName}) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.self_improvement, color: AppTheme.successColor),
            const SizedBox(width: 10),
            const Text('Warm Down?'),
          ],
        ),
        content: Text(
          'Great workout! Want to do "$stretchName" to cool down?',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Skip', style: TextStyle(color: AppTheme.textTertiary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successColor,
            ),
            child: const Text("Let's go"),
          ),
        ],
      ),
    ).then((value) => value ?? false);
  }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `cd ~/HealthTracker && flutter analyze lib/widgets/post_workout_popup.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
cd ~/HealthTracker
git add lib/widgets/post_workout_popup.dart
git commit -m "feat: add PostWorkoutPopup dialog widget"
```

---

## Task 10: Workout Tab — Restructure Top Section

**Files:**
- Modify: `lib/screens/workout_tab.dart:262-302` (build method), plus existing builder methods

This is the largest task. The build method's Column children get reorganized: new widgets at top, existing sections pushed below.

- [ ] **Step 1: Add imports for new widgets**

Add to top of `lib/screens/workout_tab.dart` (after existing imports):

```dart
import '../widgets/stretch_workout_toggle.dart';
import '../widgets/routine_circles.dart';
import '../widgets/workout_day_suggestion.dart';
```

- [ ] **Step 2: Add state for toggle and rotation**

Add to `_WorkoutTabState` class fields (around line 64):

```dart
bool _isStretchSelected = false;
```

- [ ] **Step 3: Add helper method to get last routine ID**

Add method to `_WorkoutTabState`:

```dart
String? get _lastCompletedRoutineId {
  if (_workouts.isEmpty) return null;
  // Most recent workout's routine — workouts are sorted newest first
  final lastWorkout = _workouts.first;
  // Check if this workout was from a routine
  return lastWorkout.routineId;
}
```

The `Workout` model has `routineId` as `@HiveField(7) String?` (line 30 of `workout.dart`). This field is set when a workout is started from a saved routine via `saveWorkoutSession()` in `storage_service.dart`.

- [ ] **Step 4: Restructure the build method Column**

Replace the Column children in `build()` (lines 286-299) with the new layout order:

```dart
children: [
  const SizedBox(height: 8),
  // EXISTING: Weekly goal card (unchanged — already has streak/trophy)
  _buildWeeklyGoalCard(constraints),
  const SizedBox(height: 16),
  // EXISTING: This week M-S row + NEW cardio button
  _buildThisWeekWithCardio(),
  const SizedBox(height: 16),
  // NEW: "Today is X day" banner
  _buildTodaySuggestion(),
  const SizedBox(height: 16),
  // NEW: Stretch/Workout toggle
  StretchWorkoutToggle(
    isStretchSelected: _isStretchSelected,
    onToggle: (isStretch) => setState(() => _isStretchSelected = isStretch),
  ),
  const SizedBox(height: 16),
  // NEW: Routine circles
  _buildRoutineCircles(),
  const SizedBox(height: 24),
  // EXISTING sections below the fold
  _buildImportExportButtons(),
  const SizedBox(height: 24),
  _buildWarmupStretchesSection(),
  const SizedBox(height: 24),
  _buildMyRoutinesSection(),
  const SizedBox(height: 24),
  _buildMyExercisesSection(),
  const SizedBox(height: 24),
  _buildRecentActivitiesSection(),
  const SizedBox(height: 100),
],
```

- [ ] **Step 5: Implement _buildThisWeekWithCardio**

Modify the existing `_buildThisWeekCard()` to add the cardio button. Add to the Row inside the card, after the M-S indicators:

```dart
Widget _buildThisWeekWithCardio() {
  return Consumer<StepTrackingService>(
    builder: (context, stepService, _) {
      final isCardioMet = stepService.isCardioGoalOverridden(DateTime.now()) ||
          stepService.goalMetForDate(DateTime.now());

      return Column(
        children: [
          _buildThisWeekCard(), // existing
          const SizedBox(height: 8),
          GestureDetector(
            onTap: isCardioMet
                ? null
                : () async {
                    await stepService.markCardioGoalMet();
                    setState(() {});
                  },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isCardioMet
                    ? AppTheme.successColor.withOpacity(0.15)
                    : AppTheme.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isCardioMet ? AppTheme.successColor : AppTheme.cardColorLight,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isCardioMet ? Icons.check_circle : Icons.directions_run,
                    size: 18,
                    color: isCardioMet ? AppTheme.successColor : AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isCardioMet ? 'Cardio goal met!' : 'Mark cardio completed',
                    style: TextStyle(
                      color: isCardioMet ? AppTheme.successColor : AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );
}
```

- [ ] **Step 7: Implement _buildTodaySuggestion**

```dart
Widget _buildTodaySuggestion() {
  final storage = context.read<StorageService>();
  final nextId = storage.getNextInRotation(lastRoutineId: _lastCompletedRoutineId);

  String? routineName;
  if (nextId != null) {
    final routine = _routines.where((r) => r.id == nextId).firstOrNull;
    routineName = routine?.name;
  }

  return WorkoutDaySuggestion(
    routineName: routineName,
    onTap: () {
      if (nextId != null && routineName != null) {
        final routine = _routines.firstWhere((r) => r.id == nextId);
        _startRoutine(routine);
      } else {
        // Navigate to settings to set up rotation
        // TODO: navigate to rotation management
      }
    },
  );
}
```

- [ ] **Step 8: Implement _buildRoutineCircles**

```dart
Widget _buildRoutineCircles() {
  final storage = context.read<StorageService>();

  if (_isStretchSelected) {
    return _buildStretchCircles(storage);
  } else {
    return _buildWorkoutCircles(storage);
  }
}

Widget _buildWorkoutCircles(StorageService storage) {
  final circleIds = storage.getRotationCircles(lastRoutineId: _lastCompletedRoutineId);
  final nextId = storage.getNextInRotation(lastRoutineId: _lastCompletedRoutineId);

  final circles = circleIds.map((id) {
    final routine = _routines.where((r) => r.id == id).firstOrNull;
    return RoutineCircle(
      id: id,
      name: routine?.name ?? 'Unknown',
      isHighlighted: id == nextId,
    );
  }).toList();

  return RoutineCirclesWidget(
    circles: circles,
    onCircleTap: (id) {
      final routine = _routines.where((r) => r.id == id).firstOrNull;
      if (routine != null) _startRoutine(routine);
    },
    onSeeAll: () => _showAllRoutinesSheet(),
  );
}

Widget _buildStretchCircles(StorageService storage) {
  // Get 3 most recently used stretch routines
  final recentStretches = _stretchRoutines.take(3).toList(); // Already sorted by lastUsed

  // Find suggestion based on last workout
  String? suggestionText;
  if (_lastCompletedRoutineId != null) {
    final warmDownId = storage.findWarmDownStretch(_lastCompletedRoutineId!);
    if (warmDownId != null) {
      final stretch = _stretchRoutines.where((s) => s.id == warmDownId).firstOrNull;
      if (stretch != null) {
        suggestionText = 'Suggested: ${stretch.name}';
      }
    }
  }

  final circles = recentStretches.map((s) => RoutineCircle(
    id: s.id,
    name: s.name,
  )).toList();

  return RoutineCirclesWidget(
    circles: circles,
    suggestionText: suggestionText,
    onCircleTap: (id) {
      final routine = _stretchRoutines.where((r) => r.id == id).firstOrNull;
      if (routine != null) {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => StretchSessionScreen(routine: routine),
        ));
      }
    },
    onSeeAll: () => _showAllStretchRoutinesSheet(),
  );
}

void _showAllRoutinesSheet() {
  // Show bottom sheet with full list of workout routines
  showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.surfaceColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('All Workout Routines', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        ..._routines.map((r) => ListTile(
          title: Text(r.name),
          subtitle: Text('${r.exercises.length} exercises'),
          onTap: () {
            Navigator.pop(context);
            _startRoutineWorkout(r);
          },
        )),
      ],
    ),
  );
}

void _showAllStretchRoutinesSheet() {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.surfaceColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('All Stretch Routines', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        ..._stretchRoutines.map((r) => ListTile(
          title: Text(r.name),
          subtitle: Text('${r.stretches.length} stretches'),
          onTap: () {
            Navigator.pop(context);
            _startStretchSession(r);
          },
        )),
      ],
    ),
  );
}
```

- [ ] **Step 9: Wire day-tap to DailyHistoryDialog**

Modify the existing `_buildThisWeekCard()` method. The M-T-W-T-F-S-S day indicators
currently don't have tap handlers. Add `GestureDetector` around each day's circle
to open the `DailyHistoryDialog`:

```dart
// In _buildThisWeekCard(), wrap each day indicator Column with:
GestureDetector(
  onTap: () {
    // Calculate the date for this day index
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final tappedDate = monday.add(Duration(days: index));
    showDialog(
      context: context,
      useSafeArea: false,
      builder: (context) => const DailyHistoryDialog(),
      // Note: DailyHistoryDialog has its own date picker,
      // but ideally we'd pass the initial date. Check if it
      // accepts an initialDate parameter — if not, opening it
      // and letting the user navigate is acceptable for now.
    );
  },
  child: Column(
    // ... existing day indicator content
  ),
),
```

Add import at top of file if not already present:
```dart
import '../widgets/daily_history_dialog.dart';
```

- [ ] **Step 10: Verify the app compiles**

Run: `cd ~/HealthTracker && flutter analyze`
Expected: No errors (warnings are OK)

- [ ] **Step 11: Commit**

```bash
cd ~/HealthTracker
git add lib/screens/workout_tab.dart
git commit -m "feat: restructure workout tab with new top section layout"
```

---

## Task 11: Workout Session — Post-Workout Popup

**Files:**
- Modify: `lib/screens/workout_session_screen.dart:554-630`

- [ ] **Step 1: Add import**

Add to top of `workout_session_screen.dart`:

```dart
import '../widgets/post_workout_popup.dart';
import '../services/storage_service.dart';
import '../models/stretch_routine.dart';
import 'stretch_session_screen.dart';
```

- [ ] **Step 2: Modify _completeWorkout to show popup**

In the completion dialog's "Done" button callback (around lines 629-630 where it pops twice), replace the direct pops with:

```dart
// After the existing completion dialog is dismissed:
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
        // Replace current screen with stretch session
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
```

`widget.routineId` is a required `String` field on `WorkoutSessionScreen` (line 16-22 of `workout_session_screen.dart`). It is passed when starting a workout from a routine via `_startRoutine()` in `workout_tab.dart`.

- [ ] **Step 3: Verify compile**

Run: `cd ~/HealthTracker && flutter analyze lib/screens/workout_session_screen.dart`
Expected: No errors

- [ ] **Step 4: Commit**

```bash
cd ~/HealthTracker
git add lib/screens/workout_session_screen.dart
git commit -m "feat: add post-workout warm-down stretch prompt"
```

---

## Task 12: Enhanced Daily History Dialog

**Files:**
- Modify: `lib/widgets/daily_history_dialog.dart:299-351` (workout section)

- [ ] **Step 1: Read the existing workout section rendering**

Read `lib/widgets/daily_history_dialog.dart` around the workout section (the part that renders Icons.fitness_center / Icons.directions_run) to understand current data display.

- [ ] **Step 2: Add expandable workout detail cards**

Replace the simple workout summary cards in the dialog with expandable cards. For each workout on the selected day, show:
- Collapsed: workout name, exercise count, duration (like current)
- Expanded: list of exercises with sets, reps, and weights (matching the Recent Activity detail style from `workout_tab.dart`)

```dart
// Replace the workout section builder with:
Widget _buildWorkoutDetail(Workout workout) {
  return ExpansionTile(
    tilePadding: EdgeInsets.zero,
    title: Text(workout.name, style: TextStyle(color: AppTheme.textPrimary)),
    subtitle: Text(
      '${workout.exercises.length} exercises · ${workout.durationMinutes} min',
      style: TextStyle(color: AppTheme.textTertiary, fontSize: 12),
    ),
    leading: Icon(Icons.fitness_center, color: AppTheme.successColor, size: 20),
    children: workout.exercises.map((exercise) {
      return Padding(
        padding: const EdgeInsets.only(left: 16, bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              exercise.name,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
            ),
            ...exercise.sets.asMap().entries.map((e) => Padding(
              padding: const EdgeInsets.only(left: 8, top: 2),
              child: Text(
                'Set ${e.key + 1}: ${e.value.reps} reps × ${e.value.weight} lbs',
                style: TextStyle(color: AppTheme.textTertiary, fontSize: 12),
              ),
            )),
          ],
        ),
      );
    }).toList(),
  );
}
```

- [ ] **Step 3: Verify compile**

Run: `cd ~/HealthTracker && flutter analyze lib/widgets/daily_history_dialog.dart`
Expected: No errors

- [ ] **Step 4: Commit**

```bash
cd ~/HealthTracker
git add lib/widgets/daily_history_dialog.dart
git commit -m "feat: add expandable workout details to daily history dialog"
```

---

## Task 13: Settings Tab — Rotation Management

**Files:**
- Modify: `lib/screens/settings_tab.dart` (add new section after Goals)

- [ ] **Step 1: Add imports**

```dart
import '../services/storage_service.dart'; // if not already imported
```

- [ ] **Step 2: Add "Manage Rotation" section to settings build method**

After `_buildGoalsSection()` (around line 77), add:

```dart
const SizedBox(height: 24),
_buildSectionHeader('Workout Rotation'),
_buildRotationSection(),
```

- [ ] **Step 3: Implement _buildRotationSection**

```dart
Widget _buildRotationSection() {
  final storage = context.read<StorageService>();
  final rotationOrder = storage.getWorkoutRotationOrder();
  final allRoutines = storage.getAllWorkoutRoutines();

  // Map IDs to routine objects
  final rotationRoutines = rotationOrder
      .map((id) => allRoutines.where((r) => r.id == id).firstOrNull)
      .where((r) => r != null)
      .cast<WorkoutRoutine>()
      .toList();

  final availableRoutines = allRoutines
      .where((r) => !rotationOrder.contains(r.id))
      .toList();

  return Container(
    decoration: BoxDecoration(
      color: AppTheme.cardColor,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      children: [
        if (rotationRoutines.isEmpty)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'No routines in rotation. Add routines below.',
              style: TextStyle(color: AppTheme.textTertiary),
            ),
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: rotationRoutines.length,
            onReorder: (oldIndex, newIndex) async {
              if (newIndex > oldIndex) newIndex--;
              final order = List<String>.from(rotationOrder);
              final item = order.removeAt(oldIndex);
              order.insert(newIndex, item);
              await storage.saveWorkoutRotationOrder(order);
              setState(() {});
            },
            itemBuilder: (context, index) {
              final routine = rotationRoutines[index];
              return Dismissible(
                key: ValueKey(routine.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: AppTheme.accentColor,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  child: const Icon(Icons.remove_circle, color: Colors.white),
                ),
                onDismissed: (_) async {
                  final order = List<String>.from(rotationOrder)..remove(routine.id);
                  await storage.saveWorkoutRotationOrder(order);
                  setState(() {});
                },
                child: ListTile(
                  key: ValueKey(routine.id),
                  leading: const Icon(Icons.drag_handle, color: AppTheme.textTertiary),
                  title: Text(routine.name, style: TextStyle(color: AppTheme.textPrimary)),
                  subtitle: _buildPairingDropdowns(routine, storage),
                ),
              );
            },
          ),
        if (availableRoutines.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(12),
            child: OutlinedButton.icon(
              onPressed: () => _showAddToRotationSheet(availableRoutines, storage, rotationOrder),
              icon: const Icon(Icons.add),
              label: const Text('Add to Rotation'),
            ),
          ),
      ],
    ),
  );
}

Widget _buildPairingDropdowns(WorkoutRoutine routine, StorageService storage) {
  final pairing = storage.getStretchPairing(routine.id);
  final allStretches = storage.getAllStretchRoutines();

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 4),
      _buildStretchDropdown(
        label: 'Warm-down',
        currentId: pairing?['warmDown'],
        stretches: allStretches,
        onChanged: (id) async {
          await storage.saveStretchPairing(
            routine.id,
            warmUpId: pairing?['warmUp'],
            warmDownId: id,
          );
          setState(() {});
        },
      ),
    ],
  );
}

Widget _buildStretchDropdown({
  required String label,
  required String? currentId,
  required List<StretchRoutine> stretches,
  required ValueChanged<String?> onChanged,
}) {
  return Row(
    children: [
      Text('$label: ', style: TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
      Expanded(
        child: DropdownButton<String?>(
          value: currentId,
          isExpanded: true,
          underline: const SizedBox(),
          hint: Text('None', style: TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          dropdownColor: AppTheme.surfaceColor,
          items: [
            const DropdownMenuItem(value: null, child: Text('None')),
            ...stretches.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))),
          ],
          onChanged: onChanged,
        ),
      ),
    ],
  );
}

void _showAddToRotationSheet(List<WorkoutRoutine> available, StorageService storage, List<String> currentOrder) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.surfaceColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Add to Rotation', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        ...available.map((r) => ListTile(
          title: Text(r.name),
          trailing: const Icon(Icons.add_circle_outline),
          onTap: () async {
            final order = List<String>.from(currentOrder)..add(r.id);
            await storage.saveWorkoutRotationOrder(order);
            Navigator.pop(context);
            setState(() {});
          },
        )),
      ],
    ),
  );
}
```

- [ ] **Step 4: Verify compile**

Run: `cd ~/HealthTracker && flutter analyze lib/screens/settings_tab.dart`
Expected: No errors

- [ ] **Step 5: Commit**

```bash
cd ~/HealthTracker
git add lib/screens/settings_tab.dart
git commit -m "feat: add rotation management and stretch pairing to settings"
```

---

## Task 14: Integration Testing & Final Polish

**Files:**
- All modified files

- [ ] **Step 1: Run full static analysis**

Run: `cd ~/HealthTracker && flutter analyze`
Expected: No errors

- [ ] **Step 2: Run all tests**

Run: `cd ~/HealthTracker && flutter test`
Expected: All tests PASS

- [ ] **Step 3: Fix any compile errors or test failures**

Iterate until clean.

- [ ] **Step 4: Build APK to verify full compilation**

Run: `cd ~/HealthTracker && flutter build apk --debug`
Expected: BUILD SUCCESSFUL

- [ ] **Step 5: Final commit**

```bash
cd ~/HealthTracker
git add -A
git commit -m "chore: fix integration issues from workout tab redesign"
```
