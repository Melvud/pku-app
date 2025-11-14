import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/diary_provider.dart';
import '../../models/diary_entry.dart';

class AddCustomProductScreen extends StatefulWidget {
  final MealType mealType;

  const AddCustomProductScreen({
    super.key,
    required this.mealType,
  });

  @override
  State<AddCustomProductScreen> createState() => _AddCustomProductScreenState();
}

class _AddCustomProductScreenState extends State<AddCustomProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _portionController = TextEditingController(text: '100');
  final _pheController = TextEditingController();
  final _proteinController = TextEditingController();
  final _fatController = TextEditingController();
  final _carbsController = TextEditingController();
  final _caloriesController = TextEditingController();

  bool _isLoading = false;

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

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final diaryProvider = Provider.of<DiaryProvider>(context, listen: false);

      await diaryProvider.addCustomEntry(
        productName: _nameController.text,
        portionG: double.parse(_portionController.text),
        pheUsedPer100g: double.parse(_pheController.text),
        proteinPer100g: double.parse(_proteinController.text),
        mealType: widget.mealType,
        fatPer100g: _fatController.text.isNotEmpty ? double.parse(_fatController.text) : null,
        carbsPer100g: _carbsController.text.isNotEmpty ? double.parse(_carbsController.text) : null,
        caloriesPer100g: _caloriesController.text.isNotEmpty ? double.parse(_caloriesController.text) : null,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_nameController.text} добавлен в ${widget.mealType.displayName}'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Добавить свой продукт'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info Card
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Добавление в: ${widget.mealType.displayName}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Product Name
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Название продукта *',
                  hintText: 'Например: Яблоко красное',
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
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Порция *',
                  hintText: '100',
                  suffixText: 'г',
                  prefixIcon: Icon(Icons.scale),
                ),
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

              // Required Nutrients Section
              Text(
                'Обязательные показатели (на 100г)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),

              // Phe
              TextFormField(
                controller: _pheController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Фенилаланин (Phe) *',
                  hintText: '50',
                  suffixText: 'мг на 100г',
                  prefixIcon: Icon(Icons.medical_information),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Введите содержание Phe';
                  }
                  final number = double.tryParse(value);
                  if (number == null || number < 0) {
                    return 'Введите корректное значение';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Protein
              TextFormField(
                controller: _proteinController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Белок *',
                  hintText: '1.5',
                  suffixText: 'г на 100г',
                  prefixIcon: Icon(Icons.fitness_center),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Введите содержание белка';
                  }
                  final number = double.tryParse(value);
                  if (number == null || number < 0) {
                    return 'Введите корректное значение';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Optional Nutrients Section
              Text(
                'Дополнительные показатели (необязательно)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),

              // Fat
              TextFormField(
                controller: _fatController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Жиры',
                  hintText: '0.5',
                  suffixText: 'г на 100г',
                  prefixIcon: Icon(Icons.water_drop),
                ),
              ),
              const SizedBox(height: 16),

              // Carbs
              TextFormField(
                controller: _carbsController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Углеводы',
                  hintText: '12',
                  suffixText: 'г на 100г',
                  prefixIcon: Icon(Icons.grain),
                ),
              ),
              const SizedBox(height: 16),

              // Calories
              TextFormField(
                controller: _caloriesController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Калории',
                  hintText: '52',
                  suffixText: 'ккал на 100г',
                  prefixIcon: Icon(Icons.local_fire_department),
                ),
              ),
              const SizedBox(height: 32),

              // Submit Button
              FilledButton(
                onPressed: _isLoading ? null : _handleSubmit,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Добавить в дневник',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
              const SizedBox(height: 16),

              // Note
              Card(
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        size: 20,
                        color: Theme.of(context).colorScheme.onSecondaryContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Пищевую ценность можно найти на упаковке продукта. '
                          'Данные обычно указаны на 100г продукта.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}