class UserProfile {
  final String name;  // Теперь обязательное
  final int age;      // Теперь обязательное
  final double weight; // Теперь обязательное
  final double dailyTolerancePhe;
  final String email;
  final String? medicalFormula; // Новое поле - какую смесь пьете

  UserProfile({
    required this.name,
    required this.age,
    required this.weight,
    required this.dailyTolerancePhe,
    required this.email,
    this.medicalFormula,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'age': age,
      'weight': weight,
      'dailyTolerancePhe': dailyTolerancePhe,
      'email': email,
      'medicalFormula': medicalFormula,
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      name: json['name'] ?? '',
      age: json['age'] ?? 0,
      weight: (json['weight'] ?? 0).toDouble(),
      dailyTolerancePhe: (json['dailyTolerancePhe'] ?? 0).toDouble(),
      email: json['email'] ?? '',
      medicalFormula: json['medicalFormula'],
    );
  }

  UserProfile copyWith({
    String? name,
    int? age,
    double? weight,
    double? dailyTolerancePhe,
    String? email,
    String? medicalFormula,
  }) {
    return UserProfile(
      name: name ?? this.name,
      age: age ?? this.age,
      weight: weight ?? this.weight,
      dailyTolerancePhe: dailyTolerancePhe ?? this.dailyTolerancePhe,
      email: email ?? this.email,
      medicalFormula: medicalFormula ?? this.medicalFormula,
    );
  }
}