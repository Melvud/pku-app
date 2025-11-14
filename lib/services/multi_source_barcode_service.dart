// lib/services/multi_source_barcode_service.dart
import '../models/product.dart';
import 'open_food_facts_service.dart';
import 'barcode_lookup_service.dart';

class MultiSourceBarcodeService {
  final OpenFoodFactsService _openFoodFacts = OpenFoodFactsService();
  final BarcodeLookupService _barcodeLookup = BarcodeLookupService();

  Future<ProductSearchResult> searchProductByBarcode(String barcode) async {
    // 1. Пробуем Open Food Facts (полные данные о пищевой ценности)
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

    // 2. Пробуем UPCitemdb (только название, без пищевой ценности)
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

    // 3. Ничего не найдено - возвращаем заготовку для ручного ввода
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