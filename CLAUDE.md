# HealthTracker - Flutter Mobile App

## Project Overview
A comprehensive health and fitness tracking Android app built with Flutter. Tracks workouts, nutrition, water intake, weight, steps, stretching, and daily checklists.

## Tech Stack
- **Framework**: Flutter (Dart SDK >=3.0.0 <4.0.0)
- **State Management**: Provider (ChangeNotifierProvider)
- **Local Storage**: Hive (with generated type adapters)
- **Charts**: fl_chart
- **Notifications**: flutter_local_notifications
- **Step Tracking**: pedometer package

## Architecture
```
lib/
  main.dart              # App entry point, Hive init, adapter registration
  models/                # Hive data models (with .g.dart generated files)
  screens/               # Full-page screens/tabs
    home_screen.dart      # Bottom nav: Today, Progress, Tools, Workout, Settings
    today_tab.dart
    progress_tab.dart
    tools_tab.dart
    workout_tab.dart
    settings_tab.dart
    workout_session_screen.dart
    stretch_session_screen.dart
    photo_compare_screen.dart
  services/              # Business logic layer
    storage_service.dart  # Main data service (ChangeNotifier)
    step_tracking_service.dart
    notification_service.dart
    google_fit_service.dart
    routine_import_export_service.dart
  theme/
    app_theme.dart        # Dark theme, Material 3, color constants
  widgets/               # Reusable UI components
```

## Key Patterns
- **Hive adapters** are registered in `main.dart` with specific typeIds (0-20). New models must use unique typeIds.
- **Generated files** (`*.g.dart`) are created by `build_runner`. After changing Hive models, run:
  ```
  flutter pub run build_runner build --delete-conflicting-outputs
  ```
- **Theme colors** are defined as static constants in `AppTheme` — use them instead of hardcoding colors.
- **StorageService** is the central data layer — access it via `Provider.of<StorageService>(context)` or `context.read<StorageService>()`.

## Build & Run Commands
```bash
flutter pub get                    # Install dependencies
flutter run                        # Run on connected device/emulator
flutter build apk                  # Build release APK
flutter analyze                    # Run static analysis
flutter pub run build_runner build --delete-conflicting-outputs  # Regenerate .g.dart files
```

## Current Focus
UI redesign and internal refinements. The core functionality is working — changes should preserve existing data models and storage compatibility.

## Guidelines
- Dark theme only (AppTheme.darkTheme) - all UI should use AppTheme color constants
- Keep Hive data model changes backward-compatible to avoid breaking existing user data
- Use Provider for state management - don't introduce additional state management solutions
- Target Android only for now
- **NEVER use non-ASCII characters in Dart files.** Use `\u{XXXX}` unicode escapes for special characters:
  - Bullet/dot: `\u{2022}` (not `·`)
  - Multiply sign: `\u{00D7}` (not `×`)
  - Em-dash: use `-` or `--` (not `—`)
  - Smart quotes: use `'` and `"` (not curly quotes)
  - Emoji in string literals are OK (Flutter handles them)
- A pre-commit hook in `.git/hooks/pre-commit` blocks commits with corrupted UTF-8 encoding
