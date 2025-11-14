// lib/services/barcode_lookup_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/product.dart';

class BarcodeLookupService {
  // UPCitemdb - бесплатная база данных штрих-кодов
  static const String _upcItemDbUrl = 'https://api.upcitemdb.com/prod/trial/lookup';
  
  Future<Product?> getProductByBarcode(String barcode) async {
    try {
      final url = Uri.parse('$_upcItemDbUrl?upc=$barcode');
      
      print('🔍 Searching in UPCitemdb for: $barcode');
      
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        
        if (data['items'] != null && (data['items'] as List).isNotEmpty) {
          final item = (data['items'] as List).first as Map<String, dynamic>;
          print('✅ Product found in UPCitemdb');
          return _parseUPCItemDb(item, barcode);
        }
      }
      
      print('❌ Product not found in UPCitemdb');
      return null;
    } catch (e) {
      print('❌ Error fetching from UPCitemdb: $e');
      return null;
    }
  }

  Product _parseUPCItemDb(Map<String, dynamic> item, String barcode) {
    final title = item['title'] as String? ?? 'Неизвестный продукт';
    final brand = item['brand'] as String? ?? '';
    final name = brand.isNotEmpty ? '$brand $title' : title;
    
    // UPCitemdb не предоставляет пищевую ценность, поэтому создаем заготовку
    return Product(
      id: '',
      name: name,
      category: 'other',
      proteinPer100g: 0.0,
      pheMeasuredPer100g: null,
      pheEstimatedPer100g: 0.0,
      fatPer100g: null,
      carbsPer100g: null,
      caloriesPer100g: null,
      notes: 'Найдено в UPCitemdb. Введите пищевую ценность с упаковки.',
      source: 'UPCitemdb',
      lastUpdated: DateTime.now(),
      googleSheetsId: null,
      barcode: barcode,
    );
  }
}