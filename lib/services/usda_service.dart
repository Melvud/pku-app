// lib/services/usda_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/product.dart';

class USDAService {
  static const String _apiKey = '2rO6mS1A7xnf9g26MIN6vvAPwP4gdmAvvygCDZta';
  static const String _baseUrl = 'https://api.nal.usda.gov/fdc/v1';

  Future<List<Product>> searchProducts(String query, {int pageSize = 25}) async {
    try {
      print('🔍 Searching in USDA for: $query');

      final response = await http.post(
        Uri.parse('$_baseUrl/foods/search?api_key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'query': query,
          'pageSize': pageSize,
          'dataType': ['Branded', 'SR Legacy', 'Foundation'],
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final foods = data['foods'] as List<dynamic>? ?? [];

        print('✅ Found ${foods.length} products in USDA');

        return foods.map((food) {
          return Product.fromUSDA(food as Map<String, dynamic>);
        }).toList();
      } else {
        print('❌ USDA API error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Error searching USDA: $e');
      return [];
    }
  }

  Future<Product?> getProductById(int fdcId) async {
    try {
      print('🔍 Fetching USDA product: $fdcId');

      final response = await http.get(
        Uri.parse('$_baseUrl/food/$fdcId?api_key=$_apiKey'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        print('✅ Product found in USDA');
        return Product.fromUSDA(data);
      } else {
        print('❌ USDA API error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Error fetching from USDA: $e');
      return null;
    }
  }

  Future<Product?> getProductByBarcode(String barcode) async {
    try {
      print('🔍 Searching in USDA for barcode: $barcode');

      final response = await http.post(
        Uri.parse('$_baseUrl/foods/search?api_key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'query': barcode,
          'dataType': ['Branded'],
          'pageSize': 1,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final foods = data['foods'] as List<dynamic>? ?? [];

        if (foods.isNotEmpty) {
          final food = foods.first as Map<String, dynamic>;
          final gtinUpc = food['gtinUpc'] as String?;
          if (gtinUpc != null && gtinUpc == barcode) {
            print('✅ Product found in USDA by barcode');
            return Product.fromUSDA(food);
          }
        }

        print('❌ Product not found in USDA by barcode');
        return null;
      } else {
        print('❌ USDA API error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Error fetching from USDA: $e');
      return null;
    }
  }

  Future<List<Product>> getAllProducts({
    int pageSize = 200,
    int maxPages = 10,
    List<String> dataTypes = const ['Branded'],
  }) async {
    final allProducts = <Product>[];

    try {
      for (int page = 1; page <= maxPages; page++) {
        print('📥 Fetching USDA page $page of $maxPages...');

        final response = await http.post(
          Uri.parse('$_baseUrl/foods/list?api_key=$_apiKey'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'dataType': dataTypes,
            'pageSize': pageSize,
            'pageNumber': page,
          }),
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body) as List<dynamic>;

          final products = data.map((food) {
            return Product.fromUSDA(food as Map<String, dynamic>);
          }).toList();

          allProducts.addAll(products);
          print('✅ Fetched ${products.length} products (total: ${allProducts.length})');

          if (data.length < pageSize) {
            break;
          }

          await Future.delayed(const Duration(milliseconds: 500));
        } else {
          print('❌ USDA API error on page $page: ${response.statusCode}');
          break;
        }
      }

      return allProducts;
    } catch (e) {
      print('❌ Error fetching all products from USDA: $e');
      return allProducts;
    }
  }
}
