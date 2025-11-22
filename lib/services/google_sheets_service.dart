// lib/services/google_sheets_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/product.dart';

class GoogleSheetsService {
  static const String _spreadsheetId = '1tDEp7KYh0leLhv_AjpkAFKnq-i2_d39Zx3sco1zVlp4';
  static const String _apiKey = 'AIzaSyCKgDraNgrpEOZCtWF6JoZxJ1FJjaYDMFg';

  // Sheet GIDs
  static const int _generalProductsGid = 288786302;
  static const int _barcodeProductsGid = 1127717778;

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
      print('❌ Error getting sheet name: $e');
      return null;
    }
  }

  Future<List<Product>> fetchProducts() async {
    try {
      // Get the general products sheet by GID
      final sheetTitle = await _getSheetNameByGid(_generalProductsGid);

      if (sheetTitle == null) {
        // Fallback to first sheet if not found
        final metaUrl = Uri.parse(
          'https://sheets.googleapis.com/v4/spreadsheets/$_spreadsheetId?key=$_apiKey',
        );

        final metaResponse = await http.get(metaUrl);

        if (metaResponse.statusCode != 200) {
          throw Exception('Failed to get spreadsheet metadata: ${metaResponse.statusCode}');
        }

        final metaData = json.decode(metaResponse.body);
        final sheets = metaData['sheets'] as List<dynamic>;

        final firstSheetTitle = sheets.isNotEmpty
            ? sheets[0]['properties']['title'] as String
            : 'Sheet1';

        print('Using first sheet: $firstSheetTitle');
        return _fetchFromSheet(firstSheetTitle);
      }

      print('Using general products sheet: $sheetTitle');
      return _fetchFromSheet(sheetTitle);
    } catch (e) {
      print('❌ Error: $e');
      throw Exception('Error fetching from Google Sheets: $e');
    }
  }

  Future<List<Product>> _fetchFromSheet(String sheetTitle) async {
    // Fetch columns A to L for full data including barcode
    final url = Uri.parse(
      'https://sheets.googleapis.com/v4/spreadsheets/$_spreadsheetId/values/${Uri.encodeComponent(sheetTitle)}!A2:L?key=$_apiKey',
    );

    print('Fetching from Google Sheets...');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final values = data['values'] as List<dynamic>?;

      if (values == null || values.isEmpty) {
        print('No data found in sheet');
        return [];
      }

      print('✅ Found ${values.length} products');

      return values
          .asMap()
          .entries
          .map((entry) => _parseProductRow(
                entry.value as List<dynamic>,
                entry.key,
              ))
          .where((product) => product.name.isNotEmpty)
          .toList();
    } else {
      throw Exception('Failed to load sheet: ${response.statusCode} - ${response.body}');
    }
  }

  /// Parse a product row with proper handling of Phe calculation
  /// Expected columns:
  /// A: Название
  /// B: Категория
  /// C: Белок (на 100г)
  /// D: Фе измеренное (на 100г) - может быть пустым
  /// E: Фе оценочное (на 100г)
  /// F: Жиры (на 100г)
  /// G: Углеводы (на 100г)
  /// H: Калории (на 100г)
  /// I: Примечания
  /// J: Источник
  /// K: Штрих-код (optional)
  Product _parseProductRow(List<dynamic> row, int rowIndex) {
    final name = row.isNotEmpty ? row[0].toString().trim() : '';
    final category = row.length > 1 ? row[1].toString().trim() : 'other';
    final protein = row.length > 2 ? _parseDouble(row[2]) : 0.0;
    final pheMeasured = row.length > 3 ? _parseDoubleOrNull(row[3]) : null;

    // Calculate estimated Phe if not provided (1g protein = 50mg Phe)
    double pheEstimated;
    if (row.length > 4 && row[4].toString().trim().isNotEmpty) {
      pheEstimated = _parseDouble(row[4]);
    } else {
      pheEstimated = protein * 50;
    }

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
      googleSheetsId: 'row_$rowIndex',
      barcode: barcode != null && barcode.isNotEmpty ? barcode : null,
    );
  }

  String _mapCategory(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('овощ') || lower.contains('vegetable')) return 'vegetables';
    if (lower.contains('фрукт') || lower.contains('fruit')) return 'fruits';
    if (lower.contains('зерн') || lower.contains('хлеб') || lower.contains('grain') || lower.contains('bread')) return 'grains';
    if (lower.contains('молоч') || lower.contains('dairy')) return 'dairy';
    if (lower.contains('мяс') || lower.contains('meat') || lower.contains('рыб') || lower.contains('fish')) return 'protein';
    if (lower.contains('напит') || lower.contains('drink') || lower.contains('beverage')) return 'beverages';
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

  Future<bool> testConnection() async {
    try {
      final url = Uri.parse(
        'https://sheets.googleapis.com/v4/spreadsheets/$_spreadsheetId?key=$_apiKey',
      );

      final response = await http.get(url);
      return response.statusCode == 200;
    } catch (e) {
      print('Connection test failed: $e');
      return false;
    }
  }
}