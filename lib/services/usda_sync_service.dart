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
    Function(int current, int total, String status)? onProgress,
  }) async {
    try {
      print('🔄 Starting USDA sync to Google Sheets...');

      final url = webAppUrl ?? _webAppUrl;

      // Получаем продукты из USDA постепенно и отправляем пакетами
      final batchSize = 500; // Отправляем по 500 продуктов за раз
      final pageSize = 200;
      final totalPages = (maxProducts / pageSize).ceil();

      int totalProcessed = 0;
      int totalSynced = 0;

      for (int page = 0; page < totalPages; page++) {
        onProgress?.call(page + 1, totalPages, 'Загрузка страницы ${page + 1} из $totalPages из USDA...');
        print('📥 Fetching page ${page + 1}/$totalPages from USDA...');

        // Получаем одну страницу продуктов
        final products = await _usdaService.getAllProducts(
          pageSize: pageSize,
          maxPages: 1,
          startPage: page,
          dataTypes: ['Branded', 'SR Legacy', 'Foundation'],
        );

        if (products.isEmpty) {
          print('⚠️ No more products available');
          break;
        }

        print('📦 Got ${products.length} products from USDA (total: ${totalProcessed + products.length})');

        // Разбиваем на пакеты для отправки
        for (int i = 0; i < products.length; i += batchSize) {
          final end = (i + batchSize < products.length) ? i + batchSize : products.length;
          final batch = products.sublist(i, end);

          onProgress?.call(
            page + 1,
            totalPages,
            'Отправка ${i + batch.length} из ${totalProcessed + products.length} продуктов в Google Sheets...'
          );
          print('📤 Sending batch ${(i / batchSize).floor() + 1} (${batch.length} products)...');

          final rows = batch.map((product) => _productToSheetRow(product)).toList();

          final success = await _sendToWebApp(url, rows);
          if (!success) {
            print('❌ Failed to sync batch, continuing...');
            // Продолжаем даже если один пакет не удался
          } else {
            totalSynced += batch.length;
          }

          // Небольшая пауза между пакетами, чтобы не перегружать Google Apps Script
          await Future.delayed(const Duration(milliseconds: 500));
        }

        totalProcessed += products.length;

        if (totalProcessed >= maxProducts) {
          print('✅ Reached target of $maxProducts products');
          break;
        }
      }

      print('✅ Sync completed: processed $totalProcessed products, synced $totalSynced to Google Sheets');
      return totalSynced > 0;
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
