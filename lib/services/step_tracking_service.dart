import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Simple step tracking service that reads directly from the device's step sensor
/// Stores daily step history for the week and resets at midnight
/// 
/// Now tracks:
/// - _pedometerSteps: Raw steps from device sensor
/// - _manualSteps: Additional steps from manual cardio entries (treadmill, etc.)
/// - todaySteps: Total displayed steps (_pedometerSteps + _manualSteps)
class StepTrackingService extends ChangeNotifier {
  int _pedometerSteps = 0;  // Internal: Raw steps from device pedometer
  int _manualSteps = 0;      // Additional steps from manual cardio
  int _stepsAtMidnight = 0;
  bool _isTracking = false;
  bool _hasPermission = false;
  String? _errorMessage;
  int _stepGoal = 10000;
  
  // Weekly step history: Map of date string to steps
  Map<String, int> _weeklyHistory = {};
  
  StreamSubscription<StepCount>? _stepSubscription;
  StreamSubscription<PedestrianStatus>? _pedestrianSubscription;
  Timer? _midnightTimer;
  SharedPreferences? _prefs;
  
  /// Total displayed steps (pedometer + manual cardio)
  int get todaySteps => _pedometerSteps + _manualSteps;
  
  /// Raw pedometer steps only
  int get pedometerSteps => _pedometerSteps;
  
  /// Manual cardio steps only
  int get manualSteps => _manualSteps;
  
  bool get isTracking => _isTracking;
  bool get hasPermission => _hasPermission;
  String? get errorMessage => _errorMessage;
  int get stepGoal => _stepGoal;
  Map<String, int> get weeklyHistory => _weeklyHistory;

  StepTrackingService() {
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadSavedData();
    await checkPermission();
    if (_hasPermission) {
      startTracking();
    }
    _scheduleMidnightReset();
    await pruneOldCardioOverrides();
  }

  /// Schedule a timer to reset steps at midnight
  void _scheduleMidnightReset() {
    _midnightTimer?.cancel();
    
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final timeUntilMidnight = tomorrow.difference(now);
    
    _midnightTimer = Timer(timeUntilMidnight, () {
      _onMidnight();
      _scheduleMidnightReset();
    });
    
    if (kDebugMode) {
      print('Midnight reset scheduled in ${timeUntilMidnight.inMinutes} minutes');
    }
  }

  /// Called at midnight to save yesterday's steps and reset
  void _onMidnight() {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final yesterdayString = _getDateString(yesterday);
    _weeklyHistory[yesterdayString] = todaySteps; // Save total (pedometer + manual)
    _cleanOldHistory();
    _pedometerSteps = 0;
    _manualSteps = 0;
    _stepsAtMidnight = 0;
    _saveData();
    
    if (kDebugMode) print('Midnight reset: saved $yesterdayString steps, starting new day');
    notifyListeners();
  }

  /// Remove history older than 7 days
  void _cleanOldHistory() {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    _weeklyHistory.removeWhere((dateStr, _) {
      final parts = dateStr.split('-');
      if (parts.length != 3) return true;
      final date = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      return date.isBefore(cutoff);
    });
  }

  /// Load saved step data from SharedPreferences
  Future<void> _loadSavedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _prefs = prefs;
      final savedDate = prefs.getString('step_date');
      final today = _getTodayString();
      
      _stepGoal = prefs.getInt('step_goal') ?? 10000;
      
      // Load weekly history
      final historyKeys = prefs.getKeys().where((k) => k.startsWith('steps_'));
      for (final key in historyKeys) {
        final dateStr = key.replaceFirst('steps_', '');
        _weeklyHistory[dateStr] = prefs.getInt(key) ?? 0;
      }
      
      if (savedDate == today) {
        _pedometerSteps = prefs.getInt('pedometer_steps') ?? prefs.getInt('today_steps') ?? 0;
        _manualSteps = prefs.getInt('manual_steps') ?? 0;
        _stepsAtMidnight = prefs.getInt('steps_at_midnight') ?? 0;
      } else if (savedDate != null) {
        // New day - save yesterday's steps to history first
        final yesterdayPedometer = prefs.getInt('pedometer_steps') ?? prefs.getInt('today_steps') ?? 0;
        final yesterdayManual = prefs.getInt('manual_steps') ?? 0;
        final yesterdayTotal = yesterdayPedometer + yesterdayManual;
        if (yesterdayTotal > 0) {
          _weeklyHistory[savedDate] = yesterdayTotal;
          await prefs.setInt('steps_$savedDate', yesterdayTotal);
        }
        _pedometerSteps = 0;
        _manualSteps = 0;
        _stepsAtMidnight = 0;
        await _saveData();
      }
      
      _cleanOldHistory();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('Error loading step data: $e');
    }
  }

  /// Save step data to SharedPreferences
  Future<void> _saveData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('step_date', _getTodayString());
      await prefs.setInt('pedometer_steps', _pedometerSteps);
      await prefs.setInt('manual_steps', _manualSteps);
      await prefs.setInt('today_steps', todaySteps); // For backwards compatibility
      await prefs.setInt('steps_at_midnight', _stepsAtMidnight);
      await prefs.setInt('step_goal', _stepGoal);
      
      for (final entry in _weeklyHistory.entries) {
        await prefs.setInt('steps_${entry.key}', entry.value);
      }
    } catch (e) {
      if (kDebugMode) print('Error saving step data: $e');
    }
  }

  String _getTodayString() => _getDateString(DateTime.now());
  
  String _getDateString(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Get steps for a specific date
  int getStepsForDate(DateTime date) {
    final dateStr = _getDateString(date);
    if (dateStr == _getTodayString()) return todaySteps;
    return _weeklyHistory[dateStr] ?? 0;
  }

  /// Check if step goal was met for a specific date
  bool goalMetForDate(DateTime date) {
    return getStepsForDate(date) >= _stepGoal || isCardioGoalOverridden(date);
  }

  /// Get weekly goal completion status (Mon-Sun)
  List<bool> getWeeklyGoalStatus() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    
    return List.generate(7, (index) {
      final date = monday.add(Duration(days: index));
      if (date.isAfter(now)) return false;
      return goalMetForDate(date);
    });
  }

  /// Set step goal
  void setStepGoal(int goal) {
    _stepGoal = goal;
    _saveData();
    notifyListeners();
  }

  Future<bool> checkPermission() async {
    try {
      final status = await Permission.activityRecognition.status;
      _hasPermission = status.isGranted;
      _errorMessage = null;
      notifyListeners();
      return _hasPermission;
    } catch (e) {
      _errorMessage = 'Error checking permissions: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> requestPermission() async {
    try {
      final status = await Permission.activityRecognition.request();
      _hasPermission = status.isGranted;
      
      if (!_hasPermission) {
        _errorMessage = status.isPermanentlyDenied
            ? 'Permission permanently denied. Please enable in Settings.'
            : 'Permission denied. Step tracking requires activity recognition permission.';
      } else {
        _errorMessage = null;
        startTracking();
      }
      
      notifyListeners();
      return _hasPermission;
    } catch (e) {
      _errorMessage = 'Error requesting permission: $e';
      notifyListeners();
      return false;
    }
  }

  void startTracking() {
    if (_isTracking || !_hasPermission) {
      if (!_hasPermission) {
        _errorMessage = 'No permission to track steps';
        notifyListeners();
      }
      return;
    }

    try {
      _stepSubscription = Pedometer.stepCountStream.listen(
        _onStepCount,
        onError: _onStepCountError,
        cancelOnError: false,
      );

      _pedestrianSubscription = Pedometer.pedestrianStatusStream.listen(
        _onPedestrianStatus,
        onError: (e) => kDebugMode ? print('Pedestrian status error: $e') : null,
        cancelOnError: false,
      );

      _isTracking = true;
      _errorMessage = null;
      notifyListeners();
      
      if (kDebugMode) print('Step tracking started');
    } catch (e) {
      _errorMessage = 'Failed to start step tracking: $e';
      _isTracking = false;
      notifyListeners();
    }
  }

  void stopTracking() {
    _stepSubscription?.cancel();
    _pedestrianSubscription?.cancel();
    _stepSubscription = null;
    _pedestrianSubscription = null;
    _isTracking = false;
    notifyListeners();
  }

  void _onStepCount(StepCount event) {
    final totalSteps = event.steps;
    final today = _getTodayString();
    
    SharedPreferences.getInstance().then((prefs) {
      final lastDate = prefs.getString('step_date');
      
      if (lastDate != null && lastDate != today) {
        final yesterdayPedometer = prefs.getInt('pedometer_steps') ?? prefs.getInt('today_steps') ?? 0;
        final yesterdayManual = prefs.getInt('manual_steps') ?? 0;
        final yesterdayTotal = yesterdayPedometer + yesterdayManual;
        if (yesterdayTotal > 0) {
          _weeklyHistory[lastDate] = yesterdayTotal;
          prefs.setInt('steps_$lastDate', yesterdayTotal);
        }
        _stepsAtMidnight = totalSteps;
        _pedometerSteps = 0;
        _manualSteps = 0;  // Reset manual steps for new day
        _cleanOldHistory();
      } else {
        if (_stepsAtMidnight == 0) {
          _stepsAtMidnight = totalSteps - _pedometerSteps;
        }
        _pedometerSteps = totalSteps - _stepsAtMidnight;
        if (_pedometerSteps < 0) _pedometerSteps = 0;
      }
      
      _saveData();
      _errorMessage = null;
      notifyListeners();
    });
  }

  void _onStepCountError(error) {
    _errorMessage = error.toString().contains('not available')
        ? 'Step counter not available on this device'
        : 'Step sensor error: $error';
    notifyListeners();
  }

  void _onPedestrianStatus(PedestrianStatus event) {
    if (kDebugMode) print('Pedestrian status: ${event.status}');
  }

  /// Add steps from manual cardio entry (e.g., treadmill)
  /// This adds to the display total without affecting pedometer tracking
  void addCardioSteps(int steps) {
    _manualSteps += steps;
    _saveData();
    notifyListeners();
    if (kDebugMode) print('Added $steps cardio steps. Manual total: $_manualSteps');
  }

  /// Remove cardio steps (if user deletes a cardio entry)
  void removeCardioSteps(int steps) {
    _manualSteps = (_manualSteps - steps).clamp(0, _manualSteps);
    _saveData();
    notifyListeners();
  }

  /// Set manual steps directly (replaces previous manual steps)
  void setManualSteps(int steps) {
    _manualSteps = steps;
    _saveData();
    notifyListeners();
  }

  /// Legacy method - sets total steps (clears manual, sets pedometer)
  void setTotalSteps(int steps) {
    _pedometerSteps = steps;
    _manualSteps = 0;
    _saveData();
    notifyListeners();
  }

  /// Legacy method - adds to pedometer steps
  void addSteps(int steps) {
    _pedometerSteps += steps;
    _saveData();
    notifyListeners();
  }

  void resetTodaySteps() {
    _pedometerSteps = 0;
    _manualSteps = 0;
    _stepsAtMidnight = 0;
    _saveData();
    notifyListeners();
  }

  Future<void> refresh() async {
    await _loadSavedData();
    if (!_hasPermission) await requestPermission();
    if (!_isTracking && _hasPermission) startTracking();
    notifyListeners();
  }

  /// Mark today's cardio/step goal as met (manual override).
  /// One-directional — once set, stays for the day.
  Future<void> markCardioGoalMet() async {
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    final today = _getTodayString();
    await prefs.setBool('cardio_override_$today', true);
    notifyListeners();
  }

  /// Check if a specific date has a cardio goal override.
  /// Uses the cached SharedPreferences reference for synchronous access.
  bool isCardioGoalOverridden(DateTime date) {
    if (_prefs == null) return false;
    final dateStr = _getDateString(date);
    return _prefs!.getBool('cardio_override_$dateStr') ?? false;
  }

  /// Prune cardio override entries older than 14 days.
  Future<void> pruneOldCardioOverrides() async {
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    final cutoff = DateTime.now().subtract(const Duration(days: 14));
    final keysToRemove = prefs.getKeys()
        .where((k) => k.startsWith('cardio_override_'))
        .where((k) {
      final dateStr = k.replaceFirst('cardio_override_', '');
      final parts = dateStr.split('-');
      if (parts.length != 3) return true;
      try {
        final date = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        return date.isBefore(cutoff);
      } catch (_) {
        return true;
      }
    }).toList();

    for (final key in keysToRemove) {
      await prefs.remove(key);
    }
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    stopTracking();
    super.dispose();
  }
}
