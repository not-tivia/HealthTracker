import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_theme.dart';
import '../services/storage_service.dart';
import '../models/food_entry.dart';
import '../models/food_library_item.dart';

class FoodEntryDialog extends StatefulWidget {
  final FoodEntry? existingEntry;

  const FoodEntryDialog({super.key, this.existingEntry});

  @override
  State<FoodEntryDialog> createState() => _FoodEntryDialogState();
}

class _FoodEntryDialogState extends State<FoodEntryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatsController = TextEditingController();
  final _servingSizeController = TextEditingController(text: '1');
  final _servingUnitController = TextEditingController(text: 'serving');

  String _selectedMealType = 'lunch';
  bool _showTemplates = true;
  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingEntry != null) {
      _nameController.text = widget.existingEntry!.name;
      _caloriesController.text = widget.existingEntry!.calories.toString();
      _proteinController.text = widget.existingEntry!.protein.toString();
      _carbsController.text = widget.existingEntry!.carbs.toString();
      _fatsController.text = widget.existingEntry!.fats.toString();
      _selectedMealType = widget.existingEntry!.mealType;
      _showTemplates = false;
    }
    
    // Listen for changes to track unsaved state
    _nameController.addListener(_onFieldChanged);
    _caloriesController.addListener(_onFieldChanged);
    _proteinController.addListener(_onFieldChanged);
    _carbsController.addListener(_onFieldChanged);
    _fatsController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (!_hasUnsavedChanges && _nameController.text.isNotEmpty) {
      setState(() => _hasUnsavedChanges = true);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatsController.dispose();
    _servingSizeController.dispose();
    _servingUnitController.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges || _nameController.text.isEmpty) {
      return true;
    }
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard Changes?'),
        content: const Text('You have unsaved changes. Are you sure you want to go back?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.accentColor),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    
    return result ?? false;
  }

  void _handleClose() async {
    if (await _onWillPop()) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await _onWillPop()) {
          Navigator.pop(context);
        }
      },
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
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
                    widget.existingEntry != null ? 'Edit Food' : 'Add Food',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  IconButton(
                    onPressed: _handleClose,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_showTemplates && widget.existingEntry == null) ...[
                        Text('Common Foods', style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: CommonFoods.templates.map((food) {
                            return InkWell(
                              onTap: () => _useTemplate(food),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppTheme.cardColor,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppTheme.cardColorLight),
                                ),
                                child: Text(food.name, style: const TextStyle(fontSize: 13)),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),
                        Divider(color: AppTheme.cardColorLight),
                        const SizedBox(height: 20),
                        Text('Or enter custom food', style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 12),
                      ],
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Food Name',
                          hintText: 'e.g., Chicken Breast',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a food name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      Text('Meal Type', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildMealTypeChip('breakfast', 'Breakfast'),
                          const SizedBox(width: 8),
                          _buildMealTypeChip('lunch', 'Lunch'),
                          const SizedBox(width: 8),
                          _buildMealTypeChip('dinner', 'Dinner'),
                          const SizedBox(width: 8),
                          _buildMealTypeChip('snack', 'Snack'),
                        ],
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _caloriesController,
                        decoration: const InputDecoration(labelText: 'Calories', suffixText: 'kcal'),
                        keyboardType: TextInputType.number,
                        validator: (value) => (value == null || value.isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _proteinController,
                              decoration: const InputDecoration(labelText: 'Protein', suffixText: 'g'),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _carbsController,
                              decoration: const InputDecoration(labelText: 'Carbs', suffixText: 'g'),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _fatsController,
                              decoration: const InputDecoration(labelText: 'Fats', suffixText: 'g'),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _servingSizeController,
                              decoration: const InputDecoration(labelText: 'Serving Size'),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _servingUnitController,
                              decoration: const InputDecoration(labelText: 'Unit', hintText: 'e.g., cup, oz, piece'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _saveEntry,
                          child: const Text('Save'),
                        ),
                      ),
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

  Widget _buildMealTypeChip(String value, String label) {
    bool isSelected = _selectedMealType == value;
    
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedMealType = value),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryColor : AppTheme.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppTheme.primaryColor : AppTheme.cardColorLight,
            ),
          ),
          child: Center(
            child: Text(
              label,
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

  void _useTemplate(FoodEntry template) {
    setState(() {
      _nameController.text = template.name;
      _caloriesController.text = template.calories.toString();
      _proteinController.text = template.protein.toString();
      _carbsController.text = template.carbs.toString();
      _fatsController.text = template.fats.toString();
      _servingSizeController.text = template.servingSize.toString();
      _servingUnitController.text = template.servingUnit;
      _showTemplates = false;
      _hasUnsavedChanges = true;
    });
  }

  void _saveEntry() {
    if (_formKey.currentState!.validate()) {
      final storage = context.read<StorageService>();
      
      // Create food entry
      FoodEntry entry = FoodEntry(
        id: widget.existingEntry?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text,
        date: DateTime.now(),
        mealType: _selectedMealType,
        calories: double.tryParse(_caloriesController.text) ?? 0,
        protein: double.tryParse(_proteinController.text) ?? 0,
        carbs: double.tryParse(_carbsController.text) ?? 0,
        fats: double.tryParse(_fatsController.text) ?? 0,
        servingSize: double.tryParse(_servingSizeController.text) ?? 1,
        servingUnit: _servingUnitController.text,
      );

      // Save to today's entries
      storage.saveFoodEntry(entry);
      
      // Also save/update in food library for future use
      storage.addToFoodLibrary(
        name: _nameController.text,
        calories: double.tryParse(_caloriesController.text) ?? 0,
        protein: double.tryParse(_proteinController.text) ?? 0,
        carbs: double.tryParse(_carbsController.text) ?? 0,
        fats: double.tryParse(_fatsController.text) ?? 0,
        servingSize: double.tryParse(_servingSizeController.text) ?? 1,
        servingUnit: _servingUnitController.text,
      );
      
      _hasUnsavedChanges = false;
      Navigator.pop(context);
    }
  }
}

/// Dialog to show the food library
class FoodLibraryDialog extends StatefulWidget {
  final Function(FoodLibraryItem)? onSelect;
  
  const FoodLibraryDialog({super.key, this.onSelect});

  @override
  State<FoodLibraryDialog> createState() => _FoodLibraryDialogState();
}

class _FoodLibraryDialogState extends State<FoodLibraryDialog> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
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
                Text('Food Library', style: Theme.of(context).textTheme.titleLarge),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('\u{1F4DA}', style: TextStyle(fontSize: 24)), // 📚
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search foods...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: AppTheme.cardColor,
              ),
              onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
            ),
          ),
          Expanded(
            child: Consumer<StorageService>(
              builder: (context, storage, _) {
                final items = storage.getFoodLibrary();
                final filtered = _searchQuery.isEmpty
                    ? items
                    : items.where((item) => item.name.toLowerCase().contains(_searchQuery)).toList();
                
                // Sort by last used (most recent first)
                filtered.sort((a, b) => b.lastUsed.compareTo(a.lastUsed));
                
                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.fastfood_outlined, size: 48, color: AppTheme.textTertiary),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty 
                              ? 'No foods saved yet'
                              : 'No foods match your search',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                        if (_searchQuery.isEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Foods you add will appear here',
                            style: TextStyle(color: AppTheme.textTertiary, fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  );
                }
                
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return Dismissible(
                      key: Key(item.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16),
                        color: AppTheme.accentColor,
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (_) async {
                        return await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Delete Food?'),
                            content: Text('Remove "${item.name}" from your library?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: FilledButton.styleFrom(backgroundColor: AppTheme.accentColor),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        ) ?? false;
                      },
                      onDismissed: (_) => storage.deleteFoodLibraryItem(item.id),
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          onTap: () {
                            if (widget.onSelect != null) {
                              widget.onSelect!(item);
                              Navigator.pop(context);
                            }
                          },
                          title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                          subtitle: Text(
                            '${item.caloriesDisplay}  ${item.macrosDisplay}',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (item.useCount > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${item.useCount}x',
                                    style: TextStyle(color: AppTheme.primaryColor, fontSize: 11),
                                  ),
                                ),
                              const SizedBox(width: 8),
                              Icon(Icons.chevron_right, color: AppTheme.textTertiary),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Show food library dialog
Future<FoodLibraryItem?> showFoodLibraryDialog(BuildContext context) async {
  FoodLibraryItem? selected;
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => FoodLibraryDialog(
      onSelect: (item) => selected = item,
    ),
  );
  return selected;
}
