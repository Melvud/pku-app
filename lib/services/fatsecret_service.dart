// lib/services/fatsecret_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/product.dart';

class FatSecretService {
  static const String _clientId = 'e79230eb6fdb4417bab04f9530151e12';
  static const String _clientSecret = '102da768ee124338b77f4cb38cee8010';
  static const String _baseUrl = 'https://platform.fatsecret.com/rest/server.api';

  String? _accessToken;
  DateTime? _tokenExpiry;

  Future<String> _getAccessToken() async {
    if (_accessToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      return _accessToken!;
    }

    try {
      final credentials = base64Encode(utf8.encode('$_clientId:$_clientSecret'));

      final response = await http.post(
        Uri.parse('https://oauth.fatsecret.com/connect/token'),
        headers: {
          'Authorization': 'Basic $credentials',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'grant_type': 'client_credentials',
          'scope': 'basic',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        _accessToken = data['access_token'] as String;
        final expiresIn = data['expires_in'] as int;
        _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));

        print('✅ FatSecret access token obtained');
        return _accessToken!;
      } else {
        throw Exception('Failed to get FatSecret access token: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error getting FatSecret token: $e');
      rethrow;
    }
  }

  Future<Product?> getProductByBarcode(String barcode) async {
    try {
      final token = await _getAccessToken();

      print('🔍 Searching in FatSecret for barcode: $barcode');

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'method': 'food.find_id_for_barcode',
          'barcode': barcode,
          'format': 'json',
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;

        if (data.containsKey('food_id')) {
          final foodId = data['food_id']['value'] as String;
          return await _getProductById(foodId, barcode);
        } else {
          print('❌ Product not found in FatSecret');
          return null;
        }
      } else {
        print('❌ FatSecret API error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Error fetching from FatSecret: $e');
      return null;
    }
  }

  Future<Product?> _getProductById(String foodId, String barcode) async {
    try {
      final token = await _getAccessToken();

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'method': 'food.get.v2',
          'food_id': foodId,
          'format': 'json',
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        print('✅ Product found in FatSecret');
        return Product.fromFatSecret(data, barcode);
      } else {
        print('❌ Failed to get product details from FatSecret');
        return null;
      }
    } catch (e) {
      print('❌ Error getting product details: $e');
      return null;
    }
  }

  Future<List<Product>> searchProducts(String query, {int maxResults = 20}) async {
    try {
      final token = await _getAccessToken();

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'method': 'foods.search',
          'search_expression': query,
          'max_results': maxResults.toString(),
          'format': 'json',
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;

        if (data.containsKey('foods') && data['foods']['food'] != null) {
          final foods = data['foods']['food'] as List<dynamic>;

          return foods.map((food) {
            return Product.fromFatSecret({'food': food}, '');
          }).toList();
        }
      }

      return [];
    } catch (e) {
      print('Error searching FatSecret: $e');
      return [];
    }
  }
}
