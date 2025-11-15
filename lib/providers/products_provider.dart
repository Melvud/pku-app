// lib/providers/products_provider.dart (обновленная версия)
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

    _isLoading = true;
    _error = null;
    _syncStatus = 'Загрузка локальных данных...';
    _syncProgress = 0.1;
    notifyListeners();

    try {
      // Step 1: Try to load from local SQLite cache first
      final localDb = LocalDatabaseService();
      final cachedProducts = await localDb.getCachedProducts();

      if (cachedProducts.isNotEmpty) {
        _products = cachedProducts.map((map) => _productFromMap(map)).toList();
        _syncProgress = 0.3;
        _syncStatus = 'Загружено ${_products.length} продуктов из кэша';
        debugPrint('✅ Loaded ${_products.length} products from local cache');
        notifyListeners();
      } else {
        // Fallback to Firestore cache if local cache is empty
        final snapshot = await _firestore
            .collection('products')
            .orderBy('name')
            .get(const GetOptions(source: Source.cache));

        if (snapshot.docs.isNotEmpty) {
          _products = snapshot.docs
              .map((doc) => Product.fromFirestore(doc))
              .toList();
          _syncProgress = 0.3;
          _syncStatus = 'Загружено ${_products.length} продуктов';
          notifyListeners();
        }
      }

      // Step 2: Check if we need to sync
      if (_products.isEmpty || _shouldSync() || forceSync) {
        await syncFromGoogleSheets();
      } else {
        _checkForUpdatesInBackground();
      }

    } catch (e) {
      _error = 'Ошибка загрузки продуктов: $e';
      debugPrint(_error);

      try {
        final snapshot = await _firestore
            .collection('products')
            .orderBy('name')
            .get();

        _products = snapshot.docs
            .map((doc) => Product.fromFirestore(doc))
            .toList();
      } catch (serverError) {
        debugPrint('Server load error: $serverError');
      }
    } finally {
      _isLoading = false;
      _syncProgress = 1.0;
      _syncStatus = '';
      notifyListeners();
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
      fatPer100g: (map['fatPer100g'] ?? 0).toDouble(),
      carbsPer100g: (map['carbsPer100g'] ?? 0).toDouble(),
      caloriesPer100g: (map['caloriesPer100g'] ?? 0).toDouble(),
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
      
      if (sheetProducts.isEmpty) {
        _error = 'Нет данных в таблице';
        _isSyncing = false;
        notifyListeners();
        return;
      }

      _syncProgress = 0.4;
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

      _syncProgress = 0.5;
      _syncStatus = 'Обновление базы данных...';
      notifyListeners();

      final batch = _firestore.batch();
      int addedCount = 0;
      int updatedCount = 0;

      for (int i = 0; i < sheetProducts.length; i++) {
        final product = sheetProducts[i];
        
        if (i % 20 == 0) {
          _syncProgress = 0.5 + (0.4 * (i / sheetProducts.length));
          _syncStatus = 'Обработано ${i + 1} из ${sheetProducts.length}';
          notifyListeners();
        }

        String? existingId;
        
        if (product.barcode != null && existingBarcodes.containsKey(product.barcode)) {
          existingId = existingBarcodes[product.barcode];
        } else if (existingProducts.containsKey(product.googleSheetsId)) {
          existingId = existingProducts[product.googleSheetsId];
        }
        
        if (existingId != null) {
          final docRef = _firestore.collection('products').doc(existingId);
          batch.update(docRef, product.toFirestore());
          updatedCount++;
        } else {
          final docRef = _firestore.collection('products').doc();
          batch.set(docRef, product.toFirestore());
          addedCount++;
        }
      }

      _syncProgress = 0.9;
      _syncStatus = 'Сохранение изменений...';
      notifyListeners();
      
      await batch.commit();
      
      _lastSync = DateTime.now();
      await _saveLastSyncTime();

      _syncProgress = 0.95;
      _syncStatus = 'Загрузка обновленных данных...';
      notifyListeners();

      final snapshot = await _firestore
          .collection('products')
          .orderBy('name')
          .get();

      _products = snapshot.docs
          .map((doc) => Product.fromFirestore(doc))
          .toList();

      // Save to local SQLite cache
      final localDb = LocalDatabaseService();
      final productsForCache = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'],
          'phePer100g': data['phePer100g'] ?? data['pheEstimatedPer100g'] ?? 0.0,
          'proteinPer100g': data['proteinPer100g'] ?? 0.0,
          'fatPer100g': data['fatPer100g'] ?? 0.0,
          'carbsPer100g': data['carbsPer100g'] ?? 0.0,
          'caloriesPer100g': data['caloriesPer100g'] ?? 0.0,
          'category': data['category'] ?? 'other',
          'source': data['source'],
          'barcode': data['barcode'],
          'googleSheetsId': data['googleSheetsId'],
          'notes': data['notes'],
        };
      }).toList();

      await localDb.cacheProducts(productsForCache);
      debugPrint('✅ Cached ${productsForCache.length} products to local storage');

      _syncProgress = 1.0;
      _syncStatus = 'Синхронизация завершена';

      debugPrint('✅ Sync completed: added $addedCount, updated $updatedCount products');

      await Future.delayed(const Duration(milliseconds: 500));
      
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
        'fatPer100g': product.fatPer100g ?? 0.0,
        'carbsPer100g': product.carbsPer100g ?? 0.0,
        'caloriesPer100g': product.caloriesPer100g ?? 0.0,
        'category': product.category,
        'source': product.source,
        'barcode': product.barcode,
        'notes': product.notes,
      };

      await localDb.cacheProducts([productForCache]);

      // Add to local products list
      final newProduct = product.copyWith(id: docRef.id);
      _products.add(newProduct);
      _products.sort((a, b) => a.name.compareTo(b.name));

      notifyListeners();
      debugPrint('✅ User product added: ${product.name}');
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
      await loadProducts();
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