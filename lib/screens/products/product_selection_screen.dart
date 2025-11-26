// lib/screens/products/product_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/products_provider.dart';
import '../../models/product.dart';
import '../../models/diary_entry.dart';
import 'edit_product_portion_screen.dart';

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
      final productsProvider =
          Provider.of<ProductsProvider>(context, listen: false);
      productsProvider.loadProducts();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _navigateToEditProduct(Product product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProductPortionScreen(
          product: product,
          mealType: widget.mealType,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProductsProvider>(
      builder: (context, productsProvider, child) {
        return Scaffold(
          backgroundColor: Colors.grey[50], // Light background for modern feel
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Добавить в ${widget.mealType.displayName}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                if (productsProvider.lastSync != null)
                  Text(
                    'Обновлено: ${_formatDate(productsProvider.lastSync!)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.normal,
                    ),
                  ),
              ],
            ),
            actions: [
              if (productsProvider.isSyncing)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => productsProvider.syncFromGoogleSheets(),
                  tooltip: 'Обновить базу',
                ),
            ],
          ),
          body: Column(
            children: [
              // Search Bar
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Поиск продуктов...',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                ),
              ),

              // Categories
              Container(
                color: Colors.white,
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
                      onTap: () =>
                          setState(() => _selectedCategory = 'vegetables'),
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
                      label: 'Молочные',
                      isSelected: _selectedCategory == 'dairy',
                      onTap: () => setState(() => _selectedCategory = 'dairy'),
                    ),
                    _CategoryChip(
                      label: 'Белковые',
                      isSelected: _selectedCategory == 'protein',
                      onTap: () =>
                          setState(() => _selectedCategory = 'protein'),
                    ),
                    _CategoryChip(
                      label: 'Снеки',
                      isSelected: _selectedCategory == 'snacks',
                      onTap: () => setState(() => _selectedCategory = 'snacks'),
                    ),
                    _CategoryChip(
                      label: 'Напитки',
                      isSelected: _selectedCategory == 'beverages',
                      onTap: () =>
                          setState(() => _selectedCategory = 'beverages'),
                    ),
                    _CategoryChip(
                      label: 'Другое',
                      isSelected: _selectedCategory == 'other',
                      onTap: () => setState(() => _selectedCategory = 'other'),
                    ),
                  ],
                ),
              ),

              // Status Bar (Syncing)
              if (productsProvider.isSyncing)
                LinearProgressIndicator(
                    value: productsProvider.syncProgress,
                    backgroundColor: Colors.transparent),

              // Product List
              Expanded(
                child: _buildProductList(context, productsProvider),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProductList(BuildContext context, ProductsProvider provider) {
    if (provider.isLoading && provider.products.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.error != null && provider.products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(provider.error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => provider.loadProducts(forceSync: true),
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    List<Product> filteredProducts = provider.products;

    if (_searchQuery.isNotEmpty) {
      filteredProducts = provider.searchProducts(_searchQuery);
    }

    if (_selectedCategory != 'all') {
      filteredProducts = filteredProducts
          .where((p) => p.category == _selectedCategory)
          .toList();
    }

    if (filteredProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'Продукты не найдены',
              style: TextStyle(color: Colors.grey[500], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredProducts.length,
      itemBuilder: (context, index) {
        final product = filteredProducts[index];
        return _ProductListItem(
          product: product,
          onTap: () => _navigateToEditProduct(product),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} мин назад';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} ч назад';
    } else {
      return '${diff.inDays} дн назад';
    }
  }
}

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
      padding: const EdgeInsets.only(right: 8, bottom: 8),
      child: ActionChip(
        label: Text(label),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        backgroundColor:
            isSelected ? Theme.of(context).primaryColor : Colors.grey[100],
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isSelected ? Colors.transparent : Colors.grey[300]!,
              width: 1,
            )),
        onPressed: onTap,
      ),
    );
  }
}

class _ProductListItem extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;

  const _ProductListItem({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _getCategoryColor(product.category).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getCategoryIcon(product.category),
                    color: _getCategoryColor(product.category),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _NutrientBadge(
                            label: 'Phe',
                            value: '${product.pheToUse.toStringAsFixed(1)} мг',
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          _NutrientBadge(
                            label: 'Белок',
                            value:
                                '${product.proteinPer100g.toStringAsFixed(1)} г',
                            color: Colors.blue,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.add_circle_outline, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'vegetables':
        return Colors.green;
      case 'fruits':
        return Colors.red;
      case 'grains':
        return Colors.amber;
      case 'dairy':
        return Colors.blue;
      case 'protein':
        return Colors.deepOrange;
      case 'snacks':
        return Colors.purple;
      case 'beverages':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'vegetables':
        return Icons.eco;
      case 'fruits':
        return Icons.apple;
      case 'grains':
        return Icons.breakfast_dining;
      case 'dairy':
        return Icons.local_drink; // Milk icon usually
      case 'protein':
        return Icons.restaurant;
      case 'snacks':
        return Icons.cookie;
      case 'beverages':
        return Icons.local_cafe;
      default:
        return Icons.fastfood;
    }
  }
}

class _NutrientBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _NutrientBadge({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}
