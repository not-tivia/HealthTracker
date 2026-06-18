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
