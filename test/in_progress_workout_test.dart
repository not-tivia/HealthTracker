import 'package:flutter_test/flutter_test.dart';
import 'package:health_tracker/models/in_progress_workout.dart';

void main() {
  InProgressWorkout sample() => InProgressWorkout(
        routineId: 'r1',
        routineName: 'Leg Day',
        startTime: DateTime(2026, 6, 17, 18, 30),
        lastSaved: DateTime(2026, 6, 17, 18, 52),
        currentExerciseIndex: 1,
        exercises: const [
          InProgressExercise(
            savedExerciseId: 'e1',
            name: 'Back Squat',
            targetSets: 3,
            targetReps: '8-12',
            youtubeUrl: null,
            sets: [
              InProgressSet(weight: 135, reps: 8),
              InProgressSet(weight: 135, reps: 8),
              InProgressSet(weight: 0, reps: 0),
            ],
          ),
          InProgressExercise(
            savedExerciseId: 'e2',
            name: 'Leg Press',
            targetSets: 3,
            targetReps: '10-15',
            youtubeUrl: null,
            sets: [InProgressSet(weight: 0, reps: 0)],
          ),
        ],
      );

  test('round-trips through JSON', () {
    final original = sample();
    final restored = InProgressWorkout.tryParse(original.toJsonString());
    expect(restored, isNotNull);
    expect(restored!.routineId, 'r1');
    expect(restored.routineName, 'Leg Day');
    expect(restored.startTime, DateTime(2026, 6, 17, 18, 30));
    expect(restored.currentExerciseIndex, 1);
    expect(restored.exercises.length, 2);
    expect(restored.exercises.first.name, 'Back Squat');
    expect(restored.exercises.first.sets.length, 3);
    expect(restored.exercises.first.sets[0].weight, 135);
    expect(restored.exercises.first.sets[0].reps, 8);
  });

  test('tryParse returns null on malformed JSON', () {
    expect(InProgressWorkout.tryParse('not json'), isNull);
    expect(InProgressWorkout.tryParse('{}'), isNull);
  });

  test('tryParse returns null on version mismatch', () {
    final bad = sample().toJsonString().replaceFirst('"version":1', '"version":999');
    expect(InProgressWorkout.tryParse(bad), isNull);
  });

  test('loggedExerciseCount counts only exercises with a non-empty set', () {
    expect(sample().loggedExerciseCount, 1);
  });

  test('toExercises drops empty sets and empty exercises and renumbers', () {
    final exercises = sample().toExercises();
    expect(exercises.length, 1);
    final squat = exercises.first;
    expect(squat.name, 'Back Squat');
    expect(squat.savedExerciseId, 'e1');
    expect(squat.targetReps, '8-12');
    expect(squat.isCompleted, true);
    expect(squat.completedSets.length, 2);
    expect(squat.completedSets[0].setNumber, 1);
    expect(squat.completedSets[1].setNumber, 2);
    expect(squat.completedSets[0].weight, 135);
  });
}
