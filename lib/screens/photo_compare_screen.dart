import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/weight_entry.dart';

class PhotoCompareScreen extends StatefulWidget {
  final List<WeightEntry> entries;

  const PhotoCompareScreen({super.key, required this.entries});

  @override
  State<PhotoCompareScreen> createState() => _PhotoCompareScreenState();
}

class _PhotoCompareScreenState extends State<PhotoCompareScreen> {
  int _currentIndex = 0;
  bool _showFullscreen = false;
  int _fullscreenIndex = 0;

  @override
  Widget build(BuildContext context) {
    final sortedEntries = List<WeightEntry>.from(widget.entries)
      ..sort((a, b) => a.date.compareTo(b.date));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Compare Progress (${sortedEntries.length} photos)'),
        actions: [
          if (sortedEntries.length > 2)
            IconButton(
              icon: const Icon(Icons.view_carousel),
              onPressed: () => _showCarouselMode(context, sortedEntries),
              tooltip: 'Carousel View',
            ),
        ],
      ),
      body: _showFullscreen
          ? _buildFullscreenView(sortedEntries)
          : _buildComparisonView(sortedEntries),
    );
  }

  Widget _buildComparisonView(List<WeightEntry> entries) {
    if (entries.length == 2) {
      return _buildTwoPhotoComparison(entries);
    } else {
      return _buildMultiPhotoGrid(entries);
    }
  }

  Widget _buildTwoPhotoComparison(List<WeightEntry> entries) {
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: _buildPhotoCard(entries[0], 'Before')),
              const SizedBox(width: 8),
              Expanded(child: _buildPhotoCard(entries[1], 'After')),
            ],
          ),
        ),
        _buildComparisonStats(entries[0], entries[1]),
      ],
    );
  }

  Widget _buildMultiPhotoGrid(List<WeightEntry> entries) {
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            itemCount: (entries.length / 2).ceil(),
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (context, pageIndex) {
              final startIdx = pageIndex * 2;
              final endIdx = (startIdx + 2).clamp(0, entries.length);
              final pageEntries = entries.sublist(startIdx, endIdx);

              return Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: pageEntries.map((entry) {
                    final idx = entries.indexOf(entry);
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: _buildPhotoCard(
                          entry,
                          idx == 0 ? 'Start' : (idx == entries.length - 1 ? 'Latest' : ''),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ),
        if (entries.length > 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                (entries.length / 2).ceil(),
                (index) => Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentIndex == index
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.shade600,
                  ),
                ),
              ),
            ),
          ),
        _buildOverallStats(entries),
      ],
    );
  }

  Widget _buildPhotoCard(WeightEntry entry, String label) {
    final dateFormat = DateFormat('MMM d, yyyy');
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _showFullscreen = true;
          _fullscreenIndex = widget.entries.indexOf(entry);
        });
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (label.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            Expanded(
              child: Container(
                color: Colors.grey.shade900,
                child: entry.photoPath != null
                    ? InteractiveViewer(
                        minScale: 1.0,
                        maxScale: 4.0,
                        child: Image.file(
                          File(entry.photoPath!),
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stack) => Container(
                            color: Colors.grey.shade800,
                            child: const Icon(Icons.broken_image, size: 48),
                          ),
                        ),
                      )
                    : Container(
                        color: Colors.grey.shade800,
                        child: const Icon(Icons.photo, size: 48),
                      ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              color: Theme.of(context).cardColor,
              child: Column(
                children: [
                  Text(
                    '${entry.weight.toStringAsFixed(1)} lbs',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateFormat.format(entry.date),
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonStats(WeightEntry before, WeightEntry after) {
    final weightDiff = after.weight - before.weight;
    final daysDiff = after.date.difference(before.date).inDays;
    final isLoss = weightDiff < 0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            'Change',
            '${isLoss ? '' : '+'}${weightDiff.toStringAsFixed(1)} lbs',
            isLoss ? Colors.green : Colors.red,
          ),
          _buildStatItem(
            'Duration',
            '$daysDiff days',
            Theme.of(context).colorScheme.primary,
          ),
          if (daysDiff > 0)
            _buildStatItem(
              'Rate',
              '${(weightDiff / (daysDiff / 7)).toStringAsFixed(1)} lbs/wk',
              Theme.of(context).colorScheme.secondary,
            ),
        ],
      ),
    );
  }

  Widget _buildOverallStats(List<WeightEntry> entries) {
    if (entries.length < 2) return const SizedBox.shrink();

    final first = entries.first;
    final last = entries.last;
    final weightDiff = last.weight - first.weight;
    final daysDiff = last.date.difference(first.date).inDays;
    final isLoss = weightDiff < 0;

    final highest = entries.reduce((a, b) => a.weight > b.weight ? a : b);
    final lowest = entries.reduce((a, b) => a.weight < b.weight ? a : b);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                'Total Change',
                '${isLoss ? '' : '+'}${weightDiff.toStringAsFixed(1)} lbs',
                isLoss ? Colors.green : Colors.red,
              ),
              _buildStatItem(
                'Over',
                '$daysDiff days',
                Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                'Highest',
                '${highest.weight.toStringAsFixed(1)} lbs',
                Colors.orange,
              ),
              _buildStatItem(
                'Lowest',
                '${lowest.weight.toStringAsFixed(1)} lbs',
                Colors.blue,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildFullscreenView(List<WeightEntry> entries) {
    final entry = entries[_fullscreenIndex];
    final dateFormat = DateFormat('MMMM d, yyyy');

    return GestureDetector(
      onTap: () => setState(() => _showFullscreen = false),
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity! < 0 && _fullscreenIndex < entries.length - 1) {
          setState(() => _fullscreenIndex++);
        } else if (details.primaryVelocity! > 0 && _fullscreenIndex > 0) {
          setState(() => _fullscreenIndex--);
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (entry.photoPath != null)
            Image.file(
              File(entry.photoPath!),
              fit: BoxFit.contain,
            )
          else
            Container(
              color: Colors.grey.shade900,
              child: const Icon(Icons.photo, size: 64),
            ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.8),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                children: [
                  Text(
                    '${entry.weight.toStringAsFixed(1)} lbs',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    dateFormat.format(entry.date),
                    style: TextStyle(
                      color: Colors.grey.shade300,
                      fontSize: 16,
                    ),
                  ),
                  if (entry.notes != null && entry.notes!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        entry.notes!,
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    '${_fullscreenIndex + 1} / ${entries.length}',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 40,
            right: 16,
            child: IconButton(
              onPressed: () => setState(() => _showFullscreen = false),
              icon: const Icon(Icons.close, size: 32),
            ),
          ),
        ],
      ),
    );
  }

  void _showCarouselMode(BuildContext context, List<WeightEntry> entries) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade600,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Progress Timeline',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    final dateFormat = DateFormat('MMM d, yyyy');
                    final prevEntry = index > 0 ? entries[index - 1] : null;
                    final diff = prevEntry != null
                        ? entry.weight - prevEntry.weight
                        : 0.0;

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            if (index < entries.length - 1)
                              Container(
                                width: 2,
                                height: 120,
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.3),
                              ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  if (entry.photoPath != null)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(
                                        File(entry.photoPath!),
                                        width: 80,
                                        height: 80,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  else
                                    Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade800,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.photo),
                                    ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          dateFormat.format(entry.date),
                                          style: TextStyle(
                                            color: Colors.grey.shade400,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${entry.weight.toStringAsFixed(1)} lbs',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (prevEntry != null)
                                          Text(
                                            '${diff < 0 ? '' : '+'}${diff.toStringAsFixed(1)} lbs',
                                            style: TextStyle(
                                              color: diff < 0
                                                  ? Colors.green
                                                  : Colors.red,
                                              fontSize: 12,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
