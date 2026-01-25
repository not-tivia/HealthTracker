import 'package:hive/hive.dart';

part 'checklist_item.g.dart';

@HiveType(typeId: 5)
class ChecklistItem extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  int order;

  @HiveField(3)
  bool isActive;

  @HiveField(4)
  String? category; // AM, PM, Anytime

  @HiveField(5)
  String? icon; // Emoji string

  /// Scheduled time stored as minutes from midnight (e.g., 8:30 AM = 510)
  /// Used for ordering and notifications
  @HiveField(6)
  int? scheduledTimeMinutes;

  /// Whether notifications are enabled for this specific item
  @HiveField(7)
  bool notificationEnabled;

  ChecklistItem({
    required this.id,
    required this.name,
    required this.order,
    this.isActive = true,
    this.category = 'Anytime',
    this.icon,
    this.scheduledTimeMinutes,
    this.notificationEnabled = false,
  });

  /// Get the scheduled time as a formatted string (e.g., "8:30 AM")
  String? get scheduledTimeDisplay {
    if (scheduledTimeMinutes == null) return null;
    final hours = scheduledTimeMinutes! ~/ 60;
    final minutes = scheduledTimeMinutes! % 60;
    final period = hours >= 12 ? 'PM' : 'AM';
    final displayHours = hours == 0 ? 12 : (hours > 12 ? hours - 12 : hours);
    return '${displayHours.toString()}:${minutes.toString().padLeft(2, '0')} $period';
  }

  /// Get sorting priority based on category and scheduled time
  int get sortPriority {
    // If has scheduled time, use that for sorting
    if (scheduledTimeMinutes != null) {
      return scheduledTimeMinutes!;
    }
    // Otherwise sort by category: AM (0-479), Anytime (480-959), PM (960-1439)
    switch (category) {
      case 'AM':
        return 360 + order; // 6 AM base + order offset
      case 'Anytime':
        return 720 + order; // 12 PM base + order offset
      case 'PM':
        return 1080 + order; // 6 PM base + order offset
      default:
        return 720 + order;
    }
  }

  ChecklistItem copyWith({
    String? id,
    String? name,
    int? order,
    bool? isActive,
    String? category,
    String? icon,
    int? scheduledTimeMinutes,
    bool? notificationEnabled,
  }) {
    return ChecklistItem(
      id: id ?? this.id,
      name: name ?? this.name,
      order: order ?? this.order,
      isActive: isActive ?? this.isActive,
      category: category ?? this.category,
      icon: icon ?? this.icon,
      scheduledTimeMinutes: scheduledTimeMinutes ?? this.scheduledTimeMinutes,
      notificationEnabled: notificationEnabled ?? this.notificationEnabled,
    );
  }
}

// Default checklist items with proper emoji icons using Unicode escapes
class DefaultChecklistItems {
  static List<ChecklistItem> get items => [
    ChecklistItem(
      id: 'default_1',
      name: 'Brush teeth AM',
      order: 0,
      category: 'AM',
      icon: '\u{1FAA5}', // 🪥 Toothbrush
      scheduledTimeMinutes: 420, // 7:00 AM
      notificationEnabled: false,
    ),
    ChecklistItem(
      id: 'default_2',
      name: 'Multivitamins',
      order: 1,
      category: 'AM',
      icon: '\u{1F48A}', // 💊 Pill
      scheduledTimeMinutes: 480, // 8:00 AM
      notificationEnabled: false,
    ),
    ChecklistItem(
      id: 'default_3',
      name: 'Creatine',
      order: 2,
      category: 'Anytime',
      icon: '\u{1F4AA}', // 💪 Flexed biceps
      scheduledTimeMinutes: null,
      notificationEnabled: false,
    ),
    ChecklistItem(
      id: 'default_4',
      name: 'Drink 8 glasses of water',
      order: 3,
      category: 'Anytime',
      icon: '\u{1F4A7}', // 💧 Water droplet
      scheduledTimeMinutes: null,
      notificationEnabled: false,
    ),
    ChecklistItem(
      id: 'default_5',
      name: 'Skin care routine',
      order: 4,
      category: 'PM',
      icon: '\u{2728}', // ✨ Sparkles
      scheduledTimeMinutes: 1260, // 9:00 PM
      notificationEnabled: false,
    ),
    ChecklistItem(
      id: 'default_6',
      name: 'Brush teeth PM',
      order: 5,
      category: 'PM',
      icon: '\u{1FAA5}', // 🪥 Toothbrush
      scheduledTimeMinutes: 1290, // 9:30 PM
      notificationEnabled: false,
    ),
    ChecklistItem(
      id: 'default_7',
      name: 'Stretch / Mobility',
      order: 6,
      category: 'Anytime',
      icon: '\u{1F9D8}', // 🧘 Person in lotus position
      scheduledTimeMinutes: null,
      notificationEnabled: false,
    ),
    ChecklistItem(
      id: 'default_8',
      name: 'Read for 20 minutes',
      order: 7,
      category: 'PM',
      icon: '\u{1F4DA}', // 📚 Books
      scheduledTimeMinutes: 1320, // 10:00 PM
      notificationEnabled: false,
    ),
  ];
}
