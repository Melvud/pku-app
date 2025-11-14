import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/products_provider.dart';
import '../../providers/diary_provider.dart';
import '../../models/product.dart';
import '../../models/diary_entry.dart';

class ProductSelectionScreen extends StatefulWidget {
  final MealType mealType;

  const ProductSelectionScreen({
    super.key,
    required this.mealType,
  });

  @override
  State<ProductSelectionScreen> createState() => _ProductSelectionScreenState();
}

class _ProductSelectionScreenState extends State<ProductSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final productsProvider = Provider.of<ProductsProvider>(context, listen: false);
      if (productsProvider.products.isEmpty) {
        productsProvider.loadProducts();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddPortionDialog(Product product) {
    final TextEditingController portionController = TextEditingController(text: '100');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(product.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Phe: ${product.pheToUse.toStringAsFixed(1)} мг / 100г',
              style: const TextStyle(fontSize: 14),
            ),
            Text(
              'Белок: ${product.proteinPer100g.toStringAsFixed(1)} г / 100г',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: portionController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
              ],
              decoration: const InputDecoration(
                labelText: 'Порция (грамм)',
                suffixText: 'г',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            _CalculatedNutrition(
              product: product,
              portionController: portionController,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () async {
              final portion = double.tryParse(portionController.text);
              if (portion == null || portion <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Введите корректную порцию')),
                );
                return;
              }

              try {
                await Provider.of<DiaryProvider>(context, listen: false).addEntry(
                  product: product,
                  portionG: portion,
                  mealType: widget.mealType,
                );

                if (mounted) {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Return to home screen
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${product.name} добавлен в ${widget.mealType.displayName}'),
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
            },
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Добавить в ${widget.mealType.displayName}'),
      ),
      body: Consumer<ProductsProvider>(
        builder: (context, productsProvider, child) {
          if (productsProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (productsProvider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    productsProvider.error!,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => productsProvider.loadProducts(),
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            );
          }

          List<Product> filteredProducts = productsProvider.products;

          // Apply search filter
          if (_searchQuery.isNotEmpty) {
            filteredProducts = productsProvider.searchProducts(_searchQuery);
          }

          // Apply category filter
          if (_selectedCategory != 'all') {
            filteredProducts = filteredProducts
                .where((p) => p.category == _selectedCategory)
                .toList();
          }

          return Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Поиск продуктов...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                ),
              ),

              // Category Filter
              SizedBox(
                height: 50,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _CategoryChip(
                      label: 'Все',
                      isSelected: _selectedCategory == 'all',
                      onTap: () => setState(() => _selectedCategory = 'all'),
                    ),
                    _CategoryChip(
                      label: 'Овощи',
                      isSelected: _selectedCategory == 'vegetables',
                      onTap: () => setState(() => _selectedCategory = 'vegetables'),
                    ),
                    _CategoryChip(
                      label: 'Фрукты',
                      isSelected: _selectedCategory == 'fruits',
                      onTap: () => setState(() => _selectedCategory = 'fruits'),
                    ),
                    _CategoryChip(
                      label: 'Зерновые',
                      isSelected: _selectedCategory == 'grains',
                      onTap: () => setState(() => _selectedCategory = 'grains'),
                    ),
                    _CategoryChip(
                      label: 'Другое',
                      isSelected: _selectedCategory == 'other',
                      onTap: () => setState(() => _selectedCategory = 'other'),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Products List
              Expanded(
                child: filteredProducts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Продукты не найдены',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Попробуйте изменить фильтры',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredProducts.length,
                        itemBuilder: (context, index) {
                          final product = filteredProducts[index];
                          return ListTile(
                            title: Text(product.name),
                            subtitle: Text(
                              'Phe: ${product.pheToUse.toStringAsFixed(1)} мг • '
                              'Белок: ${product.proteinPer100g.toStringAsFixed(1)} г (на 100г)',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.add_circle),
                              color: Theme.of(context).colorScheme.primary,
                              onPressed: () => _showAddPortionDialog(product),
                            ),
                            onTap: () => _showAddPortionDialog(product),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// Category Chip Widget
class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

// Calculated Nutrition Widget
class _CalculatedNutrition extends StatefulWidget {
  final Product product;
  final TextEditingController portionController;

  const _CalculatedNutrition({
    required this.product,
    required this.portionController,
  });

  @override
  State<_CalculatedNutrition> createState() => _CalculatedNutritionState();
}

class _CalculatedNutritionState extends State<_CalculatedNutrition> {
  @override
  void initState() {
    super.initState();
    widget.portionController.addListener(() {
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final portion = double.tryParse(widget.portionController.text) ?? 0;
    final multiplier = portion / 100.0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'В вашей порции:',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          _NutrientRow(
            label: 'Phe',
            value: (widget.product.pheToUse * multiplier).toStringAsFixed(1),
            unit: 'мг',
          ),
          _NutrientRow(
            label: 'Белок',
            value: (widget.product.proteinPer100g * multiplier).toStringAsFixed(1),
            unit: 'г',
          ),
          if (widget.product.caloriesPer100g != null)
            _NutrientRow(
              label: 'Калории',
              value: (widget.product.caloriesPer100g! * multiplier).toStringAsFixed(0),
              unit: 'ккал',
            ),
        ],
      ),
    );
  }
}

// Nutrient Row Widget
class _NutrientRow extends StatelessWidget {
  final String label;
  final String value;
  final String unit;

  const _NutrientRow({
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(
            '$value $unit',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}