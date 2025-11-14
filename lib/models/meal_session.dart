import 'package:flutter/material.dart';
import 'diary_entry.dart';

class MealSession {
  final String id;
  final MealType type;
  final String? customName;
  final DateTime? time;
  final int order;

  MealSession({
    required this.id,
    required this.type,
    this.customName,
    this.time,
    required this.order,
  });

  String get displayName {
    if (customName != null && customName!.isNotEmpty) {
      return customName!;
    }
    return type.displayName;
  }

  IconData get icon {
    switch (type) {
      case MealType.breakfast:
        return Icons.wb_sunny;
      case MealType.lunch:
        return Icons.wb_cloudy;
      case MealType.dinner:
        return Icons.nightlight;
      case MealType.snack:
        return Icons.local_cafe;
      case MealType.custom:
        return Icons.restaurant;
    }
  }

  Color getColor(BuildContext context) {
    switch (type) {
      case MealType.breakfast:
        return Colors.orange;
      case MealType.lunch:
        return Colors.blue;
      case MealType.dinner:
        return Colors.purple;
      case MealType.snack:
        return Colors.green;
      case MealType.custom:
        return Colors.teal;
    }
  }

  MealSession copyWith({
    String? id,
    MealType? type,
    String? customName,
    DateTime? time,
    int? order,
  }) {
    return MealSession(
      id: id ?? this.id,
      type: type ?? this.type,
      customName: customName ?? this.customName,
      time: time ?? this.time,
      order: order ?? this.order,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'customName': customName,
      'time': time?.toIso8601String(),
      'order': order,
    };
  }

  factory MealSession.fromJson(Map<String, dynamic> json) {
    return MealSession(
      id: json['id'] as String,
      type: MealType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => MealType.custom,
      ),
      customName: json['customName'] as String?,
      time: json['time'] != null ? DateTime.parse(json['time'] as String) : null,
      order: json['order'] as int,
    );
  }

  // Дефолтные приемы пищи
  static List<MealSession> get defaultMeals => [
        MealSession(
          id: 'breakfast',
          type: MealType.breakfast,
          order: 0,
          time: DateTime(2000, 1, 1, 8, 0), // 08:00
        ),
        MealSession(
          id: 'lunch',
          type: MealType.lunch,
          order: 1,
          time: DateTime(2000, 1, 1, 13, 0), // 13:00
        ),
        MealSession(
          id: 'dinner',
          type: MealType.dinner,
          order: 2,
          time: DateTime(2000, 1, 1, 18, 0), // 18:00
        ),
      ];
}