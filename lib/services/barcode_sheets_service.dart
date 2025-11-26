// lib/services/barcode_sheets_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/product.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Service for loading products with barcodes from Google Sheets
/// Sheet: gid=1127717778 - Barcode database
/// Sheet: gid=288786302 - General products database
class BarcodeSheetsService {
  static String get _spreadsheetId => dotenv.env['SPREADSHEET_ID'] ?? '';
  static String get _apiKey => dotenv.env['GOOGLE_SHEETS_API_KEY'] ?? '';

  // Sheet IDs
  static int get _barcodeSheetGid =>
      int.tryParse(dotenv.env['BARCODE_SHEET_GID'] ?? '') ?? 0;
  static int get _generalProductsSheetGid =>
      int.tryParse(dotenv.env['GENERAL_PRODUCTS_SHEET_GID'] ?? '') ?? 0;

  /// Fetch products with barcodes from the barcode sheet
  Future<List<Product>> fetchBarcodeProducts() async {
    try {
      // First get sheet name by gid
      final sheetName = await _getSheetNameByGid(_barcodeSheetGid);
      if (sheetName == null) {
        debugPrint('❌ Could not find barcode sheet');
        return [];
      }

      debugPrint('📊 Loading barcode products from sheet: $sheetName');

      final url = Uri.parse(
        'https://sheets.googleapis.com/v4/spreadsheets/$_spreadsheetId/values/${Uri.encodeComponent(sheetName)}!A2:L?key=$_apiKey',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final values = data['values'] as List<dynamic>?;

        if (values == null || values.isEmpty) {
          debugPrint('⚠️ No data found in barcode sheet');
          return [];
        }

        debugPrint('✅ Found ${values.length} barcode products');

        return values
            .asMap()
            .entries
            .map((entry) => _parseProductFromBarcodeSheet(
                  entry.value as List<dynamic>,
                  entry.key,
                ))
            .where((product) =>
                product.name.isNotEmpty &&
                product.barcode != null &&
                product.barcode!.isNotEmpty)
            .toList();
      } else {
        throw Exception('Failed to load barcode sheet: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error fetching barcode products: $e');
      return [];
    }
  }

  /// Fetch general products from the main products sheet
  Future<List<Product>> fetchGeneralProducts() async {
    try {
      final sheetName = await _getSheetNameByGid(_generalProductsSheetGid);
      if (sheetName == null) {
        debugPrint('❌ Could not find general products sheet');
        return [];
      }

      debugPrint('📊 Loading general products from sheet: $sheetName');

      final url = Uri.parse(
        'https://sheets.googleapis.com/v4/spreadsheets/$_spreadsheetId/values/${Uri.encodeComponent(sheetName)}!A2:L?key=$_apiKey',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final values = data['values'] as List<dynamic>?;

        if (values == null || values.isEmpty) {
          debugPrint('⚠️ No data found in general products sheet');
          return [];
        }

        debugPrint('✅ Found ${values.length} general products');

        return values
            .asMap()
            .entries
            .map((entry) => _parseProductFromGeneralSheet(
                  entry.value as List<dynamic>,
                  entry.key,
                ))
            .where((product) => product.name.isNotEmpty)
            .toList();
      } else {
        throw Exception(
            'Failed to load general products sheet: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error fetching general products: $e');
      return [];
    }
  }

  /// Find a product by barcode in the barcode sheet
  Future<Product?> findProductByBarcode(String barcode) async {
    try {
      final products = await fetchBarcodeProducts();

      for (var product in products) {
        if (product.barcode == barcode) {
          return product;
        }
      }

      return null;
    } catch (e) {
      debugPrint('❌ Error finding product by barcode: $e');
      return null;
    }
  }

  /// Get sheet name by gid
  Future<String?> _getSheetNameByGid(int gid) async {
    try {
      final metaUrl = Uri.parse(
        'https://sheets.googleapis.com/v4/spreadsheets/$_spreadsheetId?key=$_apiKey',
      );

      final metaResponse = await http.get(metaUrl);

      if (metaResponse.statusCode != 200) {
        return null;
      }

      final metaData = json.decode(metaResponse.body);
      final sheets = metaData['sheets'] as List<dynamic>;

      for (var sheet in sheets) {
        final properties = sheet['properties'] as Map<String, dynamic>;
        if (properties['sheetId'] == gid) {
          return properties['title'] as String;
        }
      }

      return null;
    } catch (e) {
      debugPrint('❌ Error getting sheet name: $e');
      return null;
    }
  }

  /// Parse product from barcode sheet row
  /// Expected columns:
  /// A: Штрих-код
  /// B: Название
  /// C: Категория
  /// D: Белок (на 100г)
  /// E: Фенилаланин (на 100г) - может быть пустым
  /// F: Жиры (на 100г)
  /// G: Углеводы (на 100г)
  /// H: Калории (на 100г)
  /// I: Примечания
  /// J: Источник
  Product _parseProductFromBarcodeSheet(List<dynamic> row, int rowIndex) {
    final barcode = row.isNotEmpty ? row[0].toString().trim() : '';
    final name = row.length > 1 ? row[1].toString().trim() : '';
    final category = row.length > 2 ? row[2].toString().trim() : 'other';
    final protein = row.length > 3 ? _parseDouble(row[3]) : 0.0;
    final pheMeasured = row.length > 4 ? _parseDoubleOrNull(row[4]) : null;
    final fat = row.length > 5 ? _parseDoubleOrNull(row[5]) : null;
    final carbs = row.length > 6 ? _parseDoubleOrNull(row[6]) : null;
    final calories = row.length > 7 ? _parseDoubleOrNull(row[7]) : null;
    final notes = row.length > 8 ? row[8].toString().trim() : null;
    final source =
        row.length > 9 ? row[9].toString().trim() : 'Google Sheets Barcode DB';

    // Calculate estimated Phe if not measured (1g protein = 50mg Phe)
    final pheEstimated = protein * 50;

    return Product(
      id: '',
      name: name,
      category: _mapCategory(category),
      proteinPer100g: protein,
      pheMeasuredPer100g: pheMeasured,
      pheEstimatedPer100g: pheEstimated,
      fatPer100g: fat,
      carbsPer100g: carbs,
      caloriesPer100g: calories,
      notes: notes,
      source: source.isNotEmpty ? source : 'Google Sheets Barcode DB',
      lastUpdated: DateTime.now(),
      googleSheetsId: 'barcode_$rowIndex',
      barcode: barcode.isNotEmpty ? barcode : null,
    );
  }

  /// Parse product from general products sheet row
  /// Expected columns (based on existing GoogleSheetsService):
  /// A: Название
  /// B: Категория
  /// C: Белок (на 100г)
  /// D: Фе измеренное (на 100г)
  /// E: Фе оценочное (на 100г)
  /// F: Жиры (на 100г)
  /// G: Углеводы (на 100г)
  /// H: Калории (на 100г)
  /// I: Примечания
  /// J: Источник
  /// K: Штрих-код (optional)
  Product _parseProductFromGeneralSheet(List<dynamic> row, int rowIndex) {
    final name = row.isNotEmpty ? row[0].toString().trim() : '';
    final category = row.length > 1 ? row[1].toString().trim() : 'other';
    final protein = row.length > 2 ? _parseDouble(row[2]) : 0.0;
    final pheMeasured = row.length > 3 ? _parseDoubleOrNull(row[3]) : null;
    final pheEstimated = row.length > 4 ? _parseDouble(row[4]) : protein * 50;
    final fat = row.length > 5 ? _parseDoubleOrNull(row[5]) : null;
    final carbs = row.length > 6 ? _parseDoubleOrNull(row[6]) : null;
    final calories = row.length > 7 ? _parseDoubleOrNull(row[7]) : null;
    final notes = row.length > 8 ? row[8].toString().trim() : null;
    final source = row.length > 9 ? row[9].toString().trim() : 'Google Sheets';
    final barcode = row.length > 10 ? row[10].toString().trim() : null;

    return Product(
      id: '',
      name: name,
      category: _mapCategory(category),
      proteinPer100g: protein,
      pheMeasuredPer100g: pheMeasured,
      pheEstimatedPer100g: pheEstimated,
      fatPer100g: fat,
      carbsPer100g: carbs,
      caloriesPer100g: calories,
      notes: notes,
      source: source.isNotEmpty ? source : 'Google Sheets',
      lastUpdated: DateTime.now(),
      googleSheetsId: 'general_$rowIndex',
      barcode: barcode != null && barcode.isNotEmpty ? barcode : null,
    );
  }

  String _mapCategory(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('овощ') || lower.contains('vegetable'))
      return 'vegetables';
    if (lower.contains('фрукт') || lower.contains('fruit')) return 'fruits';
    if (lower.contains('зерн') ||
        lower.contains('хлеб') ||
        lower.contains('grain') ||
        lower.contains('bread')) return 'grains';
    if (lower.contains('молоч') || lower.contains('dairy')) return 'dairy';
    if (lower.contains('мяс') ||
        lower.contains('meat') ||
        lower.contains('рыб') ||
        lower.contains('fish')) return 'protein';
    if (lower.contains('напит') ||
        lower.contains('drink') ||
        lower.contains('beverage')) return 'beverages';
    if (lower.contains('сладост') ||
        lower.contains('sweet') ||
        lower.contains('конфет')) return 'sweets';
    return 'other';
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    final str = value.toString().trim().replaceAll(',', '.');
    if (str.isEmpty) return 0.0;
    return double.tryParse(str) ?? 0.0;
  }

  double? _parseDoubleOrNull(dynamic value) {
    if (value == null) return null;
    final str = value.toString().trim().replaceAll(',', '.');
    if (str.isEmpty) return null;
    return double.tryParse(str);
  }
}
