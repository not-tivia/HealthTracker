import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart'; // If needed
import '../models/saved_stretch.dart';
import '../models/stretch_routine.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/rest_timer_widget.dart'; // Reuse for countdown

class StretchSessionScreen extends StatefulWidget {
  final StretchRoutine routine;

  const StretchSessionScreen({super.key, required this.routine});

  @override
  State<StretchSessionScreen> createState() => _StretchSessionScreenState();
}

class _StretchSessionScreenState extends State<StretchSessionScreen> {
  int _currentIndex = 0;
  late List<SavedStretch> _stretches;
  bool _isCompleted = false;

  @override
  void initState() {
    super.initState();
    _loadStretches();
  }

  Future<void> _loadStretches() async {
    final storage = context.read<StorageService>();
    _stretches = widget.routine.stretches.map((rs) {
      final saved = storage.getAllSavedStretches().firstWhere(
        (s) => s.id == rs.savedStretchId,
        orElse: () => SavedStretch(id: '', name: 'Unknown'), // Fallback
      );
      return saved.copyWith(defaultDuration: rs.overrideDuration ?? saved.defaultDuration);
    }).toList();
    setState(() {});
  }

  void _startStretchTimer(SavedStretch stretch) {
    showRestTimer(context, seconds: stretch.defaultDuration, onComplete: _nextStretch);
  }

  void _nextStretch() {
    if (_currentIndex < _stretches.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _startStretchTimer(_stretches[_currentIndex]);
    } else {
      setState(() {
        _isCompleted = true;
      });
      // Update lastUsed and timesCompleted, but NO workout history
      final storage = context.read<StorageService>();
      final updatedRoutine = widget.routine.copyWith(
        lastUsed: DateTime.now(),
        timesCompleted: widget.routine.timesCompleted + 1,
      );
      storage.saveStretchRoutine(updatedRoutine);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_stretches.isEmpty) return const Center(child: CircularProgressIndicator());

    final currentStretch = _stretches[_currentIndex];

    return Scaffold(
      appBar: AppBar(title: Text(widget.routine.name)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(currentStretch.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (currentStretch.youtubeUrl != null)
              Text('Tutorial: ${currentStretch.youtubeUrl}'),
            const SizedBox(height: 16),
            Text('Hold for: ${currentStretch.durationDisplay}'),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => _startStretchTimer(currentStretch),
              child: const Text('Start Timer'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _nextStretch,
              child: const Text('Next Stretch'),
            ),
            if (_isCompleted) const Text('Warmup Complete!'),
          ],
        ),
      ),
    );
  }
}