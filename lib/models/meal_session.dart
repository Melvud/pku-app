import 'package:flutter/material.dart';
import 'diary_entry.dart';

class MealSession {
  final String id;
  final MealType type;
  final String? customName;
  final DateTime? time;
  final int order;
  final DateTime date; // Date this session belongs to
  final bool drankFormula; // Whether medical formula was consumed

  MealSession({
    required this.id,
    required this.type,
    this.customName,
    this.time,
    required this.order,
    required this.date,
    this.drankFormula = false,
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
    DateTime? date,
    bool? drankFormula,
  }) {
    return MealSession(
      id: id ?? this.id,
      type: type ?? this.type,
      customName: customName ?? this.customName,
      time: time ?? this.time,
      order: order ?? this.order,
      date: date ?? this.date,
      drankFormula: drankFormula ?? this.drankFormula,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'customName': customName,
      'time': time?.toIso8601String(),
      'order': order,
      'date': date.toIso8601String(),
      'drankFormula': drankFormula,
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
      date: json['date'] != null 
          ? DateTime.parse(json['date'] as String)
          : DateTime.now(), // Fallback for backward compatibility
      drankFormula: json['drankFormula'] as bool? ?? false,
    );
  }

  // Дефолтные приемы пищи для конкретной даты
  static List<MealSession> defaultMealsForDate(DateTime date) => [
        MealSession(
          id: 'breakfast_${date.toIso8601String()}',
          type: MealType.breakfast,
          order: 0,
          time: DateTime(date.year, date.month, date.day, 8, 0), // 08:00
          date: date,
        ),
        MealSession(
          id: 'lunch_${date.toIso8601String()}',
          type: MealType.lunch,
          order: 1,
          time: DateTime(date.year, date.month, date.day, 13, 0), // 13:00
          date: date,
        ),
        MealSession(
          id: 'dinner_${date.toIso8601String()}',
          type: MealType.dinner,
          order: 2,
          time: DateTime(date.year, date.month, date.day, 18, 0), // 18:00
          date: date,
        ),
      ];
  
  // Старый метод для совместимости
  static List<MealSession> get defaultMeals => defaultMealsForDate(DateTime.now());
}