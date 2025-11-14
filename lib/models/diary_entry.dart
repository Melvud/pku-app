import 'package:cloud_firestore/cloud_firestore.dart';

enum MealType {
  breakfast('Завтрак'),
  lunch('Обед'),
  dinner('Ужин'),
  snack('Перекус');

  final String displayName;
  const MealType(this.displayName);
}

class DiaryEntry {
  final String id;
  final String userId;
  final String? productId;
  final String productName;
  final double portionG;
  final double pheUsedPer100g;
  final double pheInPortion;
  final double proteinInPortion;
  final double? fatInPortion;
  final double? carbsInPortion;
  final double? caloriesInPortion;
  final bool isMedicalFormula;
  final MealType mealType;
  final DateTime timestamp;

  DiaryEntry({
    required this.id,
    required this.userId,
    this.productId,
    required this.productName,
    required this.portionG,
    required this.pheUsedPer100g,
    required this.pheInPortion,
    required this.proteinInPortion,
    this.fatInPortion,
    this.carbsInPortion,
    this.caloriesInPortion,
    required this.isMedicalFormula,
    required this.mealType,
    required this.timestamp,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'productId': productId,
      'productName': productName,
      'portionG': portionG,
      'pheUsedPer100g': pheUsedPer100g,
      'pheInPortion': pheInPortion,
      'proteinInPortion': proteinInPortion,
      'fatInPortion': fatInPortion,
      'carbsInPortion': carbsInPortion,
      'caloriesInPortion': caloriesInPortion,
      'isMedicalFormula': isMedicalFormula,
      'mealType': mealType.name,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory DiaryEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DiaryEntry(
      id: doc.id,
      userId: data['userId'] ?? '',
      productId: data['productId'],
      productName: data['productName'] ?? '',
      portionG: (data['portionG'] ?? 0).toDouble(),
      pheUsedPer100g: (data['pheUsedPer100g'] ?? 0).toDouble(),
      pheInPortion: (data['pheInPortion'] ?? 0).toDouble(),
      proteinInPortion: (data['proteinInPortion'] ?? 0).toDouble(),
      fatInPortion: data['fatInPortion']?.toDouble(),
      carbsInPortion: data['carbsInPortion']?.toDouble(),
      caloriesInPortion: data['caloriesInPortion']?.toDouble(),
      isMedicalFormula: data['isMedicalFormula'] ?? false,
      mealType: MealType.values.firstWhere(
        (e) => e.name == data['mealType'],
        orElse: () => MealType.breakfast,
      ),
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }
}