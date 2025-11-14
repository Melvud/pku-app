// lib/services/open_food_facts_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/product.dart';

class OpenFoodFactsService {
  static const String _baseUrl = 'https://world.openfoodfacts.org/api/v2';
  
  Future<Product?> getProductByBarcode(String barcode) async {
    try {
      final url = Uri.parse('$_baseUrl/product/$barcode');
      
      print('🔍 Searching in Open Food Facts for: $barcode');
      
      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'PheTracker - PKU Diet App - Android',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        
        if (data['status'] == 1) {
          print('✅ Product found in Open Food Facts');
          return Product.fromOpenFoodFacts(data, barcode);
        } else {
          print('❌ Product not found in Open Food Facts');
          return null;
        }
      } else {
        print('❌ Open Food Facts API error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Error fetching from Open Food Facts: $e');
      return null;
    }
  }

  Future<List<Product>> searchProducts(String query) async {
    try {
      final url = Uri.parse('$_baseUrl/search?search_terms=$query&page_size=20&json=true');
      
      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'PheTracker - PKU Diet App - Android',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final products = data['products'] as List<dynamic>? ?? [];
        
        return products.map((productData) {
          final barcode = productData['code'] as String? ?? '';
          return Product.fromOpenFoodFacts({'product': productData}, barcode);
        }).toList();
      } else {
        return [];
      }
    } catch (e) {
      print('Error searching Open Food Facts: $e');
      return [];
    }
  }
}