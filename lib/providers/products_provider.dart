// lib/providers/products_provider.dart
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/product.dart';
import '../services/google_sheets_service.dart';
import '../services/multi_source_barcode_service.dart';
import '../services/local_database_service.dart';

class ProductsProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSheetsService _sheetsService = GoogleSheetsService();
  final MultiSourceBarcodeService _barcodeService = MultiSourceBarcodeService();

  List<Product> _products = [];
  bool _isLoading = false;
  bool _isSyncing = false;
  String? _error;
  DateTime? _lastSync;
  double _syncProgress = 0.0;
  String _syncStatus = '';

  List<Product> get products => _products;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  String? get error => _error;
  DateTime? get lastSync => _lastSync;
  double get syncProgress => _syncProgress;
  String get syncStatus => _syncStatus;

  ProductsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt('last_sync_timestamp');
      if (timestamp != null) {
        _lastSync = DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_lastSync != null) {
        await prefs.setInt(
            'last_sync_timestamp', _lastSync!.millisecondsSinceEpoch);
      }
    } catch (e) {
      debugPrint('Error saving settings: $e');
    }
  }

  Future<ProductSearchResult> findProductByBarcode(String barcode) async {
    try {
      final snapshot = await _firestore
          .collection('products')
          .where('barcode', isEqualTo: barcode)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return ProductSearchResult(
          product: Product.fromFirestore(snapshot.docs.first),
          source: 'Локальная база',
          hasNutritionData: true,
        );
      }

      final result = await _barcodeService.searchProductByBarcode(barcode);
      return result;
    } catch (e) {
      return ProductSearchResult(
        product: Product(
          id: '',
          name: '',
          category: 'other',
          proteinPer100g: 0.0,
          pheMeasuredPer100g: null,
          pheEstimatedPer100g: 0.0,
          fatPer100g: null,
          carbsPer100g: null,
          caloriesPer100g: null,
          notes: 'Ошибка поиска',
          source: 'Вручную',
          lastUpdated: DateTime.now(),
          googleSheetsId: null,
          barcode: barcode,
        ),
        source: 'Manual',
        hasNutritionData: false,
      );
    }
  }

  Future<void> loadProducts({bool forceSync = false}) async {
    if (_isLoading || _isSyncing) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final localDb = LocalDatabaseService();

      // 1. Load from local cache first (fastest)
      final hasLocalCache = await localDb.hasCache('products');

      if (hasLocalCache && !forceSync) {
        final cachedProducts =
            await localDb.getCachedProducts(source: 'Google Sheets');
        if (cachedProducts.isNotEmpty) {
          _products =
              cachedProducts.map((map) => _productFromMap(map)).toList();
          debugPrint('✅ Loaded ${_products.length} products from local cache');
          _isLoading = false;
          notifyListeners();

          // Check for updates in background
          _checkForUpdatesInBackground();
          return;
        }
      }

      // 2. If no cache or force sync, sync from sheets
      await syncFromGoogleSheets();
    } catch (e) {
      _error = 'Ошибка загрузки продуктов: $e';
      _isLoading = false;
      debugPrint(_error);
      notifyListeners();
    }
  }

  Future<void> _checkForUpdatesInBackground() async {
    try {
      debugPrint('Checking for updates in background...');
      final lastModified = await _sheetsService.getLastModifiedTime();

      if (lastModified != null && _lastSync != null) {
        if (lastModified.isAfter(_lastSync!)) {
          debugPrint(
              'Updates available (Remote: $lastModified > Local: $_lastSync)');
          await syncFromGoogleSheets();
        } else {
          debugPrint('No updates found. Local is up to date.');
        }
      } else {
        if (_lastSync == null) {
          await syncFromGoogleSheets();
        }
      }
    } catch (e) {
      debugPrint('Background update check failed: $e');
    }
  }

  Future<void> syncFromGoogleSheets() async {
    if (_isSyncing) return;

    _isSyncing = true;
    _error = null;
    _syncProgress = 0.0;
    _syncStatus = 'Проверка обновлений...';
    notifyListeners();

    try {
      _syncProgress = 0.2;
      _syncStatus = 'Загрузка базы продуктов...';
      notifyListeners();

      final sheetProducts = await _sheetsService.fetchProducts();

      if (sheetProducts.isEmpty) {
        _error = 'База данных пуста';
        _isSyncing = false;
        notifyListeners();
        return;
      }

      _syncProgress = 0.5;
      _syncStatus = 'Сохранение ${sheetProducts.length} продуктов...';
      notifyListeners();

      // Save to local DB
      final localDb = LocalDatabaseService();

      final productsForCache =
          sheetProducts.map((p) => _productToMap(p)).toList();
      await localDb.cacheProducts(productsForCache);

      _products = sheetProducts;
      _lastSync = DateTime.now();
      await _saveSettings();

      _syncProgress = 1.0;
      _syncStatus = 'Готово';
      notifyListeners();

      debugPrint('✅ Sync completed: ${sheetProducts.length} products loaded');
    } catch (e) {
      _error = 'Ошибка синхронизации: $e';
      debugPrint(_error);
    } finally {
      _isSyncing = false;
      _isLoading = false;
      _syncProgress = 0.0;
      _syncStatus = '';
      notifyListeners();
    }
  }

  Map<String, dynamic> _productToMap(Product product) {
    return {
      'id':
          product.id.isEmpty ? product.googleSheetsId ?? 'unknown' : product.id,
      'name': product.name,
      'phePer100g': product.pheToUse,
      'proteinPer100g': product.proteinPer100g,
      'fatPer100g': product.fatPer100g,
      'carbsPer100g': product.carbsPer100g,
      'caloriesPer100g': product.caloriesPer100g,
      'category': product.category,
      'source': product.source,
      'barcode': product.barcode,
      'googleSheetsId': product.googleSheetsId,
      'notes': product.notes,
      'createdBy': null,
      'isUserCreated': false,
      'lastUpdated': DateTime.now().millisecondsSinceEpoch,
    };
  }

  Product _productFromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'],
      name: map['name'],
      category: map['category'] ?? 'other',
      proteinPer100g: (map['proteinPer100g'] ?? 0).toDouble(),
      pheMeasuredPer100g: map['pheMeasuredPer100g']?.toDouble(),
      pheEstimatedPer100g: (map['phePer100g'] ?? 0).toDouble(),
      fatPer100g: map['fatPer100g'] != null
          ? (map['fatPer100g'] as num).toDouble()
          : null,
      carbsPer100g: map['carbsPer100g'] != null
          ? (map['carbsPer100g'] as num).toDouble()
          : null,
      caloriesPer100g: map['caloriesPer100g'] != null
          ? (map['caloriesPer100g'] as num).toDouble()
          : null,
      source: map['source'] ?? 'Google Sheets',
      notes: map['notes'],
      barcode: map['barcode'],
      googleSheetsId: map['googleSheetsId'],
      lastUpdated: DateTime.fromMillisecondsSinceEpoch(
          map['lastUpdated'] ?? DateTime.now().millisecondsSinceEpoch),
    );
  }

  List<Product> searchProducts(String query) {
    if (query.isEmpty) return _products;

    final lowerQuery = query.toLowerCase();
    return _products.where((product) {
      return product.name.toLowerCase().contains(lowerQuery) ||
          product.category.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  Future<void> updateProduct(Product product) async {
    try {
      if (product.id.isNotEmpty) {
        await _firestore
            .collection('products')
            .doc(product.id)
            .update(product.toFirestore());
      }

      final index = _products.indexWhere((p) => p.id == product.id);
      if (index != -1) {
        _products[index] = product;
        notifyListeners();
      }

      final localDb = LocalDatabaseService();
      await localDb.cacheProducts([_productToMap(product)]);
    } catch (e) {
      debugPrint('Error updating product: $e');
      rethrow;
    }
  }

  Future<void> saveProductWithBarcode(Product product) async {
    try {
      final docRef =
          await _firestore.collection('products').add(product.toFirestore());
      final newProduct = product.copyWith(id: docRef.id);

      _products.add(newProduct);
      notifyListeners();

      final localDb = LocalDatabaseService();
      await localDb.cacheProducts([_productToMap(newProduct)]);
    } catch (e) {
      debugPrint('Error saving product: $e');
      rethrow;
    }
  }

  List<Product> filterByCategory(String category) {
    if (category.isEmpty || category == 'all') return _products;
    return _products.where((p) => p.category == category).toList();
  }
}
