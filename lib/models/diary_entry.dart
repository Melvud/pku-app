import 'package:cloud_firestore/cloud_firestore.dart';

class DiaryEntry {
  final String id;
  final String userId;
  final String? productId;
  final String productName;
  final double portionG;
  final double pheUsedPer100g;
  final double pheInPortion;
  final bool isMedicalFormula;
  final DateTime timestamp;

  DiaryEntry({
    required this.id,
    required this.userId,
    this.productId,
    required this.productName,
    required this.portionG,
    required this.pheUsedPer100g,
    required this.pheInPortion,
    required this.isMedicalFormula,
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
      'isMedicalFormula': isMedicalFormula,
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
      isMedicalFormula: data['isMedicalFormula'] ?? false,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }
}