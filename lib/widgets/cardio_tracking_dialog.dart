import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../theme/app_theme.dart';
import '../services/storage_service.dart';
import '../services/step_tracking_service.dart';
import '../models/cardio_workout.dart';

class CardioTrackingDialog extends StatefulWidget {
  final CardioWorkout? existingWorkout;

  const CardioTrackingDialog({super.key, this.existingWorkout});

  @override
  State<CardioTrackingDialog> createState() => _CardioTrackingDialogState();
}

class _CardioTrackingDialogState extends State<CardioTrackingDialog> {
  final _formKey = GlobalKey<FormState>();
  
  CardioType _selectedType = CardioType.running;
  final _durationController = TextEditingController();
  final _distanceController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _heartRateController = TextEditingController();
  final _notesController = TextEditingController();
  int _perceivedExertion = 5;
  bool _manualCalories = false;
  
  // Store original steps if editing, to calculate delta
  int? _originalEstimatedSteps;

  @override
  void initState() {
    super.initState();
    if (widget.existingWorkout != null) {
      _selectedType = widget.existingWorkout!.type;
      _durationController.text = widget.existingWorkout!.durationMinutes.toString();
      if (widget.existingWorkout!.distanceMiles != null) {
        _distanceController.text = widget.existingWorkout!.distanceMiles!.toStringAsFixed(2);
      }
      if (widget.existingWorkout!.caloriesBurned != null) {
        _caloriesController.text = widget.existingWorkout!.caloriesBurned.toString();
        _manualCalories = true;
      }
      if (widget.existingWorkout!.avgHeartRate != null) {
        _heartRateController.text = widget.existingWorkout!.avgHeartRate.toString();
      }
      if (widget.existingWorkout!.notes != null) {
        _notesController.text = widget.existingWorkout!.notes!;
      }
      _perceivedExertion = widget.existingWorkout!.perceivedExertion ?? 5;
      _originalEstimatedSteps = widget.existingWorkout!.estimatedSteps;
    }
  }

  @override
  void dispose() {
    _durationController.dispose();
    _distanceController.dispose();
    _caloriesController.dispose();
    _heartRateController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  int get _estimatedCalories {
    final duration = int.tryParse(_durationController.text) ?? 0;
    if (duration <= 0) return 0;
    
    final distance = double.tryParse(_distanceController.text);
    final storage = context.read<StorageService>();
    final weight = storage.getLatestWeightEntry()?.weight ?? 155;
    
    return CardioCalorieCalculator.calculateCalories(
      type: _selectedType,
      durationMinutes: duration,
      weightLbs: weight,
      distanceMiles: distance,
    );
  }
  
  /// Calculate estimated steps for preview
  int get _estimatedSteps {
    if (!_selectedType.countsAsSteps) return 0;
    
    final duration = int.tryParse(_durationController.text) ?? 0;
    final distance = double.tryParse(_distanceController.text);
    
    // If we have distance for running/walking, use more accurate calculation
    if ((_selectedType == CardioType.running || _selectedType == CardioType.walking) && 
        distance != null && distance > 0) {
      final strideLength = _selectedType == CardioType.running ? 4.0 : 2.5;
      final feetPerMile = 5280.0;
      return ((distance * feetPerMile) / strideLength).round();
    }
    
    return _selectedType.stepsPerMinute * duration;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.textTertiary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      widget.existingWorkout != null ? 'Edit Cardio' : 'Log Cardio Workout',
                      style: Theme.of(context).textTheme.titleLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context, false),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Activity type selector
                      const Text(
                        'Activity Type',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: CardioType.values.map((type) {
                          final isSelected = _selectedType == type;
                          return InkWell(
                            onTap: () => setState(() => _selectedType = type),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppTheme.primaryColor
                                    : AppTheme.cardColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? AppTheme.primaryColor
                                      : AppTheme.cardColorLight,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(type.icon, style: const TextStyle(fontSize: 16)),
                                  const SizedBox(width: 6),
                                  Text(
                                    type.displayName,
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : AppTheme.textPrimary,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Duration
                      TextFormField(
                        controller: _durationController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Duration *',
                          suffixText: 'min',
                          prefixIcon: Icon(Icons.timer_outlined),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          if (int.tryParse(value) == null) {
                            return 'Invalid';
                          }
                          return null;
                        },
                        onChanged: (_) => setState(() {}),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Distance (for applicable activities)
                      if (_selectedType == CardioType.running ||
                          _selectedType == CardioType.walking ||
                          _selectedType == CardioType.cycling)
                        Column(
                          children: [
                            TextFormField(
                              controller: _distanceController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Distance (optional)',
                                suffixText: 'mi',
                                prefixIcon: Icon(Icons.straighten),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      
                      // Calories
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _caloriesController,
                              keyboardType: TextInputType.number,
                              enabled: _manualCalories,
                              decoration: InputDecoration(
                                labelText: _manualCalories ? 'Calories' : 'Est. Calories',
                                suffixText: 'cal',
                                prefixIcon: const Icon(Icons.local_fire_department),
                                hintText: _manualCalories ? null : '$_estimatedCalories',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            children: [
                              const Text('Manual', style: TextStyle(fontSize: 11)),
                              Switch(
                                value: _manualCalories,
                                onChanged: (v) => setState(() => _manualCalories = v),
                                activeColor: AppTheme.primaryColor,
                              ),
                            ],
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Heart rate (optional)
                      TextFormField(
                        controller: _heartRateController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Avg Heart Rate (optional)',
                          suffixText: 'bpm',
                          prefixIcon: Icon(Icons.favorite_border),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Perceived exertion
                      const Text(
                        'How hard was it?',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            '$_perceivedExertion',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: _getRPEColor(_perceivedExertion),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _getRPELabel(_perceivedExertion),
                              style: TextStyle(
                                color: _getRPEColor(_perceivedExertion),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: _perceivedExertion.toDouble(),
                        min: 1,
                        max: 10,
                        divisions: 9,
                        activeColor: _getRPEColor(_perceivedExertion),
                        label: '$_perceivedExertion',
                        onChanged: (v) =>
                            setState(() => _perceivedExertion = v.round()),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Notes
                      TextFormField(
                        controller: _notesController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Notes (optional)',
                          hintText: 'How did you feel?',
                          alignLabelWithHint: true,
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Summary card
                      _buildSummaryCard(),
                      
                      const SizedBox(height: 24),
                      
                      // Save button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _saveWorkout,
                          child: Text(
                            widget.existingWorkout != null
                                ? 'Save Changes'
                                : 'Log Workout',
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final duration = int.tryParse(_durationController.text) ?? 0;
    final distance = double.tryParse(_distanceController.text);
    final calories = _manualCalories
        ? (int.tryParse(_caloriesController.text) ?? 0)
        : _estimatedCalories;
    final steps = _estimatedSteps;

    String? pace;
    if (distance != null && distance > 0 && duration > 0) {
      final paceMinutes = duration / distance;
      final minutes = paceMinutes.floor();
      final seconds = ((paceMinutes - minutes) * 60).round();
      pace = '$minutes:${seconds.toString().padLeft(2, '0')} /mi';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(_selectedType.icon, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  _selectedType.displayName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            alignment: WrapAlignment.spaceAround,
            children: [
              _buildSummaryStat(Icons.timer, '$duration', 'min'),
              if (distance != null)
                _buildSummaryStat(
                    Icons.straighten, distance.toStringAsFixed(2), 'mi'),
              _buildSummaryStat(Icons.local_fire_department, '$calories', 'cal'),
              if (pace != null)
                _buildSummaryStat(Icons.speed, pace, 'pace'),
              if (steps > 0)
                _buildSummaryStat(Icons.directions_walk, _formatSteps(steps), 'steps'),
            ],
          ),
          if (steps > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_circle_outline, 
                    size: 16, 
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '+${_formatSteps(steps)} steps will be added',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  String _formatSteps(int steps) {
    if (steps >= 1000) {
      return '${(steps / 1000).toStringAsFixed(1)}k';
    }
    return '$steps';
  }

  Widget _buildSummaryStat(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.primaryColor, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
        ),
      ],
    );
  }

  Color _getRPEColor(int rpe) {
    if (rpe <= 3) return AppTheme.successColor;
    if (rpe <= 5) return Colors.yellow.shade700;
    if (rpe <= 7) return Colors.orange;
    return AppTheme.accentColor;
  }

  String _getRPELabel(int rpe) {
    if (rpe <= 2) return 'Very Easy';
    if (rpe <= 4) return 'Easy';
    if (rpe <= 6) return 'Moderate';
    if (rpe <= 8) return 'Hard';
    return 'Maximum Effort';
  }

  void _saveWorkout() async {
    if (!_formKey.currentState!.validate()) return;

    final duration = int.parse(_durationController.text);
    final distance = double.tryParse(_distanceController.text);
    final calories = _manualCalories
        ? int.tryParse(_caloriesController.text)
        : _estimatedCalories;
    final heartRate = int.tryParse(_heartRateController.text);

    final workout = CardioWorkout(
      id: widget.existingWorkout?.id ?? const Uuid().v4(),
      type: _selectedType,
      date: DateTime.now(),
      durationMinutes: duration,
      distanceMiles: distance,
      caloriesBurned: calories,
      avgHeartRate: heartRate,
      notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      perceivedExertion: _perceivedExertion,
    );

    final storage = context.read<StorageService>();
    final stepService = context.read<StepTrackingService>();
    
    await storage.saveCardioWorkout(workout);
    
    // Update step count if this activity counts as steps
    final newEstimatedSteps = workout.estimatedSteps;
    if (newEstimatedSteps > 0) {
      if (widget.existingWorkout != null && _originalEstimatedSteps != null) {
        // Editing: calculate the difference
        final stepDelta = newEstimatedSteps - _originalEstimatedSteps!;
        if (stepDelta > 0) {
          stepService.addCardioSteps(stepDelta);
        } else if (stepDelta < 0) {
          stepService.removeCardioSteps(-stepDelta);
        }
      } else {
        // New workout: add all steps
        stepService.addCardioSteps(newEstimatedSteps);
      }
    }

    if (mounted) {
      Navigator.pop(context, true); // Return true to indicate workout was saved
      
      // Build snackbar message
      String message = '${_selectedType.displayName} logged! ${calories ?? _estimatedCalories} calories burned';
      if (newEstimatedSteps > 0) {
        message += ' \u{2022} +${_formatSteps(newEstimatedSteps)} steps'; // • bullet point
      }
      message += ' \u{1F525}'; // 🔥
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

/// Show the cardio tracking dialog
/// Returns a Future<bool> - true if a workout was saved, false otherwise
Future<bool> showCardioTrackingDialog(BuildContext context, {CardioWorkout? existing}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => CardioTrackingDialog(existingWorkout: existing),
  );
  return result ?? false;
}
