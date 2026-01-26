import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/saved_stretch.dart';
import '../models/stretch_routine.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/rest_timer_widget.dart';

class StretchSessionScreen extends StatefulWidget {
  final StretchRoutine routine;

  const StretchSessionScreen({super.key, required this.routine});

  @override
  State<StretchSessionScreen> createState() => _StretchSessionScreenState();
}

class _StretchSessionScreenState extends State<StretchSessionScreen> {
  int _currentIndex = 0;
  List<SavedStretch> _stretches = [];
  List<RoutineStretch> _routineStretches = [];
  bool _isCompleted = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStretches();
  }

  Future<void> _loadStretches() async {
    final storage = context.read<StorageService>();
    final allStretches = storage.getAllSavedStretches();
    
    _routineStretches = widget.routine.stretches;
    _stretches = _routineStretches.map((rs) {
      final saved = allStretches.firstWhere(
        (s) => s.id == rs.savedStretchId,
        orElse: () => SavedStretch(id: '', name: 'Unknown Stretch'),
      );
      // Apply override duration if set
      return saved.copyWith(
        defaultDuration: rs.overrideDuration ?? saved.defaultDuration,
      );
    }).toList();
    
    setState(() {
      _isLoading = false;
    });
  }

  void _startStretchTimer(SavedStretch stretch) {
    showRestTimer(
      context, 
      seconds: stretch.defaultDuration, 
      onComplete: () {
        // Timer completed - user can manually advance
      },
    );
  }

  void _nextStretch() {
    if (_currentIndex < _stretches.length - 1) {
      setState(() {
        _currentIndex++;
      });
    } else {
      _completeSession();
    }
  }

  void _previousStretch() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
    }
  }

  void _completeSession() {
    setState(() {
      _isCompleted = true;
    });
    
    // Update routine stats
    final storage = context.read<StorageService>();
    final updatedRoutine = widget.routine.copyWith(
      lastUsed: DateTime.now(),
      timesCompleted: widget.routine.timesCompleted + 1,
    );
    storage.saveStretchRoutine(updatedRoutine);
    
    // Show completion dialog
    _showCompletionDialog();
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade400, size: 28),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Session Complete!',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Great job completing your stretch routine!',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            Text(
              '${_stretches.length} stretches completed',
              style: TextStyle(color: Colors.grey.shade400),
            ),
            Text(
              'Total time: ${_getTotalDuration()} minutes',
              style: TextStyle(color: Colors.grey.shade400),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Return to workout tab
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  int _getTotalDuration() {
    return (_stretches.fold<int>(0, (sum, s) => sum + s.defaultDuration) / 60).ceil();
  }

  Future<void> _launchYouTube(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open YouTube')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _stretches.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(widget.routine.name),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final currentStretch = _stretches[_currentIndex];
    final routineStretch = _routineStretches[_currentIndex];
    final progress = (_currentIndex + 1) / _stretches.length;

    return Scaffold(
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(widget.routine.name),
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '${_currentIndex + 1}/${_stretches.length}',
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress bar
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.shade800,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.teal),
            minHeight: 4,
          ),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Photo or placeholder
                  _buildStretchImage(currentStretch),
                  const SizedBox(height: 24),
                  
                  // Stretch name
                  Text(
                    currentStretch.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  
                  // Muscle group badge
                  if (currentStretch.muscleGroup != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        currentStretch.muscleGroup!,
                        style: const TextStyle(color: Colors.teal, fontSize: 13),
                      ),
                    ),
                  const SizedBox(height: 24),
                  
                  // Duration display
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.cardColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Hold for',
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${currentStretch.defaultDuration} seconds',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Start Timer button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _startStretchTimer(currentStretch),
                      icon: const Icon(Icons.timer, size: 24),
                      label: const Text(
                        'Start Timer',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // YouTube button
                  if (currentStretch.youtubeUrl != null && currentStretch.youtubeUrl!.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _launchYouTube(currentStretch.youtubeUrl!),
                        icon: const Icon(Icons.play_circle_outline, size: 24, color: Colors.red),
                        label: const Text(
                          'Watch Tutorial',
                          style: TextStyle(fontSize: 16),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade300,
                          side: BorderSide(color: Colors.red.shade300),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  
                  // Notes section
                  if (currentStretch.notes != null && currentStretch.notes!.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade800),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.lightbulb_outline, 
                                   color: Colors.amber.shade400, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Tips',
                                style: TextStyle(
                                  color: Colors.amber.shade400,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            currentStretch.notes!,
                            style: TextStyle(
                              color: Colors.grey.shade300,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  // Routine-specific notes
                  if (routineStretch.notes != null && routineStretch.notes!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.teal.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.note, color: Colors.teal, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Routine Notes',
                                style: TextStyle(
                                  color: Colors.teal,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            routineStretch.notes!,
                            style: TextStyle(
                              color: Colors.grey.shade300,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 100), // Space for bottom nav
                ],
              ),
            ),
          ),
        ],
      ),
      
      // Bottom navigation
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          border: Border(
            top: BorderSide(color: Colors.grey.shade800),
          ),
        ),
        child: SafeArea(
          child: Row(
            children: [
              // Previous button
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _currentIndex > 0 ? _previousStretch : null,
                  icon: const Icon(Icons.arrow_back, size: 20),
                  label: const Text('Previous'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade300,
                    side: BorderSide(
                      color: _currentIndex > 0 
                          ? Colors.grey.shade600 
                          : Colors.grey.shade800,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Next / Complete button
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _nextStretch,
                  icon: Icon(
                    _currentIndex < _stretches.length - 1 
                        ? Icons.arrow_forward 
                        : Icons.check,
                    size: 20,
                  ),
                  label: Text(
                    _currentIndex < _stretches.length - 1 
                        ? 'Next Stretch' 
                        : 'Complete',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _currentIndex < _stretches.length - 1 
                        ? Colors.teal 
                        : Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStretchImage(SavedStretch stretch) {
    if (stretch.photoPath != null && stretch.photoPath!.isNotEmpty) {
      final file = File(stretch.photoPath!);
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.file(
          file,
          width: double.infinity,
          height: 200,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildPlaceholderImage(),
        ),
      );
    }
    return _buildPlaceholderImage();
  }

  Widget _buildPlaceholderImage() {
    return Container(
      width: double.infinity,
      height: 180,
      decoration: BoxDecoration(
        color: Colors.teal.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.teal.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.self_improvement,
            size: 64,
            color: Colors.teal.withOpacity(0.5),
          ),
          const SizedBox(height: 8),
          Text(
            'No image',
            style: TextStyle(
              color: Colors.teal.withOpacity(0.5),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
