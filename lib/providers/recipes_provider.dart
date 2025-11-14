import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/recipe.dart';

class RecipesProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Recipe> _recipes = [];
  List<Recipe> _myRecipes = [];
  bool _isLoading = false;
  String? _error;

  List<Recipe> get recipes => _recipes;
  List<Recipe> get myRecipes => _myRecipes;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Загрузка одобренных рецептов
  Future<void> loadApprovedRecipes() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collection('recipes')
          .where('status', isEqualTo: RecipeStatus.approved.name)
          .orderBy('createdAt', descending: true)
          .get();

      _recipes = snapshot.docs.map((doc) => Recipe.fromFirestore(doc)).toList();
      debugPrint('✅ Loaded ${_recipes.length} approved recipes');
    } catch (e) {
      _error = 'Ошибка загрузки рецептов: $e';
      debugPrint('❌ Error loading recipes: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Загрузка моих рецептов
  Future<void> loadMyRecipes() async {
    if (_auth.currentUser == null) return;

    try {
      final snapshot = await _firestore
          .collection('recipes')
          .where('authorId', isEqualTo: _auth.currentUser!.uid)
          .orderBy('createdAt', descending: true)
          .get();

      _myRecipes = snapshot.docs.map((doc) => Recipe.fromFirestore(doc)).toList();
      debugPrint('✅ Loaded ${_myRecipes.length} my recipes');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error loading my recipes: $e');
    }
  }

  // Добавление нового рецепта
  Future<void> addRecipe(Recipe recipe) async {
    if (_auth.currentUser == null) return;

    try {
      await _firestore.collection('recipes').add(recipe.toFirestore());
      await loadMyRecipes();
      debugPrint('✅ Recipe submitted for approval');
    } catch (e) {
      _error = 'Ошибка добавления рецепта: $e';
      debugPrint('❌ Error adding recipe: $e');
      rethrow;
    }
  }

  // Фильтрация по категории
  List<Recipe> filterByCategory(RecipeCategory? category) {
    if (category == null) return _recipes;
    return _recipes.where((r) => r.category == category).toList();
  }

  // Поиск рецептов
  List<Recipe> searchRecipes(String query) {
    if (query.isEmpty) return _recipes;
    
    final lowerQuery = query.toLowerCase();
    return _recipes.where((recipe) {
      return recipe.name.toLowerCase().contains(lowerQuery) ||
             recipe.description.toLowerCase().contains(lowerQuery) ||
             recipe.ingredients.any((i) => i.name.toLowerCase().contains(lowerQuery));
    }).toList();
  }

  // Получение рецепта по ID
  Future<Recipe?> getRecipeById(String id) async {
    try {
      final doc = await _firestore.collection('recipes').doc(id).get();
      if (doc.exists) {
        return Recipe.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting recipe: $e');
      return null;
    }
  }
}