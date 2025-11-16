// lib/services/multi_source_barcode_service.dart
import '../models/product.dart';
import 'open_food_facts_service.dart';
import 'barcode_lookup_service.dart';
import 'fatsecret_service.dart';
import 'usda_service.dart';

class MultiSourceBarcodeService {
  final OpenFoodFactsService _openFoodFacts = OpenFoodFactsService();
  final BarcodeLookupService _barcodeLookup = BarcodeLookupService();
  final FatSecretService _fatSecret = FatSecretService();
  final USDAService _usda = USDAService();

  Future<ProductSearchResult> searchProductByBarcode(String barcode) async {
    // 1. Пробуем FatSecret (наиболее полные данные о пищевой ценности)
    try {
      final fatSecretProduct = await _fatSecret.getProductByBarcode(barcode);
      if (fatSecretProduct != null) {
        return ProductSearchResult(
          product: fatSecretProduct,
          source: 'FatSecret',
          hasNutritionData: true,
        );
      }
    } catch (e) {
      print('FatSecret failed: $e');
    }

    // 2. Пробуем USDA FoodData Central (обширная база данных США)
    try {
      final usdaProduct = await _usda.getProductByBarcode(barcode);
      if (usdaProduct != null) {
        return ProductSearchResult(
          product: usdaProduct,
          source: 'USDA',
          hasNutritionData: true,
        );
      }
    } catch (e) {
      print('USDA failed: $e');
    }

    // 3. Пробуем Open Food Facts (международная база данных)
    try {
      final offProduct = await _openFoodFacts.getProductByBarcode(barcode);
      if (offProduct != null) {
        return ProductSearchResult(
          product: offProduct,
          source: 'Open Food Facts',
          hasNutritionData: true,
        );
      }
    } catch (e) {
      print('Open Food Facts failed: $e');
    }

    // 4. Пробуем UPCitemdb (только название, без пищевой ценности)
    try {
      final upcProduct = await _barcodeLookup.getProductByBarcode(barcode);
      if (upcProduct != null) {
        return ProductSearchResult(
          product: upcProduct,
          source: 'UPCitemdb',
          hasNutritionData: false,
        );
      }
    } catch (e) {
      print('UPCitemdb failed: $e');
    }

    // 5. Ничего не найдено - возвращаем заготовку для ручного ввода
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
        notes: 'Продукт не найден в базах данных',
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

class ProductSearchResult {
  final Product product;
  final String source;
  final bool hasNutritionData;

  ProductSearchResult({
    required this.product,
    required this.source,
    required this.hasNutritionData,
  });
}