class UserProfile {
  final String name;
  final DateTime dateOfBirth;
  final double weight;
  final double dailyTolerancePhe;
  final String email;
  final String? medicalFormula;
  final bool isAdmin;

  UserProfile({
    required this.name,
    required this.dateOfBirth,
    required this.weight,
    required this.dailyTolerancePhe,
    required this.email,
    this.medicalFormula,
    this.isAdmin = false,
  });

  // Вычисляем возраст
  int get age {
    final now = DateTime.now();
    int age = now.year - dateOfBirth.year;
    if (now.month < dateOfBirth.month || 
        (now.month == dateOfBirth.month && now.day < dateOfBirth.day)) {
      age--;
    }
    return age;
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'dateOfBirth': dateOfBirth.toIso8601String(),
      'weight': weight,
      'dailyTolerancePhe': dailyTolerancePhe,
      'email': email,
      'medicalFormula': medicalFormula,
      'isAdmin': isAdmin,
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      name: json['name'] ?? '',
      dateOfBirth: json['dateOfBirth'] != null 
          ? DateTime.parse(json['dateOfBirth'])
          : DateTime.now().subtract(const Duration(days: 365 * 25)),
      weight: (json['weight'] ?? 0).toDouble(),
      dailyTolerancePhe: (json['dailyTolerancePhe'] ?? 0).toDouble(),
      email: json['email'] ?? '',
      medicalFormula: json['medicalFormula'],
      isAdmin: json['isAdmin'] ?? false,
    );
  }

  UserProfile copyWith({
    String? name,
    DateTime? dateOfBirth,
    double? weight,
    double? dailyTolerancePhe,
    String? email,
    String? medicalFormula,
    bool? isAdmin,
  }) {
    return UserProfile(
      name: name ?? this.name,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      weight: weight ?? this.weight,
      dailyTolerancePhe: dailyTolerancePhe ?? this.dailyTolerancePhe,
      email: email ?? this.email,
      medicalFormula: medicalFormula ?? this.medicalFormula,
      isAdmin: isAdmin ?? this.isAdmin,
    );
  }
}