import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/app_theme.dart';
import '../services/storage_service.dart';
import '../models/weight_entry.dart';
import 'photo_compare_screen.dart';

class ProgressTab extends StatefulWidget {
  const ProgressTab({super.key});

  @override
  State<ProgressTab> createState() => _ProgressTabState();
}

class _ProgressTabState extends State<ProgressTab> {
  List<WeightEntry> _selectedForCompare = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Consumer<StorageService>(
          builder: (context, storage, _) {
            List<WeightEntry> entries = storage.getWeightEntries();

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 24),
                        if (entries.isNotEmpty) ...[
                          _buildWeightChart(entries),
                          const SizedBox(height: 20),
                        ],
                        _buildStatsRow(entries, storage),
                        const SizedBox(height: 20),
                        if (_selectedForCompare.length >= 2)
                          _buildCompareButton(),
                        _buildEntriesHeader(entries),
                      ],
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      WeightEntry entry = entries[index];
                      return _buildWeightEntryTile(entry, storage);
                    },
                    childCount: entries.length,
                  ),
                ),
                SliverToBoxAdapter(
                  child: const SizedBox(height: 100),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddWeightDialog(context),
        icon: Icon(Icons.add),
        label: Text('Log Weight'),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }

  Widget _buildHeader() {
    return Text(
      'Progress',
      style: Theme.of(context).textTheme.headlineMedium,
    );
  }

  Widget _buildWeightChart(List<WeightEntry> entries) {
    if (entries.isEmpty) return const SizedBox.shrink();

    List<WeightEntry> sortedEntries = List.from(entries)
      ..sort((a, b) => a.date.compareTo(b.date));

    if (sortedEntries.length > 30) {
      sortedEntries = sortedEntries.sublist(sortedEntries.length - 30);
    }

    double minWeight = sortedEntries.map((e) => e.weight).reduce((a, b) => a < b ? a : b);
    double maxWeight = sortedEntries.map((e) => e.weight).reduce((a, b) => a > b ? a : b);
    double range = maxWeight - minWeight;
    if (range < 10) range = 10;

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: range / 4,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: AppTheme.cardColorLight,
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 45,
                interval: range / 4,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${value.toInt()}',
                    style: TextStyle(
                      color: AppTheme.textTertiary,
                      fontSize: 10,
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: (sortedEntries.length / 4).ceil().toDouble(),
                getTitlesWidget: (value, meta) {
                  int index = value.toInt();
                  if (index >= 0 && index < sortedEntries.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        DateFormat('M/d').format(sortedEntries[index].date),
                        style: TextStyle(
                          color: AppTheme.textTertiary,
                          fontSize: 10,
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (sortedEntries.length - 1).toDouble(),
          minY: minWeight - range * 0.1,
          maxY: maxWeight + range * 0.1,
          lineBarsData: [
            LineChartBarData(
              spots: sortedEntries.asMap().entries.map((e) {
                return FlSpot(e.key.toDouble(), e.value.weight);
              }).toList(),
              isCurved: true,
              color: AppTheme.primaryColor,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 4,
                    color: AppTheme.primaryColor,
                    strokeWidth: 2,
                    strokeColor: AppTheme.backgroundColor,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              tooltipBgColor: AppTheme.cardColorLight,
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  int index = spot.spotIndex;
                  if (index >= 0 && index < sortedEntries.length) {
                    WeightEntry entry = sortedEntries[index];
                    return LineTooltipItem(
                      '${entry.weight} ${entry.unit}\n${DateFormat('MMM d').format(entry.date)}',
                      TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                    );
                  }
                  return null;
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow(List<WeightEntry> entries, StorageService storage) {
    WeightEntry? latest = entries.isNotEmpty ? entries.first : null;
    WeightEntry? oldest = entries.length > 1 ? entries.last : null;

    double? change;
    if (latest != null && oldest != null) {
      change = latest.weight - oldest.weight;
    }

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Current',
            latest != null ? '${latest.weight}' : '--',
            storage.settings.weightUnit,
            AppTheme.primaryColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Change',
            change != null
                ? '${change > 0 ? '+' : ''}${change.toStringAsFixed(1)}'
                : '--',
            storage.settings.weightUnit,
            change != null
                ? (change > 0 ? AppTheme.accentColor : AppTheme.successColor)
                : AppTheme.textTertiary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Entries',
            entries.length.toString(),
            'total',
            AppTheme.secondaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, String unit, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppTheme.textTertiary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          // FittedBox ensures text scales down if needed
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    unit,
                    style: TextStyle(
                      color: AppTheme.textTertiary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompareButton() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PhotoCompareScreen(entries: _selectedForCompare),
              ),
            );
          },
          icon: Icon(Icons.compare_arrows),
          label: Text('Compare ${_selectedForCompare.length} Photos'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.secondaryColor,
          ),
        ),
      ),
    );
  }

  Widget _buildEntriesHeader(List<WeightEntry> entries) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Weight Log',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (_selectedForCompare.isNotEmpty)
          TextButton(
            onPressed: () {
              setState(() {
                _selectedForCompare.clear();
              });
            },
            child: Text('Clear Selection'),
          ),
      ],
    );
  }

  Widget _buildWeightEntryTile(WeightEntry entry, StorageService storage) {
    bool isSelected = _selectedForCompare.contains(entry);
    bool hasPhoto = entry.photoPath != null && entry.photoPath!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: () => _showEntryDetails(entry),
        onLongPress: hasPhoto
            ? () {
                setState(() {
                  if (isSelected) {
                    _selectedForCompare.remove(entry);
                  } else {
                    _selectedForCompare.add(entry);
                  }
                });
              }
            : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryColor.withValues(alpha: 0.2)
                : AppTheme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: isSelected
                ? Border.all(color: AppTheme.primaryColor, width: 2)
                : null,
          ),
          child: Row(
            children: [
              if (hasPhoto) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(entry.photoPath!),
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 60,
                      height: 60,
                      color: AppTheme.cardColorLight,
                      child: Icon(Icons.broken_image, color: AppTheme.textTertiary),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
              ] else ...[
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppTheme.cardColorLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.monitor_weight_outlined,
                    color: AppTheme.textTertiary,
                  ),
                ),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEEE, MMM d, yyyy').format(entry.date),
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${entry.weight} ${entry.unit}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (entry.notes != null && entry.notes!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          entry.notes!,
                          style: TextStyle(
                            color: AppTheme.textTertiary,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              if (hasPhoto)
                Icon(
                  isSelected ? Icons.check_circle : Icons.photo,
                  color: isSelected ? AppTheme.primaryColor : AppTheme.textTertiary,
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEntryDetails(WeightEntry entry) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _WeightEntryDetails(entry: entry),
    );
  }

  void _showAddWeightDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _AddWeightDialog(),
    );
  }
}

class _WeightEntryDetails extends StatelessWidget {
  final WeightEntry entry;

  const _WeightEntryDetails({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: entry.photoPath != null
          ? MediaQuery.of(context).size.height * 0.7
          : MediaQuery.of(context).size.height * 0.4,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.textTertiary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('MMMM d, yyyy').format(entry.date),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  onPressed: () {
                    context.read<StorageService>().deleteWeightEntry(entry.id);
                    Navigator.pop(context);
                  },
                  icon: Icon(Icons.delete_outline, color: AppTheme.accentColor),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (entry.photoPath != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(
                        File(entry.photoPath!),
                        width: double.infinity,
                        height: 300,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 300,
                          color: AppTheme.cardColor,
                          child: Center(
                            child: Icon(Icons.broken_image, size: 48),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.cardColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.monitor_weight_outlined,
                            color: AppTheme.primaryColor, size: 32),
                        const SizedBox(width: 16),
                        Text(
                          '${entry.weight}',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          entry.unit,
                          style: TextStyle(
                            fontSize: 20,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (entry.notes != null && entry.notes!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.cardColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Notes',
                            style: TextStyle(
                              color: AppTheme.textTertiary,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            entry.notes!,
                            style: TextStyle(color: AppTheme.textPrimary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddWeightDialog extends StatefulWidget {
  const _AddWeightDialog();

  @override
  State<_AddWeightDialog> createState() => _AddWeightDialogState();
}

class _AddWeightDialogState extends State<_AddWeightDialog> {
  final _weightController = TextEditingController();
  final _notesController = TextEditingController();
  File? _selectedPhoto;
  bool _isLoading = false;

  @override
  void dispose() {
    _weightController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.textTertiary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Log Weight',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Consumer<StorageService>(
                    builder: (context, storage, _) {
                      return TextFormField(
                        controller: _weightController,
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Weight',
                          suffixText: storage.settings.weightUnit,
                          prefixIcon: Icon(Icons.monitor_weight_outlined),
                        ),
                        autofocus: true,
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  Text(
                    'Progress Photo (optional)',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_selectedPhoto != null)
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.file(
                            _selectedPhoto!,
                            width: double.infinity,
                            height: 200,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: IconButton(
                            onPressed: () => setState(() => _selectedPhoto = null),
                            icon: Icon(Icons.close),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: _buildPhotoButton(
                            Icons.camera_alt,
                            'Camera',
                            () => _pickImage(ImageSource.camera),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildPhotoButton(
                            Icons.photo_library,
                            'Gallery',
                            () => _pickImage(ImageSource.gallery),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 20),

                  TextFormField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Notes (optional)',
                      hintText: 'How are you feeling?',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveEntry,
                      child: _isLoading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text('Save'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.cardColorLight),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: AppTheme.primaryColor),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedPhoto = File(image.path);
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _saveEntry() async {
    double? weight = double.tryParse(_weightController.text);
    if (weight == null || weight <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a valid weight')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      StorageService storage = context.read<StorageService>();
      String? photoPath;

      if (_selectedPhoto != null) {
        photoPath = await storage.savePhoto(_selectedPhoto!, 'weight');
      }

      WeightEntry entry = WeightEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        date: DateTime.now(),
        weight: weight,
        photoPath: photoPath,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        unit: storage.settings.weightUnit,
      );

      await storage.saveWeightEntry(entry);
      
      // Auto-update userWeight in settings
      final updatedSettings = storage.settings.copyWith(userWeight: weight);
      await storage.saveUserSettings(updatedSettings);
      
      Navigator.pop(context);
    } catch (e) {
      debugPrint('Error saving entry: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving entry')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
