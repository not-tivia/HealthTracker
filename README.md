# health_tracker

Compressed fitness app on google drive here
https://drive.google.com/file/d/1PdfYWXY3XBWPnxRF-m99MfgjHJ3RNEKg/view?usp=drive_link

For questions or feedback dm me on discord tiv0000

# Importing Routines

Health Tracker supports importing workout and stretch routines via JSON files. This allows you to share routines with others or back up your custom routines.

## How to Import

1. Go to the **Workout** tab
2. Tap **Import** button
3. Select a `.json` file from your device
4. Review the preview (shows what will be created)
5. Tap **Import** to confirm

---

## Workout Routine Format

```json
{
  "type": "workout_routine",
  "version": "1.0",
  "routine": {
    "name": "Push Day",
    "description": "Chest, shoulders, and triceps",
    "colorHex": "4CAF50",
    "exercises": [
      {
        "name": "Bench Press",
        "muscleGroup": "Chest",
        "defaultSets": 4,
        "defaultMinReps": 8,
        "defaultMaxReps": 12,
        "youtubeUrl": "https://www.youtube.com/watch?v=example",
        "notes": "Keep shoulder blades retracted",
        "overrideSets": null,
        "overrideMinReps": null,
        "overrideMaxReps": null,
        "routineNotes": "Warm up with empty bar first"
      },
      {
        "name": "Overhead Press",
        "muscleGroup": "Shoulders",
        "defaultSets": 3,
        "defaultMinReps": 8,
        "defaultMaxReps": 10,
        "youtubeUrl": null,
        "notes": null
      },
      {
        "name": "Tricep Pushdowns",
        "muscleGroup": "Arms",
        "defaultSets": 3,
        "defaultMinReps": 10,
        "defaultMaxReps": 15
      }
    ]
  }
}
```

### Workout Routine Fields

| Field | Required | Description |
|-------|----------|-------------|
| `type` | Yes | Must be `"workout_routine"` |
| `version` | No | Format version (currently `"1.0"`) |
| `routine.name` | Yes | Name of the routine |
| `routine.description` | No | Optional description |
| `routine.colorHex` | No | Color code without # (e.g., `"4CAF50"`) |
| `routine.exercises` | Yes | Array of exercises |

### Exercise Fields

| Field | Required | Default | Description |
|-------|----------|---------|-------------|
| `name` | Yes | - | Exercise name |
| `muscleGroup` | No | `null` | Muscle group (Chest, Back, Shoulders, Arms, Legs, Core, Full Body, Other) |
| `defaultSets` | No | `3` | Default number of sets |
| `defaultMinReps` | No | `8` | Minimum reps in range |
| `defaultMaxReps` | No | `12` | Maximum reps in range |
| `youtubeUrl` | No | `null` | Link to form video |
| `notes` | No | `null` | Exercise notes/tips |
| `overrideSets` | No | `null` | Override sets for this routine only |
| `overrideMinReps` | No | `null` | Override min reps for this routine |
| `overrideMaxReps` | No | `null` | Override max reps for this routine |
| `routineNotes` | No | `null` | Notes specific to this routine |

---

## Stretch Routine Format

```json
{
  "type": "stretch_routine",
  "version": "1.0",
  "routine": {
    "name": "Lower Body Warmup",
    "description": "Dynamic stretches before leg day",
    "colorHex": "26A69A",
    "stretches": [
      {
        "name": "Leg Swings (Front-Back)",
        "muscleGroup": "Hips",
        "defaultDuration": 30,
        "youtubeUrl": "https://www.youtube.com/watch?v=example",
        "notes": "Hold onto wall for balance",
        "overrideDuration": null,
        "routineNotes": "15 swings each leg"
      },
      {
        "name": "Hip Circles",
        "muscleGroup": "Hips",
        "defaultDuration": 30,
        "notes": "Large controlled circles"
      },
      {
        "name": "Walking Lunges",
        "muscleGroup": "Quads",
        "defaultDuration": 45,
        "overrideDuration": 60,
        "routineNotes": "10 steps each leg"
      }
    ]
  }
}
```

### Stretch Routine Fields

| Field | Required | Description |
|-------|----------|-------------|
| `type` | Yes | Must be `"stretch_routine"` |
| `version` | No | Format version (currently `"1.0"`) |
| `routine.name` | Yes | Name of the routine |
| `routine.description` | No | Optional description |
| `routine.colorHex` | No | Color code without # (e.g., `"26A69A"`) |
| `routine.stretches` | Yes | Array of stretches |

### Stretch Fields

| Field | Required | Default | Description |
|-------|----------|---------|-------------|
| `name` | Yes | - | Stretch name |
| `muscleGroup` | No | `null` | Target area (Neck, Shoulders, Chest, Back, Arms, Core, Hips, Glutes, Hamstrings, Quads, Calves, Full Body, Other) |
| `defaultDuration` | No | `30` | Duration in seconds |
| `youtubeUrl` | No | `null` | Link to demo video |
| `notes` | No | `null` | Form tips/notes |
| `overrideDuration` | No | `null` | Override duration for this routine |
| `routineNotes` | No | `null` | Notes specific to this routine |

---

## Color Codes

Here are some suggested colors for your routines:

| Color | Hex Code | Good For |
|-------|----------|----------|
| Green | `4CAF50` | Push day, General |
| Pink | `E91E63` | Pull day |
| Blue | `2196F3` | Leg day |
| Orange | `FF9800` | Full body |
| Purple | `9C27B0` | Arms |
| Teal | `26A69A` | Stretching |
| Cyan | `00BCD4` | Cardio warmup |
| Red | `F44336` | Intense workouts |

---

## Tips

- **Duplicate exercises**: If an exercise with the same name already exists in your library, the import will use your existing exercise instead of creating a duplicate.

- **Minimal JSON**: You only need to include required fields. This is a valid minimal workout routine:
  ```json
  {
    "type": "workout_routine",
    "routine": {
      "name": "Quick Arms",
      "exercises": [
        { "name": "Bicep Curls" },
        { "name": "Tricep Dips" }
      ]
    }
  }
  ```

- **Exporting**: You can export any of your routines to JSON using the menu on each routine card. This is great for sharing or backup.

