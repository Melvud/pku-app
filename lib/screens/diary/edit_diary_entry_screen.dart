// lib/screens/diary/edit_diary_entry_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/diary_entry.dart';
import '../../providers/diary_provider.dart';

class EditDiaryEntryScreen extends StatefulWidget {
  final DiaryEntry entry;

  const EditDiaryEntryScreen({
    super.key,
    required this.entry,
  });

  @override
  State<EditDiaryEntryScreen> createState() => _EditDiaryEntryScreenState();
}

class _EditDiaryEntryScreenState extends State<EditDiaryEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _portionController;
  late TextEditingController _pheController;
  late TextEditingController _proteinController;
  late TextEditingController _fatController;
  late TextEditingController _carbsController;
  late TextEditingController _caloriesController;

  bool _isLoading = false;
  bool _isEditing = false;

  // Store per100g values for recalculation
  late double _pheUsedPer100g;
  late double _proteinPer100g;
  double? _fatPer100g;
  double? _carbsPer100g;
  double? _caloriesPer100g;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;

    _nameController = TextEditingController(text: entry.productName);
    _portionController = TextEditingController(text: entry.portionG.toStringAsFixed(0));

    // Store per100g values
    _pheUsedPer100g = entry.pheUsedPer100g;
    _proteinPer100g = entry.portionG > 0
        ? entry.proteinInPortion / (entry.portionG / 100)
        : 0;
    _fatPer100g = entry.fatInPortion != null && entry.portionG > 0
        ? entry.fatInPortion! / (entry.portionG / 100)
        : null;
    _carbsPer100g = entry.carbsInPortion != null && entry.portionG > 0
        ? entry.carbsInPortion! / (entry.portionG / 100)
        : null;
    _caloriesPer100g = entry.caloriesInPortion != null && entry.portionG > 0
        ? entry.caloriesInPortion! / (entry.portionG / 100)
        : null;

    _pheController = TextEditingController(text: _pheUsedPer100g.toStringAsFixed(1));
    _proteinController = TextEditingController(text: _proteinPer100g.toStringAsFixed(1));
    _fatController = TextEditingController(text: _fatPer100g?.toStringAsFixed(1) ?? '');
    _carbsController = TextEditingController(text: _carbsPer100g?.toStringAsFixed(1) ?? '');
    _caloriesController = TextEditingController(text: _caloriesPer100g?.toStringAsFixed(1) ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _portionController.dispose();
    _pheController.dispose();
    _proteinController.dispose();
    _fatController.dispose();
    _carbsController.dispose();
    _caloriesController.dispose();
    super.dispose();
  }

  double get _currentPortion => double.tryParse(_portionController.text) ?? 0;
  double get _multiplier => _currentPortion / 100.0;

  double get _calculatedPhe => (double.tryParse(_pheController.text) ?? 0) * _multiplier;
  double get _calculatedProtein => (double.tryParse(_proteinController.text) ?? 0) * _multiplier;
  double? get _calculatedFat {
    final fat = double.tryParse(_fatController.text);
    return fat != null ? fat * _multiplier : null;
  }
  double? get _calculatedCarbs {
    final carbs = double.tryParse(_carbsController.text);
    return carbs != null ? carbs * _multiplier : null;
  }
  double? get _calculatedCalories {
    final cal = double.tryParse(_caloriesController.text);
    return cal != null ? cal * _multiplier : null;
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final diaryProvider = Provider.of<DiaryProvider>(context, listen: false);

      await diaryProvider.updateEntry(
        entryId: widget.entry.id,
        productName: _nameController.text.trim(),
        portionG: double.parse(_portionController.text),
        pheUsedPer100g: double.parse(_pheController.text),
        proteinPer100g: double.parse(_proteinController.text),
        fatPer100g: _fatController.text.isNotEmpty ? double.parse(_fatController.text) : null,
        carbsPer100g: _carbsController.text.isNotEmpty ? double.parse(_carbsController.text) : null,
        caloriesPer100g: _caloriesController.text.isNotEmpty ? double.parse(_caloriesController.text) : null,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Запись обновлена'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteEntry() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить запись?'),
        content: Text('Удалить "${widget.entry.productName}" из дневника?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        final diaryProvider = Provider.of<DiaryProvider>(context, listen: false);
        await diaryProvider.deleteEntry(widget.entry.id);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Запись удалена'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ошибка: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Просмотр записи'),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.lock_open : Icons.edit),
            onPressed: () => setState(() => _isEditing = !_isEditing),
            tooltip: _isEditing ? 'Заблокировать' : 'Редактировать',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _deleteEntry,
            tooltip: 'Удалить',
            color: Colors.red,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Meal type badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.restaurant,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.entry.mealType.displayName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Product name
              TextFormField(
                controller: _nameController,
                enabled: _isEditing,
                decoration: const InputDecoration(
                  labelText: 'Название продукта',
                  prefixIcon: Icon(Icons.fastfood),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Введите название';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Portion
              TextFormField(
                controller: _portionController,
                enabled: _isEditing,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Порция',
                  suffixText: 'г',
                  prefixIcon: Icon(Icons.scale),
                ),
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Введите порцию';
                  }
                  final number = double.tryParse(value);
                  if (number == null || number <= 0) {
                    return 'Введите корректное значение';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Nutrition section
              Text(
                'Пищевая ценность на 100г',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Phe
              TextFormField(
                controller: _pheController,
                enabled: _isEditing,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Фенилаланин (Phe)',
                  suffixText: 'мг на 100г',
                  prefixIcon: Icon(Icons.medical_information),
                ),
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Введите Phe';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Protein
              TextFormField(
                controller: _proteinController,
                enabled: _isEditing,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Белок',
                  suffixText: 'г на 100г',
                  prefixIcon: Icon(Icons.fitness_center),
                ),
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Введите белок';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Fat
              TextFormField(
                controller: _fatController,
                enabled: _isEditing,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Жиры',
                  suffixText: 'г на 100г',
                  prefixIcon: Icon(Icons.water_drop),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),

              // Carbs
              TextFormField(
                controller: _carbsController,
                enabled: _isEditing,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Углеводы',
                  suffixText: 'г на 100г',
                  prefixIcon: Icon(Icons.grain),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),

              // Calories
              TextFormField(
                controller: _caloriesController,
                enabled: _isEditing,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Калории',
                  suffixText: 'ккал на 100г',
                  prefixIcon: Icon(Icons.local_fire_department),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 24),

              // Calculated values card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'В вашей порции (${_currentPortion.toStringAsFixed(0)} г):',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _NutrientRow(
                      label: 'Фенилаланин',
                      value: _calculatedPhe,
                      unit: 'мг',
                      color: Colors.purple,
                    ),
                    const SizedBox(height: 8),
                    _NutrientRow(
                      label: 'Белок',
                      value: _calculatedProtein,
                      unit: 'г',
                      color: Colors.blue,
                    ),
                    if (_calculatedFat != null) ...[
                      const SizedBox(height: 8),
                      _NutrientRow(
                        label: 'Жиры',
                        value: _calculatedFat!,
                        unit: 'г',
                        color: Colors.amber,
                      ),
                    ],
                    if (_calculatedCarbs != null) ...[
                      const SizedBox(height: 8),
                      _NutrientRow(
                        label: 'Углеводы',
                        value: _calculatedCarbs!,
                        unit: 'г',
                        color: Colors.green,
                      ),
                    ],
                    if (_calculatedCalories != null) ...[
                      const SizedBox(height: 8),
                      _NutrientRow(
                        label: 'Калории',
                        value: _calculatedCalories!,
                        unit: 'ккал',
                        color: Colors.red,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Save button (only visible when editing)
              if (_isEditing)
                FilledButton.icon(
                  onPressed: _isLoading ? null : _saveChanges,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save),
                  label: const Text('Сохранить изменения'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NutrientRow extends StatelessWidget {
  final String label;
  final double value;
  final String unit;
  final Color color;

  const _NutrientRow({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
        Text(
          '${value.toStringAsFixed(1)} $unit',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
