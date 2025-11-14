import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/diary_entry.dart';
import '../models/product.dart';
import '../models/meal_session.dart';

class DiaryProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  DateTime _selectedDate = DateTime.now();
  List<DiaryEntry> _entries = [];
  List<MealSession> _mealSessions = [];
  bool _isLoading = false;
  String? _error;

  DateTime get selectedDate => _selectedDate;
  List<DiaryEntry> get entries => _entries;
  List<MealSession> get mealSessions => _mealSessions;
  bool get isLoading => _isLoading;
  String? get error => _error;

  DiaryProvider() {
    _loadMealSessions();
  }

  // Load meal sessions from SharedPreferences
  Future<void> _loadMealSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedSessions = prefs.getString('meal_sessions');
      
      if (savedSessions != null) {
        final List<dynamic> decoded = json.decode(savedSessions);
        _mealSessions = decoded.map((e) => MealSession.fromJson(e)).toList();
      } else {
        // Use default meals
        _mealSessions = MealSession.defaultMeals;
        await _saveMealSessions();
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading meal sessions: $e');
      _mealSessions = MealSession.defaultMeals;
    }
  }

  // Save meal sessions to SharedPreferences
  Future<void> _saveMealSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = json.encode(_mealSessions.map((e) => e.toJson()).toList());
      await prefs.setString('meal_sessions', encoded);
    } catch (e) {
      debugPrint('Error saving meal sessions: $e');
    }
  }

  // Add new meal session
  Future<void> addMealSession({
    required MealType type,
    String? customName,
    DateTime? time,
  }) async {
    final newSession = MealSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      customName: customName,
      time: time,
      order: _mealSessions.length,
    );
    
    _mealSessions.add(newSession);
    await _saveMealSessions();
    notifyListeners();
  }

  // Remove meal session
  Future<void> removeMealSession(String sessionId) async {
    _mealSessions.removeWhere((s) => s.id == sessionId);
    // Reorder
    for (int i = 0; i < _mealSessions.length; i++) {
      _mealSessions[i] = _mealSessions[i].copyWith(order: i);
    }
    await _saveMealSessions();
    notifyListeners();
  }

  // Update meal session time
  Future<void> updateMealSessionTime(String sessionId, DateTime time) async {
    final index = _mealSessions.indexWhere((s) => s.id == sessionId);
    if (index != -1) {
      _mealSessions[index] = _mealSessions[index].copyWith(time: time);
      await _saveMealSessions();
      notifyListeners();
    }
  }

  // Get entries for specific meal session
  List<DiaryEntry> getEntriesForMealSession(String sessionId) {
    // For now, we'll match by meal type
    // In future, we can add sessionId to DiaryEntry
    final session = _mealSessions.firstWhere((s) => s.id == sessionId);
    return _entries.where((entry) => entry.mealType == session.type).toList();
  }

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
    String? customMealName,
    DateTime? mealTime,
  }) async {
    if (_auth.currentUser == null) return;

    try {
      final multiplier = portionG / 100.0;
      final pheInPortion = product.pheToUse * multiplier;
      final proteinInPortion = product.proteinPer100g * multiplier;
      final fatInPortion = product.fatPer100g != null ? product.fatPer100g! * multiplier : null;
      final carbsInPortion = product.carbsPer100g != null ? product.carbsPer100g! * multiplier : null;
      final caloriesInPortion = product.caloriesPer100g != null ? product.caloriesPer100g! * multiplier : null;

      final entry = DiaryEntry(
        id: '',
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
        customMealName: customMealName,
        timestamp: _selectedDate,
        mealTime: mealTime,
      );

      await _firestore.collection('diary_entries').add(entry.toFirestore());
      await loadEntriesForDate(_selectedDate);

      debugPrint('✅ Added entry: ${product.name} (${portionG}g)');
    } catch (e) {
      _error = 'Ошибка добавления записи: $e';
      debugPrint('❌ Error adding entry: $e');
      rethrow;
    }
  }

  // Add custom entry
  Future<void> addCustomEntry({
    required String productName,
    required double portionG,
    required double pheUsedPer100g,
    required double proteinPer100g,
    required MealType mealType,
    String? customMealName,
    DateTime? mealTime,
    double? fatPer100g,
    double? carbsPer100g,
    double? caloriesPer100g,
  }) async {
    if (_auth.currentUser == null) return;

    try {
      final multiplier = portionG / 100.0;
      final pheInPortion = pheUsedPer100g * multiplier;
      final proteinInPortion = proteinPer100g * multiplier;
      final fatInPortion = fatPer100g != null ? fatPer100g * multiplier : null;
      final carbsInPortion = carbsPer100g != null ? carbsPer100g * multiplier : null;
      final caloriesInPortion = caloriesPer100g != null ? caloriesPer100g * multiplier : null;

      final entry = DiaryEntry(
        id: '',
        userId: _auth.currentUser!.uid,
        productId: null,
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
        customMealName: customMealName,
        timestamp: _selectedDate,
        mealTime: mealTime,
      );

      await _firestore.collection('diary_entries').add(entry.toFirestore());
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
  Future<Map<String, dynamic>> getMonthlyStats(int year, int month) async {
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

      // Group by day
      final Map<int, List<DiaryEntry>> dailyEntries = {};
      for (var entry in entries) {
        final day = entry.timestamp.day;
        dailyEntries.putIfAbsent(day, () => []);
        dailyEntries[day]!.add(entry);
      }

      // Calculate daily stats
      final List<Map<String, dynamic>> dailyStats = [];
      for (int day = 1; day <= endOfMonth.day; day++) {
        final dayEntries = dailyEntries[day] ?? [];
        dailyStats.add({
          'day': day,
          'phe': dayEntries.fold(0.0, (sum, e) => sum + e.pheInPortion),
          'protein': dayEntries.fold(0.0, (sum, e) => sum + e.proteinInPortion),
          'fat': dayEntries.fold(0.0, (sum, e) => sum + (e.fatInPortion ?? 0)),
          'carbs': dayEntries.fold(0.0, (sum, e) => sum + (e.carbsInPortion ?? 0)),
          'calories': dayEntries.fold(0.0, (sum, e) => sum + (e.caloriesInPortion ?? 0)),
          'entriesCount': dayEntries.length,
        });
      }

      final totalPhe = entries.fold(0.0, (sum, entry) => sum + entry.pheInPortion);
      final totalProtein = entries.fold(0.0, (sum, entry) => sum + entry.proteinInPortion);
      final totalFat = entries.fold(0.0, (sum, entry) => sum + (entry.fatInPortion ?? 0));
      final totalCarbs = entries.fold(0.0, (sum, entry) => sum + (entry.carbsInPortion ?? 0));
      final totalCalories = entries.fold(0.0, (sum, entry) => sum + (entry.caloriesInPortion ?? 0));
      final daysCount = endOfMonth.day;
      final activeDays = dailyEntries.length;

      return {
        'totalPhe': totalPhe,
        'totalProtein': totalProtein,
        'totalFat': totalFat,
        'totalCarbs': totalCarbs,
        'totalCalories': totalCalories,
        'avgPhePerDay': totalPhe / daysCount,
        'avgProteinPerDay': totalProtein / daysCount,
        'avgFatPerDay': totalFat / daysCount,
        'avgCarbsPerDay': totalCarbs / daysCount,
        'avgCaloriesPerDay': totalCalories / daysCount,
        'activeDays': activeDays,
        'totalDays': daysCount,
        'dailyStats': dailyStats,
      };
    } catch (e) {
      debugPrint('❌ Error getting monthly stats: $e');
      return {};
    }
  }
}