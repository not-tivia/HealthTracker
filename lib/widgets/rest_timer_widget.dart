import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../theme/app_theme.dart';

/// Global state manager for the rest timer
/// Allows the timer to persist when navigating between screens
class RestTimerManager extends ChangeNotifier {
  static final RestTimerManager _instance = RestTimerManager._internal();
  factory RestTimerManager() => _instance;
  RestTimerManager._internal();
  
  int _remainingSeconds = 0;
  int _totalSeconds = 0;
  Timer? _timer;
  bool _isRunning = false;
  bool _isPaused = false;
  bool _isMinimized = false;
  bool _soundEnabled = true;
  VoidCallback? _onComplete;
  
  // Audio player for alarm sound
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  // Notification plugin
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  
  // Method channel for media style notification
  static const MethodChannel _channel = MethodChannel('health_tracker/timer_notification');
  
  int get remainingSeconds => _remainingSeconds;
  int get totalSeconds => _totalSeconds;
  bool get isRunning => _isRunning;
  bool get isPaused => _isPaused;
  bool get isMinimized => _isMinimized;
  bool get soundEnabled => _soundEnabled;
  
  double get progress => _totalSeconds > 0 ? _remainingSeconds / _totalSeconds : 0;
  
  String get displayTime {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  
  void startTimer(int seconds, {VoidCallback? onComplete}) {
    _timer?.cancel();
    _totalSeconds = seconds;
    _remainingSeconds = seconds;
    _isRunning = true;
    _isPaused = false;
    _isMinimized = false;
    _onComplete = onComplete;
    
    // Show media-style notification for status bar chip
    _showMediaStyleNotification();
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
        
        // Warning feedback at 10 seconds
        if (_remainingSeconds == 10) {
          HapticFeedback.mediumImpact();
          _playTickSound();
        }
        
        // Countdown beeps for last 3 seconds
        if (_remainingSeconds <= 3 && _remainingSeconds > 0) {
          HapticFeedback.lightImpact();
          _playTickSound();
        }
        
        // No notification update here - chronometer handles countdown automatically
        // This prevents constant buzzing on wearables
        
        notifyListeners();
      } else {
        _timerComplete();
      }
    });
    
    notifyListeners();
  }
  
  void togglePause() {
    if (_isPaused) {
      // Resume - update notification with new end time
      _isPaused = false;
      _showMediaStyleNotification(); // Update with new 'when' time
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
          if (_remainingSeconds == 10) {
            HapticFeedback.mediumImpact();
            _playTickSound();
          }
          if (_remainingSeconds <= 3 && _remainingSeconds > 0) {
            HapticFeedback.lightImpact();
            _playTickSound();
          }
          // No notification update - chronometer handles countdown
          notifyListeners();
        } else {
          _timerComplete();
        }
      });
    } else {
      // Pause
      _timer?.cancel();
      _isPaused = true;
      _showMediaStyleNotification(); // Update to show PAUSED state
    }
    notifyListeners();
  }
  
  void addTime(int seconds) {
    _remainingSeconds += seconds;
    _totalSeconds += seconds;
    _showMediaStyleNotification(); // Update with new end time
    notifyListeners();
  }
  
  void subtractTime(int seconds) {
    if (_remainingSeconds > seconds) {
      _remainingSeconds -= seconds;
      _showMediaStyleNotification(); // Update with new end time
      notifyListeners();
    }
  }
  
  void toggleSound() {
    _soundEnabled = !_soundEnabled;
    HapticFeedback.lightImpact();
    notifyListeners();
  }
  
  void minimize() {
    _isMinimized = true;
    notifyListeners();
  }
  
  void maximize() {
    _isMinimized = false;
    notifyListeners();
  }
  
  void stop() {
    _timer?.cancel();
    _isRunning = false;
    _isPaused = false;
    _isMinimized = false;
    _remainingSeconds = 0;
    _cancelMediaStyleNotification();
    notifyListeners();
  }
  
  void _timerComplete() {
    _timer?.cancel();
    _isRunning = false;
    
    // Cancel the ongoing notification
    _cancelMediaStyleNotification();
    
    // Play alarm sound
    _playAlarmSound();
    
    // Show completion notification
    _showCompletionNotification();
    
    // Completion vibration pattern
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 150), () {
      HapticFeedback.heavyImpact();
      Future.delayed(const Duration(milliseconds: 150), () {
        HapticFeedback.heavyImpact();
      });
    });
    
    _onComplete?.call();
    notifyListeners();
  }
  
  // =========== MEDIA STYLE NOTIFICATION (Status Bar Chip) ===========
  
  Future<void> _showMediaStyleNotification() async {
    try {
      // Use AndroidNotificationDetails with media style properties
      final androidDetails = AndroidNotificationDetails(
        'rest_timer_media',
        'Rest Timer',
        channelDescription: 'Shows rest timer in status bar',
        importance: Importance.low,  // Lower importance = less intrusive
        priority: Priority.low,
        ongoing: true,
        autoCancel: false,
        playSound: false,
        enableVibration: false,
        onlyAlertOnce: true,  // CRITICAL: Only alert once, silent updates after
        showWhen: false,
        usesChronometer: true,  // Shows elapsed time
        chronometerCountDown: true,  // Count down instead of up
        when: DateTime.now().add(Duration(seconds: _remainingSeconds)).millisecondsSinceEpoch,
        category: AndroidNotificationCategory.progress,
        visibility: NotificationVisibility.public,
        colorized: true,
        color: const Color(0xFF4CAF50),  // Green color
        // These make it show in status bar more prominently
        ticker: 'Rest Timer: $displayTime',
        subText: _isPaused ? 'PAUSED' : null,
      );

      final details = NotificationDetails(android: androidDetails);

      await _notifications.show(
        997,  // Unique ID for media timer
        '\u{1F4AA} Rest Timer',  // ðŸ’ª
        displayTime,
        details,
      );
    } catch (e) {
      debugPrint('Could not show media notification: $e');
    }
  }
  
  /// Update notification only when pause state changes
  Future<void> _updateNotificationForPauseChange() async {
    if (!_isRunning) return;
    await _showMediaStyleNotification();
  }
  
  Future<void> _cancelMediaStyleNotification() async {
    try {
      await _notifications.cancel(997);
    } catch (e) {
      debugPrint('Could not cancel media notification: $e');
    }
  }
  
  // =========== AUDIO METHODS ===========
  
  Future<void> _playTickSound() async {
    if (!_soundEnabled) return;
    try {
      await _audioPlayer.play(AssetSource('sounds/beep.wav'));
    } catch (e) {
      // Sound file not found, silently ignore
    }
  }
  
  Future<void> _playAlarmSound() async {
    if (!_soundEnabled) return;
    try {
      await _audioPlayer.play(AssetSource('sounds/alarm.wav'));
    } catch (e) {
      // Sound file not found, try system default
      try {
        // Use default notification sound
        HapticFeedback.heavyImpact();
      } catch (e2) {
        debugPrint('Could not play any sound');
      }
    }
  }
  
  void stopAlarm() {
    _audioPlayer.stop();
  }
  
  // =========== COMPLETION NOTIFICATION ===========
  
  Future<void> _showCompletionNotification() async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'rest_timer_complete',
        'Rest Timer Complete',
        channelDescription: 'Notifications for rest timer completion',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        ticker: 'Rest time is up!',
        autoCancel: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.show(
        999,
        '\u{1F4AA} Rest Complete!',  // ðŸ’ª
        'Time to start your next set!',
        details,
      );
    } catch (e) {
      debugPrint('Could not show completion notification: $e');
    }
  }
}

/// The timer widget UI - displays the circular timer with controls
class RestTimerWidget extends StatefulWidget {
  final int initialSeconds;
  final VoidCallback? onComplete;
  final VoidCallback? onDismiss;
  final VoidCallback? onMinimize;
  
  const RestTimerWidget({
    super.key,
    this.initialSeconds = 90,
    this.onComplete,
    this.onDismiss,
    this.onMinimize,
  });
  
  @override
  State<RestTimerWidget> createState() => _RestTimerWidgetState();
}

class _RestTimerWidgetState extends State<RestTimerWidget> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  
  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    
    // Start the timer if not already running
    final manager = RestTimerManager();
    if (!manager.isRunning) {
      manager.startTimer(widget.initialSeconds, onComplete: widget.onComplete);
    }
  }
  
  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: RestTimerManager(),
      builder: (context, _) {
        final manager = RestTimerManager();
        final isWarning = manager.remainingSeconds <= 10 && manager.remainingSeconds > 0;
        final isComplete = manager.remainingSeconds == 0 && !manager.isRunning;
        
        // Pulse animation when warning
        if (isWarning && !_pulseController.isAnimating) {
          _pulseController.repeat(reverse: true);
        } else if (!isWarning && _pulseController.isAnimating) {
          _pulseController.stop();
          _pulseController.reset();
        }
        
        final screenWidth = MediaQuery.of(context).size.width;
        final timerWidth = screenWidth - 48 < 320 ? screenWidth - 48 : 320.0;

        return Material(
          color: Colors.transparent,
          child: Container(
            width: timerWidth,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isComplete
                  ? AppTheme.successColor.withOpacity(0.95)
                  : isWarning
                      ? AppTheme.warningColor.withOpacity(0.95)
                      : AppTheme.surfaceColor.withOpacity(0.95),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: (isComplete
                          ? AppTheme.successColor
                          : isWarning
                              ? AppTheme.warningColor
                              : AppTheme.primaryColor)
                      .withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with minimize/close buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () {
                        manager.minimize();
                        widget.onMinimize?.call();
                      },
                      icon: Icon(
                        Icons.minimize,
                        color: isWarning || isComplete ? Colors.white70 : AppTheme.textSecondary,
                      ),
                      tooltip: 'Minimize',
                    ),
                    Text(
                      isComplete ? 'Complete!' : 'Rest Timer',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: isWarning || isComplete ? Colors.white : AppTheme.textPrimary,
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        manager.stop();
                        widget.onDismiss?.call();
                      },
                      icon: Icon(
                        Icons.close,
                        color: isWarning || isComplete ? Colors.white70 : AppTheme.textSecondary,
                      ),
                      tooltip: 'Stop Timer',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Circular timer display
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final scale = isWarning ? 1.0 + (_pulseController.value * 0.05) : 1.0;
                    return Transform.scale(
                      scale: scale,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Background circle
                          SizedBox(
                            width: 180,
                            height: 180,
                            child: CircularProgressIndicator(
                              value: 1.0,
                              strokeWidth: 8,
                              backgroundColor: Colors.transparent,
                              valueColor: AlwaysStoppedAnimation(
                                (isWarning || isComplete ? Colors.white : AppTheme.primaryColor)
                                    .withOpacity(0.2),
                              ),
                            ),
                          ),
                          // Progress circle
                          SizedBox(
                            width: 180,
                            height: 180,
                            child: CircularProgressIndicator(
                              value: manager.progress,
                              strokeWidth: 8,
                              backgroundColor: Colors.transparent,
                              valueColor: AlwaysStoppedAnimation(
                                isComplete
                                    ? Colors.white
                                    : isWarning
                                        ? Colors.white
                                        : AppTheme.primaryColor,
                              ),
                            ),
                          ),
                          // Time display
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                manager.displayTime,
                                style: TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                  color: isWarning || isComplete ? Colors.white : AppTheme.textPrimary,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              ),
                              if (manager.isPaused)
                                Text(
                                  'PAUSED',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isWarning || isComplete
                                        ? Colors.white70
                                        : AppTheme.textSecondary,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                
                // Controls
                if (!isComplete) ...[
                  // Time adjustment buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildControlButton(
                        icon: Icons.remove,
                        label: '-30s',
                        onTap: () => manager.subtractTime(30),
                        isWarning: isWarning,
                      ),
                      const SizedBox(width: 16),
                      _buildControlButton(
                        icon: manager.isPaused ? Icons.play_arrow : Icons.pause,
                        label: manager.isPaused ? 'Resume' : 'Pause',
                        onTap: () => manager.togglePause(),
                        isPrimary: true,
                        isWarning: isWarning,
                      ),
                      const SizedBox(width: 16),
                      _buildControlButton(
                        icon: Icons.add,
                        label: '+30s',
                        onTap: () => manager.addTime(30),
                        isWarning: isWarning,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Sound toggle
                  TextButton.icon(
                    onPressed: () => manager.toggleSound(),
                    icon: Icon(
                      manager.soundEnabled ? Icons.volume_up : Icons.volume_off,
                      size: 18,
                      color: isWarning ? Colors.white70 : AppTheme.textSecondary,
                    ),
                    label: Text(
                      manager.soundEnabled ? 'Sound On' : 'Sound Off',
                      style: TextStyle(
                        color: isWarning ? Colors.white70 : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ] else ...[
                  // Completion state
                  ElevatedButton.icon(
                    onPressed: () {
                      manager.stop();
                      manager.stopAlarm();
                      widget.onDismiss?.call();
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Done'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.successColor,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isPrimary = false,
    bool isWarning = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isPrimary
              ? (isWarning ? Colors.white24 : AppTheme.primaryColor)
              : (isWarning ? Colors.white12 : AppTheme.cardColor),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isWarning ? Colors.white : AppTheme.textPrimary,
              size: isPrimary ? 28 : 20,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isWarning ? Colors.white70 : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Minimized timer bar that appears at the top of screens
class MinimizedRestTimerBar extends StatelessWidget {
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;
  
  const MinimizedRestTimerBar({
    super.key,
    this.onTap,
    this.onDismiss,
  });
  
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: RestTimerManager(),
      builder: (context, _) {
        final manager = RestTimerManager();
        
        if (!manager.isRunning || !manager.isMinimized) {
          return const SizedBox.shrink();
        }
        
        final isWarning = manager.remainingSeconds <= 10 && manager.remainingSeconds > 0;
        final isComplete = manager.remainingSeconds == 0;
        
        return GestureDetector(
          onTap: () {
            manager.maximize();
            onTap?.call();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isComplete
                  ? AppTheme.successColor
                  : isWarning
                      ? AppTheme.warningColor
                      : AppTheme.primaryColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  const Icon(
                    Icons.timer,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isComplete ? 'Rest Complete!' : 'Rest: ${manager.displayTime}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (manager.isPaused && !isComplete) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'PAUSED',
                        style: TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ],
                  const Spacer(),
                  const Text(
                    'Tap to expand',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      manager.stop();
                      onDismiss?.call();
                    },
                    child: const Icon(
                      Icons.close,
                      color: Colors.white70,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Bottom sheet to select rest time before starting timer
class RestTimeSelector extends StatefulWidget {
  final Function(int seconds) onSelect;

  const RestTimeSelector({super.key, required this.onSelect});

  @override
  State<RestTimeSelector> createState() => _RestTimeSelectorState();
}

class _RestTimeSelectorState extends State<RestTimeSelector> {
  bool _showCustomInput = false;
  final _minutesController = TextEditingController(text: '2');
  final _secondsController = TextEditingController(text: '00');

  @override
  void dispose() {
    _minutesController.dispose();
    _secondsController.dispose();
    super.dispose();
  }

  void _submitCustomTime() {
    final minutes = int.tryParse(_minutesController.text) ?? 0;
    final seconds = int.tryParse(_secondsController.text) ?? 0;
    final total = minutes * 60 + seconds;
    if (total > 0) {
      Navigator.pop(context);
      widget.onSelect(total);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Rest Timer',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Select rest duration',
                style: TextStyle(color: Colors.grey.shade400),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildTimeOption(60, '1:00', 'Light'),
                  const SizedBox(width: 12),
                  _buildTimeOption(90, '1:30', 'Moderate'),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildTimeOption(120, '2:00', 'Heavy'),
                  const SizedBox(width: 12),
                  _buildTimeOption(180, '3:00', 'Max Effort'),
                ],
              ),
              const SizedBox(height: 10),
              if (_showCustomInput)
                _buildCustomInput()
              else
                _buildCustomButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomButton() {
    return InkWell(
      onTap: () => setState(() => _showCustomInput = true),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.edit, size: 18, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            Text(
              'Custom Time',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _minutesController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: 'min',
                labelStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text(':', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: TextField(
              controller: _secondsController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: 'sec',
                labelStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onSubmitted: (_) => _submitCustomTime(),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: _submitCustomTime,
            child: const Text('Start'),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeOption(int seconds, String time, String label) {
    return Expanded(
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          widget.onSelect(seconds);
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.cardColorLight),
          ),
          child: Column(
            children: [
              Text(
                time,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Helper function to show rest timer overlay
void showRestTimer(BuildContext context, {int seconds = 90, VoidCallback? onComplete}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black54,
    builder: (context) => Center(
      child: RestTimerWidget(
        initialSeconds: seconds,
        onComplete: () {
          // Keep dialog open to show completion state
        },
        onDismiss: () {
          Navigator.pop(context);
          onComplete?.call();
        },
        onMinimize: () {
          Navigator.pop(context);
        },
      ),
    ),
  );
}

/// Helper function to show rest time selector then start timer
void showRestTimeSelector(BuildContext context, {VoidCallback? onComplete}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => RestTimeSelector(
      onSelect: (seconds) {
        showRestTimer(context, seconds: seconds, onComplete: onComplete);
      },
    ),
  );
}
