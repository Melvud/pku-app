// lib/screens/products/quick_add_product_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/products_provider.dart';
import '../../providers/diary_provider.dart';
import '../../models/product.dart';
import '../../models/diary_entry.dart';

class QuickAddProductScreen extends StatefulWidget {
  final String barcode;
  final String productName;
  final MealType mealType;
  final String source;

  const QuickAddProductScreen({
    super.key,
    required this.barcode,
    required this.productName,
    required this.mealType,
    required this.source,
  });

  @override
  State<QuickAddProductScreen> createState() => _QuickAddProductScreenState();
}

class _QuickAddProductScreenState extends State<QuickAddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _portionController;
  late TextEditingController _proteinController;
  late TextEditingController _pheController;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.productName);
    _portionController = TextEditingController(text: '100');
    _proteinController = TextEditingController();
    _pheController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _portionController.dispose();
    _proteinController.dispose();
    _pheController.dispose();
    super.dispose();
  }

  void _autoCalculatePhe() {
    final protein = double.tryParse(_proteinController.text) ?? 0;
    if (protein > 0) {
      final estimatedPhe = protein * 50; // 50 мг Phe на 1 г белка
      _pheController.text = estimatedPhe.toStringAsFixed(0);
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final product = Product(
        id: '',
        name: _nameController.text,
        category: 'other',
        proteinPer100g: double.parse(_proteinController.text),
        pheMeasuredPer100g: null,
        pheEstimatedPer100g: double.parse(_pheController.text),
        fatPer100g: null,
        carbsPer100g: null,
        caloriesPer100g: null,
        notes: 'Добавлено со штрих-кодом ${widget.barcode}',
        source: 'Пользователь',
        lastUpdated: DateTime.now(),
        googleSheetsId: null,
        barcode: widget.barcode,
      );

      final productsProvider = Provider.of<ProductsProvider>(context, listen: false);
      await productsProvider.saveProductWithBarcode(product);

      final diaryProvider = Provider.of<DiaryProvider>(context, listen: false);
      await diaryProvider.addCustomEntry(
        productName: product.name,
        portionG: double.parse(_portionController.text),
        pheUsedPer100g: product.pheEstimatedPer100g,
        proteinPer100g: product.proteinPer100g,
        mealType: widget.mealType,
      );

      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${product.name} добавлен и сохранен в базу!'),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Быстрое добавление'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                color: Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.orange.shade900),
                          const SizedBox(width: 8),
                          Text(
                            'Продукт не найден в базах',
                            style: TextStyle(
                              color: Colors.orange.shade900,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Введите данные с упаковки продукта. Штрих-код будет сохранен для быстрого доступа в будущем.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.qr_code, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              widget.barcode,
                              style: const TextStyle(
                                fontFamily: 'monospace',
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
              const SizedBox(height: 24),

              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Название продукта *',
                  hintText: 'Введите название с упаковки',
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

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb, size: 20, color: Colors.blue.shade900),
                        const SizedBox(width: 8),
                        Text(
                          'Найдите на упаковке (на 100г)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _proteinController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Белок (обязательно) *',
                        hintText: 'Например: 3.5',
                        suffixText: 'г на 100г',
                        prefixIcon: Icon(Icons.fitness_center),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      onChanged: (value) {
                        _autoCalculatePhe();
                      },
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
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _pheController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Фенилаланин (Phe) *',
                        hintText: 'Рассчитается автоматически',
                        suffixText: 'мг на 100г',
                        prefixIcon: const Icon(Icons.medical_information),
                        filled: true,
                        fillColor: Colors.white,
                        helperText: 'Автоматически: белок × 50 мг',
                        helperStyle: TextStyle(
                          fontSize: 11,
                          color: Colors.blue.shade700,
                        ),
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
                  ],
                ),
              ),
              const SizedBox(height: 32),

              FilledButton.icon(
                onPressed: _isLoading ? null : _handleSubmit,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.add_circle),
                label: const Text(
                  'Добавить и сохранить',
                  style: TextStyle(fontSize: 16),
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 16),

              Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, size: 20, color: Colors.green.shade900),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Продукт будет сохранен со штрих-кодом. При следующем сканировании он откроется моментально!',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade900,
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