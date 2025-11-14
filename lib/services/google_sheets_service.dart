import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis_auth/auth_io.dart';
import 'dart:convert'; 
import 'package:http/http.dart' as http;
import '../models/product.dart';

class GoogleSheetsService {
  static const String _apiKey = 'AIzaSyCKgDraNgrpEOZCtWF6JoZxJ1FJjaYDMFg';
  
  Future<List<Product>> fetchProducts(String spreadsheetId) async {
    try {
      final url = Uri.parse(
        'https://sheets.googleapis.com/v4/spreadsheets/$spreadsheetId/values/Sheet1!A2:J?key=$_apiKey',
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
            .map((row) => Product.fromGoogleSheets(row as List<dynamic>))
            .where((product) => product.name.isNotEmpty)
            .toList();
      } else {
        throw Exception('Failed to load sheet: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('❌ Error: $e');
      throw Exception('Error fetching from Google Sheets: $e');
    }
  }

  Future<bool> testConnection(String spreadsheetId) async {
    try {
      final url = Uri.parse(
        'https://sheets.googleapis.com/v4/spreadsheets/$spreadsheetId?key=$_apiKey',
      );

      final response = await http.get(url);
      return response.statusCode == 200;
    } catch (e) {
      print('Connection test failed: $e');
      return false;
    }
  }
}