// lib/screens/products/scanned_product_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../providers/diary_provider.dart';
import '../../providers/products_provider.dart';
import '../../models/product.dart';
import '../../models/diary_entry.dart';
import '../../models/pending_product.dart';
import '../../services/pending_products_service.dart';

class ScannedProductScreen extends StatefulWidget {
  final String barcode;
  final Product? product;
  final String source;
  final MealType mealType;
  final bool isPheCalculated;

  const ScannedProductScreen({
    super.key,
    required this.barcode,
    this.product,
    required this.source,
    required this.mealType,
    required this.isPheCalculated,
  });

  @override
  State<ScannedProductScreen> createState() => _ScannedProductScreenState();
}

class _ScannedProductScreenState extends State<ScannedProductScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _portionController;
  late TextEditingController _proteinController;
  late TextEditingController _pheController;
  late TextEditingController _fatController;
  late TextEditingController _carbsController;
  late TextEditingController _caloriesController;

  String _selectedCategory = 'other';
  bool _isLoading = false;
  bool _isEditing = false;
  bool _isPheCalculated = false;
  bool _hasChanges = false;
  bool _categorySelected = false; // Track if category was selected for new product

  // PKU-specific categories with Phe coefficients (mg per 1g protein)
  final List<Map<String, dynamic>> _categories = [
    {'value': 'meat_fish_eggs_cheese', 'label': 'Мясо/рыба/яйца/сыры', 'coefficient': 50},
    {'value': 'dairy', 'label': 'Молочное (кроме сыров и творога)', 'coefficient': 40},
    {'value': 'grains_bread', 'label': 'Крупы/хлеб', 'coefficient': 30},
    {'value': 'vegetables', 'label': 'Овощи', 'coefficient': 25},
    {'value': 'fruits', 'label': 'Фрукты', 'coefficient': 25},
    {'value': 'nuts_legumes', 'label': 'Орехи/бобовые', 'coefficient': 45},
    {'value': 'other', 'label': 'Другое', 'coefficient': 45},
  ];

  /// Get Phe coefficient for a category (mg per 1g protein)
  int _getPheCoefficient(String category) {
    final cat = _categories.firstWhere(
      (c) => c['value'] == category,
      orElse: () => {'coefficient': 45},
    );
    return cat['coefficient'] as int;
  }

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _isPheCalculated = widget.isPheCalculated;

    _nameController = TextEditingController(text: p?.name ?? '');
    _portionController = TextEditingController(text: '100');
    _proteinController = TextEditingController(
      text: p?.proteinPer100g.toStringAsFixed(1) ?? '',
    );
    _pheController = TextEditingController(
      text: p?.pheToUse.toStringAsFixed(1) ?? '',
    );
    _fatController = TextEditingController(
      text: p?.fatPer100g?.toStringAsFixed(1) ?? '',
    );
    _carbsController = TextEditingController(
      text: p?.carbsPer100g?.toStringAsFixed(1) ?? '',
    );
    _caloriesController = TextEditingController(
      text: p?.caloriesPer100g?.toStringAsFixed(1) ?? '',
    );
    _selectedCategory = _mapOldCategoryToNew(p?.category ?? 'other');

    // If product not found, enable editing mode
    if (widget.product == null) {
      _isEditing = true;
      _categorySelected = false;
    } else {
      _categorySelected = true;
    }
  }

  /// Map old category values to new PKU categories
  String _mapOldCategoryToNew(String oldCategory) {
    switch (oldCategory) {
      case 'vegetables':
        return 'vegetables';
      case 'fruits':
        return 'fruits';
      case 'grains':
        return 'grains_bread';
      case 'dairy':
        return 'dairy';
      case 'protein':
        return 'meat_fish_eggs_cheese';
      default:
        return 'other';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _portionController.dispose();
    _proteinController.dispose();
    _pheController.dispose();
    _fatController.dispose();
    _carbsController.dispose();
    _caloriesController.dispose();
    super.dispose();
  }

  void _autoCalculatePhe() {
    final protein = double.tryParse(_proteinController.text) ?? 0;
    if (protein > 0) {
      final coefficient = _getPheCoefficient(_selectedCategory);
      final estimatedPhe = protein * coefficient;
      _pheController.text = estimatedPhe.toStringAsFixed(0);
      setState(() {
        _isPheCalculated = true;
        _hasChanges = true;
      });
    }
  }

  /// Recalculate Phe when category changes (only if Phe was auto-calculated)
  void _onCategoryChanged(String category) {
    setState(() {
      _selectedCategory = category;
      _categorySelected = true;
      _hasChanges = true;
    });
    // Only recalculate if Phe was previously auto-calculated
    if (_isPheCalculated) {
      _autoCalculatePhe();
    }
  }

  Future<void> _handleAddToDiary() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final product = _buildProduct();
      final productsProvider = Provider.of<ProductsProvider>(context, listen: false);
      final diaryProvider = Provider.of<DiaryProvider>(context, listen: false);

      // Save product to user's local database
      await productsProvider.saveProductWithBarcode(product);

      // Add to diary
      await diaryProvider.addCustomEntry(
        productName: product.name,
        portionG: double.parse(_portionController.text),
        pheUsedPer100g: double.parse(_pheController.text),
        proteinPer100g: double.parse(_proteinController.text),
        mealType: widget.mealType,
        fatPer100g: _fatController.text.isNotEmpty ? double.parse(_fatController.text) : null,
        carbsPer100g: _carbsController.text.isNotEmpty ? double.parse(_carbsController.text) : null,
        caloriesPer100g: _caloriesController.text.isNotEmpty ? double.parse(_caloriesController.text) : null,
      );

      // If there are changes or it's a new product, submit for moderation
      if (_hasChanges || widget.product == null) {
        await _submitForModeration(product);
      }

      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${product.name} добавлен в ${widget.mealType.displayName}'),
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

  Future<void> _submitForModeration(Product product) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('⚠️ Cannot submit for moderation: user not logged in');
        return;
      }

      debugPrint('📤 Submitting product for moderation: ${product.name}');

      final pendingProduct = PendingProduct.fromProduct(
        product: product,
        userId: user.uid,
        userName: user.displayName ?? user.email ?? 'Unknown',
        isPheCalculated: _isPheCalculated,
        originalProductId: widget.product?.id,
        action: widget.product == null
            ? PendingProductAction.add
            : PendingProductAction.update,
      );

      final pendingService = PendingProductsService();
      final docId = await pendingService.submitProduct(pendingProduct);

      debugPrint('✅ Product submitted for moderation with ID: $docId');
    } catch (e) {
      debugPrint('❌ Error submitting for moderation: $e');
      // Don't fail the main operation, but log the error
    }
  }

  Product _buildProduct() {
    return Product(
      id: widget.product?.id ?? '',
      name: _nameController.text.trim(),
      category: _selectedCategory,
      proteinPer100g: double.parse(_proteinController.text),
      pheMeasuredPer100g: _isPheCalculated ? null : double.parse(_pheController.text),
      pheEstimatedPer100g: double.parse(_pheController.text),
      fatPer100g: _fatController.text.isNotEmpty ? double.parse(_fatController.text) : null,
      carbsPer100g: _carbsController.text.isNotEmpty ? double.parse(_carbsController.text) : null,
      caloriesPer100g: _caloriesController.text.isNotEmpty ? double.parse(_caloriesController.text) : null,
      notes: 'Штрих-код: ${widget.barcode}',
      source: widget.source,
      lastUpdated: DateTime.now(),
      googleSheetsId: null,
      barcode: widget.barcode,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNewProduct = widget.product == null;
    final portion = double.tryParse(_portionController.text) ?? 0;
    final multiplier = portion / 100.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(isNewProduct ? 'Новый продукт' : 'Найденный продукт'),
        actions: [
          if (!isNewProduct)
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
              // Status card
              _buildStatusCard(isNewProduct),

              // Phe calculated warning
              if (_isPheCalculated) ...[
                const SizedBox(height: 12),
                _buildPheWarning(),
              ],

              // Category selection hint for new products
              if (isNewProduct && !_categorySelected) ...[
                const SizedBox(height: 12),
                Card(
                  color: Colors.blue.shade50,
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Выберите категорию продукта для расчёта Phe',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Barcode display
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.qr_code, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Штрих-код',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          Text(
                            widget.barcode,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Product name
              TextFormField(
                controller: _nameController,
                enabled: _isEditing,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Название продукта *',
                  prefixIcon: Icon(Icons.fastfood),
                ),
                onChanged: (_) => setState(() => _hasChanges = true),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Введите название';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Category dropdown with Phe coefficient info
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: InputDecoration(
                  labelText: 'Категория *',
                  prefixIcon: const Icon(Icons.category),
                  helperText: 'Коэффициент: ${_getPheCoefficient(_selectedCategory)} мг Phe на 1г белка',
                  helperStyle: TextStyle(
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                items: _categories.map((cat) {
                  return DropdownMenuItem(
                    value: cat['value'] as String,
                    child: Text(cat['label'] as String),
                  );
                }).toList(),
                onChanged: _isEditing
                    ? (value) {
                        if (value != null) {
                          _onCategoryChanged(value);
                        }
                      }
                    : null,
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

              // Nutrition section title
              Row(
                children: [
                  Text(
                    'Пищевая ценность на 100г',
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
                          Icon(Icons.edit, size: 14, color: Colors.orange.shade900),
                          const SizedBox(width: 4),
                          Text(
                            'Редактирование',
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

              // Protein
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
                onChanged: (value) {
                  _autoCalculatePhe();
                  setState(() => _hasChanges = true);
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Введите белок';
                  }
                  final number = double.tryParse(value);
                  if (number == null || number < 0) {
                    return 'Введите корректное значение';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Phe with warning indicator
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
                  prefixIcon: Icon(
                    Icons.medical_information,
                    color: _isPheCalculated ? Colors.orange : null,
                  ),
                  helperText: _isPheCalculated
                      ? 'Рассчитано автоматически (белок × ${_getPheCoefficient(_selectedCategory)})'
                      : 'Введено вручную',
                  helperStyle: TextStyle(
                    color: _isPheCalculated ? Colors.orange.shade700 : Colors.green.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _isPheCalculated = false; // User manually entered Phe
                    _hasChanges = true;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Введите Phe';
                  }
                  final number = double.tryParse(value);
                  if (number == null || number < 0) {
                    return 'Введите корректное значение';
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
                onChanged: (_) => setState(() => _hasChanges = true),
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
                onChanged: (_) => setState(() => _hasChanges = true),
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
                onChanged: (_) => setState(() => _hasChanges = true),
              ),
              const SizedBox(height: 24),

              // Calculated values
              _buildCalculatedValuesCard(portion, multiplier),
              const SizedBox(height: 24),

              // Info about moderation
              if (_hasChanges || isNewProduct) _buildModerationInfo(),
              const SizedBox(height: 16),

              // Submit button
              FilledButton.icon(
                onPressed: _isLoading ? null : _handleAddToDiary,
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
                label: Text(
                  isNewProduct ? 'Добавить в дневник и сохранить' : 'Добавить в дневник',
                  style: const TextStyle(fontSize: 16),
                ),
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

  Widget _buildStatusCard(bool isNewProduct) {
    if (isNewProduct) {
      return Card(
        color: Colors.orange.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orange.shade900),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Продукт не найден в базе',
                      style: TextStyle(
                        color: Colors.orange.shade900,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Введите данные с упаковки продукта',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      return Card(
        color: Colors.green.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade900),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Продукт найден',
                      style: TextStyle(
                        color: Colors.green.shade900,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Источник: ${widget.source}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade900,
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
  }

  Widget _buildPheWarning() {
    final coefficient = _getPheCoefficient(_selectedCategory);
    final categoryLabel = _categories.firstWhere(
      (c) => c['value'] == _selectedCategory,
      orElse: () => {'label': 'Другое'},
    )['label'] as String;

    return Card(
      color: Colors.amber.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.amber.shade900),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Фенилаланин рассчитан автоматически',
                    style: TextStyle(
                      color: Colors.amber.shade900,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Формула: 1г белка × $coefficient мг ($categoryLabel).\nВы можете изменить значение вручную.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.amber.shade900,
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

  Widget _buildCalculatedValuesCard(double portion, double multiplier) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'В вашей порции (${portion.toStringAsFixed(0)} г):',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          _CalculatedRow(
            label: 'Фенилаланин (Phe)',
            value: (double.tryParse(_pheController.text) ?? 0) * multiplier,
            unit: 'мг',
            color: _isPheCalculated ? Colors.orange : Colors.purple,
            hasWarning: _isPheCalculated,
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
              color: Colors.red,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModerationInfo() {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Icon(Icons.info, color: Colors.blue.shade900),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Продукт будет сохранен в вашу базу и отправлен на проверку администратору для добавления в общую базу.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue.shade900,
                ),
              ),
            ),
          ],
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
  final bool hasWarning;

  const _CalculatedRow({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    this.hasWarning = false,
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
          child: Row(
            children: [
              Text(label, style: const TextStyle(fontSize: 13)),
              if (hasWarning) ...[
                const SizedBox(width: 4),
                Icon(Icons.warning_amber, size: 14, color: Colors.orange.shade700),
              ],
            ],
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
