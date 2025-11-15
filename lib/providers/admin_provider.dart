import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/recipe.dart';
import '../models/article.dart';
import '../models/recipe_comment.dart';
import '../services/local_database_service.dart';

class AdminProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final LocalDatabaseService _localDb = LocalDatabaseService();

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
      
      // Clear recipes cache to force refresh on next load
      await _localDb.clearTable('recipes');
      
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
      
      // Clear recipes cache to force refresh on next load
      await _localDb.clearTable('recipes');
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error rejecting recipe: $e');
      rethrow;
    }
  }

  // Load all articles with caching
  Future<void> loadArticles() async {
    _isLoadingArticles = true;
    notifyListeners();

    try {
      // Step 1: Load from cache first and display immediately
      final cachedArticles = await _localDb.getCachedArticles();
      if (cachedArticles.isNotEmpty) {
        _articles = cachedArticles.map((a) => _articleFromMap(a)).toList();
        debugPrint('✅ Loaded ${_articles.length} articles from cache');
        _isLoadingArticles = false;
        notifyListeners();
      }

      // Step 2: Check if we should sync with Firebase
      final shouldSync = await _localDb.shouldSyncWithFirebase('articles', maxAge: const Duration(minutes: 5));
      if (!shouldSync && cachedArticles.isNotEmpty) {
        debugPrint('ℹ️ Using cached articles (recent sync)');
        return;
      }

      // Step 3: Fetch from Firebase in the background
      debugPrint('🔄 Syncing articles from Firebase...');
      final snapshot = await _firestore
          .collection('articles')
          .orderBy('createdAt', descending: true)
          .get();

      // Step 4: Only update if Firebase has different data
      if (snapshot.docs.isNotEmpty) {
        final firebaseArticles = snapshot.docs
            .map((doc) => Article.fromFirestore(doc))
            .toList();

        // Compare if data has changed
        bool hasChanges = _articles.length != firebaseArticles.length;
        if (!hasChanges && _articles.isNotEmpty) {
          // Check if any article has been updated
          for (var i = 0; i < _articles.length && i < firebaseArticles.length; i++) {
            if (_articles[i].id != firebaseArticles[i].id ||
                _articles[i].createdAt != firebaseArticles[i].createdAt) {
              hasChanges = true;
              break;
            }
          }
        }

        if (hasChanges) {
          // Update cache with new data from Firebase
          await _localDb.cacheArticles(
            snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList(),
          );

          _articles = firebaseArticles;
          debugPrint('✅ Updated ${_articles.length} articles from Firebase');
          notifyListeners();
        } else {
          // Just update sync time without changing data
          await _localDb.cacheArticles(
            snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList(),
          );
          debugPrint('✅ Articles up to date, refreshed sync time');
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading articles: $e');
      // If we have cached data, keep using it even if Firebase fails
      if (_articles.isEmpty) {
        _articles = [];
      }
    }

    _isLoadingArticles = false;
    notifyListeners();
  }

  Article _articleFromMap(Map<String, dynamic> map) {
    return Article(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      pdfUrl: map['pdfUrl'],
      createdBy: map['createdBy'],
      createdByName: map['createdByName'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
    );
  }

  // Add new article
  Future<void> addArticle(Article article) async {
    try {
      await _firestore.collection('articles').add(article.toFirestore());
      await loadArticles(); // Reload articles and update cache
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
      
      // Force refresh cache
      await _localDb.clearTable('articles');
      await loadArticles();
      
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
