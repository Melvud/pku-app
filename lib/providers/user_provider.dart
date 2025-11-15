import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/local_database_service.dart';

class UserProvider with ChangeNotifier {
  final LocalDatabaseService _localDb = LocalDatabaseService();
  UserProfile? _userProfile;
  double _currentPheIntake = 0.0;

  UserProfile? get userProfile => _userProfile;
  double get currentPheIntake => _currentPheIntake;
  
  double get remainingPhe {
    if (_userProfile == null) return 0.0;
    return _userProfile!.dailyTolerancePhe - _currentPheIntake;
  }
  
  double get progressPercentage {
    if (_userProfile == null || _userProfile!.dailyTolerancePhe == 0) return 0.0;
    return (_currentPheIntake / _userProfile!.dailyTolerancePhe).clamp(0.0, 1.0);
  }

  Future<void> loadUserProfile() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Load from cache first
      final cachedProfile = await _localDb.getCachedUserProfile(currentUser.uid);
      if (cachedProfile != null) {
        _userProfile = _profileFromMap(cachedProfile);
        debugPrint('✅ Loaded user profile from cache');
        notifyListeners();
      }

      // Check if we should sync with Firebase
      final shouldSync = await _localDb.shouldSyncWithFirebase('user_profile');
      if (!shouldSync) {
        debugPrint('ℹ️ Using cached profile (recent sync)');
        return;
      }

      // Fetch from Firebase
      debugPrint('🔄 Syncing user profile from Firebase...');
      final firebaseProfile = await AuthService.getUserProfile();
      if (firebaseProfile != null) {
        _userProfile = firebaseProfile;
        
        // Update cache
        await _localDb.cacheUserProfile({
          'userId': currentUser.uid,
          'name': firebaseProfile.name,
          'email': firebaseProfile.email,
          'dateOfBirth': firebaseProfile.dateOfBirth,
          'weight': firebaseProfile.weight,
          'dailyTolerancePhe': firebaseProfile.dailyTolerancePhe,
          'medicalFormula': firebaseProfile.medicalFormula,
          'isAdmin': firebaseProfile.isAdmin,
        });
        
        debugPrint('✅ Loaded user profile from Firebase');
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ Error loading user profile: $e');
    }
  }

  UserProfile _profileFromMap(Map<String, dynamic> map) {
    return UserProfile(
      name: map['name'],
      email: map['email'],
      dateOfBirth: map['dateOfBirth'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['dateOfBirth'])
          : null,
      weight: map['weight'],
      dailyTolerancePhe: map['dailyTolerancePhe'],
      medicalFormula: map['medicalFormula'],
      isAdmin: map['isAdmin'] ?? false,
    );
  }

  Future<void> updateUserProfile(UserProfile profile) async {
    _userProfile = profile;
    await AuthService.saveUserProfile(profile);
    
    // Update cache
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      await _localDb.cacheUserProfile({
        'userId': currentUser.uid,
        'name': profile.name,
        'email': profile.email,
        'dateOfBirth': profile.dateOfBirth,
        'weight': profile.weight,
        'dailyTolerancePhe': profile.dailyTolerancePhe,
        'medicalFormula': profile.medicalFormula,
        'isAdmin': profile.isAdmin,
      });
    }
    
    notifyListeners();
  }

  void addPheIntake(double amount) {
    _currentPheIntake += amount;
    notifyListeners();
  }

  void resetDailyIntake() {
    _currentPheIntake = 0.0;
    notifyListeners();
  }
}