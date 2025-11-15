import 'package:cloud_firestore/cloud_firestore.dart';

enum CommentStatus {
  pending('На модерации'),
  approved('Одобрен'),
  rejected('Отклонен');

  final String displayName;
  const CommentStatus(this.displayName);
}

class RecipeComment {
  final String id;
  final String recipeId;
  final String authorId;
  final String authorName;
  final String text;
  final DateTime createdAt;
  final CommentStatus status;
  final String? parentCommentId; // For replies

  RecipeComment({
    required this.id,
    required this.recipeId,
    required this.authorId,
    required this.authorName,
    required this.text,
    required this.createdAt,
    required this.status,
    this.parentCommentId,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'recipeId': recipeId,
      'authorId': authorId,
      'authorName': authorName,
      'text': text,
      'createdAt': Timestamp.fromDate(createdAt),
      'status': status.name,
      'parentCommentId': parentCommentId,
    };
  }

  factory RecipeComment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RecipeComment(
      id: doc.id,
      recipeId: data['recipeId'] ?? '',
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? 'Аноним',
      text: data['text'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: CommentStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => CommentStatus.approved,
      ),
      parentCommentId: data['parentCommentId'],
    );
  }
}
