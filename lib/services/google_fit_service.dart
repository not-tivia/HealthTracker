import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

class GoogleFitService extends ChangeNotifier {
  int _todaySteps = 0;
  bool _isLoading = false;
  bool _isAuthorized = false;
  String? _errorMessage;

  int get todaySteps => _todaySteps;
  bool get isLoading => _isLoading;
  bool get isAuthorized => _isAuthorized;
  String? get errorMessage => _errorMessage;

  // Use the Health singleton
  final Health _health = Health();

  // Data types we want to access
  static const List<HealthDataType> _types = [
    HealthDataType.STEPS,
  ];

  // Permissions we need
  static const List<HealthDataAccess> _permissions = [
    HealthDataAccess.READ,
  ];

  GoogleFitService() {
    _initialize();
  }

  Future<void> _initialize() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      // Configure the health plugin
      await _health.configure();
      
      if (kDebugMode) {
        print('Health plugin configured successfully');
      }
      
      // Check existing permissions
      final hasPermissions = await _health.hasPermissions(
        _types,
        permissions: _permissions,
      );
      
      _isAuthorized = hasPermissions ?? false;
      
      if (kDebugMode) {
        print('Has health permissions: $_isAuthorized');
      }
      
      if (_isAuthorized) {
        await fetchTodaySteps();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing health service: $e');
      }
      _errorMessage = 'Health Connect not available. Please install Health Connect from Play Store.';
    }
    
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> requestAuthorization() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // First request activity recognition permission on Android
      if (Platform.isAndroid) {
        if (kDebugMode) {
          print('Requesting activity recognition permission...');
        }
        final activityStatus = await Permission.activityRecognition.request();
        if (kDebugMode) {
          print('Activity recognition status: $activityStatus');
        }
        if (!activityStatus.isGranted) {
          _errorMessage = 'Activity recognition permission denied. Please allow in Settings.';
          _isLoading = false;
          notifyListeners();
          return false;
        }
      }

      if (kDebugMode) {
        print('Requesting health data permissions...');
      }
      
      // Request health data permissions
      final authorized = await _health.requestAuthorization(
        _types,
        permissions: _permissions,
      );

      if (kDebugMode) {
        print('Health authorization result: $authorized');
      }

      _isAuthorized = authorized;
      
      if (_isAuthorized) {
        // Fetch initial data
        await fetchTodaySteps();
      } else {
        _errorMessage = 'Health data access not authorized. Please allow access in Health Connect settings.';
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error requesting authorization: $e');
      }
      _errorMessage = 'Failed to connect. Make sure Health Connect is installed and try again.';
      _isAuthorized = false;
    }

    _isLoading = false;
    notifyListeners();
    return _isAuthorized;
  }

  Future<void> fetchTodaySteps() async {
    if (!_isAuthorized) {
      _todaySteps = 0;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);

      // Try to get step count using the aggregated method first
      int? steps;
      
      try {
        // Use getTotalStepsInInterval for more accurate step count
        steps = await _health.getTotalStepsInInterval(startOfDay, now);
      } catch (e) {
        if (kDebugMode) {
          print('getTotalStepsInInterval failed, trying getHealthDataFromTypes: $e');
        }
      }

      // If that didn't work, fall back to getting individual data points
      if (steps == null) {
        try {
          final healthData = await _health.getHealthDataFromTypes(
            types: _types,
            startTime: startOfDay,
            endTime: now,
          );

          // Remove duplicates
          final cleanData = _health.removeDuplicates(healthData);

          // Sum up all step values
          steps = 0;
          for (final point in cleanData) {
            if (point.type == HealthDataType.STEPS) {
              final value = point.value;
              if (value is NumericHealthValue) {
                steps = steps! + value.numericValue.toInt();
              }
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('getHealthDataFromTypes failed: $e');
          }
          _errorMessage = 'Failed to fetch steps';
        }
      }

      _todaySteps = steps ?? 0;
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching steps: $e');
      }
      _errorMessage = 'Error: ${e.toString()}';
      _todaySteps = 0;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<List<HealthDataPoint>> getStepsForPeriod(DateTime start, DateTime end) async {
    if (!_isAuthorized) return [];

    try {
      final healthData = await _health.getHealthDataFromTypes(
        types: _types,
        startTime: start,
        endTime: end,
      );
      return _health.removeDuplicates(healthData);
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching steps for period: $e');
      }
      return [];
    }
  }

  Future<Map<DateTime, int>> getWeeklySteps() async {
    if (!_isAuthorized) return {};

    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final Map<DateTime, int> dailySteps = {};

    try {
      for (int i = 0; i < 7; i++) {
        final date = weekAgo.add(Duration(days: i));
        final startOfDay = DateTime(date.year, date.month, date.day);
        final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

        final steps = await _health.getTotalStepsInInterval(startOfDay, endOfDay);
        dailySteps[startOfDay] = steps ?? 0;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching weekly steps: $e');
      }
    }

    return dailySteps;
  }

  Future<void> revokeAccess() async {
    try {
      await _health.revokePermissions();
    } catch (e) {
      if (kDebugMode) {
        print('Error revoking permissions: $e');
      }
    }
    _isAuthorized = false;
    _todaySteps = 0;
    _errorMessage = null;
    notifyListeners();
  }

  /// Manual step entry for when health services aren't available
  void setManualSteps(int steps) {
    _todaySteps = steps;
    notifyListeners();
  }
}
