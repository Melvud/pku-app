// lib/services/usda_sync_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/product.dart';
import 'usda_service.dart';

class USDASyncService {
  static const String _spreadsheetId = '1tDEp7KYh0leLhv_AjpkAFKnq-i2_d39Zx3sco1zVlp4';
  static const String _apiKey = 'AIzaSyCKgDraNgrpEOZCtWF6JoZxJ1FJjaYDMFg';
  static const String _webAppUrl = 'https://script.google.com/macros/s/AKfycbwUMjuNiNJ0kp-N1_Qr8D6Uhcnc2sbYYHHwy71bO-HKLEpL5wQBQmb8qsk-0Zxr3yY5/exec';

  final USDAService _usdaService = USDAService();

  Future<bool> syncToGoogleSheets({
    int maxProducts = 1000,
    String? webAppUrl,
  }) async {
    try {
      print('🔄 Starting USDA sync to Google Sheets...');

      // Получаем продукты из USDA
      final products = await _usdaService.getAllProducts(
        pageSize: 200,
        maxPages: (maxProducts / 200).ceil(),
        dataTypes: ['Branded', 'SR Legacy'],
      );

      if (products.isEmpty) {
        print('❌ No products to sync');
        return false;
      }

      print('📦 Got ${products.length} products from USDA');

      final rows = products.map((product) => _productToSheetRow(product)).toList();
      final url = webAppUrl ?? _webAppUrl;

      return await _sendToWebApp(url, rows);
    } catch (e) {
      print('❌ Error syncing to Google Sheets: $e');
      return false;
    }
  }

  List<dynamic> _productToSheetRow(Product product) {
    return [
      product.name,
      product.category,
      product.proteinPer100g,
      product.pheMeasuredPer100g ?? '',
      product.pheEstimatedPer100g,
      product.fatPer100g ?? '',
      product.carbsPer100g ?? '',
      product.caloriesPer100g ?? '',
      product.notes ?? '',
      product.source ?? '',
      product.barcode ?? '',
    ];
  }

  Future<bool> _sendToWebApp(String webAppUrl, List<List<dynamic>> rows) async {
    try {
      print('📤 Sending data to Google Apps Script...');

      final response = await http.post(
        Uri.parse(webAppUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': 'sync_usda',
          'data': rows,
        }),
      );

      if (response.statusCode == 200) {
        print('✅ Data synced successfully');
        return true;
      } else {
        print('❌ Failed to sync data: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Error sending to Web App: $e');
      return false;
    }
  }

  Future<bool> shouldSync() async {
    return true;
  }
}
