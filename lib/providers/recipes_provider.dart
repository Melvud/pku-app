import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/recipe.dart';
import '../models/recipe_comment.dart';
import '../services/local_database_service.dart';

class RecipesProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final LocalDatabaseService _localDb = LocalDatabaseService();

  List<Recipe> _recipes = [];
  List<Recipe> _myRecipes = [];
  bool _isLoading = false;
  String? _error;

  List<Recipe> get recipes => _recipes;
  List<Recipe> get myRecipes => _myRecipes;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Загрузка одобренных рецептов с кешированием
  Future<void> loadApprovedRecipes() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Load from cache first
      final cachedRecipes = await _localDb.getCachedRecipes();
      if (cachedRecipes.isNotEmpty) {
        _recipes = cachedRecipes
            .where((r) => r['status'] == RecipeStatus.approved.name)
            .map((r) => _recipeFromMap(r))
            .toList();
        debugPrint('✅ Loaded ${_recipes.length} recipes from cache');
        _isLoading = false;
        notifyListeners();
      }

      // Check if we should sync with Firebase
      final shouldSync = await _localDb.shouldSyncWithFirebase('recipes');
      if (!shouldSync) {
        debugPrint('ℹ️ Using cached recipes (recent sync)');
        return;
      }

      // Fetch from Firebase
      debugPrint('🔄 Syncing recipes from Firebase...');
      final snapshot = await _firestore
          .collection('recipes')
          .where('status', isEqualTo: RecipeStatus.approved.name)
          .orderBy('createdAt', descending: true)
          .get();

      final firebaseRecipes = snapshot.docs.map((doc) => Recipe.fromFirestore(doc)).toList();
      
      // Update cache
      await _localDb.cacheRecipes(
        snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList(),
      );

      _recipes = firebaseRecipes;
      debugPrint('✅ Loaded ${_recipes.length} approved recipes from Firebase');
    } catch (e) {
      _error = 'Ошибка загрузки рецептов: $e';
      debugPrint('❌ Error loading recipes: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Recipe _recipeFromMap(Map<String, dynamic> map) {
    // Helper method to convert cached recipe map to Recipe object
    return Recipe(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      category: RecipeCategory.values.firstWhere(
        (e) => e.name == map['category'],
        orElse: () => RecipeCategory.breakfast,
      ),
      ingredients: (map['ingredients'] as List).cast<String>(),
      instructions: (map['instructions'] as List).cast<String>(),
      status: RecipeStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => RecipeStatus.pending,
      ),
      authorId: map['authorId'],
      authorName: map['authorName'],
      phePer100g: map['phePer100g'],
      proteinPer100g: map['proteinPer100g'],
      fatPer100g: map['fatPer100g'],
      carbsPer100g: map['carbsPer100g'],
      caloriesPer100g: map['caloriesPer100g'],
      defaultServingSize: map['defaultServingSize'],
      cookingTime: map['cookingTime'],
      difficulty: map['difficulty'] != null
          ? RecipeDifficulty.values.firstWhere(
              (e) => e.name == map['difficulty'],
              orElse: () => RecipeDifficulty.medium,
            )
          : null,
      imageUrl: map['imageUrl'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
    );
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
      final docRef = await _firestore.collection('recipes').add(recipe.toFirestore());
      
      // Get the created recipe with the ID
      final doc = await docRef.get();
      final createdRecipe = Recipe.fromFirestore(doc);
      
      // Add to my recipes immediately
      _myRecipes.insert(0, createdRecipe);
      notifyListeners();
      
      debugPrint('✅ Recipe submitted for approval and added to my recipes');
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

  // Toggle like on a recipe
  Future<void> toggleLike(String recipeId) async {
    if (_auth.currentUser == null) return;

    try {
      final userId = _auth.currentUser!.uid;
      final recipeRef = _firestore.collection('recipes').doc(recipeId);
      final doc = await recipeRef.get();
      
      if (!doc.exists) return;
      
      final recipe = Recipe.fromFirestore(doc);
      final isLiked = recipe.likedBy.contains(userId);
      
      if (isLiked) {
        // Unlike
        await recipeRef.update({
          'likesCount': FieldValue.increment(-1),
          'likedBy': FieldValue.arrayRemove([userId]),
        });
      } else {
        // Like
        await recipeRef.update({
          'likesCount': FieldValue.increment(1),
          'likedBy': FieldValue.arrayUnion([userId]),
        });
      }
      
      // Refresh recipes lists
      await loadApprovedRecipes();
      await loadMyRecipes();
      
      debugPrint('✅ Toggled like on recipe $recipeId');
    } catch (e) {
      debugPrint('❌ Error toggling like: $e');
      rethrow;
    }
  }

  // Add comment to recipe
  Future<void> addComment({
    required String recipeId,
    required String text,
    required String authorName,
    String? parentCommentId,
  }) async {
    if (_auth.currentUser == null) return;

    try {
      final comment = RecipeComment(
        id: '',
        recipeId: recipeId,
        authorId: _auth.currentUser!.uid,
        authorName: authorName,
        text: text,
        createdAt: DateTime.now(),
        status: CommentStatus.approved, // Immediately approved
        parentCommentId: parentCommentId,
      );
      
      await _firestore.collection('recipe_comments').add(comment.toFirestore());
      
      debugPrint('✅ Comment added to recipe $recipeId');
    } catch (e) {
      debugPrint('❌ Error adding comment: $e');
      rethrow;
    }
  }

  // Get comments for a recipe
  Future<List<RecipeComment>> getCommentsForRecipe(String recipeId) async {
    try {
      final snapshot = await _firestore
          .collection('recipe_comments')
          .where('recipeId', isEqualTo: recipeId)
          .where('status', isEqualTo: CommentStatus.approved.name)
          .orderBy('createdAt', descending: false)
          .get();

      return snapshot.docs
          .map((doc) => RecipeComment.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('❌ Error getting comments: $e');
      return [];
    }
  }

  // Delete comment (admin only)
  Future<void> deleteComment(String commentId) async {
    try {
      await _firestore.collection('recipe_comments').doc(commentId).delete();
      
      debugPrint('✅ Comment deleted: $commentId');
    } catch (e) {
      debugPrint('❌ Error deleting comment: $e');
      rethrow;
    }
  }

  // Get all comments (for admin)
  Future<List<RecipeComment>> getAllComments() async {
    try {
      final snapshot = await _firestore
          .collection('recipe_comments')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => RecipeComment.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('❌ Error getting all comments: $e');
      return [];
    }
  }

  // Approve comment (admin only)
  Future<void> approveComment(String commentId) async {
    try {
      await _firestore.collection('recipe_comments').doc(commentId).update({
        'status': CommentStatus.approved.name,
      });
      
      debugPrint('✅ Comment approved: $commentId');
    } catch (e) {
      debugPrint('❌ Error approving comment: $e');
      rethrow;
    }
  }

  // Reject comment (admin only)
  Future<void> rejectComment(String commentId) async {
    try {
      await _firestore.collection('recipe_comments').doc(commentId).update({
        'status': CommentStatus.rejected.name,
      });
      
      debugPrint('✅ Comment rejected: $commentId');
    } catch (e) {
      debugPrint('❌ Error rejecting comment: $e');
      rethrow;
    }
  }
}