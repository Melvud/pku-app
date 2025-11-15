// lib/screens/products/product_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/products_provider.dart';
import '../../models/product.dart';
import '../../models/diary_entry.dart';
import 'edit_product_portion_screen.dart';
import 'qr_scanner_screen.dart';

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
      // Загружаем только если продукты ещё не загружены
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

  void _navigateToQRScanner() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QRScannerScreen(mealType: widget.mealType),
      ),
    );

    if (result != null && result is String) {
      setState(() {
        _searchController.text = result;
        _searchQuery = result;
      });
    }
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Добавить в ${widget.mealType.displayName}'),
      ),
      body: Consumer<ProductsProvider>(
        builder: (context, productsProvider, child) {
          // Показываем прогресс синхронизации
          if (productsProvider.isSyncing) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: productsProvider.syncProgress,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      productsProvider.syncStatus,
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(productsProvider.syncProgress * 100).toInt()}%',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ),
            );
          }

          // Показываем загрузку для начальной загрузки
          if (productsProvider.isLoading && productsProvider.products.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Загрузка продуктов...'),
                ],
              ),
            );
          }

          if (productsProvider.error != null && productsProvider.products.isEmpty) {
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
                    onPressed: () => productsProvider.loadProducts(forceSync: true),
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            );
          }

          List<Product> filteredProducts = productsProvider.products;

          if (_searchQuery.isNotEmpty) {
            filteredProducts = productsProvider.searchProducts(_searchQuery);
          }

          if (_selectedCategory != 'all') {
            filteredProducts = filteredProducts
                .where((p) => p.category == _selectedCategory)
                .toList();
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
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
                    const SizedBox(width: 8),
                    IconButton.filled(
                      icon: const Icon(Icons.qr_code_scanner),
                      onPressed: _navigateToQRScanner,
                      tooltip: 'Сканировать QR',
                    ),
                  ],
                ),
              ),

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

              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Text(
                      'Найдено: ${filteredProducts.length}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const Spacer(),
                    if (productsProvider.lastSync != null)
                      Text(
                        'Обновлено: ${_formatDate(productsProvider.lastSync!)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 20),
                      onPressed: () => productsProvider.syncFromGoogleSheets(),
                      tooltip: 'Синхронизировать',
                    ),
                  ],
                ),
              ),

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
                              onPressed: () => _navigateToEditProduct(product),
                            ),
                            onTap: () => _navigateToEditProduct(product),
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
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}