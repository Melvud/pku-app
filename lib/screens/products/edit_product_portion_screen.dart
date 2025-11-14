// lib/screens/products/edit_product_portion_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/diary_provider.dart';
import '../../providers/products_provider.dart';
import '../../models/product.dart';
import '../../models/diary_entry.dart';

class EditProductPortionScreen extends StatefulWidget {
  final Product product;
  final MealType mealType;

  const EditProductPortionScreen({
    super.key,
    required this.product,
    required this.mealType,
  });

  @override
  State<EditProductPortionScreen> createState() => _EditProductPortionScreenState();
}

class _EditProductPortionScreenState extends State<EditProductPortionScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _portionController;
  late TextEditingController _pheController;
  late TextEditingController _proteinController;
  late TextEditingController _fatController;
  late TextEditingController _carbsController;
  late TextEditingController _caloriesController;

  bool _isLoading = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _portionController = TextEditingController(text: '100');
    _pheController = TextEditingController(
      text: widget.product.pheToUse.toStringAsFixed(1),
    );
    _proteinController = TextEditingController(
      text: widget.product.proteinPer100g.toStringAsFixed(1),
    );
    _fatController = TextEditingController(
      text: widget.product.fatPer100g?.toStringAsFixed(1) ?? '',
    );
    _carbsController = TextEditingController(
      text: widget.product.carbsPer100g?.toStringAsFixed(1) ?? '',
    );
    _caloriesController = TextEditingController(
      text: widget.product.caloriesPer100g?.toStringAsFixed(1) ?? '',
    );
  }

  @override
  void dispose() {
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
      // Если были изменения в данных продукта, сохраняем их
      if (_isEditing) {
        final productsProvider = Provider.of<ProductsProvider>(context, listen: false);
        final updatedProduct = widget.product.copyWith(
          pheEstimatedPer100g: double.parse(_pheController.text),
          proteinPer100g: double.parse(_proteinController.text),
          fatPer100g: _fatController.text.isNotEmpty ? double.parse(_fatController.text) : null,
          carbsPer100g: _carbsController.text.isNotEmpty ? double.parse(_carbsController.text) : null,
          caloriesPer100g: _caloriesController.text.isNotEmpty ? double.parse(_caloriesController.text) : null,
        );
        
        if (widget.product.id.isNotEmpty) {
          await productsProvider.updateProduct(updatedProduct);
        } else {
          await productsProvider.saveProductWithBarcode(updatedProduct);
        }
      }

      final diaryProvider = Provider.of<DiaryProvider>(context, listen: false);

      await diaryProvider.addCustomEntry(
        productName: widget.product.name,
        portionG: double.parse(_portionController.text),
        pheUsedPer100g: double.parse(_pheController.text),
        proteinPer100g: double.parse(_proteinController.text),
        mealType: widget.mealType,
        fatPer100g: _fatController.text.isNotEmpty 
            ? double.parse(_fatController.text) 
            : null,
        carbsPer100g: _carbsController.text.isNotEmpty 
            ? double.parse(_carbsController.text) 
            : null,
        caloriesPer100g: _caloriesController.text.isNotEmpty 
            ? double.parse(_caloriesController.text) 
            : null,
      );

      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.product.name} добавлен в ${widget.mealType.displayName}'),
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

  @override
  Widget build(BuildContext context) {
    final portion = double.tryParse(_portionController.text) ?? 0;
    final multiplier = portion / 100.0;
    final isFromOpenFoodFacts = widget.product.source == 'Open Food Facts';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product.name),
        actions: [
          if (isFromOpenFoodFacts)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Chip(
                avatar: const Icon(Icons.public, size: 16),
                label: const Text('Open Food Facts', style: TextStyle(fontSize: 11)),
                backgroundColor: Colors.green.shade100,
              ),
            ),
          IconButton(
            icon: Icon(_isEditing ? Icons.lock_open : Icons.lock),
            onPressed: () {
              setState(() => _isEditing = !_isEditing);
            },
            tooltip: _isEditing ? 'Заблокировать' : 'Редактировать',
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
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(
                        isFromOpenFoodFacts ? Icons.cloud_done : Icons.check_circle,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.product.name,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'Добавление в: ${widget.mealType.displayName}',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                                fontSize: 12,
                              ),
                            ),
                            if (isFromOpenFoodFacts) ...[
                              const SizedBox(height: 4),
                              Text(
                                '💾 Автоматически сохранен в вашу базу',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                '⚠️ Phe рассчитан автоматически, можно откорректировать',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

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
                onChanged: (value) => setState(() {}),
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

              Row(
                children: [
                  Text(
                    'Значения на 100г',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const Spacer(),
                  if (_isEditing)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.edit,
                            size: 14,
                            color: Colors.orange.shade900,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Режим редактирования',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.orange.shade900,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _pheController,
                enabled: _isEditing,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
                ],
                decoration: InputDecoration(
                  labelText: 'Фенилаланин (Phe) *',
                  suffixText: 'мг на 100г',
                  prefixIcon: const Icon(Icons.medical_information),
                  helperText: isFromOpenFoodFacts ? 'Оценочное значение, рекомендуем проверить' : null,
                ),
                onChanged: (value) => setState(() {}),
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

              TextFormField(
                controller: _proteinController,
                enabled: _isEditing,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Белок *',
                  suffixText: 'г на 100г',
                  prefixIcon: Icon(Icons.fitness_center),
                ),
                onChanged: (value) => setState(() {}),
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
              const SizedBox(height: 16),

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
                onChanged: (value) => setState(() {}),
              ),
              const SizedBox(height: 16),

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
                onChanged: (value) => setState(() {}),
              ),
              const SizedBox(height: 16),

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
                onChanged: (value) => setState(() {}),
              ),
              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'В вашей порции ($portion г):',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    _CalculatedRow(
                      label: 'Фенилаланин (Phe)',
                      value: (double.tryParse(_pheController.text) ?? 0) * multiplier,
                      unit: 'мг',
                      color: Colors.purple,
                    ),
                    const SizedBox(height: 8),
                    _CalculatedRow(
                      label: 'Белок',
                      value: (double.tryParse(_proteinController.text) ?? 0) * multiplier,
                      unit: 'г',
                      color: Colors.blue,
                    ),
                    if (_fatController.text.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _CalculatedRow(
                        label: 'Жиры',
                        value: (double.tryParse(_fatController.text) ?? 0) * multiplier,
                        unit: 'г',
                        color: Colors.amber,
                      ),
                    ],
                    if (_carbsController.text.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _CalculatedRow(
                        label: 'Углеводы',
                        value: (double.tryParse(_carbsController.text) ?? 0) * multiplier,
                        unit: 'г',
                        color: Colors.green,
                      ),
                    ],
                    if (_caloriesController.text.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _CalculatedRow(
                        label: 'Калории',
                        value: (double.tryParse(_caloriesController.text) ?? 0) * multiplier,
                        unit: 'ккал',
                        color: Colors.orange,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 32),

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
            ],
          ),
        ),
      ),
    );
  }
}

class _CalculatedRow extends StatelessWidget {
  final String label;
  final double value;
  final String unit;
  final Color color;

  const _CalculatedRow({
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
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13),
          ),
        ),
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