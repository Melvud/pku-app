import 'package:flutter/foundation.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';

class UserProvider with ChangeNotifier {
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
    _userProfile = await AuthService.getUserProfile();
    notifyListeners();
  }

  Future<void> updateUserProfile(UserProfile profile) async {
    _userProfile = profile;
    await AuthService.saveUserProfile(profile);
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