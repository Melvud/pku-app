// lib/services/usda_sync_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/product.dart';
import 'usda_service.dart';

/// Сервис для синхронизации данных USDA с Google Sheets
///
/// Этот сервис загружает продукты из USDA FoodData Central
/// и синхронизирует их с Google Sheets для кэширования и автономного доступа.
class USDASyncService {
  static const String _spreadsheetId = '1tDEp7KYh0leLhv_AjpkAFKnq-i2_d39Zx3sco1zVlp4';
  static const String _apiKey = 'AIzaSyCKgDraNgrpEOZCtWF6JoZxJ1FJjaYDMFg';

  final USDAService _usdaService = USDAService();

  /// Синхронизация данных USDA с Google Sheets
  ///
  /// ВАЖНО: Для записи в Google Sheets требуется OAuth авторизация.
  /// Этот метод использует Google Apps Script для записи данных.
  ///
  /// Инструкции по настройке:
  /// 1. Откройте Google Sheet: https://docs.google.com/spreadsheets/d/$_spreadsheetId
  /// 2. Перейдите в Extensions > Apps Script
  /// 3. Создайте скрипт с функцией doPost() для приема данных
  /// 4. Разверните как Web App
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

      // Конвертируем в формат для Google Sheets
      final rows = products.map((product) => _productToSheetRow(product)).toList();

      if (webAppUrl != null) {
        // Отправляем данные в Google Apps Script Web App
        return await _sendToWebApp(webAppUrl, rows);
      } else {
        // Сохраняем в JSON для ручной загрузки
        return await _saveToJsonForManualUpload(rows);
      }
    } catch (e) {
      print('❌ Error syncing to Google Sheets: $e');
      return false;
    }
  }

  /// Конвертирует Product в строку для Google Sheets
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

  /// Отправка данных в Google Apps Script Web App
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

  /// Сохранение данных в JSON для ручной загрузки
  Future<bool> _saveToJsonForManualUpload(List<List<dynamic>> rows) async {
    try {
      print('💾 Saving data for manual upload...');

      final jsonData = json.encode({
        'timestamp': DateTime.now().toIso8601String(),
        'rows': rows,
        'instructions': [
          '1. Откройте Google Sheet: https://docs.google.com/spreadsheets/d/$_spreadsheetId',
          '2. Скопируйте данные из rows',
          '3. Вставьте их в таблицу, начиная со строки 2',
        ],
      });

      print('✅ JSON data prepared for manual upload');
      print('📋 Total rows: ${rows.length}');
      print('\nСохраните эти данные и загрузите вручную в Google Sheets:');
      print(jsonData);

      return true;
    } catch (e) {
      print('❌ Error saving JSON: $e');
      return false;
    }
  }

  /// Проверка необходимости синхронизации
  Future<bool> shouldSync() async {
    try {
      // Проверяем, когда была последняя синхронизация
      // Можно хранить timestamp в SharedPreferences
      // Для простоты возвращаем true
      return true;
    } catch (e) {
      return false;
    }
  }
}

/// Google Apps Script для записи данных в Google Sheets
///
/// Вставьте этот код в Google Apps Script (Extensions > Apps Script):
///
/// ```javascript
/// function doPost(e) {
///   try {
///     const data = JSON.parse(e.postData.contents);
///
///     if (data.action === 'sync_usda') {
///       const sheet = SpreadsheetApp.getActiveSpreadsheet().getActiveSheet();
///
///       // Очищаем старые данные (кроме заголовков)
///       const lastRow = sheet.getLastRow();
///       if (lastRow > 1) {
///         sheet.deleteRows(2, lastRow - 1);
///       }
///
///       // Вставляем новые данные
///       if (data.data && data.data.length > 0) {
///         sheet.getRange(2, 1, data.data.length, data.data[0].length).setValues(data.data);
///       }
///
///       return ContentService
///         .createTextOutput(JSON.stringify({ success: true, rows: data.data.length }))
///         .setMimeType(ContentService.MimeType.JSON);
///     }
///
///     return ContentService
///       .createTextOutput(JSON.stringify({ success: false, error: 'Unknown action' }))
///       .setMimeType(ContentService.MimeType.JSON);
///
///   } catch (error) {
///     return ContentService
///       .createTextOutput(JSON.stringify({ success: false, error: error.toString() }))
///       .setMimeType(ContentService.MimeType.JSON);
///   }
/// }
/// ```
///
/// После создания скрипта:
/// 1. Нажмите Deploy > New deployment
/// 2. Выберите "Web app"
/// 3. Execute as: Me
/// 4. Who has access: Anyone
/// 5. Скопируйте Web app URL и используйте в методе syncToGoogleSheets()
