import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/diary_entry.dart';
import '../models/product.dart';

class DiaryProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  DateTime _selectedDate = DateTime.now();
  List<DiaryEntry> _entries = [];
  bool _isLoading = false;
  String? _error;

  DateTime get selectedDate => _selectedDate;
  List<DiaryEntry> get entries => _entries;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Get entries for specific meal type
  List<DiaryEntry> getEntriesForMeal(MealType mealType) {
    return _entries.where((entry) => entry.mealType == mealType).toList();
  }

  // Calculate total Phe for the selected date
  double get totalPheToday {
    return _entries.fold(0.0, (sum, entry) => sum + entry.pheInPortion);
  }

  // Calculate total protein for the selected date
  double get totalProteinToday {
    return _entries.fold(0.0, (sum, entry) => sum + entry.proteinInPortion);
  }

  // Calculate total calories for the selected date
  double get totalCaloriesToday {
    return _entries.fold(0.0, (sum, entry) => sum + (entry.caloriesInPortion ?? 0));
  }

  // Calculate total fat for the selected date
  double get totalFatToday {
    return _entries.fold(0.0, (sum, entry) => sum + (entry.fatInPortion ?? 0));
  }

  // Calculate total carbs for the selected date
  double get totalCarbsToday {
    return _entries.fold(0.0, (sum, entry) => sum + (entry.carbsInPortion ?? 0));
  }

  // Get statistics for a specific meal
  Map<String, double> getMealStats(MealType mealType) {
    final mealEntries = getEntriesForMeal(mealType);
    return {
      'phe': mealEntries.fold(0.0, (sum, entry) => sum + entry.pheInPortion),
      'protein': mealEntries.fold(0.0, (sum, entry) => sum + entry.proteinInPortion),
      'calories': mealEntries.fold(0.0, (sum, entry) => sum + (entry.caloriesInPortion ?? 0)),
    };
  }

  // Set selected date
  void setSelectedDate(DateTime date) {
    _selectedDate = DateTime(date.year, date.month, date.day);
    loadEntriesForDate(_selectedDate);
  }

  // Load entries for specific date
  Future<void> loadEntriesForDate(DateTime date) async {
    if (_auth.currentUser == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Get start and end of the day
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      final snapshot = await _firestore
          .collection('diary_entries')
          .where('userId', isEqualTo: _auth.currentUser!.uid)
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .orderBy('timestamp', descending: false)
          .get();

      _entries = snapshot.docs
          .map((doc) => DiaryEntry.fromFirestore(doc))
          .toList();

      debugPrint('✅ Loaded ${_entries.length} entries for ${date.toLocal()}');
    } catch (e) {
      _error = 'Ошибка загрузки записей: $e';
      debugPrint('❌ Error loading entries: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Add entry from product
  Future<void> addEntry({
    required Product product,
    required double portionG,
    required MealType mealType,
  }) async {
    if (_auth.currentUser == null) return;

    try {
      // Calculate nutritional values
      final multiplier = portionG / 100.0;
      final pheInPortion = product.pheToUse * multiplier;
      final proteinInPortion = product.proteinPer100g * multiplier;
      final fatInPortion = product.fatPer100g != null ? product.fatPer100g! * multiplier : null;
      final carbsInPortion = product.carbsPer100g != null ? product.carbsPer100g! * multiplier : null;
      final caloriesInPortion = product.caloriesPer100g != null ? product.caloriesPer100g! * multiplier : null;

      // Create entry
      final entry = DiaryEntry(
        id: '', // Will be set by Firestore
        userId: _auth.currentUser!.uid,
        productId: product.id,
        productName: product.name,
        portionG: portionG,
        pheUsedPer100g: product.pheToUse,
        pheInPortion: pheInPortion,
        proteinInPortion: proteinInPortion,
        fatInPortion: fatInPortion,
        carbsInPortion: carbsInPortion,
        caloriesInPortion: caloriesInPortion,
        isMedicalFormula: false,
        mealType: mealType,
        timestamp: _selectedDate,
      );

      // Save to Firestore
      await _firestore.collection('diary_entries').add(entry.toFirestore());

      // Reload entries
      await loadEntriesForDate(_selectedDate);

      debugPrint('✅ Added entry: ${product.name} (${portionG}g)');
    } catch (e) {
      _error = 'Ошибка добавления записи: $e';
      debugPrint('❌ Error adding entry: $e');
      rethrow;
    }
  }

  // Add custom entry (without product from database)
  Future<void> addCustomEntry({
    required String productName,
    required double portionG,
    required double pheUsedPer100g,
    required double proteinPer100g,
    required MealType mealType,
    double? fatPer100g,
    double? carbsPer100g,
    double? caloriesPer100g,
  }) async {
    if (_auth.currentUser == null) return;

    try {
      // Calculate nutritional values
      final multiplier = portionG / 100.0;
      final pheInPortion = pheUsedPer100g * multiplier;
      final proteinInPortion = proteinPer100g * multiplier;
      final fatInPortion = fatPer100g != null ? fatPer100g * multiplier : null;
      final carbsInPortion = carbsPer100g != null ? carbsPer100g * multiplier : null;
      final caloriesInPortion = caloriesPer100g != null ? caloriesPer100g * multiplier : null;

      // Create entry
      final entry = DiaryEntry(
        id: '', // Will be set by Firestore
        userId: _auth.currentUser!.uid,
        productId: null, // No product ID for custom entries
        productName: productName,
        portionG: portionG,
        pheUsedPer100g: pheUsedPer100g,
        pheInPortion: pheInPortion,
        proteinInPortion: proteinInPortion,
        fatInPortion: fatInPortion,
        carbsInPortion: carbsInPortion,
        caloriesInPortion: caloriesInPortion,
        isMedicalFormula: false,
        mealType: mealType,
        timestamp: _selectedDate,
      );

      // Save to Firestore
      await _firestore.collection('diary_entries').add(entry.toFirestore());

      // Reload entries
      await loadEntriesForDate(_selectedDate);

      debugPrint('✅ Added custom entry: $productName (${portionG}g)');
    } catch (e) {
      _error = 'Ошибка добавления записи: $e';
      debugPrint('❌ Error adding custom entry: $e');
      rethrow;
    }
  }

  // Delete entry
  Future<void> deleteEntry(String entryId) async {
    try {
      await _firestore.collection('diary_entries').doc(entryId).delete();
      await loadEntriesForDate(_selectedDate);
      debugPrint('✅ Deleted entry: $entryId');
    } catch (e) {
      _error = 'Ошибка удаления записи: $e';
      debugPrint('❌ Error deleting entry: $e');
      rethrow;
    }
  }

  // Get monthly statistics
  Future<Map<String, double>> getMonthlyStats(int year, int month) async {
    if (_auth.currentUser == null) return {};

    try {
      final startOfMonth = DateTime(year, month, 1);
      final endOfMonth = DateTime(year, month + 1, 0, 23, 59, 59);

      final snapshot = await _firestore
          .collection('diary_entries')
          .where('userId', isEqualTo: _auth.currentUser!.uid)
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
          .get();

      final entries = snapshot.docs
          .map((doc) => DiaryEntry.fromFirestore(doc))
          .toList();

      final totalPhe = entries.fold(0.0, (sum, entry) => sum + entry.pheInPortion);
      final totalProtein = entries.fold(0.0, (sum, entry) => sum + entry.proteinInPortion);
      final totalCalories = entries.fold(0.0, (sum, entry) => sum + (entry.caloriesInPortion ?? 0));
      final daysCount = endOfMonth.day;

      return {
        'totalPhe': totalPhe,
        'totalProtein': totalProtein,
        'totalCalories': totalCalories,
        'avgPhePerDay': totalPhe / daysCount,
        'avgProteinPerDay': totalProtein / daysCount,
        'avgCaloriesPerDay': totalCalories / daysCount,
      };
    } catch (e) {
      debugPrint('❌ Error getting monthly stats: $e');
      return {};
    }
  }
}