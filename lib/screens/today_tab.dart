import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

import '../theme/app_theme.dart';
import '../services/storage_service.dart';
import '../services/step_tracking_service.dart';
import '../services/notification_service.dart';
import '../models/checklist_item.dart';
import '../models/food_entry.dart';
import '../models/water_entry.dart';
import '../models/food_library_item.dart';
import '../widgets/food_entry_dialog.dart';
import '../widgets/daily_history_dialog.dart';

class TodayTab extends StatefulWidget {
  const TodayTab({super.key});

  @override
  State<TodayTab> createState() => _TodayTabState();
}

class _TodayTabState extends State<TodayTab> {
  final Set<String> _quickAddDeleteMode = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StepTrackingService>().refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await context.read<StepTrackingService>().refresh();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                _buildStepsCard(),
                const SizedBox(height: 20),
                _buildWaterSection(),
                const SizedBox(height: 20),
                _buildChecklistSection(),
                const SizedBox(height: 20),
                _buildNutritionSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Today', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text(
                DateFormat('EEEE, MMMM d').format(DateTime.now()),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Calendar history button
            GestureDetector(
              onTap: () => _openDailyHistory(),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.calendar_month,
                  color: AppTheme.primaryColor,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Profile avatar
            CircleAvatar(
              radius: 22,
              backgroundColor: AppTheme.cardColor,
              child: Icon(Icons.person_outline, color: AppTheme.textSecondary, size: 22),
            ),
          ],
        ),
      ],
    );
  }

  void _openDailyHistory() {
    showDialog(
      context: context,
      useSafeArea: false,
      builder: (context) => const DailyHistoryDialog(),
    );
  }

  Widget _buildStepsCard() {
    return Consumer2<StepTrackingService, StorageService>(
      builder: (context, stepService, storage, _) {
        int steps = stepService.todaySteps;
        int pedometerSteps = stepService.pedometerSteps;
        int manualSteps = stepService.manualSteps;
        int goal = storage.settings.dailyStepGoal;
        double progress = (steps / goal).clamp(0.0, 1.0);
        final weeklyStatus = stepService.getWeeklyGoalStatus();
        final weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryColor.withOpacity(0.3),
                AppTheme.secondaryColor.withOpacity(0.2),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.directions_walk, color: AppTheme.textPrimary, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text('Steps', style: Theme.of(context).textTheme.titleMedium, overflow: TextOverflow.ellipsis),
                            ),
                            if (stepService.isTracking)
                              Icon(Icons.sensors, size: 16, color: AppTheme.successColor),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          NumberFormat('#,###').format(steps),
                          style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text('of ${NumberFormat('#,###').format(goal)} goal', style: Theme.of(context).textTheme.bodyMedium),
                        
                        // NEW: Show breakdown if there are manual cardio steps
                        if (manualSteps > 0) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _buildStepBreakdownChip(
                                Icons.sensors,
                                NumberFormat('#,###').format(pedometerSteps),
                                'Device',
                              ),
                              const SizedBox(width: 8),
                              _buildStepBreakdownChip(
                                Icons.fitness_center,
                                '+${NumberFormat('#,###').format(manualSteps)}',
                                'Cardio',
                              ),
                            ],
                          ),
                        ],
                        
                        if (stepService.errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              stepService.errorMessage!,
                              style: TextStyle(color: AppTheme.warningColor, fontSize: 12),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        if (!stepService.hasPermission)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: TextButton.icon(
                              onPressed: () => stepService.requestPermission(),
                              icon: const Icon(Icons.sensors, size: 18),
                              label: const Text('Enable Step Tracking'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.textPrimary,
                                backgroundColor: AppTheme.primaryColor.withOpacity(0.3),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  CircularPercentIndicator(
                    radius: 50,
                    lineWidth: 8,
                    percent: progress,
                    center: Text(
                      '${(progress * 100).toInt()}%',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    progressColor: AppTheme.primaryColor,
                    backgroundColor: AppTheme.cardColor,
                    circularStrokeCap: CircularStrokeCap.round,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(7, (index) {
                    final isToday = index == DateTime.now().weekday - 1;
                    final goalMet = weeklyStatus[index];
                    return Column(
                      children: [
                        Text(
                          weekdays[index],
                          style: TextStyle(
                            fontSize: 11,
                            color: isToday ? AppTheme.primaryColor : AppTheme.textTertiary,
                            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: goalMet 
                                ? AppTheme.successColor
                                : isToday
                                    ? AppTheme.primaryColor.withOpacity(0.3)
                                    : Colors.transparent,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isToday ? AppTheme.primaryColor : AppTheme.cardColorLight,
                              width: isToday ? 2 : 1,
                            ),
                          ),
                          child: goalMet
                              ? const Icon(Icons.check, size: 14, color: Colors.white)
                              : null,
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Helper widget to show step breakdown
  Widget _buildStepBreakdownChip(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppTheme.textTertiary),
          const SizedBox(width: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: AppTheme.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _buildWaterSection() {
    return Consumer<StorageService>(
      builder: (context, storage, _) {
        final waterIntake = storage.getDailyWaterIntake(DateTime.now());
        final useMetric = storage.settings.useMetric;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.water_drop, color: AppTheme.secondaryColor, size: 22),
                    const SizedBox(width: 8),
                    Text('Water', style: Theme.of(context).textTheme.titleLarge),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: waterIntake.goalReached
                        ? AppTheme.successColor.withOpacity(0.2)
                        : AppTheme.secondaryColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    waterIntake.goalReached
                        ? '\u{2713} Goal reached!'
                        : '${waterIntake.remainingDisplay(useMetric)} left',
                    style: TextStyle(
                      color: waterIntake.goalReached ? AppTheme.successColor : AppTheme.secondaryColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatWaterAmount(waterIntake.totalOz, useMetric),
                                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                                ),
                                Text(
                                  '/ ${_formatWaterAmount(waterIntake.goalOz, useMetric)}',
                                  style: TextStyle(color: AppTheme.textTertiary, fontSize: 14),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: waterIntake.progress,
                                backgroundColor: AppTheme.cardColorLight,
                                valueColor: AlwaysStoppedAnimation(
                                  waterIntake.goalReached ? AppTheme.successColor : AppTheme.secondaryColor,
                                ),
                                minHeight: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: WaterAmounts.quickAddOz.asMap().entries.map((entry) {
                      final index = entry.key;
                      final oz = entry.value;
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            left: index == 0 ? 0 : 4,
                            right: index == WaterAmounts.quickAddOz.length - 1 ? 0 : 4,
                          ),
                          child: _buildWaterQuickAddButton(oz, useMetric, storage),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showCustomWaterDialog(context, storage),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Custom Amount'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.secondaryColor,
                        side: BorderSide(color: AppTheme.secondaryColor.withOpacity(0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (waterIntake.entries.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Today\'s Log',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                        if (waterIntake.entries.length > 1)
                          InkWell(
                            onTap: () => _showClearWaterDialog(context, storage),
                            child: Text('Clear All', style: TextStyle(color: AppTheme.accentColor, fontSize: 12)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...waterIntake.entries.take(5).map((entry) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(Icons.water_drop_outlined, size: 16, color: AppTheme.secondaryColor),
                          const SizedBox(width: 8),
                          Text(entry.displayAmount(useMetric), style: TextStyle(color: AppTheme.textPrimary)),
                          const Spacer(),
                          Text(DateFormat('h:mm a').format(entry.timestamp), style: TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () => storage.deleteWaterEntry(entry.id),
                            child: Icon(Icons.close, size: 16, color: AppTheme.textTertiary),
                          ),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildWaterQuickAddButton(int oz, bool useMetric, StorageService storage) {
    String icon;
    String label;
    String amountDisplay;

    if (oz <= 8) {
      icon = '\u{1F95B}'; // glass of milk
      label = 'Glass';
    } else if (oz <= 12) {
      icon = '\u{1F964}'; // cup with straw
      label = 'Cup';
    } else if (oz <= 20) {
      icon = '\u{1FAD6}'; // teapot (using as bottle)
      label = 'Bottle';
    } else {
      icon = '\u{1F4A7}'; // droplet
      label = 'Large';
    }

    if (useMetric) {
      final ml = (oz * 29.5735).round();
      amountDisplay = '${ml}ml';
    } else {
      amountDisplay = '${oz}oz';
    }

    return InkWell(
      onTap: () => storage.quickAddWater(oz),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.secondaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.secondaryColor.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
            Text(amountDisplay, style: TextStyle(color: AppTheme.secondaryColor, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  String _formatWaterAmount(int oz, bool useMetric) {
    if (useMetric) {
      final ml = (oz * 29.5735).round();
      return '$ml ml';
    }
    return '$oz oz';
  }

  void _showCustomWaterDialog(BuildContext context, StorageService storage) {
    final controller = TextEditingController();
    final useMetric = storage.settings.useMetric;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Custom Amount'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            labelText: useMetric ? 'Amount (ml)' : 'Amount (oz)',
            hintText: useMetric ? 'e.g., 500' : 'e.g., 16',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final amount = int.tryParse(controller.text);
              if (amount != null && amount > 0) {
                final oz = useMetric ? (amount / 29.5735).round() : amount;
                storage.quickAddWater(oz);
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showClearWaterDialog(BuildContext context, StorageService storage) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Water Log?'),
        content: const Text('This will remove all water entries for today.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              storage.clearWaterEntriesForDate(DateTime.now());
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(backgroundColor: AppTheme.accentColor),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistSection() {
    return Consumer<StorageService>(
      builder: (context, storage, _) {
        List<ChecklistItem> items = storage.getChecklistItems();
        DateTime today = DateTime.now();
        int completedCount = storage.getCompletedChecklistCount(today);
        List<ChecklistItem> sortedItems = _sortChecklistItems(items, storage, today);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Daily Self-Care', style: Theme.of(context).textTheme.titleLarge),
                Row(
                  children: [
                    IconButton(
                      onPressed: () => _toggleAllNotifications(storage, items),
                      icon: Icon(
                        storage.settings.notificationsEnabled ? Icons.notifications_active : Icons.notifications_off_outlined,
                        color: storage.settings.notificationsEnabled ? AppTheme.primaryColor : AppTheme.textTertiary,
                        size: 22,
                      ),
                      tooltip: storage.settings.notificationsEnabled ? 'Notifications on' : 'Notifications off',
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$completedCount/${items.length}',
                        style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => _showAddChecklistItemDialog(context),
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: AppTheme.primaryColor, borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.add, size: 18, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(color: AppTheme.cardColor, borderRadius: BorderRadius.circular(16)),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sortedItems.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: AppTheme.cardColorLight),
                itemBuilder: (context, index) {
                  ChecklistItem item = sortedItems[index];
                  bool isCompleted = storage.isChecklistItemCompleted(item.id, today);

                  return Dismissible(
                    key: Key(item.id),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (direction) async {
                      return await _showDeleteChecklistConfirmation(context, item);
                    },
                    onDismissed: (_) => storage.deleteChecklistItem(item.id),
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.accentColor,
                        borderRadius: BorderRadius.circular(index == 0 ? 16 : (index == sortedItems.length - 1 ? 16 : 0)),
                      ),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: isCompleted ? AppTheme.successColor.withOpacity(0.1) : Colors.transparent,
                        borderRadius: BorderRadius.circular(index == 0 ? 16 : (index == sortedItems.length - 1 ? 16 : 0)),
                      ),
                      child: ListTile(
                        onTap: () => storage.toggleChecklistItem(item.id, today),
                        onLongPress: () => _showEditChecklistItemDialog(context, item),
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isCompleted ? AppTheme.successColor.withOpacity(0.2) : AppTheme.cardColorLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: isCompleted
                                ? Icon(Icons.check, color: AppTheme.successColor, size: 20)
                                : Text(item.icon ?? '\u{2022}', style: const TextStyle(fontSize: 16)),
                          ),
                        ),
                        title: Text(
                          item.name,
                          style: TextStyle(
                            decoration: isCompleted ? TextDecoration.lineThrough : null,
                            color: isCompleted ? AppTheme.textTertiary : AppTheme.textPrimary,
                          ),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: _getCategoryColor(item.category ?? 'Anytime'), borderRadius: BorderRadius.circular(8)),
                          child: Text(item.category ?? 'Anytime', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  List<ChecklistItem> _sortChecklistItems(List<ChecklistItem> items, StorageService storage, DateTime today) {
    List<ChecklistItem> uncompleted = [];
    List<ChecklistItem> completed = [];

    for (var item in items) {
      if (storage.isChecklistItemCompleted(item.id, today)) {
        completed.add(item);
      } else {
        uncompleted.add(item);
      }
    }

    uncompleted.sort((a, b) {
      int orderA = _getCategoryOrder(a.category);
      int orderB = _getCategoryOrder(b.category);
      if (orderA != orderB) return orderA.compareTo(orderB);
      return a.order.compareTo(b.order);
    });

    return [...uncompleted, ...completed];
  }

  int _getCategoryOrder(String? category) {
    final hour = DateTime.now().hour;
    switch (category) {
      case 'AM':
        return hour < 12 ? 0 : 2;
      case 'PM':
        return hour >= 12 ? 0 : 2;
      default:
        return 1;
    }
  }

  Future<bool?> _showDeleteChecklistConfirmation(BuildContext context, ChecklistItem item) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item?'),
        content: Text('Are you sure you want to delete "${item.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.accentColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _toggleAllNotifications(StorageService storage, List<ChecklistItem> items) async {
    final notificationService = context.read<NotificationService>();
    final currentlyEnabled = storage.settings.notificationsEnabled;

    if (!currentlyEnabled) {
      final granted = await notificationService.requestPermission();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enable notifications in system settings')),
          );
        }
        return;
      }
      await notificationService.scheduleAllNotifications(items);
    } else {
      await notificationService.cancelAllNotifications();
    }

    final newSettings = storage.settings.copyWith(notificationsEnabled: !currentlyEnabled);
    await storage.updateSettings(newSettings);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(!currentlyEnabled ? 'Notifications enabled' : 'Notifications disabled'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  // Emoji list using Unicode escape sequences to prevent corruption
  static const List<String> _checklistEmojis = [
    '\u{1F48A}', // pill
    '\u{1F4AA}', // flexed biceps
    '\u{1F4A7}', // droplet
    '\u{1F9D8}', // person in lotus
    '\u{1F4DA}', // books
    '\u{1FAA5}', // toothbrush
    '\u{2728}',  // sparkles
    '\u{1F957}', // salad
    '\u{1F634}', // sleeping
    '\u{1F3C3}', // running
  ];

  void _showAddChecklistItemDialog(BuildContext context) {
    final nameController = TextEditingController();
    String category = 'Anytime';
    String? selectedIcon;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Self-Care Item'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Task Name', hintText: 'e.g., Take vitamins'),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                Text('Ideal Time', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildCategoryChip('AM', category, (val) => setDialogState(() => category = val)),
                    const SizedBox(width: 8),
                    _buildCategoryChip('Anytime', category, (val) => setDialogState(() => category = val)),
                    const SizedBox(width: 8),
                    _buildCategoryChip('PM', category, (val) => setDialogState(() => category = val)),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Icon (optional)', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _checklistEmojis.map((icon) => GestureDetector(
                    onTap: () => setDialogState(() => selectedIcon = icon),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: selectedIcon == icon ? AppTheme.primaryColor.withOpacity(0.3) : AppTheme.cardColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: selectedIcon == icon ? AppTheme.primaryColor : AppTheme.cardColorLight),
                      ),
                      child: Center(child: Text(icon, style: const TextStyle(fontSize: 20))),
                    ),
                  )).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;
                final storage = context.read<StorageService>();
                final items = storage.getChecklistItems();
                final item = ChecklistItem(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameController.text.trim(),
                  category: category,
                  order: items.length,
                  icon: selectedIcon,
                );
                await storage.saveChecklistItem(item);
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditChecklistItemDialog(BuildContext context, ChecklistItem item) {
    final nameController = TextEditingController(text: item.name);
    String category = item.category ?? 'Anytime';
    String? selectedIcon = item.icon;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Item'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Task Name')),
                const SizedBox(height: 16),
                Text('Ideal Time', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildCategoryChip('AM', category, (val) => setDialogState(() => category = val)),
                    const SizedBox(width: 8),
                    _buildCategoryChip('Anytime', category, (val) => setDialogState(() => category = val)),
                    const SizedBox(width: 8),
                    _buildCategoryChip('PM', category, (val) => setDialogState(() => category = val)),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Icon (optional)', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _checklistEmojis.map((icon) => GestureDetector(
                    onTap: () => setDialogState(() => selectedIcon = icon),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: selectedIcon == icon ? AppTheme.primaryColor.withOpacity(0.3) : AppTheme.cardColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: selectedIcon == icon ? AppTheme.primaryColor : AppTheme.cardColorLight),
                      ),
                      child: Center(child: Text(icon, style: const TextStyle(fontSize: 20))),
                    ),
                  )).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await context.read<StorageService>().deleteChecklistItem(item.id);
                Navigator.pop(context);
              },
              style: TextButton.styleFrom(foregroundColor: AppTheme.accentColor),
              child: const Text('Delete'),
            ),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;
                item.name = nameController.text.trim();
                item.category = category;
                item.icon = selectedIcon;
                await context.read<StorageService>().saveChecklistItem(item);
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String value, String selected, Function(String) onTap) {
    bool isSelected = selected == value;
    return Expanded(
      child: InkWell(
        onTap: () => onTap(value),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryColor : AppTheme.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? AppTheme.primaryColor : AppTheme.cardColorLight),
          ),
          child: Center(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? Colors.white : AppTheme.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'AM':
        return AppTheme.warningColor.withOpacity(0.3);
      case 'PM':
        return AppTheme.primaryColor.withOpacity(0.3);
      default:
        return AppTheme.cardColorLight;
    }
  }

  Widget _buildNutritionSection() {
    return Consumer<StorageService>(
      builder: (context, storage, _) {
        DailyNutrition nutrition = storage.getDailyNutrition(DateTime.now());
        List<FoodEntry> frequentFoods = storage.getFrequentFoods();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Nutrition', style: Theme.of(context).textTheme.titleLarge),
                IconButton(
                  onPressed: () => _showAddFoodDialog(context),
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: AppTheme.primaryColor, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.add, size: 18, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppTheme.cardColor, borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  _buildMacroRow('Calories', nutrition.totalCalories.toInt(), storage.settings.dailyCalorieGoal, AppTheme.accentColor),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildMacroItem('Protein', nutrition.totalProtein.toInt(), storage.settings.dailyProteinGoal, AppTheme.primaryColor)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildMacroItem('Carbs', nutrition.totalCarbs.toInt(), storage.settings.dailyCarbsGoal, AppTheme.warningColor)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildMacroItem('Fats', nutrition.totalFats.toInt(), storage.settings.dailyFatsGoal, AppTheme.secondaryColor)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Quick Add', style: Theme.of(context).textTheme.titleSmall),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _showFoodLibraryDialog(context, storage),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: AppTheme.cardColor, borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('\u{1F4DA}', style: TextStyle(fontSize: 16)),
                            const SizedBox(width: 4),
                            Text('Library', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('Long press to remove', style: TextStyle(fontSize: 10, color: AppTheme.textTertiary)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (frequentFoods.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: frequentFoods.take(6).map((food) {
                  bool inDeleteMode = _quickAddDeleteMode.contains(food.id);
                  return GestureDetector(
                    onTap: () {
                      if (inDeleteMode) {
                        setState(() => _quickAddDeleteMode.remove(food.id));
                      } else {
                        _quickAddFood(context, food);
                      }
                    },
                    onLongPress: () {
                      HapticFeedback.mediumImpact();
                      setState(() => _quickAddDeleteMode.add(food.id));
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: inDeleteMode ? AppTheme.accentColor.withOpacity(0.2) : AppTheme.cardColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: inDeleteMode ? AppTheme.accentColor : AppTheme.cardColorLight),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (inDeleteMode) ...[
                            GestureDetector(
                              onTap: () => _deleteQuickAddFood(context, food, storage),
                              child: Icon(Icons.close, size: 16, color: AppTheme.accentColor),
                            ),
                            const SizedBox(width: 6),
                          ] else ...[
                            Icon(Icons.add, size: 16, color: AppTheme.primaryColor),
                            const SizedBox(width: 6),
                          ],
                          Text(food.name, style: TextStyle(fontSize: 13, color: inDeleteMode ? AppTheme.accentColor : AppTheme.textPrimary)),
                          Text(' (${food.calories.toInt()})', style: TextStyle(fontSize: 11, color: AppTheme.textTertiary)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            if (nutrition.entries.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Today\'s Meals', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              ...nutrition.entries.map((entry) => _buildFoodEntryTile(entry, storage)),
            ],
          ],
        );
      },
    );
  }

  void _showFoodLibraryDialog(BuildContext context, StorageService storage) async {
    final selected = await showFoodLibraryDialog(context);
    if (selected != null && mounted) {
      final entry = FoodEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: selected.name,
        date: DateTime.now(),
        mealType: 'snack',
        calories: selected.calories,
        protein: selected.protein,
        carbs: selected.carbs,
        fats: selected.fats,
        servingSize: selected.servingSize,
        servingUnit: selected.servingUnit,
      );
      storage.saveFoodEntry(entry);
      storage.markFoodLibraryItemUsed(selected.name);
    }
  }

  void _deleteQuickAddFood(BuildContext context, FoodEntry food, StorageService storage) {
    storage.resetFoodUseCount(food.name);
    setState(() => _quickAddDeleteMode.remove(food.id));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Removed ${food.name} from quick add'), duration: const Duration(seconds: 2), behavior: SnackBarBehavior.floating),
    );
  }

  Widget _buildMacroRow(String label, int current, int goal, Color color) {
    double progress = (current / goal).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(context).textTheme.titleMedium),
            Text('$current / $goal', style: TextStyle(color: current > goal ? AppTheme.accentColor : AppTheme.textSecondary, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: progress, backgroundColor: AppTheme.cardColorLight, valueColor: AlwaysStoppedAnimation(color), minHeight: 8),
        ),
      ],
    );
  }

  Widget _buildMacroItem(String label, int current, int goal, Color color) {
    double progress = (current / goal).clamp(0.0, 1.0);
    return Column(
      children: [
        Text('${current}g', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: progress, backgroundColor: AppTheme.cardColorLight, valueColor: AlwaysStoppedAnimation(color), minHeight: 6),
        ),
      ],
    );
  }

  Widget _buildFoodEntryTile(FoodEntry entry, StorageService storage) {
    return Dismissible(
      key: Key(entry.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => storage.deleteFoodEntry(entry.id),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(color: AppTheme.accentColor, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppTheme.cardColor, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: _getMealTypeColor(entry.mealType).withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
              child: Icon(_getMealTypeIcon(entry.mealType), color: _getMealTypeColor(entry.mealType), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                  Text(
                    '${entry.calories.toInt()} cal \u{2022} ${entry.protein.toInt()}p ${entry.carbs.toInt()}c ${entry.fats.toInt()}f',
                    style: TextStyle(fontSize: 12, color: AppTheme.textTertiary),
                  ),
                ],
              ),
            ),
            Text(entry.mealType.capitalize(), style: TextStyle(fontSize: 11, color: AppTheme.textTertiary)),
          ],
        ),
      ),
    );
  }

  Color _getMealTypeColor(String mealType) {
    switch (mealType.toLowerCase()) {
      case 'breakfast': return AppTheme.warningColor;
      case 'lunch': return AppTheme.primaryColor;
      case 'dinner': return AppTheme.secondaryColor;
      case 'snack': return AppTheme.successColor;
      default: return AppTheme.cardColorLight;
    }
  }

  IconData _getMealTypeIcon(String mealType) {
    switch (mealType.toLowerCase()) {
      case 'breakfast': return Icons.wb_sunny_outlined;
      case 'lunch': return Icons.restaurant_outlined;
      case 'dinner': return Icons.nightlight_outlined;
      case 'snack': return Icons.cookie_outlined;
      default: return Icons.fastfood_outlined;
    }
  }

  void _showAddFoodDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const FoodEntryDialog(),
    );
  }

  void _quickAddFood(BuildContext context, FoodEntry template) {
    FoodEntry newEntry = template.asNewEntry(DateTime.now(), 'snack');
    context.read<StorageService>().saveFoodEntry(newEntry);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added ${template.name}'), duration: const Duration(seconds: 2), behavior: SnackBarBehavior.floating),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}