import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/recipe.dart';
import '../models/article.dart';
import '../models/recipe_comment.dart';

class AdminProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isAdmin = false;
  bool get isAdmin => _isAdmin;

  List<Recipe> _pendingRecipes = [];
  List<Recipe> get pendingRecipes => _pendingRecipes;

  List<Article> _articles = [];
  List<Article> get articles => _articles;

  List<RecipeComment> _pendingComments = [];
  List<RecipeComment> get pendingComments => _pendingComments;

  List<RecipeComment> _allComments = [];
  List<RecipeComment> get allComments => _allComments;

  Map<String, dynamic> _appStats = {};
  Map<String, dynamic> get appStats => _appStats;

  bool _isLoadingRecipes = false;
  bool get isLoadingRecipes => _isLoadingRecipes;

  bool _isLoadingArticles = false;
  bool get isLoadingArticles => _isLoadingArticles;

  bool _isLoadingStats = false;
  bool get isLoadingStats => _isLoadingStats;

  bool _isLoadingComments = false;
  bool get isLoadingComments => _isLoadingComments;

  // Check if current user is admin
  Future<void> checkAdminStatus() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        _isAdmin = false;
        notifyListeners();
        return;
      }

      final userDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (userDoc.exists && userDoc.data() != null) {
        _isAdmin = userDoc.data()!['isAdmin'] ?? false;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error checking admin status: $e');
      _isAdmin = false;
      notifyListeners();
    }
  }

  // Load pending recipes for approval
  Future<void> loadPendingRecipes() async {
    _isLoadingRecipes = true;
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collection('recipes')
          .where('status', isEqualTo: RecipeStatus.pending.name)
          .orderBy('createdAt', descending: true)
          .get();

      _pendingRecipes = snapshot.docs
          .map((doc) => Recipe.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error loading pending recipes: $e');
      _pendingRecipes = [];
    }

    _isLoadingRecipes = false;
    notifyListeners();
  }

  // Approve a recipe
  Future<void> approveRecipe(String recipeId) async {
    try {
      await _firestore.collection('recipes').doc(recipeId).update({
        'status': RecipeStatus.approved.name,
        'approvedAt': FieldValue.serverTimestamp(),
      });

      _pendingRecipes.removeWhere((r) => r.id == recipeId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error approving recipe: $e');
      rethrow;
    }
  }

  // Reject a recipe
  Future<void> rejectRecipe(String recipeId, String reason) async {
    try {
      await _firestore.collection('recipes').doc(recipeId).update({
        'status': RecipeStatus.rejected.name,
        'rejectionReason': reason,
      });

      _pendingRecipes.removeWhere((r) => r.id == recipeId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error rejecting recipe: $e');
      rethrow;
    }
  }

  // Load all articles
  Future<void> loadArticles() async {
    _isLoadingArticles = true;
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collection('articles')
          .orderBy('createdAt', descending: true)
          .get();

      _articles = snapshot.docs
          .map((doc) => Article.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error loading articles: $e');
      _articles = [];
    }

    _isLoadingArticles = false;
    notifyListeners();
  }

  // Add new article
  Future<void> addArticle(Article article) async {
    try {
      await _firestore.collection('articles').add(article.toFirestore());
      await loadArticles(); // Reload articles
    } catch (e) {
      debugPrint('Error adding article: $e');
      rethrow;
    }
  }

  // Delete article
  Future<void> deleteArticle(String articleId) async {
    try {
      await _firestore.collection('articles').doc(articleId).delete();
      _articles.removeWhere((a) => a.id == articleId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting article: $e');
      rethrow;
    }
  }

  // Load app statistics
  Future<void> loadAppStats() async {
    _isLoadingStats = true;
    notifyListeners();

    try {
      // Get total users
      final usersSnapshot = await _firestore.collection('users').get();
      final totalUsers = usersSnapshot.docs.length;

      // Get total recipes
      final recipesSnapshot = await _firestore.collection('recipes').get();
      final totalRecipes = recipesSnapshot.docs.length;
      final approvedRecipes = recipesSnapshot.docs
          .where((doc) => doc.data()['status'] == RecipeStatus.approved.name)
          .length;
      final pendingRecipes = recipesSnapshot.docs
          .where((doc) => doc.data()['status'] == RecipeStatus.pending.name)
          .length;

      // Get total diary entries (last 30 days)
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final diarySnapshot = await _firestore
          .collection('diary')
          .where('date', isGreaterThan: Timestamp.fromDate(thirtyDaysAgo))
          .get();
      final recentEntries = diarySnapshot.docs.length;

      // Get active users (users with entries in last 7 days)
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      final recentDiarySnapshot = await _firestore
          .collection('diary')
          .where('date', isGreaterThan: Timestamp.fromDate(sevenDaysAgo))
          .get();
      
      final activeUserIds = <String>{};
      for (var doc in recentDiarySnapshot.docs) {
        activeUserIds.add(doc.data()['userId'] ?? '');
      }
      final activeUsers = activeUserIds.length;

      _appStats = {
        'totalUsers': totalUsers,
        'totalRecipes': totalRecipes,
        'approvedRecipes': approvedRecipes,
        'pendingRecipes': pendingRecipes,
        'recentEntries': recentEntries,
        'activeUsers': activeUsers,
      };
    } catch (e) {
      debugPrint('Error loading app stats: $e');
      _appStats = {};
    }

    _isLoadingStats = false;
    notifyListeners();
  }

  // Load pending comments for moderation
  Future<void> loadPendingComments() async {
    _isLoadingComments = true;
    notifyListeners();

    try {
      // Load all comments (not just pending) since comments are now approved by default
      final snapshot = await _firestore
          .collection('recipe_comments')
          .orderBy('createdAt', descending: true)
          .get();

      _allComments = snapshot.docs
          .map((doc) => RecipeComment.fromFirestore(doc))
          .toList();
      
      // Also keep pending list for backward compatibility
      _pendingComments = _allComments
          .where((c) => c.status == CommentStatus.pending)
          .toList();
    } catch (e) {
      debugPrint('Error loading comments: $e');
      _pendingComments = [];
      _allComments = [];
    }

    _isLoadingComments = false;
    notifyListeners();
  }

  // Approve a comment
  Future<void> approveComment(String commentId) async {
    try {
      await _firestore.collection('recipe_comments').doc(commentId).update({
        'status': CommentStatus.approved.name,
      });

      _pendingComments.removeWhere((c) => c.id == commentId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error approving comment: $e');
      rethrow;
    }
  }

  // Reject a comment
  Future<void> rejectComment(String commentId) async {
    try {
      await _firestore.collection('recipe_comments').doc(commentId).update({
        'status': CommentStatus.rejected.name,
      });

      _pendingComments.removeWhere((c) => c.id == commentId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error rejecting comment: $e');
      rethrow;
    }
  }

  // Mark a comment as reviewed (keeps in public but removes from moderation)
  Future<void> reviewComment(String commentId) async {
    try {
      await _firestore.collection('recipe_comments').doc(commentId).update({
        'status': CommentStatus.reviewed.name,
      });

      _pendingComments.removeWhere((c) => c.id == commentId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error reviewing comment: $e');
      rethrow;
    }
  }

  // Delete a comment
  Future<void> deleteComment(String commentId) async {
    try {
      await _firestore.collection('recipe_comments').doc(commentId).delete();

      _pendingComments.removeWhere((c) => c.id == commentId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting comment: $e');
      rethrow;
    }
  }
}
