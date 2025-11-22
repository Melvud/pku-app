// lib/models/pending_product.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'product.dart';

enum PendingProductStatus {
  pending,
  approved,
  rejected,
}

enum PendingProductAction {
  add,     // New product submission
  update,  // Update to existing product
}

class PendingProduct {
  final String id;
  final String userId;
  final String userName;
  final String name;
  final String category;
  final double proteinPer100g;
  final double? pheMeasuredPer100g;
  final double pheEstimatedPer100g;
  final bool isPheCalculated; // True if Phe was auto-calculated from protein
  final double? fatPer100g;
  final double? carbsPer100g;
  final double? caloriesPer100g;
  final String? notes;
  final String? barcode;
  final String? originalProductId; // If updating an existing product
  final PendingProductStatus status;
  final PendingProductAction action;
  final DateTime createdAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String? rejectionReason;
  final String? adminNotes;

  PendingProduct({
    required this.id,
    required this.userId,
    required this.userName,
    required this.name,
    required this.category,
    required this.proteinPer100g,
    this.pheMeasuredPer100g,
    required this.pheEstimatedPer100g,
    required this.isPheCalculated,
    this.fatPer100g,
    this.carbsPer100g,
    this.caloriesPer100g,
    this.notes,
    this.barcode,
    this.originalProductId,
    required this.status,
    required this.action,
    required this.createdAt,
    this.reviewedAt,
    this.reviewedBy,
    this.rejectionReason,
    this.adminNotes,
  });

  /// The Phe value to use (measured if available, otherwise estimated)
  double get pheToUse => pheMeasuredPer100g ?? pheEstimatedPer100g;

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userName': userName,
      'name': name,
      'category': category,
      'proteinPer100g': proteinPer100g,
      'pheMeasuredPer100g': pheMeasuredPer100g,
      'pheEstimatedPer100g': pheEstimatedPer100g,
      'isPheCalculated': isPheCalculated,
      'fatPer100g': fatPer100g,
      'carbsPer100g': carbsPer100g,
      'caloriesPer100g': caloriesPer100g,
      'notes': notes,
      'barcode': barcode,
      'originalProductId': originalProductId,
      'status': status.name,
      'action': action.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'reviewedAt': reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
      'reviewedBy': reviewedBy,
      'rejectionReason': rejectionReason,
      'adminNotes': adminNotes,
    };
  }

  /// Create from Firestore document
  factory PendingProduct.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PendingProduct(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Unknown',
      name: data['name'] ?? '',
      category: data['category'] ?? 'other',
      proteinPer100g: (data['proteinPer100g'] ?? 0).toDouble(),
      pheMeasuredPer100g: data['pheMeasuredPer100g']?.toDouble(),
      pheEstimatedPer100g: (data['pheEstimatedPer100g'] ?? 0).toDouble(),
      isPheCalculated: data['isPheCalculated'] ?? false,
      fatPer100g: data['fatPer100g']?.toDouble(),
      carbsPer100g: data['carbsPer100g']?.toDouble(),
      caloriesPer100g: data['caloriesPer100g']?.toDouble(),
      notes: data['notes'],
      barcode: data['barcode'],
      originalProductId: data['originalProductId'],
      status: PendingProductStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => PendingProductStatus.pending,
      ),
      action: PendingProductAction.values.firstWhere(
        (a) => a.name == data['action'],
        orElse: () => PendingProductAction.add,
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
      reviewedBy: data['reviewedBy'],
      rejectionReason: data['rejectionReason'],
      adminNotes: data['adminNotes'],
    );
  }

  /// Create a pending product from a Product for submission
  factory PendingProduct.fromProduct({
    required Product product,
    required String userId,
    required String userName,
    required bool isPheCalculated,
    String? originalProductId,
    PendingProductAction action = PendingProductAction.add,
  }) {
    return PendingProduct(
      id: '',
      userId: userId,
      userName: userName,
      name: product.name,
      category: product.category,
      proteinPer100g: product.proteinPer100g,
      pheMeasuredPer100g: product.pheMeasuredPer100g,
      pheEstimatedPer100g: product.pheEstimatedPer100g,
      isPheCalculated: isPheCalculated,
      fatPer100g: product.fatPer100g,
      carbsPer100g: product.carbsPer100g,
      caloriesPer100g: product.caloriesPer100g,
      notes: product.notes,
      barcode: product.barcode,
      originalProductId: originalProductId,
      status: PendingProductStatus.pending,
      action: action,
      createdAt: DateTime.now(),
    );
  }

  /// Convert approved pending product to Product
  Product toProduct() {
    return Product(
      id: originalProductId ?? '',
      name: name,
      category: category,
      proteinPer100g: proteinPer100g,
      pheMeasuredPer100g: pheMeasuredPer100g,
      pheEstimatedPer100g: pheEstimatedPer100g,
      fatPer100g: fatPer100g,
      carbsPer100g: carbsPer100g,
      caloriesPer100g: caloriesPer100g,
      notes: notes,
      source: 'User Submission',
      lastUpdated: DateTime.now(),
      googleSheetsId: null,
      barcode: barcode,
    );
  }

  /// Create a copy with updated fields
  PendingProduct copyWith({
    String? id,
    String? userId,
    String? userName,
    String? name,
    String? category,
    double? proteinPer100g,
    double? pheMeasuredPer100g,
    double? pheEstimatedPer100g,
    bool? isPheCalculated,
    double? fatPer100g,
    double? carbsPer100g,
    double? caloriesPer100g,
    String? notes,
    String? barcode,
    String? originalProductId,
    PendingProductStatus? status,
    PendingProductAction? action,
    DateTime? createdAt,
    DateTime? reviewedAt,
    String? reviewedBy,
    String? rejectionReason,
    String? adminNotes,
  }) {
    return PendingProduct(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      name: name ?? this.name,
      category: category ?? this.category,
      proteinPer100g: proteinPer100g ?? this.proteinPer100g,
      pheMeasuredPer100g: pheMeasuredPer100g ?? this.pheMeasuredPer100g,
      pheEstimatedPer100g: pheEstimatedPer100g ?? this.pheEstimatedPer100g,
      isPheCalculated: isPheCalculated ?? this.isPheCalculated,
      fatPer100g: fatPer100g ?? this.fatPer100g,
      carbsPer100g: carbsPer100g ?? this.carbsPer100g,
      caloriesPer100g: caloriesPer100g ?? this.caloriesPer100g,
      notes: notes ?? this.notes,
      barcode: barcode ?? this.barcode,
      originalProductId: originalProductId ?? this.originalProductId,
      status: status ?? this.status,
      action: action ?? this.action,
      createdAt: createdAt ?? this.createdAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      adminNotes: adminNotes ?? this.adminNotes,
    );
  }

  /// Get display status text
  String get statusDisplayName {
    switch (status) {
      case PendingProductStatus.pending:
        return 'На проверке';
      case PendingProductStatus.approved:
        return 'Одобрено';
      case PendingProductStatus.rejected:
        return 'Отклонено';
    }
  }

  /// Get action display text
  String get actionDisplayName {
    switch (action) {
      case PendingProductAction.add:
        return 'Добавление';
      case PendingProductAction.update:
        return 'Изменение';
    }
  }
}
