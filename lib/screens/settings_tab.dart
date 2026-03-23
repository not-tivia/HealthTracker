import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/checklist_item.dart';
import '../models/user_settings.dart';
import '../models/saved_exercise.dart';
import '../models/workout_routine.dart';
import '../models/saved_stretch.dart';
import '../models/stretch_routine.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../services/routine_import_export_service.dart';
import '../theme/app_theme.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  UserSettings? _settings;
  List<ChecklistItem> _checklistItems = [];
  List<SavedExercise> _exercises = [];
  List<WorkoutRoutine> _routines = [];
  List<SavedStretch> _stretches = [];
  List<StretchRoutine> _stretchRoutines = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final storage = context.read<StorageService>();
    final settings = await storage.getUserSettings();
    final items = storage.getChecklistItems();
    final exercises = storage.getAllSavedExercises();
    final routines = storage.getAllWorkoutRoutines();
    final stretches = storage.getAllSavedStretches();
    final stretchRoutines = storage.getAllStretchRoutines();

    setState(() {
      _settings = settings;
      _checklistItems = items;
      _exercises = exercises;
      _routines = routines;
      _stretches = stretches;
      _stretchRoutines = stretchRoutines;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Profile'),
            _buildProfileSection(),
            const SizedBox(height: 24),
            _buildSectionHeader('Goals'),
            _buildGoalsSection(),
            const SizedBox(height: 24),
            _buildSectionHeader('Workout Rotation'),
            _buildRotationSection(),
            const SizedBox(height: 24),
            _buildSectionHeader('Daily Checklist'),
            _buildChecklistSection(),
            const SizedBox(height: 24),
            _buildSectionHeader('Preferences'),
            _buildPreferencesSection(),
            const SizedBox(height: 24),
            _buildSectionHeader('Data'),
            _buildDataSection(),
            const SizedBox(height: 32),
            _buildAppInfo(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildProfileSection() {
    final latestWeight = context.read<StorageService>().getLatestWeightEntry();
    
    return Card(
      child: Column(
        children: [
          // Gender
          ListTile(
            leading: Icon(
              _settings?.gender == 'male' ? Icons.male : 
              _settings?.gender == 'female' ? Icons.female : Icons.person,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: const Text('Gender'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _settings?.gender?.capitalize() ?? 'Not set',
                  style: TextStyle(color: Colors.grey.shade400),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, size: 20, color: Colors.grey.shade500),
              ],
            ),
            onTap: _showGenderDialog,
          ),
          const Divider(height: 1),
          // Weight (synced from progress tab)
          ListTile(
            leading: Icon(Icons.monitor_weight, color: Theme.of(context).colorScheme.primary),
            title: const Text('Weight'),
            subtitle: latestWeight != null 
                ? Text('Last logged: ${latestWeight.weight} ${latestWeight.unit}', 
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500))
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _settings?.weightDisplay ?? '--',
                  style: TextStyle(color: Colors.grey.shade400),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, size: 20, color: Colors.grey.shade500),
              ],
            ),
            onTap: _showWeightDialog,
          ),
          const Divider(height: 1),
          // Height
          ListTile(
            leading: Icon(Icons.height, color: Theme.of(context).colorScheme.primary),
            title: const Text('Height'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _settings?.heightDisplay ?? '--',
                  style: TextStyle(color: Colors.grey.shade400),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, size: 20, color: Colors.grey.shade500),
              ],
            ),
            onTap: _showHeightDialog,
          ),
          const Divider(height: 1),
          // Water Goal
          ListTile(
            leading: Icon(Icons.water_drop, color: AppTheme.secondaryColor),
            title: const Text('Daily Water Goal'),
            subtitle: Text(
              'Recommended: ${_settings?.recommendedWaterGoal ?? 92} oz based on gender',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatWaterGoal(_settings?.dailyWaterGoalOz ?? 92),
                  style: TextStyle(color: Colors.grey.shade400),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, size: 20, color: Colors.grey.shade500),
              ],
            ),
            onTap: _showWaterGoalDialog,
          ),
        ],
      ),
    );
  }

  String _formatWaterGoal(int oz) {
    if (_settings?.useMetric == true) {
      final ml = (oz * 29.5735).round();
      return '$ml ml';
    }
    return '$oz oz';
  }

  void _showGenderDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Gender'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.male, color: Colors.blue),
              title: const Text('Male'),
              trailing: _settings?.gender == 'male' 
                  ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                  : null,
              onTap: () async {
                await context.read<StorageService>().updateWaterGoalForGender('male');
                await _loadData();
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.female, color: Colors.pink),
              title: const Text('Female'),
              trailing: _settings?.gender == 'female' 
                  ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                  : null,
              onTap: () async {
                await context.read<StorageService>().updateWaterGoalForGender('female');
                await _loadData();
                Navigator.pop(context);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showWeightDialog() {
    final controller = TextEditingController(
      text: _settings?.userWeight?.toStringAsFixed(1) ?? '',
    );
    final unit = _settings?.weightUnit ?? 'lbs';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Weight'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Weight',
            suffixText: unit,
            hintText: 'e.g., 165.5',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final weight = double.tryParse(controller.text);
              if (weight != null && weight > 0) {
                _settings = _settings?.copyWith(userWeight: weight);
                if (_settings != null) {
                  await context.read<StorageService>().saveUserSettings(_settings!);
                }
                setState(() {});
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showHeightDialog() {
    if (_settings?.useMetric == true) {
      _showHeightDialogMetric();
    } else {
      _showHeightDialogImperial();
    }
  }

  void _showHeightDialogImperial() {
    int feet = 5;
    int inches = 8;
    
    if (_settings?.userHeight != null) {
      feet = (_settings!.userHeight! / 12).floor();
      inches = (_settings!.userHeight! % 12).round();
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Enter Height'),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Feet picker
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: feet < 8 ? () => setDialogState(() => feet++) : null,
                    icon: const Icon(Icons.keyboard_arrow_up),
                  ),
                  Text(
                    '$feet',
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: feet > 3 ? () => setDialogState(() => feet--) : null,
                    icon: const Icon(Icons.keyboard_arrow_down),
                  ),
                  const Text('feet'),
                ],
              ),
              const SizedBox(width: 24),
              // Inches picker
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: inches < 11 ? () => setDialogState(() => inches++) : null,
                    icon: const Icon(Icons.keyboard_arrow_up),
                  ),
                  Text(
                    '$inches',
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: inches > 0 ? () => setDialogState(() => inches--) : null,
                    icon: const Icon(Icons.keyboard_arrow_down),
                  ),
                  const Text('inches'),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final totalInches = (feet * 12 + inches).toDouble();
                _settings = _settings?.copyWith(userHeight: totalInches);
                if (_settings != null) {
                  await context.read<StorageService>().saveUserSettings(_settings!);
                }
                setState(() {});
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showHeightDialogMetric() {
    final controller = TextEditingController(
      text: _settings?.userHeight?.toStringAsFixed(0) ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Height'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Height',
            suffixText: 'cm',
            hintText: 'e.g., 175',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final height = double.tryParse(controller.text);
              if (height != null && height > 0) {
                _settings = _settings?.copyWith(userHeight: height);
                if (_settings != null) {
                  await context.read<StorageService>().saveUserSettings(_settings!);
                }
                setState(() {});
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showWaterGoalDialog() {
    int goal = _settings?.dailyWaterGoalOz ?? 92;
    final useMetric = _settings?.useMetric ?? false;
    final recommended = _settings?.recommendedWaterGoal ?? 92;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Daily Water Goal'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                useMetric ? '${(goal * 29.5735).round()} ml' : '$goal oz',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.secondaryColor,
                ),
              ),
              const SizedBox(height: 16),
              Slider(
                value: goal.toDouble(),
                min: 32,
                max: 200,
                divisions: 168,
                activeColor: AppTheme.secondaryColor,
                onChanged: (value) => setDialogState(() => goal = value.round()),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => setDialogState(() => goal = recommended),
                child: Text('Use recommended ($recommended oz)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                _settings = _settings?.copyWith(dailyWaterGoalOz: goal);
                if (_settings != null) {
                  await context.read<StorageService>().saveUserSettings(_settings!);
                }
                setState(() {});
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalsSection() {
    return Card(
      child: Column(
        children: [
          _buildGoalTile(
            'Weekly Workouts',
            '${_settings?.weeklyWorkoutGoal ?? 4} per week',
            Icons.fitness_center,
            () => _showEditGoalDialog('workout'),
          ),
          const Divider(height: 1),
          _buildGoalTile(
            'Daily Steps',
            '${_settings?.dailyStepGoal ?? 10000} steps',
            Icons.directions_walk,
            () => _showEditGoalDialog('steps'),
          ),
          const Divider(height: 1),
          _buildGoalTile(
            'Daily Calories',
            '${_settings?.dailyCalorieGoal ?? 2000} cal',
            Icons.local_fire_department,
            () => _showEditGoalDialog('calories'),
          ),
          const Divider(height: 1),
          _buildGoalTile(
            'Daily Protein',
            '${_settings?.dailyProteinGoal ?? 150}g',
            Icons.egg,
            () => _showEditGoalDialog('protein'),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalTile(
    String title,
    String value,
    IconData icon,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey.shade400),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right, size: 20, color: Colors.grey.shade500),
        ],
      ),
      onTap: onTap,
    );
  }

  Widget _buildChecklistSection() {
    return Card(
      child: Column(
        children: [
          ..._checklistItems.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return Column(
              children: [
                if (index > 0) const Divider(height: 1),
                _buildChecklistItemTile(item, index),
              ],
            );
          }),
          const Divider(height: 1),
          ListTile(
            leading: Icon(
              Icons.add_circle_outline,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: const Text('Add Item'),
            onTap: () => _showAddChecklistItemDialog(),
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistItemTile(ChecklistItem item, int index) {
    // Category icons map
    final categoryIcons = {
      'AM': Icons.wb_sunny,
      'PM': Icons.nightlight_round,
      'Anytime': Icons.access_time,
    };

    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: _buildItemIcon(item, categoryIcons),
        ),
      ),
      title: Text(
        item.name,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Row(
        children: [
          Text(
            item.category ?? 'Anytime',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
          if (item.scheduledTimeMinutes != null) ...[
            const SizedBox(width: 8),
            Icon(Icons.schedule, size: 12, color: Colors.grey.shade500),
            const SizedBox(width: 2),
            Text(
              item.scheduledTimeDisplay ?? '',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ],
          if (item.notificationEnabled) ...[
            const SizedBox(width: 8),
            Icon(Icons.notifications_active, size: 12, color: Theme.of(context).colorScheme.primary),
          ],
        ],
      ),
      trailing: PopupMenuButton<String>(
        icon: Icon(Icons.more_vert, color: Colors.grey.shade500),
        onSelected: (value) {
          switch (value) {
            case 'edit':
              _showEditChecklistItemDialog(item);
              break;
            case 'up':
              if (index > 0) _reorderItem(index, index - 1);
              break;
            case 'down':
              if (index < _checklistItems.length - 1) _reorderItem(index, index + 1);
              break;
            case 'delete':
              _confirmDeleteItem(item);
              break;
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(value: 'edit', child: Text('Edit')),
          if (index > 0) const PopupMenuItem(value: 'up', child: Text('Move Up')),
          if (index < _checklistItems.length - 1) const PopupMenuItem(value: 'down', child: Text('Move Down')),
          PopupMenuItem(
            value: 'delete',
            child: Text('Delete', style: TextStyle(color: Colors.red.shade400)),
          ),
        ],
      ),
      onTap: () => _showEditChecklistItemDialog(item),
    );
  }

  /// Safely build the icon - handles both emoji strings and prevents int.parse crash
  Widget _buildItemIcon(ChecklistItem item, Map<String, IconData> categoryIcons) {
    // If icon is an emoji string, display it as text
    if (item.icon != null && item.icon!.isNotEmpty) {
      // Check if it's an emoji (not a number string)
      final isNumeric = int.tryParse(item.icon!) != null;
      if (!isNumeric) {
        // It's an emoji, display as text
        return Text(
          item.icon!,
          style: const TextStyle(fontSize: 18),
        );
      } else {
        // It's a numeric icon code (Material Icons)
        return Icon(
          IconData(int.parse(item.icon!), fontFamily: 'MaterialIcons'),
          color: Colors.grey.shade400,
          size: 20,
        );
      }
    }
    
    // Fallback to category icon
    return Icon(
      categoryIcons[item.category ?? 'Anytime'] ?? Icons.check_circle_outline,
      color: Colors.grey.shade400,
      size: 20,
    );
  }

  Widget _buildPreferencesSection() {
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.scale),
            title: const Text('Use Metric Units'),
            subtitle: const Text('kg instead of lbs, ml instead of oz'),
            value: _settings?.useMetric ?? false,
            onChanged: (value) async {
              setState(() {
                _settings = _settings?.copyWith(
                  useMetric: value,
                  weightUnit: value ? 'kg' : 'lbs',
                );
              });
              if (_settings != null) {
                await context.read<StorageService>().saveUserSettings(_settings!);
              }
            },
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: const Icon(Icons.notifications),
            title: const Text('Reminder Notifications'),
            subtitle: const Text('Daily self-care reminders'),
            value: _settings?.notificationsEnabled ?? true,
            onChanged: (value) async {
              if (value) {
                // Request permission when enabling
                final notificationService = NotificationService();
                final granted = await notificationService.requestPermissions();
                if (!granted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enable notifications in system settings')),
                  );
                  return;
                }
              }
              setState(() => _settings = _settings?.copyWith(notificationsEnabled: value));
              if (_settings != null) {
                await context.read<StorageService>().saveUserSettings(_settings!);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDataSection() {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.backup, color: Theme.of(context).colorScheme.primary),
            title: const Text('Export Data'),
            subtitle: const Text('Save a backup of your data'),
            onTap: () => _exportData(),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.download, color: Colors.blue.shade400),
            title: const Text('Import Routine'),
            subtitle: const Text('Import a workout or stretch routine'),
            onTap: () => _showImportRoutineDialog(),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.upload, color: Colors.green.shade400),
            title: const Text('Export Routine'),
            subtitle: const Text('Share a routine with others'),
            onTap: () => _showExportRoutineDialog(),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.delete_sweep, color: Colors.orange.shade400),
            title: const Text('Clear Food History'),
            subtitle: const Text('Remove all logged meals'),
            onTap: () => _confirmClearData('food'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.delete_forever, color: Colors.red.shade400),
            title: const Text('Reset All Data'),
            subtitle: const Text('Delete everything and start fresh'),
            onTap: () => _confirmClearData('all'),
          ),
        ],
      ),
    );
  }

  Widget _buildAppInfo() {
    return Center(
      child: Column(
        children: [
          Text(
            'Health Tracker',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Version 1.0.0',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.favorite, size: 14, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(
                'Made with Flutter',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showEditGoalDialog(String goalType) {
    int value = 0;
    String title = '';
    String unit = '';
    int min = 1;
    int max = 100;
    int step = 1;

    switch (goalType) {
      case 'workout':
        value = _settings?.weeklyWorkoutGoal ?? 4;
        title = 'Weekly Workout Goal';
        unit = 'workouts/week';
        min = 1;
        max = 7;
        break;
      case 'steps':
        value = _settings?.dailyStepGoal ?? 10000;
        title = 'Daily Step Goal';
        unit = 'steps';
        min = 1000;
        max = 30000;
        step = 1000;
        break;
      case 'calories':
        value = _settings?.dailyCalorieGoal ?? 2000;
        title = 'Daily Calorie Goal';
        unit = 'calories';
        min = 1000;
        max = 5000;
        step = 100;
        break;
      case 'protein':
        value = _settings?.dailyProteinGoal ?? 150;
        title = 'Daily Protein Goal';
        unit = 'grams';
        min = 50;
        max = 300;
        step = 10;
        break;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$value',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              Text(
                unit,
                style: TextStyle(color: Colors.grey.shade400),
              ),
              const SizedBox(height: 24),
              Slider(
                value: value.toDouble(),
                min: min.toDouble(),
                max: max.toDouble(),
                divisions: ((max - min) / step).round(),
                label: '$value',
                onChanged: (newValue) {
                  setDialogState(() => value = newValue.round());
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              switch (goalType) {
                case 'workout':
                  _settings = _settings?.copyWith(weeklyWorkoutGoal: value);
                  break;
                case 'steps':
                  _settings = _settings?.copyWith(dailyStepGoal: value);
                  break;
                case 'calories':
                  _settings = _settings?.copyWith(dailyCalorieGoal: value);
                  break;
                case 'protein':
                  _settings = _settings?.copyWith(dailyProteinGoal: value);
                  break;
              }
              
              if (_settings != null) {
                await context.read<StorageService>().saveUserSettings(_settings!);
              }
              
              setState(() {});
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddChecklistItemDialog() {
    final nameController = TextEditingController();
    String category = 'Anytime';
    String selectedEmoji = 'âœ…';
    TimeOfDay? scheduledTime;
    bool notificationEnabled = false;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Checklist Item'),
        content: StatefulBuilder(
          builder: (context, setDialogState) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Item Name',
                    hintText: 'e.g., Take vitamins',
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                
                // Emoji picker
                Text('Icon', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['âœ…', 'ðŸ’Š', 'ðŸ’ª', 'ðŸ’§', 'ðŸª¥', 'âœ¨', 'ðŸ§˜', 'ðŸ“š', 'ðŸƒ', 'ðŸ¥—', 'ðŸ˜´', 'ðŸŽ¯']
                      .map((emoji) => GestureDetector(
                            onTap: () => setDialogState(() => selectedEmoji = emoji),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: selectedEmoji == emoji
                                    ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                                    : Colors.grey.shade800,
                                borderRadius: BorderRadius.circular(8),
                                border: selectedEmoji == emoji
                                    ? Border.all(color: Theme.of(context).colorScheme.primary)
                                    : null,
                              ),
                              child: Text(emoji, style: const TextStyle(fontSize: 20)),
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 16),
                
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: ['AM', 'PM', 'Anytime'].map((c) => DropdownMenuItem(
                    value: c,
                    child: Text(c),
                  )).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => category = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                
                // Scheduled time picker
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule),
                  title: Text(
                    scheduledTime != null 
                        ? 'Scheduled: ${scheduledTime!.format(context)}'
                        : 'Set reminder time (optional)',
                  ),
                  trailing: scheduledTime != null
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setDialogState(() => scheduledTime = null),
                        )
                      : null,
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: scheduledTime ?? TimeOfDay.now(),
                    );
                    if (time != null) {
                      setDialogState(() => scheduledTime = time);
                    }
                  },
                ),
                
                // Notification toggle (only if time is set)
                if (scheduledTime != null)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enable notification'),
                    subtitle: const Text('Get reminded at this time'),
                    value: notificationEnabled,
                    onChanged: (value) => setDialogState(() => notificationEnabled = value),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;

              // Convert TimeOfDay to minutes from midnight
              int? timeMinutes;
              if (scheduledTime != null) {
                timeMinutes = scheduledTime!.hour * 60 + scheduledTime!.minute;
              }

              final item = ChecklistItem(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: nameController.text.trim(),
                category: category,
                order: _checklistItems.length,
                icon: selectedEmoji,
                scheduledTimeMinutes: timeMinutes,
                notificationEnabled: notificationEnabled && timeMinutes != null,
              );

              await context.read<StorageService>().saveChecklistItem(item);
              
              // Schedule notification if enabled
              if (item.notificationEnabled) {
                final notificationService = NotificationService();
                await notificationService.scheduleChecklistNotification(item);
              }
              
              _loadData();
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditChecklistItemDialog(ChecklistItem item) {
    final nameController = TextEditingController(text: item.name);
    String category = item.category ?? 'Anytime';
    String selectedEmoji = item.icon ?? 'âœ…';
    TimeOfDay? scheduledTime;
    bool notificationEnabled = item.notificationEnabled;
    
    // Convert stored minutes to TimeOfDay
    if (item.scheduledTimeMinutes != null) {
      final hours = item.scheduledTimeMinutes! ~/ 60;
      final minutes = item.scheduledTimeMinutes! % 60;
      scheduledTime = TimeOfDay(hour: hours, minute: minutes);
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Checklist Item'),
        content: StatefulBuilder(
          builder: (context, setDialogState) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Item Name'),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                
                // Emoji picker
                Text('Icon', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['âœ…', 'ðŸ’Š', 'ðŸ’ª', 'ðŸ’§', 'ðŸª¥', 'âœ¨', 'ðŸ§˜', 'ðŸ“š', 'ðŸƒ', 'ðŸ¥—', 'ðŸ˜´', 'ðŸŽ¯']
                      .map((emoji) => GestureDetector(
                            onTap: () => setDialogState(() => selectedEmoji = emoji),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: selectedEmoji == emoji
                                    ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                                    : Colors.grey.shade800,
                                borderRadius: BorderRadius.circular(8),
                                border: selectedEmoji == emoji
                                    ? Border.all(color: Theme.of(context).colorScheme.primary)
                                    : null,
                              ),
                              child: Text(emoji, style: const TextStyle(fontSize: 20)),
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 16),
                
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: ['AM', 'PM', 'Anytime'].map((c) => DropdownMenuItem(
                    value: c,
                    child: Text(c),
                  )).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => category = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                
                // Scheduled time picker
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule),
                  title: Text(
                    scheduledTime != null 
                        ? 'Scheduled: ${scheduledTime!.format(context)}'
                        : 'Set reminder time (optional)',
                  ),
                  trailing: scheduledTime != null
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setDialogState(() {
                            scheduledTime = null;
                            notificationEnabled = false;
                          }),
                        )
                      : null,
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: scheduledTime ?? TimeOfDay.now(),
                    );
                    if (time != null) {
                      setDialogState(() => scheduledTime = time);
                    }
                  },
                ),
                
                // Notification toggle (only if time is set)
                if (scheduledTime != null)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enable notification'),
                    subtitle: const Text('Get reminded at this time'),
                    value: notificationEnabled,
                    onChanged: (value) => setDialogState(() => notificationEnabled = value),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;

              // Convert TimeOfDay to minutes from midnight
              int? timeMinutes;
              if (scheduledTime != null) {
                timeMinutes = scheduledTime!.hour * 60 + scheduledTime!.minute;
              }

              item.name = nameController.text.trim();
              item.category = category;
              item.icon = selectedEmoji;
              item.scheduledTimeMinutes = timeMinutes;
              item.notificationEnabled = notificationEnabled && timeMinutes != null;

              await context.read<StorageService>().saveChecklistItem(item);
              
              // Update notification
              final notificationService = NotificationService();
              if (item.notificationEnabled) {
                await notificationService.scheduleChecklistNotification(item);
              } else {
                await notificationService.cancelChecklistNotification(item);
              }
              
              _loadData();
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _reorderItem(int oldIndex, int newIndex) async {
    setState(() {
      final item = _checklistItems.removeAt(oldIndex);
      _checklistItems.insert(newIndex, item);
      
      // Update order values
      for (int i = 0; i < _checklistItems.length; i++) {
        _checklistItems[i].order = i;
      }
    });

    final storage = context.read<StorageService>();
    for (final item in _checklistItems) {
      await storage.saveChecklistItem(item);
    }
  }

  void _confirmDeleteItem(ChecklistItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item?'),
        content: Text('Remove "${item.name}" from your checklist?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              // Cancel any notifications for this item
              final notificationService = NotificationService();
              await notificationService.cancelChecklistNotification(item);
              
              await context.read<StorageService>().deleteChecklistItem(item.id);
              _loadData();
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade400,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _exportData() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Export feature coming soon!'),
      ),
    );
  }

  void _confirmClearData(String type) {
    final title = type == 'all' ? 'Reset All Data?' : 'Clear Food History?';
    final message = type == 'all'
        ? 'This will delete all workouts, weight entries, food logs, water logs, and settings. This cannot be undone.'
        : 'This will delete all logged meals. This cannot be undone.';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final storage = context.read<StorageService>();
              
              if (type == 'all') {
                // Cancel all notifications
                final notificationService = NotificationService();
                await notificationService.cancelAllNotifications();
                
                await storage.clearAllData();
                await _loadData();
              } else {
                await storage.clearFoodHistory();
              }

              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(type == 'all' ? 'All data cleared' : 'Food history cleared'),
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade400,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  // ============ IMPORT/EXPORT ROUTINES ============

  void _showImportRoutineDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Import Routine',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.folder_open, color: AppTheme.primaryColor),
                ),
                title: const Text('Choose File'),
                subtitle: const Text('Select a .json file'),
                onTap: () async {
                  Navigator.pop(context);
                  await _importFromFile();
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.content_paste, color: Colors.blue),
                ),
                title: const Text('Paste JSON'),
                subtitle: const Text('Paste routine data'),
                onTap: () {
                  Navigator.pop(context);
                  _showPasteJsonDialog();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _importFromFile() async {
    final jsonString = await RoutineImportExportService.pickJsonFile();
    if (jsonString == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No file selected')),
        );
      }
      return;
    }
    await _processImportJson(jsonString);
  }

  void _showPasteJsonDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Paste Routine JSON'),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: controller,
            maxLines: 10,
            decoration: InputDecoration(
              hintText: 'Paste your routine JSON here...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              if (controller.text.trim().isNotEmpty) {
                _processImportJson(controller.text.trim());
              }
            },
            child: const Text('Import'),
          ),
        ],
      ),
    );
  }

  Future<void> _processImportJson(String jsonString) async {
    final storage = context.read<StorageService>();
    final preview = RoutineImportExportService.parseImportJson(
      jsonString,
      _exercises,
      _stretches,
    );

    if (preview.hasError) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(preview.error!),
            backgroundColor: Colors.red.shade400,
          ),
        );
      }
      return;
    }

    if (mounted) {
      _showImportPreviewDialog(preview, storage);
    }
  }

  void _showImportPreviewDialog(ImportPreview preview, StorageService storage) {
    final nameController = TextEditingController(text: preview.routineName);
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            preview.isWorkoutRoutine ? 'Import Workout Routine' : 'Import Stretch Routine',
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Routine Name:', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (preview.isWorkoutRoutine) ...[
                    Text(
                      '${preview.exercises.length} exercises:',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    ...preview.exercises.map((e) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Icon(
                            e.existsLocally ? Icons.check_circle : Icons.add_circle,
                            size: 16,
                            color: e.existsLocally ? Colors.green : AppTheme.primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              e.name,
                              style: TextStyle(
                                color: e.existsLocally ? Colors.grey.shade400 : Colors.white,
                              ),
                            ),
                          ),
                          if (!e.existsLocally)
                            Text(
                              '(new)',
                              style: TextStyle(color: AppTheme.primaryColor, fontSize: 12),
                            ),
                        ],
                      ),
                    )),
                    const SizedBox(height: 12),
                    if (preview.existingExerciseCount > 0)
                      Text(
                        '${preview.existingExerciseCount} exercises already exist.',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                      ),
                    if (preview.newExerciseCount > 0)
                      Text(
                        '${preview.newExerciseCount} new exercises will be created.',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                      ),
                  ] else ...[
                    Text(
                      '${preview.stretches.length} stretches:',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    ...preview.stretches.map((s) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Icon(
                            s.existsLocally ? Icons.check_circle : Icons.add_circle,
                            size: 16,
                            color: s.existsLocally ? Colors.green : AppTheme.primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              s.name,
                              style: TextStyle(
                                color: s.existsLocally ? Colors.grey.shade400 : Colors.white,
                              ),
                            ),
                          ),
                          if (!s.existsLocally)
                            Text(
                              '(new)',
                              style: TextStyle(color: AppTheme.primaryColor, fontSize: 12),
                            ),
                        ],
                      ),
                    )),
                    const SizedBox(height: 12),
                    if (preview.existingStretchCount > 0)
                      Text(
                        '${preview.existingStretchCount} stretches already exist.',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                      ),
                    if (preview.newStretchCount > 0)
                      Text(
                        '${preview.newStretchCount} new stretches will be created.',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                      ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(context);
                final error = await RoutineImportExportService.executeImport(
                  preview,
                  nameController.text.trim(),
                  storage,
                );
                if (mounted) {
                  if (error == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Imported "${nameController.text.trim()}" successfully'),
                        backgroundColor: Colors.green.shade400,
                      ),
                    );
                    _loadData();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(error), backgroundColor: Colors.red.shade400),
                    );
                  }
                }
              },
              child: const Text('Import'),
            ),
          ],
        ),
      ),
    );
  }

  void _showExportRoutineDialog() {
    if (_routines.isEmpty && _stretchRoutines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No routines to export')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Routine to Export',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: [
                      if (_routines.isNotEmpty) ...[
                        Text(
                          'WORKOUT ROUTINES',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ..._routines.map((routine) => ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: routine.colorHex != null
                                  ? Color(int.parse('FF${routine.colorHex}', radix: 16)).withOpacity(0.2)
                                  : AppTheme.primaryColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.fitness_center, size: 20),
                          ),
                          title: Text(routine.name),
                          subtitle: Text('${routine.exercises.length} exercises'),
                          onTap: () {
                            Navigator.pop(context);
                            _showExportOptionsDialog(
                              routineName: routine.name,
                              jsonString: RoutineImportExportService.exportWorkoutRoutine(routine, _exercises),
                            );
                          },
                        )),
                        const SizedBox(height: 16),
                      ],
                      if (_stretchRoutines.isNotEmpty) ...[
                        Text(
                          'STRETCH ROUTINES',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ..._stretchRoutines.map((routine) => ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: routine.colorHex != null
                                  ? Color(int.parse('FF${routine.colorHex}', radix: 16)).withOpacity(0.2)
                                  : Colors.teal.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.self_improvement, size: 20),
                          ),
                          title: Text(routine.name),
                          subtitle: Text('${routine.stretches.length} stretches'),
                          onTap: () {
                            Navigator.pop(context);
                            _showExportOptionsDialog(
                              routineName: routine.name,
                              jsonString: RoutineImportExportService.exportStretchRoutine(routine, _stretches),
                            );
                          },
                        )),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showExportOptionsDialog({
    required String routineName,
    required String jsonString,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Export "$routineName"',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.share, color: Colors.blue),
                ),
                title: const Text('Share'),
                subtitle: const Text('Send via apps'),
                onTap: () async {
                  Navigator.pop(context);
                  await RoutineImportExportService.shareJson(jsonString, routineName);
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.save_alt, color: Colors.green),
                ),
                title: const Text('Save to Downloads'),
                subtitle: const Text('Save as .json file'),
                onTap: () async {
                  Navigator.pop(context);
                  final path = await RoutineImportExportService.saveToDownloads(jsonString, routineName);
                  if (mounted) {
                    if (path != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Saved to: ${path.split('/').last}'),
                          backgroundColor: Colors.green.shade400,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Failed to save file'),
                          backgroundColor: Colors.red.shade400,
                        ),
                      );
                    }
                  }
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.copy, color: Colors.purple),
                ),
                title: const Text('Copy to Clipboard'),
                subtitle: const Text('Copy raw JSON'),
                onTap: () async {
                  Navigator.pop(context);
                  await RoutineImportExportService.copyToClipboard(jsonString);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Copied to clipboard'),
                        backgroundColor: Colors.green.shade400,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRotationSection() {
    final storage = context.read<StorageService>();
    final rotationOrder = storage.getWorkoutRotationOrder();
    final allRoutines = storage.getAllWorkoutRoutines();

    final rotationRoutines = rotationOrder
        .map((id) => allRoutines.where((r) => r.id == id).firstOrNull)
        .where((r) => r != null)
        .cast<WorkoutRoutine>()
        .toList();

    final availableRoutines = allRoutines
        .where((r) => !rotationOrder.contains(r.id))
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          if (rotationRoutines.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'No routines in rotation. Add routines below.',
                style: TextStyle(color: AppTheme.textTertiary),
              ),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: rotationRoutines.length,
              onReorder: (oldIndex, newIndex) async {
                if (newIndex > oldIndex) newIndex--;
                final order = List<String>.from(rotationOrder);
                final item = order.removeAt(oldIndex);
                order.insert(newIndex, item);
                await storage.saveWorkoutRotationOrder(order);
                setState(() {});
              },
              itemBuilder: (context, index) {
                final routine = rotationRoutines[index];
                return Dismissible(
                  key: ValueKey(routine.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: AppTheme.accentColor,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    child: const Icon(Icons.remove_circle, color: Colors.white),
                  ),
                  onDismissed: (_) async {
                    final order = List<String>.from(rotationOrder)..remove(routine.id);
                    await storage.saveWorkoutRotationOrder(order);
                    setState(() {});
                  },
                  child: ListTile(
                    key: ValueKey(routine.id),
                    leading: Icon(Icons.drag_handle, color: AppTheme.textTertiary),
                    title: Text(routine.name, style: TextStyle(color: AppTheme.textPrimary)),
                    subtitle: _buildPairingDropdowns(routine, storage),
                  ),
                );
              },
            ),
          if (availableRoutines.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: OutlinedButton.icon(
                onPressed: () => _showAddToRotationSheet(availableRoutines, storage, rotationOrder),
                icon: const Icon(Icons.add),
                label: const Text('Add to Rotation'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPairingDropdowns(WorkoutRoutine routine, StorageService storage) {
    final pairing = storage.getStretchPairing(routine.id);
    final allStretches = storage.getAllStretchRoutines();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        Row(
          children: [
            Text('Warm-down: ', style: TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
            Expanded(
              child: DropdownButton<String?>(
                value: pairing?['warmDown'],
                isExpanded: true,
                underline: const SizedBox(),
                hint: Text('None', style: TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                dropdownColor: AppTheme.surfaceColor,
                items: [
                  const DropdownMenuItem(value: null, child: Text('None')),
                  ...allStretches.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))),
                ],
                onChanged: (id) async {
                  await storage.saveStretchPairing(
                    routine.id,
                    warmUpId: pairing?['warmUp'],
                    warmDownId: id,
                  );
                  setState(() {});
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showAddToRotationSheet(List<WorkoutRoutine> available, StorageService storage, List<String> currentOrder) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Add to Rotation', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          ...available.map((r) => ListTile(
            title: Text(r.name),
            trailing: const Icon(Icons.add_circle_outline),
            onTap: () async {
              final order = List<String>.from(currentOrder)..add(r.id);
              await storage.saveWorkoutRotationOrder(order);
              Navigator.pop(context);
              setState(() {});
            },
          )),
        ],
      ),
    );
  }
}

extension StringCapitalize on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
