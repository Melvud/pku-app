// lib/providers/products_provider.dart (обновленная версия)
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/product.dart';
import '../services/google_sheets_service.dart';
import '../services/multi_source_barcode_service.dart';
import '../services/local_database_service.dart';
import '../services/usda_sync_service.dart';

class ProductsProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSheetsService _sheetsService = GoogleSheetsService();
  final MultiSourceBarcodeService _barcodeService = MultiSourceBarcodeService();
  final USDASyncService _usdaSyncService = USDASyncService();

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
    _loadLastSyncTime();
  }

  Future<void> _loadLastSyncTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt('last_sync_timestamp');
      if (timestamp != null) {
        _lastSync = DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
    } catch (e) {
      debugPrint('Error loading last sync time: $e');
    }
  }

  Future<void> _saveLastSyncTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('last_sync_timestamp', _lastSync!.millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('Error saving last sync time: $e');
    }
  }

  Future<ProductSearchResult> findProductByBarcode(String barcode) async {
    try {
      // 1. Ищем в локальной базе Firestore по barcode
      final snapshot = await _firestore
          .collection('products')
          .where('barcode', isEqualTo: barcode)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        debugPrint('✅ Product found in local database by barcode');
        return ProductSearchResult(
          product: Product.fromFirestore(snapshot.docs.first),
          source: 'Локальная база',
          hasNutritionData: true,
        );
      }

      // 2. Ищем во внешних источниках
      debugPrint('🔍 Searching in external sources...');
      final result = await _barcodeService.searchProductByBarcode(barcode);
      
      if (result.product.name.isNotEmpty) {
        // Проверяем есть ли похожий продукт в нашей базе
        final existingProduct = await _findSimilarProductByName(result.product.name);
        
        if (existingProduct != null) {
          debugPrint('📝 Found similar product in database, updating barcode...');
          
          final updatedProduct = existingProduct.copyWith(barcode: barcode);
          await _firestore
              .collection('products')
              .doc(existingProduct.id)
              .update({'barcode': barcode});
          
          await loadProducts();
          
          return ProductSearchResult(
            product: updatedProduct,
            source: 'Локальная база',
            hasNutritionData: true,
          );
        }
      }
      
      return result;
    } catch (e) {
      debugPrint('Error finding product by barcode: $e');
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

  Future<Product?> _findSimilarProductByName(String name) async {
    try {
      final normalizedName = _normalizeName(name);
      
      final exactMatch = _products.where((p) {
        return _normalizeName(p.name) == normalizedName;
      }).toList();
      
      if (exactMatch.isNotEmpty) {
        return exactMatch.first;
      }
      
      final words = normalizedName.split(' ').where((w) => w.length > 3).toList();
      if (words.isEmpty) return null;
      
      final similarMatches = _products.where((p) {
        final productWords = _normalizeName(p.name).split(' ');
        int matchCount = 0;
        for (var word in words) {
          if (productWords.any((pw) => pw.contains(word) || word.contains(pw))) {
            matchCount++;
          }
        }
        return matchCount >= (words.length * 0.7);
      }).toList();
      
      return similarMatches.isNotEmpty ? similarMatches.first : null;
    } catch (e) {
      debugPrint('Error finding similar product: $e');
      return null;
    }
  }

  String _normalizeName(String name) {
    return name.toLowerCase()
        .replaceAll(RegExp(r'[^\wа-яё\s]', unicode: true), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Future<void> saveProductWithBarcode(Product product) async {
    try {
      if (product.barcode != null) {
        final existing = await _firestore
            .collection('products')
            .where('barcode', isEqualTo: product.barcode)
            .limit(1)
            .get();
        
        if (existing.docs.isNotEmpty) {
          await _firestore
              .collection('products')
              .doc(existing.docs.first.id)
              .update(product.toFirestore());
          debugPrint('✅ Updated existing product with barcode: ${product.barcode}');
        } else {
          await _firestore.collection('products').add(product.toFirestore());
          debugPrint('✅ Created new product with barcode: ${product.barcode}');
        }
      } else {
        await _firestore.collection('products').add(product.toFirestore());
        debugPrint('✅ Created new product without barcode');
      }
      
      await loadProducts();
    } catch (e) {
      debugPrint('Error saving product: $e');
      rethrow;
    }
  }

  Future<void> loadProducts({bool forceSync = false}) async {
    if (_isLoading || _isSyncing) return;

    try {
      // Step 1: Проверяем нужна ли синхронизация ДО загрузки данных из кэша
      final localDb = LocalDatabaseService();
      final shouldSync = _products.isEmpty || _shouldSync() || forceSync;
      final hasLocalCache = await localDb.hasCache('products');

      // Step 2: Если нужна синхронизация - запускаем её сразу
      if (shouldSync) {
        await syncFromGoogleSheets();
        return;
      }

      // Step 3: Если синхронизация не нужна - загружаем из кэша
      _isLoading = true;
      _error = null;
      notifyListeners();

      if (hasLocalCache) {
        final cachedProducts = await localDb.getCachedProducts();
        if (cachedProducts.isNotEmpty) {
          _products = cachedProducts.map((map) => _productFromMap(map)).toList();
          debugPrint('✅ Loaded ${_products.length} products from local cache');
          _isLoading = false;
          notifyListeners();

          // Проверяем обновления в фоне
          _checkForUpdatesInBackground();
          return;
        }
      }

      // Step 4: Если локального кэша нет - пробуем Firestore cache
      final snapshot = await _firestore
          .collection('products')
          .orderBy('name')
          .get(const GetOptions(source: Source.cache));

      if (snapshot.docs.isNotEmpty) {
        _products = snapshot.docs
            .map((doc) => Product.fromFirestore(doc))
            .toList();
        debugPrint('✅ Loaded ${_products.length} products from Firestore cache');
        _isLoading = false;
        notifyListeners();

        // Сохраняем в локальный кэш для следующего раза
        await _saveCacheFromFirestore(snapshot.docs);
        _checkForUpdatesInBackground();
        return;
      }

      // Step 5: Если ничего нет - делаем полную синхронизацию
      _isLoading = false;
      notifyListeners();
      await syncFromGoogleSheets();

    } catch (e) {
      _error = 'Ошибка загрузки продуктов: $e';
      _isLoading = false;
      debugPrint(_error);
      notifyListeners();

      // Fallback: пробуем загрузить с сервера
      try {
        final snapshot = await _firestore
            .collection('products')
            .orderBy('name')
            .get();

        _products = snapshot.docs
            .map((doc) => Product.fromFirestore(doc))
            .toList();
        notifyListeners();
      } catch (serverError) {
        debugPrint('Server load error: $serverError');
      }
    }
  }

  Future<void> _saveCacheFromFirestore(List<DocumentSnapshot> docs) async {
    try {
      final localDb = LocalDatabaseService();
      final productsForCache = docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'name': data['name'],
          'phePer100g': data['phePer100g'] ?? data['pheEstimatedPer100g'] ?? 0.0,
          'proteinPer100g': data['proteinPer100g'] ?? 0.0,
          'fatPer100g': data['fatPer100g'],
          'carbsPer100g': data['carbsPer100g'],
          'caloriesPer100g': data['caloriesPer100g'],
          'category': data['category'] ?? 'other',
          'source': data['source'],
          'barcode': data['barcode'],
          'googleSheetsId': data['googleSheetsId'],
          'notes': data['notes'],
          'createdBy': data['createdBy'],
          'isUserCreated': data['isUserCreated'] ?? false,
        };
      }).toList();
      await localDb.cacheProducts(productsForCache);
      debugPrint('✅ Saved ${productsForCache.length} products to local cache');
    } catch (e) {
      debugPrint('Error saving cache: $e');
    }
  }

  Product _productFromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'],
      name: map['name'],
      category: map['category'] ?? 'other',
      proteinPer100g: (map['proteinPer100g'] ?? 0).toDouble(),
      pheMeasuredPer100g: map['pheMeasuredPer100g']?.toDouble(),
      pheEstimatedPer100g: (map['phePer100g'] ?? 0).toDouble(),
      fatPer100g: map['fatPer100g'] != null ? (map['fatPer100g'] as num).toDouble() : null,
      carbsPer100g: map['carbsPer100g'] != null ? (map['carbsPer100g'] as num).toDouble() : null,
      caloriesPer100g: map['caloriesPer100g'] != null ? (map['caloriesPer100g'] as num).toDouble() : null,
      source: map['source'] ?? 'Google Sheets',
      notes: map['notes'],
      barcode: map['barcode'],
      googleSheetsId: map['googleSheetsId'],
      lastUpdated: DateTime.fromMillisecondsSinceEpoch(map['lastUpdated'] ?? DateTime.now().millisecondsSinceEpoch),
    );
  }

  bool _shouldSync() {
    if (_lastSync == null) return true;
    final hoursSinceSync = DateTime.now().difference(_lastSync!).inHours;
    return hoursSinceSync >= 24;
  }

  Future<void> _checkForUpdatesInBackground() async {
    try {
      final hasUpdates = await _hasGoogleSheetsUpdates();
      if (hasUpdates) {
        debugPrint('Updates available, syncing...');
        await syncFromGoogleSheets();
      }
    } catch (e) {
      debugPrint('Background check error: $e');
    }
  }

  Future<bool> _hasGoogleSheetsUpdates() async {
    try {
      final sheetProducts = await _sheetsService.fetchProducts();
      
      if (sheetProducts.length != _products.length) {
        return true;
      }

      for (int i = 0; i < 10 && i < sheetProducts.length; i++) {
        final sheetProduct = sheetProducts[i];
        final localProduct = _products.firstWhere(
          (p) => p.name == sheetProduct.name,
          orElse: () => sheetProduct,
        );
        
        if (localProduct.pheToUse != sheetProduct.pheToUse ||
            localProduct.proteinPer100g != sheetProduct.proteinPer100g) {
          return true;
        }
      }

      return false;
    } catch (e) {
      debugPrint('Error checking updates: $e');
      return false;
    }
  }

  Future<void> syncFromGoogleSheets() async {
    if (_isSyncing) return;

    _isSyncing = true;
    _error = null;
    _syncProgress = 0.0;
    _syncStatus = 'Подключение к Google Sheets...';
    notifyListeners();

    try {
      _syncProgress = 0.2;
      _syncStatus = 'Загрузка данных из таблицы...';
      notifyListeners();

      final sheetProducts = await _sheetsService.fetchProducts();

      // Если в Google Sheets нет данных, загружаем из USDA в Google Sheets
      if (sheetProducts.isEmpty) {
        _syncProgress = 0.3;
        _syncStatus = 'Google Sheets пуста, начинаем загрузку из USDA...';
        notifyListeners();

        try {
          final usdaSyncService = USDASyncService();

          _syncProgress = 0.4;
          _syncStatus = 'Загрузка базы данных USDA (это может занять несколько минут)...';
          notifyListeners();

          // Загружаем всю базу USDA в Google Sheets
          // Рекомендуется начать с 10000 продуктов для первоначального наполнения
          final success = await usdaSyncService.syncToGoogleSheets(
            maxProducts: 10000, // Можно увеличить до 50000+ если нужно больше
            onProgress: (current, total, status) {
              _syncProgress = 0.4 + (0.4 * (current / total));
              _syncStatus = status;
              notifyListeners();
            },
          );

          if (!success) {
            _error = 'Не удалось загрузить данные из USDA в Google Sheets';
            _isSyncing = false;
            notifyListeners();
            return;
          }

          _syncProgress = 0.8;
          _syncStatus = 'Данные загружены в Google Sheets, синхронизация с приложением...';
          notifyListeners();

          // Теперь загружаем данные из Google Sheets как обычно
          // Продолжаем выполнение, чтобы загрузить данные из Sheets
        } catch (e) {
          _error = 'Ошибка загрузки из USDA: $e';
          _isSyncing = false;
          notifyListeners();
          return;
        }

        // Перезагружаем данные из Google Sheets после успешной загрузки
        final reloadedSheetProducts = await _sheetsService.fetchProducts();

        if (reloadedSheetProducts.isEmpty) {
          _error = 'Данные не появились в Google Sheets. Проверьте настройки Web App.';
          _isSyncing = false;
          notifyListeners();
          return;
        }

        // Используем перезагруженные данные для дальнейшей обработки
        await _processSyncedProducts(reloadedSheetProducts);
        return;
      }

      await _processSyncedProducts(sheetProducts);
    } catch (e) {
      _error = 'Ошибка синхронизации: $e';
      debugPrint(_error);
    } finally {
      _isSyncing = false;
      _syncProgress = 0.0;
      _syncStatus = '';
      notifyListeners();
    }
  }

  /// Обработка продуктов из Google Sheets и сохранение в Firestore
  Future<void> _processSyncedProducts(List<Product> sheetProducts) async {
    try {
      _syncProgress = 0.4;
      _syncStatus = 'Получено ${sheetProducts.length} продуктов';
      notifyListeners();

        final success = await _usdaSyncService.syncToGoogleSheets(maxProducts: 500);

        if (!success) {
          _error = 'Ошибка загрузки данных из USDA';
          _isSyncing = false;
          notifyListeners();
          return;
        }

        _syncProgress = 0.5;
        _syncStatus = 'Данные USDA загружены в таблицу. Обновление локальной базы...';
        notifyListeners();

        await Future.delayed(const Duration(seconds: 2));

        final updatedSheetProducts = await _sheetsService.fetchProducts();

        if (updatedSheetProducts.isEmpty) {
          _error = 'Не удалось загрузить данные из USDA';
          _isSyncing = false;
          notifyListeners();
          return;
        }

        return await _syncProductsToFirestore(updatedSheetProducts);
      }

      return await _syncProductsToFirestore(sheetProducts);
    } catch (e) {
      _error = 'Ошибка синхронизации: $e';
      debugPrint(_error);
    } finally {
      _isSyncing = false;
      _syncProgress = 0.0;
      _syncStatus = '';
      notifyListeners();
    }
  }

  Future<void> _syncProductsToFirestore(List<Product> sheetProducts) async {
    _syncProgress = 0.6;
    _syncStatus = 'Получено ${sheetProducts.length} продуктов';
    notifyListeners();

    final existingSnapshot = await _firestore.collection('products').get();
    final existingProducts = <String, String>{};
    final existingBarcodes = <String, String>{};

    for (var doc in existingSnapshot.docs) {
      final data = doc.data();
      if (data['googleSheetsId'] != null) {
        existingProducts[data['googleSheetsId'] as String] = doc.id;
      }
      if (data['barcode'] != null) {
        existingBarcodes[data['barcode'] as String] = doc.id;
      }
    }

    _syncProgress = 0.7;
    _syncStatus = 'Обновление базы данных...';
    notifyListeners();

    final batch = _firestore.batch();
    int addedCount = 0;
    int updatedCount = 0;

    for (int i = 0; i < sheetProducts.length; i++) {
      final product = sheetProducts[i];

      if (i % 20 == 0) {
        _syncProgress = 0.7 + (0.2 * (i / sheetProducts.length));
        _syncStatus = 'Обработано ${i + 1} из ${sheetProducts.length}';
        notifyListeners();
      }

      await Future.delayed(const Duration(milliseconds: 500));
  }

  Future<void> addProduct(Product product) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Add user-specific metadata
      final productData = product.toFirestore();
      productData['createdBy'] = currentUser.uid;
      productData['isUserCreated'] = true;
      productData['createdAt'] = FieldValue.serverTimestamp();

      // Save to Firebase
      final docRef = await _firestore.collection('products').add(productData);

      // Save to local cache immediately
      final localDb = LocalDatabaseService();
      final productForCache = {
        'id': docRef.id,
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
        'createdBy': currentUser.uid,
        'isUserCreated': true,
      };

      await localDb.cacheProducts([productForCache]);

      // Add to local products list
      final newProduct = product.copyWith(id: docRef.id);
      _products.add(newProduct);
      _products.sort((a, b) => a.name.compareTo(b.name));

      notifyListeners();
      debugPrint('✅ User product added and saved locally: ${product.name}');
    } catch (e) {
      _error = 'Ошибка добавления продукта: $e';
      debugPrint(_error);
      rethrow;
    }
  }

  Future<void> updateProduct(Product product) async {
    try {
      await _firestore
          .collection('products')
          .doc(product.id)
          .update(product.toFirestore());

      // Update in local cache
      final localDb = LocalDatabaseService();
      final productForCache = {
        'id': product.id,
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
      };
      await localDb.cacheProducts([productForCache]);

      // Update in local list
      final index = _products.indexWhere((p) => p.id == product.id);
      if (index != -1) {
        _products[index] = product;
        notifyListeners();
      }

      debugPrint('✅ Product updated: ${product.name}');
    } catch (e) {
      _error = 'Ошибка обновления продукта: $e';
      debugPrint(_error);
      rethrow;
    }
  }

  Future<void> deleteProduct(String productId) async {
    try {
      await _firestore.collection('products').doc(productId).delete();
      await loadProducts();
    } catch (e) {
      _error = 'Ошибка удаления продукта: $e';
      debugPrint(_error);
      rethrow;
    }
  }

  List<Product> searchProducts(String query) {
    if (query.isEmpty) return _products;
    
    final lowerQuery = query.toLowerCase();
    return _products.where((product) {
      return product.name.toLowerCase().contains(lowerQuery) ||
             product.category.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  Product? findProductByName(String name) {
    try {
      return _products.firstWhere(
        (p) => p.name.toLowerCase() == name.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }

  List<Product> filterByCategory(String category) {
    if (category.isEmpty || category == 'all') return _products;
    return _products.where((p) => p.category == category).toList();
  }
}