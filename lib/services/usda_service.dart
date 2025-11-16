// lib/services/usda_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/product.dart';

/// Сервис для работы с USDA FoodData Central API
///
/// USDA предоставляет одну из самых полных баз данных продуктов в США
/// с подробной пищевой ценностью.
///
/// Для использования необходимо получить бесплатный API ключ на
/// https://fdc.nal.usda.gov/api-key-signup.html
class USDAService {
  // TODO: Заменить на реальный ключ из USDA FoodData Central
  static const String _apiKey = 'YOUR_USDA_API_KEY';
  static const String _baseUrl = 'https://api.nal.usda.gov/fdc/v1';

  /// Поиск продуктов по названию
  Future<List<Product>> searchProducts(String query, {int pageSize = 25}) async {
    try {
      print('🔍 Searching in USDA for: $query');

      final response = await http.post(
        Uri.parse('$_baseUrl/foods/search?api_key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'query': query,
          'pageSize': pageSize,
          'dataType': ['Branded', 'SR Legacy', 'Foundation'], // Типы данных
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

  /// Получение детальной информации о продукте по FDC ID
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

  /// Поиск продукта по штрих-коду (UPC/GTIN)
  Future<Product?> getProductByBarcode(String barcode) async {
    try {
      print('🔍 Searching in USDA for barcode: $barcode');

      final response = await http.post(
        Uri.parse('$_baseUrl/foods/search?api_key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'query': barcode,
          'dataType': ['Branded'], // Только брендированные продукты имеют штрих-коды
          'pageSize': 1,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final foods = data['foods'] as List<dynamic>? ?? [];

        if (foods.isNotEmpty) {
          final food = foods.first as Map<String, dynamic>;
          // Проверяем, что найденный продукт действительно имеет этот штрих-код
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

  /// Получение всех продуктов из USDA для синхронизации с Google Sheets
  /// ВАЖНО: Этот метод может занять много времени и трафика!
  /// Используйте с осторожностью и фильтрами
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

          // Если получили меньше продуктов чем pageSize, значит это последняя страница
          if (data.length < pageSize) {
            break;
          }

          // Небольшая задержка между запросами, чтобы не перегружать API
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
