# Multiple Photos Per Weight-Log Day - Design

**Date:** 2026-06-17
**Status:** Approved, ready for implementation planning

## Problem

A weight-log entry stores at most one progress photo (`WeightEntry.photoPath`,
a single `String?`). Users want to attach several photos to the same day (e.g.
multiple angles of a weigh-in).

## Goal

Let a weight entry hold multiple photos, displayed everywhere a photo currently
appears, without breaking or rewriting existing single-photo entries.

## Approach

### Data model - additive, backward-compatible

`lib/models/weight_entry.dart` (Hive typeId 3):

- KEEP `@HiveField(3) String? photoPath` unchanged (legacy single photo). Old
  entries are never rewritten or migrated.
- ADD `@HiveField(6) List<String> photoPaths` defaulting to `[]` (next free
  field index; current max is 5).
- ADD a getter that unifies old + new for all readers:
  ```dart
  List<String> get allPhotos {
    if (photoPaths.isNotEmpty) return photoPaths;
    if (photoPath != null && photoPath!.isNotEmpty) return [photoPath!];
    return [];
  }
  ```
- The constructor takes `List<String>? photoPaths` and stores `photoPaths ?? []`.
- `copyWith` gains a `List<String>? photoPaths` parameter.

New saves write `photoPaths` and leave `photoPath` null. Every display site
reads `allPhotos`, so legacy and new entries render through one path.

### Hive adapter

`lib/models/weight_entry.g.dart` must be regenerated. Because `build_runner`
cannot run in the WSL dev environment (Windows Flutter SDK, CRLF scripts), the
adapter is hand-edited to match what the generator would produce:
- `read`: add `photoPaths: (fields[6] as List?)?.cast<String>()`. Old entries
  lacking field 6 yield `null`, which the constructor turns into `[]`.
- `write`: bump `writeByte(6)` to `writeByte(7)` and append field 6:
  `..writeByte(6)..write(obj.photoPaths)`.

The implementer must STILL run `flutter pub run build_runner build
--delete-conflicting-outputs` on Windows afterward to confirm the hand-edit
matches generator output.

### Photo file storage

`StorageService.savePhoto(File, prefix)` already copies one file and returns its
path. No change - the add-photo flow calls it once per selected file.

## UI changes (`lib/screens/progress_tab.dart`)

### Add-weight dialog (`_AddWeightDialog`)
- `File? _selectedPhoto` becomes `List<File> _selectedPhotos = []`.
- Gallery action uses `ImagePicker().pickMultiImage(...)` and appends all picked
  files (gallery multi-select is the primary path).
- Camera action uses `pickImage(camera)` and appends one file.
- Selected photos render as a horizontal thumbnail strip; each thumbnail has a
  remove "x"; an "add more" affordance remains visible.
- On save: `for (final f in _selectedPhotos) photoPaths.add(await savePhoto(f, 'weight'));`
  then build the `WeightEntry` with `photoPaths: photoPaths` (and `photoPath: null`).

### Entry tile (`_buildWeightEntryTile`)
- `hasPhoto` uses `entry.allPhotos.isNotEmpty`.
- Thumbnail shows `entry.allPhotos.first`; when `allPhotos.length > 1`, overlay a
  small "+N" badge (N = `allPhotos.length - 1`).
- Long-press "select for compare" remains gated on `hasPhoto`.

### Entry details sheet (`_WeightEntryDetails`)
- Replace the single `Image.file(entry.photoPath!)` with a horizontally
  scrollable row of all `entry.allPhotos`. Sheet height logic keys off
  `entry.allPhotos.isNotEmpty`.

## Photo-compare screen (`lib/screens/photo_compare_screen.dart`)

Compare still operates on two entries side-by-side; each entry is represented by
its FIRST photo. Replace every `entry.photoPath != null` guard with
`entry.allPhotos.isNotEmpty` and every `File(entry.photoPath!)` with
`File(entry.allPhotos.first)`. (Per-photo swiping is explicitly out of scope.)

## Testing

- Unit test for `WeightEntry.allPhotos`:
  - new entry with `photoPaths: ['a','b']` -> `['a','b']`
  - legacy entry with `photoPath: 'x'`, no `photoPaths` -> `['x']`
  - empty entry -> `[]`
  - `photoPaths` takes precedence when both are set.
- Adapter round-trip is verified on Windows via `build_runner` + `flutter test`.

**Toolchain note:** all `flutter`/`build_runner`/`test` commands run on the
Windows side; the implementer states explicitly what was and was not run.

## Out of scope

- Migrating legacy `photoPath` into `photoPaths` (handled transparently by
  `allPhotos`).
- Per-photo swiping in the compare screen.
- Reordering photos within a day.
