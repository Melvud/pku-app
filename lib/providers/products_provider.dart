import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product.dart';
import '../services/google_sheets_service.dart';

class ProductsProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSheetsService _sheetsService = GoogleSheetsService();
  
  List<Product> _products = [];
  bool _isLoading = false;
  String? _error;

  List<Product> get products => _products;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Get products from Firestore
  Future<void> loadProducts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collection('products')
          .orderBy('name')
          .get();

      _products = snapshot.docs
          .map((doc) => Product.fromFirestore(doc))
          .toList();
    } catch (e) {
      _error = 'Ошибка загрузки продуктов: $e';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Sync products from Google Sheets
  Future<void> syncFromGoogleSheets(String spreadsheetId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final sheetProducts = await _sheetsService.fetchProducts(spreadsheetId);
      
      // Batch write to Firestore
      final batch = _firestore.batch();
      
      for (final product in sheetProducts) {
        final docRef = _firestore.collection('products').doc();
        batch.set(docRef, product.toFirestore());
      }
      
      await batch.commit();
      
      // Reload products
      await loadProducts();
      
      debugPrint('Synced ${sheetProducts.length} products from Google Sheets');
    } catch (e) {
      _error = 'Ошибка синхронизации: $e';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Add product
  Future<void> addProduct(Product product) async {
    try {
      await _firestore.collection('products').add(product.toFirestore());
      await loadProducts();
    } catch (e) {
      _error = 'Ошибка добавления продукта: $e';
      debugPrint(_error);
      rethrow;
    }
  }

  // Update product
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

  // Delete product
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

  // Search products
  List<Product> searchProducts(String query) {
    if (query.isEmpty) return _products;
    
    final lowerQuery = query.toLowerCase();
    return _products.where((product) {
      return product.name.toLowerCase().contains(lowerQuery) ||
             product.category.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  // Filter by category
  List<Product> filterByCategory(String category) {
    if (category.isEmpty || category == 'all') return _products;
    return _products.where((p) => p.category == category).toList();
  }
}