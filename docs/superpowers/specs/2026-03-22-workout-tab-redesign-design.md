# Workout Tab Redesign — Design Spec

## Problem

The workout tab is cluttered with too many sections visible at once (weekly goal, week tracker, start workout button, import/export, warm-up stretches, routines, recent activity, exercise library). Users must scroll extensively to reach what they need. The tab needs a cleaner top-level layout that surfaces the most important actions immediately.

## Design

### Layout (Top to Bottom)

#### 1. Weekly Goal Ring
Keep the existing circular progress indicator showing "3/4 this week" style progress. Add two new data points beside it:
- **Streak (current)** — consecutive weeks where the weekly workout goal was met
- **Trophy (best)** — the longest streak ever achieved

These already exist — the current `currentStreak` and `bestStreak` fields on UserSettings and `StorageService.calculateStreak()` are kept as-is (day-based streaks). No changes needed.

#### 2. Weekly Day Row + Cardio Button
The existing M T W T F S S row with checkmarks stays as-is. Add a **"Cardio completed"** button next to the row.

**Cardio button behavior:** Single tap marks today's step goal as met (one-directional — once marked, stays marked for the day). This exists because the pedometer package only reads the phone's hardware sensor and misses treadmill/watch-synced steps. No cardio type selection — just a quick goal-met confirmation.

**Storage:** Cardio overrides stored in `SharedPreferences` (key: `cardio_override_YYYY-MM-DD` → `true`) to stay consistent with `StepTrackingService`'s existing SharedPreferences pattern. Entries older than 14 days are pruned on app launch.

**Integration:** `StepTrackingService.goalMetForDate()` checks both the step count AND the cardio override. If either indicates goal met, returns true.

**Day tap behavior:** Tapping any day icon opens a calendar picker identical to the Today tab's existing `DailyHistoryDialog` widget (`lib/widgets/daily_history_dialog.dart`), but with enhanced workout details. Instead of just showing "Push/Pull Upper — 5 exercises — 45 min", it shows expandable cards (like the current Recent Activity section at the bottom of the workout tab) with full sets, reps, and weights visible when expanded.

#### 3. "Today is [X] Day" Banner
A text banner above the routine circles that shows the next workout in the user's rotation. E.g., "Today is Push/Pull Upper day". Tapping the banner or the highlighted circle below starts that workout.

The suggestion is determined by the **rotation system** (see below).

**Empty state:** If no rotation is configured, the banner shows "Set up your workout rotation" with a tap action that navigates to the rotation management screen in settings.

#### 4. Stretch / Workout Toggle
Two toggle buttons ("Stretch" / "Workout") that switch which content appears in the circles below. Only one section is visible at a time.

#### 5. Routine Circles (up to 3)

**When "Workout" is selected:**
- Shows up to 3 circles representing workout routines from the active rotation
- The first circle is the suggested next workout (highlighted — brighter border or subtle glow)
- The other 2 are the next routines after that in the rotation sequence
- If the rotation has fewer than 3 routines, show only that many circles (1 routine = 1 circle, 2 = 2, etc.)
- Tapping a circle starts that workout session

**When "Stretch" is selected:**
- Shows up to 3 circles representing the most recently used stretch routines (recency-based)
- Above the circles, a **suggestion banner** displays a context-aware recommendation: "Suggested: Push/Pull Warm Down" — based on what workout was just completed
- Pairing logic: name-matched by default, with manual override available in settings (see Stretch-Workout Pairing below)

**Empty state (no rotation configured):** Show a centered prompt: "Add routines to your rotation to get started" with a button to manage rotation.

#### 6. "All Routines" Link
A small text link/button below the circles to access the full list of routines (both workout and stretch, depending on the current toggle state).

#### 7. Existing Sections (Below the Fold)
All current sections are preserved and pushed below the new top-level layout:
- Import/Export buttons
- Exercise library
- Recent activity list

These remain accessible by scrolling but are no longer the first thing visible.

### Post-Workout Popup
When a workout session completes, a popup/dialog prompts: "Want to do the warm-down stretch?" with the matched stretch routine name. Tapping "Yes" launches the stretch session directly. Tapping "No" dismisses.

This dialog is shown in `workout_session_screen.dart` before popping back to the workout tab, so the user sees it immediately after finishing.

### Rotation System

**Concept:** An ordered list of workout routines that the user cycles through. The app tracks position in the rotation based on the last completed workout.

**Algorithm for determining next workout:**
1. Get the most recent completed workout from history
2. Find that workout's `routineId` in the rotation list
3. Return the next routine in the list (wrapping to the start if at the end)
4. **Fallback cases:**
   - If the last workout's routine is not in the rotation → suggest the first routine in the rotation
   - If workout history is empty → suggest the first routine in the rotation
   - If the rotation is empty → show empty state (see above)
   - If a routine is removed from the rotation after being the last completed one → suggest the first routine in the rotation

**Rules:**
- Users create/manage their rotation as an ordered list (drag-to-reorder) in settings or via a "Manage Rotation" entry point
- Not all routines need to be in the rotation — routines outside it are still accessible via "All Routines"
- The "Today is X day" suggestion advances to the next routine in the rotation after each completed workout
- If a workout is done out of order (e.g., user picks a different circle), the rotation advances past that one

**Settings UI:** A "Manage Rotation" section in the Settings tab. Shows a drag-to-reorder list of routines currently in the rotation, with an "Add" button to include other routines and swipe-to-remove to take them out.

**Storage:** Rotation order stored as a list of routine IDs in `appDataBox` (untyped Hive box), following the same pattern as the existing `stretch_routine_order` storage in `StorageService`.

### Stretch-Workout Pairing

**Default:** Name-based matching using shared prefix. The app checks if the stretch routine name starts with the workout routine's name, or if they share a multi-word prefix of 2+ words. E.g., workout "Push/Pull Upper" matches stretch "Push/Pull Upper Warm Down" because the stretch name starts with the workout name. This avoids false matches from single common words like "Upper" or "Full".

**Override:** In settings, users can explicitly link a workout routine to a warm-up and/or warm-down stretch routine via dropdown selectors. These explicit links take priority over name matching.

**Settings UI:** Under each workout routine in the "Manage Rotation" section, optional "Warm-up stretch" and "Warm-down stretch" dropdown selectors that list all available stretch routines.

**Storage:** Stored in `appDataBox` as a JSON-serializable map: key = workout routine ID, value = `{"warmUp": stretchId, "warmDown": stretchId}`. Follows the existing `appDataBox` pattern to avoid modifying the Hive-generated UserSettings adapter with complex map types.

## Data Model Changes

### Storage approach
All new data is stored in `appDataBox` (the existing untyped Hive `Box('app_data')`), following the pattern used by `stretch_routine_order`. This avoids adding complex map types to the generated UserSettings adapter.

### New `appDataBox` keys:
- `workout_rotation_order: List<String>` — ordered routine IDs for the active rotation
- `stretch_pairings: Map<String, dynamic>` — workout routine ID → `{"warmUp": stretchId, "warmDown": stretchId}`

### Unchanged UserSettings fields:
- `currentStreak` (HiveField 12) — kept as daily streak, no changes
- `bestStreak` (HiveField 11) — kept as daily best, no changes

### New SharedPreferences keys:
- `cardio_override_YYYY-MM-DD: bool` — manual step goal override for a specific date
- Pruned on app launch: entries older than 14 days are removed

### Step tracking changes:
- `StepTrackingService.goalMetForDate()` checks both the step count AND the cardio override key in SharedPreferences. If either indicates goal met, returns true.

## Widget Decomposition

The current `workout_tab.dart` is 2700+ lines. This redesign should extract new UI into separate widget files:

- `lib/widgets/routine_circles.dart` — the 3 tappable routine circles with highlight logic
- `lib/widgets/stretch_workout_toggle.dart` — the toggle buttons
- `lib/widgets/workout_day_suggestion.dart` — the "Today is X day" banner
- `lib/widgets/post_workout_popup.dart` — the warm-down stretch prompt dialog

Existing sections that remain below the fold stay in `workout_tab.dart` for now.

## Files Modified

- `lib/screens/workout_tab.dart` — main redesign target, restructure top section, delegate to new widgets
- `lib/services/storage_service.dart` — new methods for rotation management, pairing lookups, using `appDataBox`
- `lib/services/step_tracking_service.dart` — cardio goal override support via SharedPreferences
- `lib/screens/settings_tab.dart` — new sections for rotation management and stretch-workout linking
- `lib/screens/workout_session_screen.dart` — post-workout popup before popping back
- `lib/widgets/daily_history_dialog.dart` — enhanced version with expandable workout details
- `lib/widgets/` — new widget files listed above

## Out of Scope

- Changes to other tabs (Today, Progress, Tools, Settings layout beyond new settings entries)
- Building out the Tools tab
- Google Fit/Health API integration
- Any changes to existing Hive data models for workouts, exercises, stretches (no new typeIds needed)
- Refactoring existing sections that are being pushed below the fold
