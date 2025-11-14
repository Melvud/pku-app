import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';

class UserAuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  User? get currentUser => _auth.currentUser;
  bool get isAuthenticated => currentUser != null;

  // Register with email and password
  Future<String?> register({
    required String email,
    required String password,
    required UserProfile profile,
  }) async {
    UserCredential? userCredential;
    
    try {
      // Создаем пользователя в Authentication
      userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        try {
          // Пытаемся сохранить профиль в Firestore
          await _firestore
              .collection('users')
              .doc(userCredential.user!.uid)
              .set(profile.toJson());
          
          debugPrint('✅ User profile saved successfully');
          
        } catch (firestoreError) {
          debugPrint('❌ Firestore error: $firestoreError');
          
          // Rollback - удаляем пользователя из Authentication
          try {
            await userCredential.user!.delete();
            debugPrint('🔄 User deleted from Authentication (rollback)');
          } catch (deleteError) {
            debugPrint('❌ Failed to delete user: $deleteError');
          }
          
          // Возвращаем понятную ошибку
          return 'Ошибка сохранения данных. Проверьте подключение к интернету и попробуйте снова.';
        }
      }

      notifyListeners();
      return null; // Success
      
    } on FirebaseAuthException catch (e) {
      return _getErrorMessage(e);
    } catch (e) {
      debugPrint('❌ Unexpected error: $e');
      return 'Произошла ошибка: $e';
    }
  }

  // Login with email and password
  Future<String?> login({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      notifyListeners();
      return null; // Success
    } on FirebaseAuthException catch (e) {
      return _getErrorMessage(e);
    } catch (e) {
      return 'Произошла ошибка: $e';
    }
  }

  // Logout
  Future<void> logout() async {
    await _auth.signOut();
    notifyListeners();
  }

  // Reset password
  Future<String?> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return null; // Success
    } on FirebaseAuthException catch (e) {
      return _getErrorMessage(e);
    } catch (e) {
      return 'Произошла ошибка: $e';
    }
  }

  // Get user profile from Firestore
  Future<UserProfile?> getUserProfile() async {
    if (currentUser == null) return null;

    try {
      final doc = await _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .get();

      if (doc.exists && doc.data() != null) {
        return UserProfile.fromJson(doc.data()!);
      }
      
      debugPrint('⚠️ User profile not found in Firestore');
      return null;
    } catch (e) {
      debugPrint('❌ Error getting user profile: $e');
      return null;
    }
  }

  // Update user profile
  Future<void> updateUserProfile(UserProfile profile) async {
    if (currentUser == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .update(profile.toJson());
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error updating user profile: $e');
      rethrow;
    }
  }

  String _getErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'Пользователь не найден';
      case 'wrong-password':
        return 'Неверный пароль';
      case 'email-already-in-use':
        return 'Этот email уже используется. Попробуйте войти в аккаунт.';
      case 'weak-password':
        return 'Слишком слабый пароль (минимум 6 символов)';
      case 'invalid-email':
        return 'Некорректный email';
      case 'network-request-failed':
        return 'Ошибка сети. Проверьте подключение к интернету.';
      case 'too-many-requests':
        return 'Слишком много попыток. Попробуйте позже.';
      default:
        debugPrint('Firebase Auth Error: ${e.code} - ${e.message}');
        return 'Ошибка: ${e.message ?? e.code}';
    }
  }
}