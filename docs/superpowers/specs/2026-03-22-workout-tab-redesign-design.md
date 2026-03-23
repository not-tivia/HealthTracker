# Workout Tab Redesign — Design Spec

## Problem

The workout tab is cluttered with too many sections visible at once (weekly goal, week tracker, start workout button, import/export, warm-up stretches, routines, recent activity, exercise library). Users must scroll extensively to reach what they need. The tab needs a cleaner top-level layout that surfaces the most important actions immediately.

## Design

### Layout (Top to Bottom)

#### 1. Weekly Goal Ring
Keep the existing circular progress indicator showing "3/4 this week" style progress. Add two new data points beside it:
- **Streak (current)** — consecutive weeks where the weekly workout goal was met
- **Trophy (best)** — the longest streak ever achieved

These values are persisted in UserSettings or a dedicated Hive box.

#### 2. Weekly Day Row + Cardio Button
The existing M T W T F S S row with checkmarks stays as-is. Add a **"Cardio completed"** button next to the row.

**Cardio button behavior:** Single tap marks today's step goal as met (boolean override). This exists because the pedometer package only reads the phone's hardware sensor and misses treadmill/watch-synced steps. No cardio type selection — just a goal-met toggle that preserves the step streak.

**Day tap behavior:** Tapping any day icon opens a calendar picker identical to the Today tab's `DailyHistoryDialog`, but with enhanced workout details. Instead of just showing "Push/Pull Upper — 5 exercises — 45 min", it shows expandable cards (like the current Recent Activity section at the bottom of the workout tab) with full sets, reps, and weights visible when expanded.

#### 3. "Today is [X] Day" Banner
A text banner above the routine circles that shows the next workout in the user's rotation. E.g., "Today is Push/Pull Upper day". Tapping the banner or the highlighted circle below starts that workout.

The suggestion is determined by the **rotation system** (see below).

#### 4. Stretch / Workout Toggle
Two toggle buttons ("Stretch" / "Workout") that switch which content appears in the circles below. Only one section is visible at a time.

#### 5. Routine Circles (up to 3)

**When "Workout" is selected:**
- Shows up to 3 circles representing workout routines from the active rotation
- The first circle is the suggested next workout (highlighted — brighter border or subtle glow)
- The other 2 are the next routines after that in the rotation sequence
- If the rotation has fewer than 3 routines, show only that many circles
- Tapping a circle starts that workout session

**When "Stretch" is selected:**
- Shows up to 3 circles representing the most recently used stretch routines (recency-based)
- Above the circles, a **suggestion banner** displays a context-aware recommendation: "Suggested: Push/Pull Warm Down" — based on what workout was just completed
- Pairing logic: name-matched by default (e.g., "Push/Pull Upper" workout matches "Push/Pull Warm Down" stretch), with manual override available in settings

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

### Rotation System

**Concept:** An ordered list of workout routines that the user cycles through. The app tracks position in the rotation based on the last completed workout.

**Rules:**
- Users create/manage their rotation as an ordered list (drag-to-reorder) in settings or via a "Manage Rotation" entry point
- Not all routines need to be in the rotation — routines outside it are still accessible via "All Routines"
- The "Today is X day" suggestion advances to the next routine in the rotation after each completed workout
- If a workout is done out of order (e.g., user picks a different circle), the rotation advances past that one

**Storage:** Rotation order stored as a list of routine IDs in Hive (similar to existing `stretchRoutineOrder`). Current position tracked by comparing the last completed workout against the rotation list.

### Stretch-Workout Pairing

**Default:** Name-based matching. The app looks for stretch routines whose name contains the workout routine's name (or vice versa). E.g., workout "Push/Pull Upper" matches stretch "Push/Pull Warm Up" and "Push/Pull Warm Down".

**Override:** In settings, users can explicitly link a workout routine to a warm-up and/or warm-down stretch routine. These explicit links take priority over name matching.

**Storage:** A map of workout routine ID to stretch routine IDs stored in UserSettings or a dedicated Hive box.

## Data Model Changes

### New fields in UserSettings (or new Hive box):
- `workoutRotationOrder: List<String>` — ordered routine IDs for the active rotation
- `currentStreakWeeks: int` — consecutive weeks with goal met
- `bestStreakWeeks: int` — longest streak ever
- `stretchPairings: Map<String, Map<String, String>>` — workout routine ID → `{"warmUp": stretchId, "warmDown": stretchId}`
- `cardioGoalOverrides: Map<String, bool>` — date string → manual goal-met override

### Step tracking changes:
- `StepTrackingService.goalMetForDate()` should also check `cardioGoalOverrides` — if the date has a manual override set to true, return true regardless of step count.

## Files Likely Modified

- `lib/screens/workout_tab.dart` — main redesign target, largest changes
- `lib/models/user_settings.dart` + `.g.dart` — new fields for rotation, streaks, pairings
- `lib/services/storage_service.dart` — methods for rotation management, streak tracking, pairing lookups
- `lib/services/step_tracking_service.dart` — cardio goal override support
- `lib/screens/settings_tab.dart` — new sections for rotation management and stretch-workout linking
- `lib/widgets/` — potentially new widget files for the toggle, routine circles, suggestion banner, post-workout popup

## Out of Scope

- Changes to other tabs (Today, Progress, Tools, Settings layout beyond new settings entries)
- Building out the Tools tab
- Google Fit/Health API integration
- Any changes to existing data models for workouts, exercises, stretches
