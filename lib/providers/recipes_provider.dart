import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/recipe.dart';
import '../models/recipe_comment.dart';

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