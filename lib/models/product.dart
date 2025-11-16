// lib/models/product.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String name;
  final String category;
  final double proteinPer100g;
  final double? pheMeasuredPer100g;
  final double pheEstimatedPer100g;
  final double? fatPer100g;
  final double? carbsPer100g;
  final double? caloriesPer100g;
  final String? notes;
  final String? source;
  final DateTime lastUpdated;
  final String? googleSheetsId;
  final String? barcode;

  Product({
    required this.id,
    required this.name,
    required this.category,
    required this.proteinPer100g,
    this.pheMeasuredPer100g,
    required this.pheEstimatedPer100g,
    this.fatPer100g,
    this.carbsPer100g,
    this.caloriesPer100g,
    this.notes,
    this.source,
    required this.lastUpdated,
    this.googleSheetsId,
    this.barcode,
  });

  double get pheToUse => pheMeasuredPer100g ?? pheEstimatedPer100g;

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'category': category,
      'proteinPer100g': proteinPer100g,
      'pheMeasuredPer100g': pheMeasuredPer100g,
      'pheEstimatedPer100g': pheEstimatedPer100g,
      'fatPer100g': fatPer100g,
      'carbsPer100g': carbsPer100g,
      'caloriesPer100g': caloriesPer100g,
      'notes': notes,
      'source': source,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
      'googleSheetsId': googleSheetsId,
      'barcode': barcode,
    };
  }

  factory Product.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Product(
      id: doc.id,
      name: data['name'] ?? '',
      category: data['category'] ?? 'other',
      proteinPer100g: (data['proteinPer100g'] ?? 0).toDouble(),
      pheMeasuredPer100g: data['pheMeasuredPer100g']?.toDouble(),
      pheEstimatedPer100g: (data['pheEstimatedPer100g'] ?? 0).toDouble(),
      fatPer100g: data['fatPer100g']?.toDouble(),
      carbsPer100g: data['carbsPer100g']?.toDouble(),
      caloriesPer100g: data['caloriesPer100g']?.toDouble(),
      notes: data['notes'],
      source: data['source'],
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
      googleSheetsId: data['googleSheetsId'],
      barcode: data['barcode'],
    );
  }

  factory Product.fromGoogleSheets(List<dynamic> row, int rowIndex) {
    final googleSheetsId = 'row_$rowIndex';
    return Product(
      id: '',
      name: row.length > 0 ? row[0].toString() : '',
      category: row.length > 1 ? row[1].toString() : 'other',
      proteinPer100g: row.length > 2 ? _parseDouble(row[2]) : 0.0,
      pheMeasuredPer100g: row.length > 3 ? _parseDouble(row[3]) : null,
      pheEstimatedPer100g: row.length > 4 ? _parseDouble(row[4]) : 0.0,
      fatPer100g: row.length > 5 ? _parseDouble(row[5]) : null,
      carbsPer100g: row.length > 6 ? _parseDouble(row[6]) : null,
      caloriesPer100g: row.length > 7 ? _parseDouble(row[7]) : null,
      notes: row.length > 8 ? row[8].toString() : null,
      source: row.length > 9 ? row[9].toString() : 'Google Sheets',
      lastUpdated: DateTime.now(),
      googleSheetsId: googleSheetsId,
      barcode: row.length > 10 ? row[10].toString() : null,
    );
  }

  factory Product.fromOpenFoodFacts(Map<String, dynamic> data, String barcode) {
    final product = data['product'] as Map<String, dynamic>?;
    if (product == null) {
      throw Exception('Product data not found');
    }

    final nutriments = product['nutriments'] as Map<String, dynamic>? ?? {};
    final proteinPer100g = (nutriments['proteins_100g'] ?? 0).toDouble();
    
    // Оценочный расчет Phe: примерно 50 мг на 1 г белка
    final estimatedPhe = proteinPer100g * 50;

    return Product(
      id: '',
      name: product['product_name'] ?? 'Неизвестный продукт',
      category: _mapOpenFoodFactsCategory(product['categories'] ?? ''),
      proteinPer100g: proteinPer100g,
      pheMeasuredPer100g: null,
      pheEstimatedPer100g: estimatedPhe,
      fatPer100g: (nutriments['fat_100g'] ?? 0).toDouble(),
      carbsPer100g: (nutriments['carbohydrates_100g'] ?? 0).toDouble(),
      caloriesPer100g: (nutriments['energy-kcal_100g'] ?? 0).toDouble(),
      notes: 'Данные из Open Food Facts',
      source: 'Open Food Facts',
      lastUpdated: DateTime.now(),
      googleSheetsId: null,
      barcode: barcode,
    );
  }

  static String _mapOpenFoodFactsCategory(String categories) {
    final lowerCategories = categories.toLowerCase();
    if (lowerCategories.contains('fruit') || lowerCategories.contains('фрукт')) {
      return 'fruits';
    } else if (lowerCategories.contains('vegetable') || lowerCategories.contains('овощ')) {
      return 'vegetables';
    } else if (lowerCategories.contains('grain') || lowerCategories.contains('зерно') || 
               lowerCategories.contains('хлеб') || lowerCategories.contains('bread')) {
      return 'grains';
    }
    return 'other';
  }

  static double _parseDouble(dynamic value) {
    if (value == null || value.toString().isEmpty) return 0.0;
    return double.tryParse(value.toString()) ?? 0.0;
  }

  factory Product.fromFatSecret(Map<String, dynamic> data, String barcode) {
    final food = data['food'] as Map<String, dynamic>? ?? data;

    final servings = food['servings'] as Map<String, dynamic>?;
    final serving = servings != null && servings['serving'] != null
        ? (servings['serving'] is List
            ? (servings['serving'] as List).first as Map<String, dynamic>
            : servings['serving'] as Map<String, dynamic>)
        : <String, dynamic>{};

    final protein = _parseDouble(serving['protein']);
    final fat = _parseDouble(serving['fat']);
    final carbs = _parseDouble(serving['carbohydrate']);
    final calories = _parseDouble(serving['calories']);

    final estimatedPhe = protein * 50;

    return Product(
      id: '',
      name: food['food_name'] ?? 'Неизвестный продукт',
      category: _mapFatSecretCategory(food['food_type'] ?? ''),
      proteinPer100g: protein,
      pheMeasuredPer100g: null,
      pheEstimatedPer100g: estimatedPhe,
      fatPer100g: fat,
      carbsPer100g: carbs,
      caloriesPer100g: calories,
      notes: 'Данные из FatSecret Platform',
      source: 'FatSecret',
      lastUpdated: DateTime.now(),
      googleSheetsId: null,
      barcode: barcode.isNotEmpty ? barcode : null,
    );
  }

  factory Product.fromUSDA(Map<String, dynamic> data) {
    final description = data['description'] as String? ??
                       data['lowercaseDescription'] as String? ??
                       'Неизвестный продукт';

    final nutrients = data['foodNutrients'] as List<dynamic>? ?? [];

    double protein = 0.0;
    double fat = 0.0;
    double carbs = 0.0;
    double calories = 0.0;

    for (var nutrient in nutrients) {
      final nutrientData = nutrient is Map<String, dynamic> ? nutrient : {};
      final nutrientId = nutrientData['nutrientId'] as int? ??
                        nutrientData['nutrientNumber'] as int? ?? 0;
      final value = _parseDouble(nutrientData['value']);

      switch (nutrientId) {
        case 1003:
          protein = value;
          break;
        case 1004:
          fat = value;
          break;
        case 1005:
          carbs = value;
          break;
        case 1008:
          calories = value;
          break;
      }
    }

    final estimatedPhe = protein * 50;
    final barcode = data['gtinUpc'] as String?;

    return Product(
      id: '',
      name: description,
      category: _mapUSDACategory(data['foodCategory'] as String? ?? ''),
      proteinPer100g: protein,
      pheMeasuredPer100g: null,
      pheEstimatedPer100g: estimatedPhe,
      fatPer100g: fat > 0 ? fat : null,
      carbsPer100g: carbs > 0 ? carbs : null,
      caloriesPer100g: calories > 0 ? calories : null,
      notes: 'Данные из USDA FoodData Central',
      source: 'USDA',
      lastUpdated: DateTime.now(),
      googleSheetsId: null,
      barcode: barcode,
    );
  }

  static String _mapFatSecretCategory(String foodType) {
    final lowerType = foodType.toLowerCase();
    if (lowerType.contains('fruit')) {
      return 'fruits';
    } else if (lowerType.contains('vegetable')) {
      return 'vegetables';
    } else if (lowerType.contains('grain') || lowerType.contains('bread')) {
      return 'grains';
    }
    return 'other';
  }

  static String _mapUSDACategory(String category) {
    final lowerCategory = category.toLowerCase();
    if (lowerCategory.contains('fruit')) {
      return 'fruits';
    } else if (lowerCategory.contains('vegetable')) {
      return 'vegetables';
    } else if (lowerCategory.contains('grain') ||
               lowerCategory.contains('bread') ||
               lowerCategory.contains('cereal')) {
      return 'grains';
    } else if (lowerCategory.contains('dairy') || lowerCategory.contains('milk')) {
      return 'dairy';
    } else if (lowerCategory.contains('meat') ||
               lowerCategory.contains('poultry') ||
               lowerCategory.contains('fish')) {
      return 'protein';
    }
    return 'other';
  }

  Product copyWith({
    String? id,
    String? name,
    String? category,
    double? proteinPer100g,
    double? pheMeasuredPer100g,
    double? pheEstimatedPer100g,
    double? fatPer100g,
    double? carbsPer100g,
    double? caloriesPer100g,
    String? notes,
    String? source,
    DateTime? lastUpdated,
    String? googleSheetsId,
    String? barcode,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      proteinPer100g: proteinPer100g ?? this.proteinPer100g,
      pheMeasuredPer100g: pheMeasuredPer100g ?? this.pheMeasuredPer100g,
      pheEstimatedPer100g: pheEstimatedPer100g ?? this.pheEstimatedPer100g,
      fatPer100g: fatPer100g ?? this.fatPer100g,
      carbsPer100g: carbsPer100g ?? this.carbsPer100g,
      caloriesPer100g: caloriesPer100g ?? this.caloriesPer100g,
      notes: notes ?? this.notes,
      source: source ?? this.source,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      googleSheetsId: googleSheetsId ?? this.googleSheetsId,
      barcode: barcode ?? this.barcode,
    );
  }
}