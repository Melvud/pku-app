// lib/services/google_sheets_service.dart
import 'dart:convert'; 
import 'package:http/http.dart' as http;
import '../models/product.dart';

class GoogleSheetsService {
  static const String _spreadsheetId = '1tDEp7KYh0leLhv_AjpkAFKnq-i2_d39Zx3sco1zVlp4';
  static const String _apiKey = 'AIzaSyCKgDraNgrpEOZCtWF6JoZxJ1FJjaYDMFg';
  
  Future<List<Product>> fetchProducts() async {
    try {
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
      
      print('Using sheet: $firstSheetTitle');
      
      final url = Uri.parse(
        'https://sheets.googleapis.com/v4/spreadsheets/$_spreadsheetId/values/${Uri.encodeComponent(firstSheetTitle)}!A2:J?key=$_apiKey',
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
            .map((entry) => Product.fromGoogleSheets(
                  entry.value as List<dynamic>,
                  entry.key,
                ))
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