// lib/services/pending_products_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/pending_product.dart';
import '../models/product.dart';

class PendingProductsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Submit a product for moderation
  Future<String> submitProduct(PendingProduct pendingProduct) async {
    try {
      final docRef = await _firestore
          .collection('pending_products')
          .add(pendingProduct.toFirestore());

      debugPrint('✅ Product submitted for moderation: ${pendingProduct.name}');
      return docRef.id;
    } catch (e) {
      debugPrint('❌ Error submitting product: $e');
      rethrow;
    }
  }

  /// Get all pending products for admin review
  Future<List<PendingProduct>> getPendingProducts() async {
    try {
      final snapshot = await _firestore
          .collection('pending_products')
          .where('status', isEqualTo: PendingProductStatus.pending.name)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => PendingProduct.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error loading pending products: $e');
      return [];
    }
  }

  /// Get pending products submitted by a specific user
  Future<List<PendingProduct>> getUserPendingProducts(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('pending_products')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      return snapshot.docs
          .map((doc) => PendingProduct.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error loading user pending products: $e');
      return [];
    }
  }

  /// Approve a pending product and add it to the main products collection
  Future<void> approveProduct(String pendingProductId, {String? adminNotes}) async {
    try {
      // Get the pending product
      final doc = await _firestore
          .collection('pending_products')
          .doc(pendingProductId)
          .get();

      if (!doc.exists) {
        throw Exception('Pending product not found');
      }

      final pendingProduct = PendingProduct.fromFirestore(doc);
      final product = pendingProduct.toProduct();

      // If it's an update to existing product, update it
      if (pendingProduct.action == PendingProductAction.update &&
          pendingProduct.originalProductId != null &&
          pendingProduct.originalProductId!.isNotEmpty) {
        await _firestore
            .collection('products')
            .doc(pendingProduct.originalProductId)
            .update({
          ...product.toFirestore(),
          'lastUpdated': FieldValue.serverTimestamp(),
          'updatedFromPending': pendingProductId,
        });
        debugPrint('✅ Updated existing product: ${product.name}');
      } else {
        // Add new product
        await _firestore.collection('products').add({
          ...product.toFirestore(),
          'lastUpdated': FieldValue.serverTimestamp(),
          'addedFromPending': pendingProductId,
        });
        debugPrint('✅ Added new product: ${product.name}');
      }

      // Update pending product status
      await _firestore.collection('pending_products').doc(pendingProductId).update({
        'status': PendingProductStatus.approved.name,
        'reviewedAt': FieldValue.serverTimestamp(),
        'adminNotes': adminNotes,
      });

      debugPrint('✅ Product approved: ${pendingProduct.name}');
    } catch (e) {
      debugPrint('❌ Error approving product: $e');
      rethrow;
    }
  }

  /// Reject a pending product
  Future<void> rejectProduct(String pendingProductId, String reason, {String? adminNotes}) async {
    try {
      await _firestore.collection('pending_products').doc(pendingProductId).update({
        'status': PendingProductStatus.rejected.name,
        'rejectionReason': reason,
        'reviewedAt': FieldValue.serverTimestamp(),
        'adminNotes': adminNotes,
      });

      debugPrint('✅ Product rejected: $pendingProductId');
    } catch (e) {
      debugPrint('❌ Error rejecting product: $e');
      rethrow;
    }
  }

  /// Update a pending product before approval (admin edits)
  Future<void> updatePendingProduct(PendingProduct pendingProduct) async {
    try {
      await _firestore
          .collection('pending_products')
          .doc(pendingProduct.id)
          .update(pendingProduct.toFirestore());

      debugPrint('✅ Pending product updated: ${pendingProduct.name}');
    } catch (e) {
      debugPrint('❌ Error updating pending product: $e');
      rethrow;
    }
  }

  /// Delete a pending product
  Future<void> deletePendingProduct(String pendingProductId) async {
    try {
      await _firestore.collection('pending_products').doc(pendingProductId).delete();
      debugPrint('✅ Pending product deleted: $pendingProductId');
    } catch (e) {
      debugPrint('❌ Error deleting pending product: $e');
      rethrow;
    }
  }

  /// Get count of pending products for admin badge
  Future<int> getPendingCount() async {
    try {
      final snapshot = await _firestore
          .collection('pending_products')
          .where('status', isEqualTo: PendingProductStatus.pending.name)
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      debugPrint('Error getting pending count: $e');
      return 0;
    }
  }
}
