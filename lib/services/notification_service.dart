import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:permission_handler/permission_handler.dart';

import '../models/checklist_item.dart';

class NotificationService extends ChangeNotifier {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  bool _notificationsEnabled = false;

  bool get isInitialized => _isInitialized;
  bool get notificationsEnabled => _notificationsEnabled;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize timezone database
    tz_data.initializeTimeZones();

    // Set local timezone (safe fallback)
    try {
      tz.setLocalLocation(tz.getLocation('America/Los_Angeles'));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    await _createNotificationChannel();

    _isInitialized = true;
    notifyListeners();

    if (kDebugMode) {
      print('✓ NotificationService initialized');
    }
  }

  Future<void> _createNotificationChannel() async {
    const channel = AndroidNotificationChannel(
      'checklist_reminders',
      'Self-Care Reminders',
      description: 'Reminders for your daily self-care tasks',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  void _onNotificationTapped(NotificationResponse response) {
    if (kDebugMode) {
      print('Notification tapped: ${response.payload}');
    }
  }

  // ============================================================
  // ✅ THIS IS THE FIX (method name your UI expects)
  // ============================================================
  Future<bool> requestPermission() async {
    final status = await Permission.notification.request();
    _notificationsEnabled = status.isGranted;
    notifyListeners();
    return _notificationsEnabled;
  }

  /// (kept for compatibility / internal use)
  Future<bool> requestPermissions() async {
    return requestPermission();
  }

  /// Check if notifications are permitted
  Future<bool> checkPermissions() async {
    final status = await Permission.notification.status;
    _notificationsEnabled = status.isGranted;
    notifyListeners();
    return _notificationsEnabled;
  }

  /// Schedule a notification for a checklist item
  Future<void> scheduleChecklistNotification(ChecklistItem item) async {
    if (!_isInitialized || !item.notificationEnabled) return;
    if (item.scheduledTimeMinutes == null) return;

    await cancelNotification(item.id.hashCode);

    final now = DateTime.now();
    final hours = item.scheduledTimeMinutes! ~/ 60;
    final minutes = item.scheduledTimeMinutes! % 60;

    var scheduledDate =
        DateTime(now.year, now.month, now.day, hours, minutes);

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    final androidDetails = AndroidNotificationDetails(
      'checklist_reminders',
      'Self-Care Reminders',
      channelDescription: 'Reminders for your daily self-care tasks',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    final tzScheduledDate =
        tz.TZDateTime.from(scheduledDate, tz.local);

    await _notifications.zonedSchedule(
      item.id.hashCode,
      'Self-Care Reminder',
      "Don't forget: ${item.name}",
      tzScheduledDate,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: item.id,
    );

    if (kDebugMode) {
      print('✓ Scheduled "${item.name}" at $tzScheduledDate');
    }
  }

  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  Future<void> cancelChecklistNotification(ChecklistItem item) async {
    await cancelNotification(item.id.hashCode);
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  Future<void> scheduleAllNotifications(List<ChecklistItem> items) async {
    for (final item in items) {
      if (item.notificationEnabled &&
          item.scheduledTimeMinutes != null) {
        await scheduleChecklistNotification(item);
      }
    }
  }

  /// Show an immediate notification (testing)
  Future<void> showTestNotification() async {
    if (!_isInitialized) return;

    const androidDetails = AndroidNotificationDetails(
      'test_channel',
      'Test Notifications',
      importance: Importance.high,
      priority: Priority.high,
    );

    const details =
        NotificationDetails(android: androidDetails);

    await _notifications.show(
      0,
      'Test Notification',
      'Notifications are working!',
      details,
    );
  }

  Future<void> checkAndNotifyIncompleteItems(
    List<ChecklistItem> items,
    bool Function(String itemId) isCompleted,
  ) async {
    if (!_isInitialized || !_notificationsEnabled) return;
  }
}
