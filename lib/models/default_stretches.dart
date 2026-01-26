import 'saved_stretch.dart';
import 'stretch_routine.dart';

/// Default stretches that come bundled with the app
/// Uses Unicode escape sequences for any special characters
class DefaultStretches {
  static List<SavedStretch> get items => [
    // ============ UPPER BODY DYNAMIC (Warm-up) ============
    SavedStretch(
      id: 'default_stretch_1',
      name: 'Arm Circles Forward',
      muscleGroup: 'Shoulders',
      defaultDuration: 30,
      youtubeUrl: 'https://www.youtube.com/watch?v=140RTsLjFfY',
      notes: 'Start with small circles and gradually increase to large circles. Keep core engaged.',
    ),
    SavedStretch(
      id: 'default_stretch_2',
      name: 'Arm Circles Backward',
      muscleGroup: 'Shoulders',
      defaultDuration: 30,
      youtubeUrl: 'https://www.youtube.com/watch?v=140RTsLjFfY',
      notes: 'Reverse direction. Focus on controlled movement through full range of motion.',
    ),
    SavedStretch(
      id: 'default_stretch_3',
      name: 'Shoulder Rolls',
      muscleGroup: 'Shoulders',
      defaultDuration: 20,
      youtubeUrl: 'https://www.youtube.com/watch?v=iLP7VPXroHs',
      notes: 'Roll shoulders up, forward, down, and back. Then reverse direction. Open up the chest.',
    ),
    SavedStretch(
      id: 'default_stretch_4',
      name: 'Standing Torso Twists',
      muscleGroup: 'Core',
      defaultDuration: 30,
      youtubeUrl: 'https://www.youtube.com/watch?v=gcZBX_nsvXg',
      notes: 'Stand with feet shoulder-width apart. Rotate torso side to side, letting arms swing naturally. Keep hips facing forward.',
    ),
    SavedStretch(
      id: 'default_stretch_5',
      name: 'Arm Swings (Chest Hugs)',
      muscleGroup: 'Chest',
      defaultDuration: 30,
      youtubeUrl: 'https://www.youtube.com/watch?v=vCsZC-CrjYE',
      notes: 'Swing arms wide open then across chest in a hugging motion. Alternate which arm goes on top.',
    ),
    SavedStretch(
      id: 'default_stretch_6',
      name: 'Band Pull-Aparts',
      muscleGroup: 'Back',
      defaultDuration: 30,
      youtubeUrl: 'https://www.youtube.com/watch?v=JObYtU7Y7ag',
      notes: 'Hold band at shoulder width, arms extended. Pull apart until band touches chest. Squeeze shoulder blades together. Skip if no band available.',
    ),

    // ============ UPPER BODY STATIC (Cooldown) ============
    SavedStretch(
      id: 'default_stretch_7',
      name: "Child's Pose",
      muscleGroup: 'Back',
      defaultDuration: 45,
      youtubeUrl: 'https://www.youtube.com/watch?v=2MJGg-dUKh0',
      notes: 'Kneel and sit back on heels, arms extended forward. Let chest sink toward floor. Breathe deeply for back and lats.',
    ),
    SavedStretch(
      id: 'default_stretch_8',
      name: 'Cat-Cow Pose',
      muscleGroup: 'Back',
      defaultDuration: 40,
      youtubeUrl: 'https://www.youtube.com/watch?v=kqnua4rHVVA',
      notes: 'On all fours, alternate between arching back (cat) and dropping belly (cow). Inhale cow, exhale cat.',
    ),
    SavedStretch(
      id: 'default_stretch_9',
      name: 'Cobra Pose',
      muscleGroup: 'Back',
      defaultDuration: 30,
      youtubeUrl: 'https://www.youtube.com/watch?v=JDcdhTuycOI',
      notes: "Lie face down, hands under shoulders. Gently press up, keeping hips on floor. Don't overextend.",
    ),
    SavedStretch(
      id: 'default_stretch_10',
      name: 'Doorway Pec Stretch',
      muscleGroup: 'Chest',
      defaultDuration: 30,
      youtubeUrl: 'https://www.youtube.com/watch?v=SxQfVHqhyjo',
      notes: 'Place forearm on doorframe at 90 degrees, step through gently. Keep core engaged. Do both sides.',
    ),
    SavedStretch(
      id: 'default_stretch_11',
      name: 'Overhead Tricep Stretch',
      muscleGroup: 'Arms',
      defaultDuration: 30,
      youtubeUrl: 'https://www.youtube.com/watch?v=YKnbq8wqzfk',
      notes: 'Raise arm overhead, bend elbow, reach hand down back. Use other hand to gently press elbow. Do both sides.',
    ),
    SavedStretch(
      id: 'default_stretch_12',
      name: 'Cross-Body Shoulder Stretch',
      muscleGroup: 'Shoulders',
      defaultDuration: 30,
      youtubeUrl: 'https://www.youtube.com/watch?v=WHeQnm6Dpt4',
      notes: "Pull arm across chest with opposite hand. Keep shoulder down, don't rotate torso. Do both sides.",
    ),
    SavedStretch(
      id: 'default_stretch_13',
      name: 'Hanging Lat Stretch',
      muscleGroup: 'Back',
      defaultDuration: 30,
      youtubeUrl: 'https://www.youtube.com/watch?v=VgGa69aWGjQ',
      notes: 'Hang from pull-up bar with relaxed grip. Alternative: seated forward lean reaching for toes.',
    ),

    // ============ LOWER BODY DYNAMIC (Warm-up) ============
    SavedStretch(
      id: 'default_stretch_14',
      name: 'Leg Swings Front-to-Back',
      muscleGroup: 'Hips',
      defaultDuration: 30,
      youtubeUrl: 'https://www.youtube.com/watch?v=oDlkHdpPbkk',
      notes: 'Hold wall for balance. Swing leg forward and backward in controlled motion. Keep core tight. Do both legs.',
    ),
    SavedStretch(
      id: 'default_stretch_15',
      name: 'Leg Swings Side-to-Side',
      muscleGroup: 'Hips',
      defaultDuration: 30,
      youtubeUrl: 'https://www.youtube.com/watch?v=oDlkHdpPbkk',
      notes: 'Face wall, swing leg across body and out to side. Keep torso stable. Do both legs.',
    ),
    SavedStretch(
      id: 'default_stretch_16',
      name: 'Bodyweight Good Mornings',
      muscleGroup: 'Hamstrings',
      defaultDuration: 30,
      youtubeUrl: 'https://www.youtube.com/watch?v=vKPGe8zb2S4',
      notes: 'Hands behind head, soft knees. Hinge at hips pushing butt back, keep back flat. 8-10 slow reps.',
    ),
    SavedStretch(
      id: 'default_stretch_17',
      name: 'Walking Lunges',
      muscleGroup: 'Legs',
      defaultDuration: 40,
      youtubeUrl: 'https://www.youtube.com/watch?v=L8fvypPrzzs',
      notes: 'Short stride, no weight. Step forward, lower back knee toward ground, alternate legs. 10-12 steps.',
    ),
    SavedStretch(
      id: 'default_stretch_18',
      name: 'Hip Circles',
      muscleGroup: 'Hips',
      defaultDuration: 30,
      youtubeUrl: 'https://www.youtube.com/watch?v=QxAfxtzk1wQ',
      notes: 'Stand with hands on hips. Make large circles - forward, side, back, other side. Do both directions.',
    ),
    SavedStretch(
      id: 'default_stretch_19',
      name: 'Bodyweight Squats',
      muscleGroup: 'Legs',
      defaultDuration: 30,
      youtubeUrl: 'https://www.youtube.com/watch?v=aclHkVaku9U',
      notes: 'Feet shoulder-width, toes slightly out. Squat down keeping chest up. 8-10 slow controlled reps.',
    ),

    // ============ LOWER BODY STATIC (Cooldown) ============
    SavedStretch(
      id: 'default_stretch_20',
      name: 'Standing Quad Stretch',
      muscleGroup: 'Quads',
      defaultDuration: 30,
      youtubeUrl: 'https://www.youtube.com/watch?v=i5TGNK18dv4',
      notes: 'Stand on one leg, grab ankle and pull heel toward glute. Keep knees together. Hold wall for balance. Do both legs.',
    ),
    SavedStretch(
      id: 'default_stretch_21',
      name: 'Hip Flexor Lunge Stretch',
      muscleGroup: 'Hip Flexors',
      defaultDuration: 45,
      youtubeUrl: 'https://www.youtube.com/watch?v=YQmpO9VT2X4',
      notes: 'Kneel on back knee, front foot flat. Push hips forward until you feel stretch in front of back hip. Do both sides.',
    ),
    SavedStretch(
      id: 'default_stretch_22',
      name: 'Pigeon Pose',
      muscleGroup: 'Glutes',
      defaultDuration: 45,
      youtubeUrl: 'https://www.youtube.com/watch?v=_fGFL3BMKQE',
      notes: 'From hands and knees, bring one knee forward and angle shin. Extend back leg. Fold forward for deeper stretch. Do both sides.',
    ),
    SavedStretch(
      id: 'default_stretch_23',
      name: 'Figure-4 Glute Stretch',
      muscleGroup: 'Glutes',
      defaultDuration: 40,
      youtubeUrl: 'https://www.youtube.com/watch?v=lMvP1lPi8bY',
      notes: 'Lie on back, cross one ankle over opposite knee. Pull bottom leg toward chest. Alternative to pigeon pose. Do both sides.',
    ),
    SavedStretch(
      id: 'default_stretch_24',
      name: 'Seated Forward Fold',
      muscleGroup: 'Hamstrings',
      defaultDuration: 45,
      youtubeUrl: 'https://www.youtube.com/watch?v=g_tea8ZNorA',
      notes: "Sit with legs extended. Hinge at hips reaching toward toes gently. Don't force it!",
    ),
    SavedStretch(
      id: 'default_stretch_25',
      name: 'Lying Knee-to-Chest',
      muscleGroup: 'Lower Back',
      defaultDuration: 30,
      youtubeUrl: 'https://www.youtube.com/watch?v=LT7ApSi63lA',
      notes: 'Lie on back, pull knees toward chest. Rock gently side to side to massage lower back.',
    ),
  ];
}

/// Default stretch routines that come bundled with the app
class DefaultStretchRoutines {
  static List<StretchRoutine> get items => [
    // ============ DAY 1: PUSH/PULL (UPPER) ============
    StretchRoutine(
      id: 'default_routine_1',
      name: 'Push/Pull Pre-Workout Warm-up',
      description: 'Dynamic warm-up to prepare shoulders, back, chest, and arms for upper body training',
      colorHex: 'FF9800',
      stretches: [
        RoutineStretch(savedStretchId: 'default_stretch_1', order: 0), // Arm Circles Forward
        RoutineStretch(savedStretchId: 'default_stretch_2', order: 1), // Arm Circles Backward
        RoutineStretch(savedStretchId: 'default_stretch_3', order: 2), // Shoulder Rolls
        RoutineStretch(savedStretchId: 'default_stretch_4', order: 3), // Torso Twists
        RoutineStretch(savedStretchId: 'default_stretch_5', order: 4), // Arm Swings
        RoutineStretch(savedStretchId: 'default_stretch_6', order: 5), // Band Pull-Aparts
      ],
    ),
    StretchRoutine(
      id: 'default_routine_2',
      name: 'Push/Pull Post-Workout Cooldown',
      description: 'Static stretches to recover back, chest, shoulders, lats, and arms after upper body training',
      colorHex: '5C6BC0',
      stretches: [
        RoutineStretch(savedStretchId: 'default_stretch_7', order: 0),  // Child's Pose
        RoutineStretch(savedStretchId: 'default_stretch_8', order: 1),  // Cat-Cow
        RoutineStretch(savedStretchId: 'default_stretch_9', order: 2),  // Cobra
        RoutineStretch(savedStretchId: 'default_stretch_10', order: 3, notes: '30 seconds each side'), // Doorway Pec
        RoutineStretch(savedStretchId: 'default_stretch_11', order: 4, notes: '15 seconds each arm'), // Tricep
        RoutineStretch(savedStretchId: 'default_stretch_12', order: 5, notes: '15 seconds each arm'), // Cross-Body Shoulder
        RoutineStretch(savedStretchId: 'default_stretch_13', order: 6, notes: 'Skip if no bar - do seated version'), // Hanging Lat
      ],
    ),

    // ============ DAY 2: LEGS + STRONGMAN ============
    StretchRoutine(
      id: 'default_routine_3',
      name: 'Legs Pre-Workout Warm-up',
      description: 'Dynamic warm-up to prepare legs, glutes, and hips for lower body and strongman training',
      colorHex: '66BB6A',
      stretches: [
        RoutineStretch(savedStretchId: 'default_stretch_14', order: 0, notes: '15 seconds each leg'), // Leg Swings F-B
        RoutineStretch(savedStretchId: 'default_stretch_15', order: 1, notes: '15 seconds each leg'), // Leg Swings S-S
        RoutineStretch(savedStretchId: 'default_stretch_16', order: 2, notes: '8-10 slow reps'), // Good Mornings
        RoutineStretch(savedStretchId: 'default_stretch_17', order: 3, notes: '10-12 steps total'), // Walking Lunges
        RoutineStretch(savedStretchId: 'default_stretch_18', order: 4, notes: '15 seconds each direction'), // Hip Circles
        RoutineStretch(savedStretchId: 'default_stretch_19', order: 5, notes: '8-10 slow reps'), // BW Squats
      ],
    ),
    StretchRoutine(
      id: 'default_routine_4',
      name: 'Legs Post-Workout Cooldown',
      description: 'Static stretches to recover legs, glutes, hips, and hamstrings after lower body training',
      colorHex: '26A69A',
      stretches: [
        RoutineStretch(savedStretchId: 'default_stretch_20', order: 0, notes: '30 seconds each leg'), // Quad Stretch
        RoutineStretch(savedStretchId: 'default_stretch_21', order: 1, notes: '45 seconds each side'), // Hip Flexor
        RoutineStretch(savedStretchId: 'default_stretch_22', order: 2, notes: '45 seconds each side'), // Pigeon
        RoutineStretch(savedStretchId: 'default_stretch_23', order: 3, notes: 'Alternative to pigeon - 40s each side'), // Figure-4
        RoutineStretch(savedStretchId: 'default_stretch_24', order: 4, notes: 'Gentle stretch only'), // Forward Fold
        RoutineStretch(savedStretchId: 'default_stretch_25', order: 5, notes: 'Both knees together'), // Knee-to-Chest
      ],
    ),

    // ============ DAY 3: FULL BODY ============
    StretchRoutine(
      id: 'default_routine_5',
      name: 'Full Body Pre-Workout Warm-up',
      description: 'Complete dynamic warm-up combining upper and lower body prep for full body training',
      colorHex: 'AB47BC',
      stretches: [
        // Upper body dynamic
        RoutineStretch(savedStretchId: 'default_stretch_1', order: 0, overrideDuration: 25), // Arm Circles Forward
        RoutineStretch(savedStretchId: 'default_stretch_2', order: 1, overrideDuration: 25), // Arm Circles Backward
        RoutineStretch(savedStretchId: 'default_stretch_3', order: 2, overrideDuration: 20), // Shoulder Rolls
        RoutineStretch(savedStretchId: 'default_stretch_4', order: 3, overrideDuration: 25), // Torso Twists
        RoutineStretch(savedStretchId: 'default_stretch_5', order: 4, overrideDuration: 25), // Arm Swings
        // Lower body dynamic
        RoutineStretch(savedStretchId: 'default_stretch_14', order: 5, notes: '15 seconds each leg'), // Leg Swings F-B
        RoutineStretch(savedStretchId: 'default_stretch_15', order: 6, notes: '15 seconds each leg'), // Leg Swings S-S
        RoutineStretch(savedStretchId: 'default_stretch_18', order: 7, overrideDuration: 25), // Hip Circles
        RoutineStretch(savedStretchId: 'default_stretch_17', order: 8, overrideDuration: 35, notes: '10-12 steps'), // Walking Lunges
        RoutineStretch(savedStretchId: 'default_stretch_19', order: 9, notes: '8-10 slow reps'), // BW Squats
      ],
    ),
    StretchRoutine(
      id: 'default_routine_6',
      name: 'Full Body Post-Workout Cooldown',
      description: 'Complete static stretch routine combining upper and lower body recovery',
      colorHex: 'EC407A',
      stretches: [
        // Upper body static
        RoutineStretch(savedStretchId: 'default_stretch_7', order: 0, overrideDuration: 40), // Child's Pose
        RoutineStretch(savedStretchId: 'default_stretch_8', order: 1, overrideDuration: 35, notes: '5-6 slow cycles'), // Cat-Cow
        RoutineStretch(savedStretchId: 'default_stretch_10', order: 2, notes: '30 seconds each side'), // Doorway Pec
        RoutineStretch(savedStretchId: 'default_stretch_12', order: 3, notes: '15 seconds each arm'), // Cross-Body Shoulder
        // Lower body static
        RoutineStretch(savedStretchId: 'default_stretch_20', order: 4, notes: '30 seconds each leg'), // Quad Stretch
        RoutineStretch(savedStretchId: 'default_stretch_21', order: 5, overrideDuration: 40, notes: '40 seconds each side'), // Hip Flexor
        RoutineStretch(savedStretchId: 'default_stretch_23', order: 6, overrideDuration: 40, notes: '40 seconds each side'), // Figure-4
        RoutineStretch(savedStretchId: 'default_stretch_24', order: 7, overrideDuration: 40, notes: 'Gentle stretch only'), // Forward Fold
        RoutineStretch(savedStretchId: 'default_stretch_25', order: 8, notes: 'Both knees together'), // Knee-to-Chest
      ],
    ),
  ];
}
