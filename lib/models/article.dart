import 'package:cloud_firestore/cloud_firestore.dart';

class Article {
  final String id;
  final String title;
  final String pdfUrl;
  final String? description;
  final DateTime createdAt;
  final String createdBy;
  final String createdByName;

  Article({
    required this.id,
    required this.title,
    required this.pdfUrl,
    this.description,
    required this.createdAt,
    required this.createdBy,
    required this.createdByName,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'pdfUrl': pdfUrl,
      'description': description,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
      'createdByName': createdByName,
    };
  }

  factory Article.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Article(
      id: doc.id,
      title: data['title'] ?? '',
      pdfUrl: data['pdfUrl'] ?? '',
      description: data['description'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'] ?? '',
      createdByName: data['createdByName'] ?? 'Админ',
    );
  }
}
