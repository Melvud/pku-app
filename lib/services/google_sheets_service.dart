// lib/services/google_sheets_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/product.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

class GoogleSheetsService {
  static String get _spreadsheetId => dotenv.env['SPREADSHEET_ID'] ?? '';
  static String get _apiKey => dotenv.env['GOOGLE_SHEETS_API_KEY'] ?? '';
  static int get _productsGid =>
      int.tryParse(dotenv.env['PRODUCTS_GID'] ?? '') ?? 0;

  Future<String?> _getSheetTitle(int gid) async {
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

  Future<DateTime?> getLastModifiedTime() async {
    try {
      final url = Uri.parse(
        'https://www.googleapis.com/drive/v3/files/$_spreadsheetId?fields=modifiedTime&key=$_apiKey',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return DateTime.parse(data['modifiedTime']);
      }
      return null;
    } catch (e) {
      debugPrint('Error checking modified time: $e');
      return null;
    }
  }

  Future<List<Product>> fetchProducts() async {
    try {
      final sheetTitle = await _getSheetTitle(_productsGid);

      if (sheetTitle == null) {
        throw Exception('Sheet not found for GID: $_productsGid');
      }

      debugPrint('Fetching from sheet: $sheetTitle');

      // Fetch columns A to I (fdc_id to energy)
      // Start from A3 to skip headers (Row 1: Title, Row 2: Headers)
      final url = Uri.parse(
        'https://sheets.googleapis.com/v4/spreadsheets/$_spreadsheetId/values/${Uri.encodeComponent(sheetTitle)}!A3:I?key=$_apiKey',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final values = data['values'] as List<dynamic>?;

        if (values == null || values.isEmpty) {
          debugPrint('No data found in sheet');
          return [];
        }

        debugPrint('✅ Found ${values.length} products');
        if (values.isNotEmpty) {
          debugPrint('First row raw data: ${values[0]}');
        }

        return values
            .asMap()
            .entries
            .map((entry) {
              try {
                return _parseProductRow(
                    entry.value as List<dynamic>, entry.key);
              } catch (e) {
                debugPrint('Error parsing row ${entry.key}: $e');
                return null;
              }
            })
            .where((p) => p != null && p.name.isNotEmpty)
            .cast<Product>()
            .toList();
      } else {
        throw Exception('Failed to load sheet: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error: $e');
      throw Exception('Error fetching from Google Sheets: $e');
    }
  }

  // Schema:
  // A: fdc_id (0)
  // B: name (1)
  // C: category (2)
  // D: protein (3)
  // E: phe (4)
  // F: phe_source (5)
  // G: fat (6)
  // H: carbs (7)
  // I: energy (8)
  Product? _parseProductRow(List<dynamic> row, int rowIndex) {
    if (row.isEmpty) return null;

    // Safety check for header row if we accidentally fetched it
    if (row[0].toString() == 'fdc_id' || row[0].toString() == '# fdc_id')
      return null;

    final fdcId = row.isNotEmpty ? row[0].toString().trim() : '';
    final name = row.length > 1 ? row[1].toString().trim() : '';
    final category = row.length > 2 ? row[2].toString().trim() : 'other';
    final protein = row.length > 3 ? _parseDouble(row[3]) : 0.0;

    final pheValue = row.length > 4 ? _parseDoubleOrNull(row[4]) : null;
    final pheSource = row.length > 5 ? row[5].toString().trim() : 'unknown';
    final fat = row.length > 6 ? _parseDoubleOrNull(row[6]) : null;
    final carbs = row.length > 7 ? _parseDoubleOrNull(row[7]) : null;
    final calories = row.length > 8 ? _parseDoubleOrNull(row[8]) : null;

    double? pheMeasured;
    double pheEstimated;

    if (pheValue != null) {
      pheEstimated = pheValue;
      if (pheSource.toLowerCase() != 'calculated' &&
          pheSource.toLowerCase() != 'unknown') {
        pheMeasured = pheValue;
      }
    } else {
      pheEstimated = protein * 50;
    }

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
      notes: null,
      source: 'Google Sheets ($pheSource)',
      lastUpdated: DateTime.now(),
      googleSheetsId: fdcId.isNotEmpty ? fdcId : 'row_$rowIndex',
      barcode: null,
    );
  }

  String _mapCategory(String category) {
    final lower = category.toLowerCase().trim();

    if (lower == 'овощи' || lower.contains('vegetable')) return 'vegetables';
    if (lower == 'фрукты' || lower.contains('fruit')) return 'fruits';
    if (lower == 'бобовые' ||
        lower.contains('legume') ||
        lower.contains('bean')) return 'legumes';
    if (lower == 'орехи и семена' ||
        lower.contains('nut') ||
        lower.contains('seed')) return 'nuts_seeds';
    if (lower == 'яйца' || lower.contains('egg')) return 'eggs';
    if (lower == 'сыры' || lower.contains('cheese')) return 'dairy';
    if (lower == 'хлеб и выпечка' ||
        lower.contains('bread') ||
        lower.contains('bakery')) return 'grains';
    if (lower == 'молочные продукты' ||
        lower.contains('dairy') ||
        lower.contains('milk')) return 'dairy';
    if (lower == 'рыба и морепродукты' ||
        lower.contains('fish') ||
        lower.contains('seafood')) return 'protein';
    if (lower == 'крупы и макароны' ||
        lower.contains('grain') ||
        lower.contains('pasta') ||
        lower.contains('cereal')) return 'grains';
    if (lower == 'грибы' || lower.contains('mushroom')) return 'vegetables';
    if (lower == 'ягоды' || lower.contains('berry')) return 'fruits';
    if (lower == 'сладости' ||
        lower.contains('sweet') ||
        lower.contains('candy')) return 'snacks';

    if (lower.contains('овощ')) return 'vegetables';
    if (lower.contains('фрукт')) return 'fruits';
    if (lower.contains('зерн') || lower.contains('хлеб')) return 'grains';
    if (lower.contains('молоч')) return 'dairy';
    if (lower.contains('мяс') || lower.contains('рыб')) return 'protein';
    if (lower.contains('напит')) return 'beverages';
    if (lower.contains('снек') || lower.contains('слад')) return 'snacks';

    return 'other';
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    final str = value.toString().trim().replaceAll(',', '.');
    if (str.isEmpty) return 0.0;
    if (str.startsWith('<')) {
      return 0.0;
    }
    return double.tryParse(str) ?? 0.0;
  }

  double? _parseDoubleOrNull(dynamic value) {
    if (value == null) return null;
    final str = value.toString().trim().replaceAll(',', '.');
    if (str.isEmpty) return null;
    if (str.startsWith('<')) {
      return 0.0;
    }
    return double.tryParse(str);
  }

  Future<bool> testConnection() async {
    try {
      final url = Uri.parse(
        'https://sheets.googleapis.com/v4/spreadsheets/$_spreadsheetId?key=$_apiKey',
      );

      final response = await http.get(url);
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Connection test failed: $e');
      return false;
    }
  }
}
