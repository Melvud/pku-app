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

  // Cache for entries and sessions by date key (yyyy-MM-dd)
  final Map<String, List<DiaryEntry>> _entriesCache = {};
  final Map<String, List<MealSession>> _sessionsCache = {};

  bool _isLoading = false;
  String? _error;

  DateTime get selectedDate => _selectedDate;

  // Get entries for the currently selected date from cache
  List<DiaryEntry> get entries => getEntriesForDate(_selectedDate);

  // Get meal sessions for the currently selected date from cache
  List<MealSession> get mealSessions => getMealSessionsForDate(_selectedDate);

  bool get isLoading => _isLoading;
  String? get error => _error;

  DiaryProvider() {
    _loadMealSessionsForDate(_selectedDate);
  }

  String _getDateKey(DateTime date) {
    return date.toIso8601String().split('T')[0];
  }

  List<DiaryEntry> getEntriesForDate(DateTime date) {
    return _entriesCache[_getDateKey(date)] ?? [];
  }

  List<MealSession> getMealSessionsForDate(DateTime date) {
    return _sessionsCache[_getDateKey(date)] ?? [];
  }

  // Load meal sessions from SharedPreferences for specific date
  Future<void> _loadMealSessionsForDate(DateTime date) async {
    try {
      final dateKey = _getDateKey(date);

      // If already in cache, don't reload unless forced?
      // For now, we'll try to load from prefs to be safe/fresh

      final prefs = await SharedPreferences.getInstance();
      final savedSessions = prefs.getString('meal_sessions_$dateKey');

      List<MealSession> sessions;
      if (savedSessions != null) {
        final List<dynamic> decoded = json.decode(savedSessions);
        sessions = decoded.map((e) => MealSession.fromJson(e)).toList();
      } else {
        // Use default meals for this date
        sessions = MealSession.defaultMealsForDate(date);
        // We don't await saving here to avoid blocking, but we should save eventually
        _saveMealSessionsForDate(date, sessions);
      }

      _sessionsCache[dateKey] = sessions;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading meal sessions: $e');
      _sessionsCache[_getDateKey(date)] = MealSession.defaultMealsForDate(date);
    }
  }

  // Save meal sessions to SharedPreferences for specific date
  Future<void> _saveMealSessionsForDate(
      DateTime date, List<MealSession> sessions) async {
    try {
      final dateKey = _getDateKey(date);
      final prefs = await SharedPreferences.getInstance();
      final encoded = json.encode(sessions.map((e) => e.toJson()).toList());
      await prefs.setString('meal_sessions_$dateKey', encoded);
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
      order: mealSessions.length,
      date: _selectedDate,
    );

    final dateKey = _getDateKey(_selectedDate);
    final currentSessions =
        List<MealSession>.from(_sessionsCache[dateKey] ?? []);
    currentSessions.add(newSession);
    _sessionsCache[dateKey] = currentSessions;

    await _saveMealSessionsForDate(_selectedDate, currentSessions);
    notifyListeners();
  }

  // Remove meal session
  Future<void> removeMealSession(String sessionId) async {
    final dateKey = _getDateKey(_selectedDate);
    final currentSessions =
        List<MealSession>.from(_sessionsCache[dateKey] ?? []);

    currentSessions.removeWhere((s) => s.id == sessionId);
    // Reorder
    for (int i = 0; i < currentSessions.length; i++) {
      currentSessions[i] = currentSessions[i].copyWith(order: i);
    }

    _sessionsCache[dateKey] = currentSessions;
    await _saveMealSessionsForDate(_selectedDate, currentSessions);
    notifyListeners();
  }

  // Update meal session time
  Future<void> updateMealSessionTime(String sessionId, DateTime time) async {
    final dateKey = _getDateKey(_selectedDate);
    final currentSessions =
        List<MealSession>.from(_sessionsCache[dateKey] ?? []);

    final index = currentSessions.indexWhere((s) => s.id == sessionId);
    if (index != -1) {
      currentSessions[index] = currentSessions[index].copyWith(time: time);
      _sessionsCache[dateKey] = currentSessions;
      await _saveMealSessionsForDate(_selectedDate, currentSessions);
      notifyListeners();
    }
  }

  // Toggle formula checkbox for meal session
  Future<void> toggleMealSessionFormula(String sessionId) async {
    final dateKey = _getDateKey(_selectedDate);
    final currentSessions =
        List<MealSession>.from(_sessionsCache[dateKey] ?? []);

    final index = currentSessions.indexWhere((s) => s.id == sessionId);
    if (index != -1) {
      currentSessions[index] = currentSessions[index].copyWith(
        drankFormula: !currentSessions[index].drankFormula,
      );
      _sessionsCache[dateKey] = currentSessions;
      await _saveMealSessionsForDate(_selectedDate, currentSessions);
      notifyListeners();
    }
  }

  // Get entries for specific meal session
  List<DiaryEntry> getEntriesForMealSession(String sessionId) {
    // For now, we'll match by meal type
    // In future, we can add sessionId to DiaryEntry
    final session = mealSessions.firstWhere((s) => s.id == sessionId);
    return entries.where((entry) => entry.mealType == session.type).toList();
  }

  // Helper to get entries for a specific session on a specific date (for PageView)
  List<DiaryEntry> getEntriesForMealSessionOnDate(
      String sessionId, DateTime date) {
    final sessions = getMealSessionsForDate(date);
    final dateEntries = getEntriesForDate(date);

    try {
      final session = sessions.firstWhere((s) => s.id == sessionId);
      return dateEntries
          .where((entry) => entry.mealType == session.type)
          .toList();
    } catch (e) {
      return [];
    }
  }

  // Get entries for specific meal type
  List<DiaryEntry> getEntriesForMeal(MealType mealType) {
    return entries.where((entry) => entry.mealType == mealType).toList();
  }

  // Calculate total Phe for the selected date
  double get totalPheToday => getTotalPheForDate(_selectedDate);

  double getTotalPheForDate(DateTime date) {
    return getEntriesForDate(date)
        .fold(0.0, (total, entry) => total + entry.pheInPortion);
  }

  // Calculate total protein for the selected date
  double get totalProteinToday => getTotalProteinForDate(_selectedDate);

  double getTotalProteinForDate(DateTime date) {
    return getEntriesForDate(date)
        .fold(0.0, (total, entry) => total + entry.proteinInPortion);
  }

  // Calculate total calories for the selected date
  double get totalCaloriesToday => getTotalCaloriesForDate(_selectedDate);

  double getTotalCaloriesForDate(DateTime date) {
    return getEntriesForDate(date)
        .fold(0.0, (total, entry) => total + (entry.caloriesInPortion ?? 0));
  }

  // Calculate total fat for the selected date
  double get totalFatToday => getTotalFatForDate(_selectedDate);

  double getTotalFatForDate(DateTime date) {
    return getEntriesForDate(date)
        .fold(0.0, (total, entry) => total + (entry.fatInPortion ?? 0));
  }

  // Calculate total carbs for the selected date
  double get totalCarbsToday => getTotalCarbsForDate(_selectedDate);

  double getTotalCarbsForDate(DateTime date) {
    return getEntriesForDate(date)
        .fold(0.0, (total, entry) => total + (entry.carbsInPortion ?? 0));
  }

  // Get statistics for a specific meal
  Map<String, double> getMealStats(MealType mealType) {
    final mealEntries = getEntriesForMeal(mealType);
    return {
      'phe': mealEntries.fold(0.0, (total, e) => total + e.pheInPortion),
      'protein':
          mealEntries.fold(0.0, (total, e) => total + e.proteinInPortion),
      'calories': mealEntries.fold(
          0.0, (total, e) => total + (e.caloriesInPortion ?? 0)),
    };
  }

  // Set selected date
  void setSelectedDate(DateTime date) {
    _selectedDate = DateTime(date.year, date.month, date.day);
    // Ensure data is loaded for this date
    _loadMealSessionsForDate(_selectedDate);
    if (_entriesCache[_getDateKey(_selectedDate)] == null) {
      loadEntriesForDate(_selectedDate);
    }
    notifyListeners();
  }

  // Load entries for specific date
  Future<void> loadEntriesForDate(DateTime date) async {
    if (_auth.currentUser == null) return;

    // Only set loading if we are loading the selected date and it's not cached
    final isSelectedDate = _getDateKey(date) == _getDateKey(_selectedDate);
    if (isSelectedDate && _entriesCache[_getDateKey(date)] == null) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    // Ensure sessions are loaded too
    await _loadMealSessionsForDate(date);

    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      final snapshot = await _firestore
          .collection('diary_entries')
          .where('userId', isEqualTo: _auth.currentUser!.uid)
          .where('timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .orderBy('timestamp', descending: false)
          .get();

      final loadedEntries =
          snapshot.docs.map((doc) => DiaryEntry.fromFirestore(doc)).toList();

      _entriesCache[_getDateKey(date)] = loadedEntries;

      debugPrint(
          '✅ Loaded ${loadedEntries.length} entries for ${date.toLocal()}');
    } catch (e) {
      if (isSelectedDate) {
        _error = 'Ошибка загрузки записей: $e';
      }
      debugPrint('❌ Error loading entries: $e');
    } finally {
      if (isSelectedDate) {
        _isLoading = false;
        notifyListeners();
      } else {
        // If background loading, just notify to update UI if visible
        notifyListeners();
      }
    }
  }

  // Add entry from product
  Future<void> addEntry({
    required Product product,
    required double portionG,
    required MealType mealType,
    String? customMealName,
    DateTime? mealTime,
    String? recipeId, // Optional recipe ID
  }) async {
    if (_auth.currentUser == null) return;

    try {
      final multiplier = portionG / 100.0;
      final pheInPortion = product.pheToUse * multiplier;
      final proteinInPortion = product.proteinPer100g * multiplier;
      final fatInPortion =
          product.fatPer100g != null ? product.fatPer100g! * multiplier : null;
      final carbsInPortion = product.carbsPer100g != null
          ? product.carbsPer100g! * multiplier
          : null;
      final caloriesInPortion = product.caloriesPer100g != null
          ? product.caloriesPer100g! * multiplier
          : null;

      final entry = DiaryEntry(
        id: '',
        userId: _auth.currentUser!.uid,
        productId: product.id,
        recipeId: recipeId,
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
      final carbsInPortion =
          carbsPer100g != null ? carbsPer100g * multiplier : null;
      final caloriesInPortion =
          caloriesPer100g != null ? caloriesPer100g * multiplier : null;

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

  // Update existing entry
  Future<void> updateEntry({
    required String entryId,
    required String productName,
    required double portionG,
    required double pheUsedPer100g,
    required double proteinPer100g,
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
      final carbsInPortion =
          carbsPer100g != null ? carbsPer100g * multiplier : null;
      final caloriesInPortion =
          caloriesPer100g != null ? caloriesPer100g * multiplier : null;

      await _firestore.collection('diary_entries').doc(entryId).update({
        'productName': productName,
        'portionG': portionG,
        'pheUsedPer100g': pheUsedPer100g,
        'pheInPortion': pheInPortion,
        'proteinInPortion': proteinInPortion,
        'fatInPortion': fatInPortion,
        'carbsInPortion': carbsInPortion,
        'caloriesInPortion': caloriesInPortion,
      });

      await loadEntriesForDate(_selectedDate);
      debugPrint('✅ Updated entry: $entryId');
    } catch (e) {
      _error = 'Ошибка обновления записи: $e';
      debugPrint('❌ Error updating entry: $e');
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
          .where('timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('timestamp',
              isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
          .get();

      final entries =
          snapshot.docs.map((doc) => DiaryEntry.fromFirestore(doc)).toList();

      // Group by day
      final Map<int, List<DiaryEntry>> dailyEntries = {};
      for (var entry in entries) {
        final day = entry.timestamp.day;
        dailyEntries.putIfAbsent(day, () => []);
        dailyEntries[day]!.add(entry);
      }

      // Calculate daily stats
      final List<Map<String, dynamic>> dailyStats = [];
      final now = DateTime.now();

      for (int day = 1; day <= endOfMonth.day; day++) {
        final dayEntries = dailyEntries[day] ?? [];
        final date = DateTime(year, month, day);

        // Skip future days in stats
        if (date.isAfter(now)) {
          dailyStats.add({
            'day': day,
            'phe': 0.0,
            'protein': 0.0,
            'fat': 0.0,
            'carbs': 0.0,
            'calories': 0.0,
            'entriesCount': 0,
          });
          continue;
        }

        dailyStats.add({
          'day': day,
          'phe': dayEntries.fold(0.0, (total, e) => total + e.pheInPortion),
          'protein':
              dayEntries.fold(0.0, (total, e) => total + e.proteinInPortion),
          'fat':
              dayEntries.fold(0.0, (total, e) => total + (e.fatInPortion ?? 0)),
          'carbs': dayEntries.fold(
              0.0, (total, e) => total + (e.carbsInPortion ?? 0)),
          'calories': dayEntries.fold(
              0.0, (total, e) => total + (e.caloriesInPortion ?? 0)),
          'entriesCount': dayEntries.length,
        });
      }

      // Filter entries for total stats - exclude future entries
      final pastEntries =
          entries.where((e) => !e.timestamp.isAfter(now)).toList();

      final totalPhe =
          pastEntries.fold(0.0, (total, entry) => total + entry.pheInPortion);
      final totalProtein = pastEntries.fold(
          0.0, (total, entry) => total + entry.proteinInPortion);
      final totalFat = pastEntries.fold(
          0.0, (total, entry) => total + (entry.fatInPortion ?? 0));
      final totalCarbs = pastEntries.fold(
          0.0, (total, entry) => total + (entry.carbsInPortion ?? 0));
      final totalCalories = pastEntries.fold(
          0.0, (total, entry) => total + (entry.caloriesInPortion ?? 0));
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

  // Get statistics for a date range
  Future<Map<String, dynamic>> getDateRangeStats(
      DateTime startDate, DateTime endDate) async {
    if (_auth.currentUser == null) return {};

    try {
      final start = DateTime(startDate.year, startDate.month, startDate.day);
      final end =
          DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

      final snapshot = await _firestore
          .collection('diary_entries')
          .where('userId', isEqualTo: _auth.currentUser!.uid)
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();

      final entries =
          snapshot.docs.map((doc) => DiaryEntry.fromFirestore(doc)).toList();

      // Group by date
      final Map<String, List<DiaryEntry>> dailyEntries = {};
      final Map<String, List<DiaryEntry>> monthlyEntries = {};

      for (var entry in entries) {
        final dateKey =
            '${entry.timestamp.year}-${entry.timestamp.month.toString().padLeft(2, '0')}-${entry.timestamp.day.toString().padLeft(2, '0')}';
        final monthKey =
            '${entry.timestamp.year}-${entry.timestamp.month.toString().padLeft(2, '0')}';

        dailyEntries.putIfAbsent(dateKey, () => []);
        dailyEntries[dateKey]!.add(entry);

        monthlyEntries.putIfAbsent(monthKey, () => []);
        monthlyEntries[monthKey]!.add(entry);
      }

      // Calculate daily stats
      final List<Map<String, dynamic>> dailyStats = [];
      DateTime current = start;
      final now = DateTime.now();

      while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
        final dateKey =
            '${current.year}-${current.month.toString().padLeft(2, '0')}-${current.day.toString().padLeft(2, '0')}';
        final dayEntries = dailyEntries[dateKey] ?? [];

        // Skip future days in stats
        if (current.isAfter(now)) {
          dailyStats.add({
            'date': current,
            'day': current.day,
            'month': current.month,
            'year': current.year,
            'phe': 0.0,
            'protein': 0.0,
            'fat': 0.0,
            'carbs': 0.0,
            'calories': 0.0,
            'entriesCount': 0,
          });
        } else {
          dailyStats.add({
            'date': current,
            'day': current.day,
            'month': current.month,
            'year': current.year,
            'phe': dayEntries.fold(0.0, (total, e) => total + e.pheInPortion),
            'protein':
                dayEntries.fold(0.0, (total, e) => total + e.proteinInPortion),
            'fat': dayEntries.fold(
                0.0, (total, e) => total + (e.fatInPortion ?? 0)),
            'carbs': dayEntries.fold(
                0.0, (total, e) => total + (e.carbsInPortion ?? 0)),
            'calories': dayEntries.fold(
                0.0, (total, e) => total + (e.caloriesInPortion ?? 0)),
            'entriesCount': dayEntries.length,
          });
        }

        current = current.add(const Duration(days: 1));
      }

      // Filter entries for total stats - exclude future entries
      final pastEntries =
          entries.where((e) => !e.timestamp.isAfter(now)).toList();
      final pastMonthlyEntries = <String, List<DiaryEntry>>{};

      for (var entry in pastEntries) {
        final monthKey =
            '${entry.timestamp.year}-${entry.timestamp.month.toString().padLeft(2, '0')}';
        pastMonthlyEntries.putIfAbsent(monthKey, () => []);
        pastMonthlyEntries[monthKey]!.add(entry);
      }

      // Calculate monthly stats
      final List<Map<String, dynamic>> monthlyStats = [];
      for (var monthKey in pastMonthlyEntries.keys.toList()..sort()) {
        final parts = monthKey.split('-');
        final year = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final monthEntriesData = pastMonthlyEntries[monthKey]!;

        final daysInMonth = DateTime(year, month + 1, 0).day;

        monthlyStats.add({
          'year': year,
          'month': month,
          'totalPhe':
              monthEntriesData.fold(0.0, (total, e) => total + e.pheInPortion),
          'totalProtein': monthEntriesData.fold(
              0.0, (total, e) => total + e.proteinInPortion),
          'totalFat': monthEntriesData.fold(
              0.0, (total, e) => total + (e.fatInPortion ?? 0)),
          'totalCarbs': monthEntriesData.fold(
              0.0, (total, e) => total + (e.carbsInPortion ?? 0)),
          'totalCalories': monthEntriesData.fold(
              0.0, (total, e) => total + (e.caloriesInPortion ?? 0)),
          'avgPhePerDay':
              monthEntriesData.fold(0.0, (total, e) => total + e.pheInPortion) /
                  daysInMonth,
          'entriesCount': monthEntriesData.length,
        });
      }

      final totalPhe =
          pastEntries.fold(0.0, (total, entry) => total + entry.pheInPortion);
      final totalProtein = pastEntries.fold(
          0.0, (total, entry) => total + entry.proteinInPortion);
      final totalFat = pastEntries.fold(
          0.0, (total, entry) => total + (entry.fatInPortion ?? 0));
      final totalCarbs = pastEntries.fold(
          0.0, (total, entry) => total + (entry.carbsInPortion ?? 0));
      final totalCalories = pastEntries.fold(
          0.0, (total, entry) => total + (entry.caloriesInPortion ?? 0));
      final daysDifference = end.difference(start).inDays + 1;
      final activeDays = dailyEntries.length;

      return {
        'startDate': start,
        'endDate': end,
        'totalPhe': totalPhe,
        'totalProtein': totalProtein,
        'totalFat': totalFat,
        'totalCarbs': totalCarbs,
        'totalCalories': totalCalories,
        'avgPhePerDay': daysDifference > 0 ? totalPhe / daysDifference : 0,
        'avgProteinPerDay':
            daysDifference > 0 ? totalProtein / daysDifference : 0,
        'avgFatPerDay': daysDifference > 0 ? totalFat / daysDifference : 0,
        'avgCarbsPerDay': daysDifference > 0 ? totalCarbs / daysDifference : 0,
        'avgCaloriesPerDay':
            daysDifference > 0 ? totalCalories / daysDifference : 0,
        'activeDays': activeDays,
        'totalDays': daysDifference,
        'dailyStats': dailyStats,
        'monthlyStats': monthlyStats,
      };
    } catch (e) {
      debugPrint('❌ Error getting date range stats: $e');
      return {};
    }
  }
}
