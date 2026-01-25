class WorkoutTemplate {
  final String type;
  final String name;
  final List<ExerciseTemplate> exercises;

  const WorkoutTemplate({
    required this.type,
    required this.name,
    required this.exercises,
  });
}

class ExerciseTemplate {
  final String name;
  final int sets;
  final String reps; // e.g., "8-12"
  final String? youtubeUrl;
  final String? instructions;

  const ExerciseTemplate({
    required this.name,
    required this.sets,
    required this.reps,
    this.youtubeUrl,
    this.instructions,
  });

  int get minReps {
    final parts = reps.split('-');
    return parts.isNotEmpty ? int.tryParse(parts.first.trim()) ?? 8 : 8;
  }

  int get maxReps {
    final parts = reps.split('-');
    return parts.length > 1 ? int.tryParse(parts.last.trim()) ?? 12 : minReps;
  }
}

class WorkoutTemplates {
  static const List<WorkoutTemplate> templates = [
    // Push Day
    WorkoutTemplate(
      type: 'Push',
      name: 'Push Day',
      exercises: [
        ExerciseTemplate(name: 'Bench Press', sets: 3, reps: '8-12', youtubeUrl: 'https://www.youtube.com/watch?v=rT7DgCr-3pg'),
        ExerciseTemplate(name: 'Overhead Shoulder Press', sets: 3, reps: '8-10'),
        ExerciseTemplate(name: 'Incline Dumbbell Press', sets: 3, reps: '10-12'),
        ExerciseTemplate(name: 'Lateral Raises', sets: 3, reps: '12-15'),
        ExerciseTemplate(name: 'Tricep Pushdowns', sets: 3, reps: '12-15'),
        ExerciseTemplate(name: 'Chest Flyes', sets: 3, reps: '12-15'),
      ],
    ),
    // Pull Day
    WorkoutTemplate(
      type: 'Pull',
      name: 'Pull Day',
      exercises: [
        ExerciseTemplate(name: 'Pull-ups', sets: 3, reps: '6-10'),
        ExerciseTemplate(name: 'Barbell Rows', sets: 3, reps: '8-10'),
        ExerciseTemplate(name: 'Lat Pulldowns', sets: 3, reps: '10-12'),
        ExerciseTemplate(name: 'Face Pulls', sets: 3, reps: '15-20'),
        ExerciseTemplate(name: 'Bicep Curls', sets: 3, reps: '10-12'),
        ExerciseTemplate(name: 'Hammer Curls', sets: 3, reps: '10-12'),
      ],
    ),
    // Legs Day
    WorkoutTemplate(
      type: 'Legs',
      name: 'Legs Day',
      exercises: [
        ExerciseTemplate(name: 'Barbell Squats', sets: 3, reps: '6-8'),
        ExerciseTemplate(name: 'Romanian Deadlifts', sets: 3, reps: '8-10'),
        ExerciseTemplate(name: 'Leg Press', sets: 3, reps: '10-12'),
        ExerciseTemplate(name: 'Walking Lunges', sets: 3, reps: '12 each leg'),
        ExerciseTemplate(name: 'Leg Curls', sets: 3, reps: '12-15'),
        ExerciseTemplate(name: 'Calf Raises', sets: 4, reps: '15-20'),
      ],
    ),
  ];

  static List<ExerciseTemplate> getExercises(String workoutType) {
    final template = templates.firstWhere(
      (t) => t.type == workoutType,
      orElse: () => templates[0],
    );
    return template.exercises;
  }
}
