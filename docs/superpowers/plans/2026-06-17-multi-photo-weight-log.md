# Multiple Photos Per Weight-Log Day Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Let a weight-log entry store and display multiple progress photos, backward-compatible with existing single-photo entries.

**Architecture:** Add a `List<String> photoPaths` Hive field (#6) to `WeightEntry`, keep the legacy `String? photoPath`, and expose a unified `allPhotos` getter all readers use. Update the add dialog to multi-pick and every display site to render `allPhotos`.

**Tech Stack:** Flutter, Hive, image_picker.

**Toolchain note:** The Flutter SDK is a Windows install (`/mnt/c/flutter`); `flutter`, `dart`, `build_runner`, and `flutter test` CANNOT run under this WSL shell (CRLF scripts). Implementers must NOT run them - write code, verify by reading, and say so. The user runs `flutter pub run build_runner build --delete-conflicting-outputs`, `flutter analyze`, and `flutter test` on Windows.

**Spec:** `docs/superpowers/specs/2026-06-17-multi-photo-weight-log-design.md`

---

## File Structure

- **Modify** `lib/models/weight_entry.dart` - add `photoPaths` field, `allPhotos` getter, constructor + copyWith.
- **Modify** `lib/models/weight_entry.g.dart` - hand-edit the adapter to read/write field 6.
- **Create** `test/weight_entry_test.dart` - unit tests for `allPhotos`.
- **Modify** `lib/screens/progress_tab.dart` - multi-photo add dialog + tile + details display.
- **Modify** `lib/screens/photo_compare_screen.dart` - read `allPhotos.first`.

---

## Task 1: WeightEntry model + adapter + tests

**Files:**
- Modify: `lib/models/weight_entry.dart`
- Modify: `lib/models/weight_entry.g.dart`
- Create: `test/weight_entry_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/weight_entry_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:health_tracker/models/weight_entry.dart';

void main() {
  WeightEntry make({String? photoPath, List<String>? photoPaths}) => WeightEntry(
        id: '1',
        date: DateTime(2026, 6, 17),
        weight: 180,
        photoPath: photoPath,
        photoPaths: photoPaths,
      );

  test('allPhotos returns photoPaths when set', () {
    expect(make(photoPaths: ['a', 'b']).allPhotos, ['a', 'b']);
  });

  test('allPhotos falls back to legacy photoPath', () {
    expect(make(photoPath: 'x').allPhotos, ['x']);
  });

  test('allPhotos is empty when there are no photos', () {
    expect(make().allPhotos, isEmpty);
  });

  test('photoPaths takes precedence over legacy photoPath', () {
    expect(make(photoPath: 'x', photoPaths: ['a']).allPhotos, ['a']);
  });

  test('photoPaths defaults to empty list when omitted', () {
    expect(make().photoPaths, isEmpty);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run (Windows): `flutter test test/weight_entry_test.dart`
Expected: FAIL - `photoPaths` / `allPhotos` not defined.

- [ ] **Step 3: Update `weight_entry.dart`**

Add the field after the `unit` field (after line 23, the `@HiveField(5) String unit;` block):

```dart
  @HiveField(6)
  List<String> photoPaths;
```

Change the constructor to accept and default `photoPaths`. Replace:

```dart
  WeightEntry({
    required this.id,
    required this.date,
    required this.weight,
    this.photoPath,
    this.notes,
    this.unit = 'lbs',
  });
```

with:

```dart
  WeightEntry({
    required this.id,
    required this.date,
    required this.weight,
    this.photoPath,
    List<String>? photoPaths,
    this.notes,
    this.unit = 'lbs',
  }) : photoPaths = photoPaths ?? [];

  /// All photos for this entry: the new list if present, otherwise the legacy
  /// single photo, otherwise empty. Every reader should use this.
  List<String> get allPhotos {
    if (photoPaths.isNotEmpty) return photoPaths;
    if (photoPath != null && photoPath!.isNotEmpty) return [photoPath!];
    return [];
  }
```

In `copyWith`, add a `List<String>? photoPaths` parameter and thread it through. Replace the `copyWith` signature line `String? photoPath,` group and the constructor call so the method becomes:

```dart
  WeightEntry copyWith({
    String? id,
    DateTime? date,
    double? weight,
    String? photoPath,
    List<String>? photoPaths,
    String? notes,
    String? unit,
  }) {
    return WeightEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      weight: weight ?? this.weight,
      photoPath: photoPath ?? this.photoPath,
      photoPaths: photoPaths ?? this.photoPaths,
      notes: notes ?? this.notes,
      unit: unit ?? this.unit,
    );
  }
```

- [ ] **Step 4: Hand-edit `weight_entry.g.dart`**

In `read(...)`, add `photoPaths` to the returned constructor (after the `unit:` line):

```dart
    return WeightEntry(
      id: fields[0] as String,
      date: fields[1] as DateTime,
      weight: fields[2] as double,
      photoPath: fields[3] as String?,
      notes: fields[4] as String?,
      unit: fields[5] as String,
      photoPaths: (fields[6] as List?)?.cast<String>(),
    );
```

In `write(...)`, change `..writeByte(6)` to `..writeByte(7)` and append field 6 after the `unit` write:

```dart
  void write(BinaryWriter writer, WeightEntry obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.weight)
      ..writeByte(3)
      ..write(obj.photoPath)
      ..writeByte(4)
      ..write(obj.notes)
      ..writeByte(5)
      ..write(obj.unit)
      ..writeByte(6)
      ..write(obj.photoPaths);
  }
```

- [ ] **Step 5: Run the test to verify it passes (Windows)**

Run (Windows): `flutter test test/weight_entry_test.dart`
Expected: PASS (5 tests). Implementer in WSL: verify by reading instead.

- [ ] **Step 6: Commit**

```bash
git add lib/models/weight_entry.dart lib/models/weight_entry.g.dart test/weight_entry_test.dart
git commit -m "feat: WeightEntry supports multiple photos (photoPaths + allPhotos)"
```

---

## Task 2: Multi-photo add-weight dialog

**Files:**
- Modify: `lib/screens/progress_tab.dart`

- [ ] **Step 1: Change the selected-photo state field**

In `_AddWeightDialogState` change:

```dart
  File? _selectedPhoto;
```

to:

```dart
  final List<File> _selectedPhotos = [];
```

- [ ] **Step 2: Replace the photo preview/picker block**

Replace the entire block that starts with `if (_selectedPhoto != null)` (the `Stack(...)`) and its `else Row(...)` of Camera/Gallery buttons (currently the `if (_selectedPhoto != null) Stack(...) else Row(...)` spanning the two photo buttons) with:

```dart
                  if (_selectedPhotos.isNotEmpty) ...[
                    SizedBox(
                      height: 100,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _selectedPhotos.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, i) => Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                _selectedPhotos[i],
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _selectedPhotos.removeAt(i)),
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close,
                                      size: 18, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: _buildPhotoButton(
                          Icons.camera_alt,
                          'Camera',
                          _pickCameraPhoto,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildPhotoButton(
                          Icons.photo_library,
                          'Gallery',
                          _pickGalleryPhotos,
                        ),
                      ),
                    ],
                  ),
```

(The Camera/Gallery buttons are now always visible so the user can keep adding photos.)

- [ ] **Step 3: Replace `_pickImage` with two pickers**

Replace the whole `_pickImage(ImageSource source)` method with:

```dart
  Future<void> _pickGalleryPhotos() async {
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage(
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (images.isNotEmpty) {
        setState(() =>
            _selectedPhotos.addAll(images.map((x) => File(x.path))));
      }
    } catch (e) {
      debugPrint('Error picking images: $e');
    }
  }

  Future<void> _pickCameraPhoto() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() => _selectedPhotos.add(File(image.path)));
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }
```

- [ ] **Step 4: Update `_saveEntry` to save all photos**

Replace the photo-save + entry-construction part of `_saveEntry`:

```dart
      StorageService storage = context.read<StorageService>();
      String? photoPath;

      if (_selectedPhoto != null) {
        photoPath = await storage.savePhoto(_selectedPhoto!, 'weight');
      }

      WeightEntry entry = WeightEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        date: DateTime.now(),
        weight: weight,
        photoPath: photoPath,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        unit: storage.settings.weightUnit,
      );
```

with:

```dart
      StorageService storage = context.read<StorageService>();
      final List<String> photoPaths = [];
      for (final photo in _selectedPhotos) {
        photoPaths.add(await storage.savePhoto(photo, 'weight'));
      }

      WeightEntry entry = WeightEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        date: DateTime.now(),
        weight: weight,
        photoPaths: photoPaths,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        unit: storage.settings.weightUnit,
      );
```

- [ ] **Step 5: Verify (Windows) + self-review**

Run (Windows): `flutter analyze lib/screens/progress_tab.dart`. Implementer in WSL: confirm `_selectedPhoto` has no remaining references, `pickMultiImage` is used, and `_saveEntry` writes `photoPaths`.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/progress_tab.dart
git commit -m "feat: pick and save multiple progress photos in add-weight dialog"
```

---

## Task 3: Display multiple photos (tile + details)

**Files:**
- Modify: `lib/screens/progress_tab.dart`

- [ ] **Step 1: Update the entry tile**

In `_buildWeightEntryTile`, change:

```dart
    bool hasPhoto = entry.photoPath != null && entry.photoPath!.isNotEmpty;
```

to:

```dart
    bool hasPhoto = entry.allPhotos.isNotEmpty;
```

Replace the tile thumbnail `ClipRRect(...Image.file(File(entry.photoPath!))...)` (the one with width/height 60) with a Stack that shows the first photo and a "+N" badge:

```dart
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(entry.allPhotos.first),
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 60,
                          height: 60,
                          color: AppTheme.cardColorLight,
                          child: Icon(Icons.broken_image,
                              color: AppTheme.textTertiary),
                        ),
                      ),
                    ),
                    if (entry.allPhotos.length > 1)
                      Positioned(
                        right: 2,
                        bottom: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '+${entry.allPhotos.length - 1}',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 10),
                          ),
                        ),
                      ),
                  ],
                ),
```

- [ ] **Step 2: Update the details sheet**

In `_WeightEntryDetails.build`, change the height guard:

```dart
      height: entry.photoPath != null
```

to:

```dart
      height: entry.allPhotos.isNotEmpty
```

Replace the single-photo block:

```dart
                  if (entry.photoPath != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(
                        File(entry.photoPath!),
                        width: double.infinity,
                        height: 300,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 300,
                          color: AppTheme.cardColor,
                          child: Center(
                            child: Icon(Icons.broken_image, size: 48),
                          ),
                        ),
                      ),
                    ),
```

with a horizontally scrollable gallery:

```dart
                  if (entry.allPhotos.isNotEmpty)
                    SizedBox(
                      height: 300,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: entry.allPhotos.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, i) => ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.file(
                            File(entry.allPhotos[i]),
                            width: entry.allPhotos.length == 1
                                ? MediaQuery.of(context).size.width - 40
                                : 240,
                            height: 300,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 240,
                              height: 300,
                              color: AppTheme.cardColor,
                              child: const Center(
                                child: Icon(Icons.broken_image, size: 48),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
```

- [ ] **Step 3: Verify (Windows) + self-review**

Run (Windows): `flutter analyze lib/screens/progress_tab.dart`. Implementer in WSL: confirm no remaining `entry.photoPath` reads in this file and `allPhotos` used everywhere.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/progress_tab.dart
git commit -m "feat: show all weight-log photos in tile (+N badge) and details gallery"
```

---

## Task 4: Photo-compare screen reads allPhotos

**Files:**
- Modify: `lib/screens/photo_compare_screen.dart`

- [ ] **Step 1: Replace photoPath reads**

In `lib/screens/photo_compare_screen.dart`, replace every occurrence of:
- `entry.photoPath != null` with `entry.allPhotos.isNotEmpty`
- `File(entry.photoPath!)` with `File(entry.allPhotos.first)`

There are three of each (around lines 158, 338, 490). Read the file and make all six replacements. If any `entry.photoPath` appears in a different form (e.g. `entry.photoPath!.isNotEmpty`), convert it to the `allPhotos` equivalent (`entry.allPhotos.isNotEmpty` / `entry.allPhotos.first`).

- [ ] **Step 2: Verify (Windows) + self-review**

Run (Windows): `flutter analyze lib/screens/photo_compare_screen.dart`. Implementer in WSL: grep to confirm zero remaining `photoPath` references in the file.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/photo_compare_screen.dart
git commit -m "feat: photo-compare uses first of each entry's photos"
```

---

## Task 5: Full verification (Windows shell)

**Files:** none (verification only)

- [ ] **Step 1: Regenerate the adapter and confirm it matches the hand-edit**

Run (Windows): `flutter pub run build_runner build --delete-conflicting-outputs`
Expected: `weight_entry.g.dart` is unchanged (or only cosmetically different) - confirming the hand-edit matched the generator.

- [ ] **Step 2: Analyze + test**

Run (Windows): `flutter analyze` then `flutter test`
Expected: no new analyzer errors; `weight_entry_test.dart` passes.

- [ ] **Step 3: Manual device check**

On a device (`flutter run`), verify and check each:
  - [ ] Add a weight entry with 3 gallery photos -> all 3 save; tile shows first + "+2" badge.
  - [ ] Add one with the camera (append) + gallery in the same entry -> all appear.
  - [ ] Open details -> horizontal gallery scrolls through all photos.
  - [ ] An OLD single-photo entry (created before this change) still shows its photo in tile and details.
  - [ ] Select two photo entries and open compare -> each side shows that entry's first photo.

---

## Notes for the implementer

- Backward compatibility is the whole point: never rewrite `photoPath`; always read `allPhotos`.
- ASCII-only in Dart files (CLAUDE.md). The "+N" badge uses a plain `+`.
- DRY: `allPhotos` is the single source of truth for "what photos does this entry have."
