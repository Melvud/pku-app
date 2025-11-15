import 'package:cloud_firestore/cloud_firestore.dart';

enum RecipeCategory {
  breakfast('Завтраки'),
  lunch('Обеды'),
  dinner('Ужины'),
  snack('Перекусы'),
  dessert('Десерты'),
  baking('Выпечка'),
  salad('Салаты'),
  soup('Супы');

  final String displayName;
  const RecipeCategory(this.displayName);
}

enum RecipeStatus {
  approved('Одобрен'),
  pending('На проверке'),
  rejected('Отклонен');

  final String displayName;
  const RecipeStatus(this.displayName);
}

class RecipeStep {
  final String instruction;
  final String? imageUrl;

  RecipeStep({
    required this.instruction,
    this.imageUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'instruction': instruction,
      'imageUrl': imageUrl,
    };
  }

  factory RecipeStep.fromMap(Map<String, dynamic> map) {
    return RecipeStep(
      instruction: map['instruction'] ?? '',
      imageUrl: map['imageUrl'],
    );
  }
}

class Recipe {
  final String id;
  final String name;
  final String description;
  final RecipeCategory category;
  final List<RecipeIngredient> ingredients;
  final List<String> instructions; // Keep for backward compatibility
  final List<RecipeStep>? steps; // New field for steps with images
  final int servings;
  final int cookingTimeMinutes;
  final double phePer100g;
  final double proteinPer100g;
  final double? fatPer100g;
  final double? carbsPer100g;
  final double? caloriesPer100g;
  final String? imageUrl; // Cover image
  final String authorId;
  final String authorName;
  final RecipeStatus status;
  final DateTime createdAt;
  final DateTime? approvedAt;
  final String? rejectionReason;
  final bool isOfficial; // Официальный рецепт от команды приложения
  final int likesCount; // Number of likes
  final List<String> likedBy; // User IDs who liked this recipe

  Recipe({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.ingredients,
    required this.instructions,
    this.steps,
    required this.servings,
    required this.cookingTimeMinutes,
    required this.phePer100g,
    required this.proteinPer100g,
    this.fatPer100g,
    this.carbsPer100g,
    this.caloriesPer100g,
    this.imageUrl,
    required this.authorId,
    required this.authorName,
    required this.status,
    required this.createdAt,
    this.approvedAt,
    this.rejectionReason,
    this.isOfficial = false,
    this.likesCount = 0,
    this.likedBy = const [],
  });
  
  // Helper to get steps (either new format or old)
  List<RecipeStep> get recipeSteps {
    if (steps != null && steps!.isNotEmpty) {
      return steps!;
    }
    // Convert old instructions to steps
    return instructions.map((i) => RecipeStep(instruction: i)).toList();
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'category': category.name,
      'ingredients': ingredients.map((i) => i.toMap()).toList(),
      'instructions': instructions,
      'steps': steps?.map((s) => s.toMap()).toList(),
      'servings': servings,
      'cookingTimeMinutes': cookingTimeMinutes,
      'phePer100g': phePer100g,
      'proteinPer100g': proteinPer100g,
      'fatPer100g': fatPer100g,
      'carbsPer100g': carbsPer100g,
      'caloriesPer100g': caloriesPer100g,
      'imageUrl': imageUrl,
      'authorId': authorId,
      'authorName': authorName,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'rejectionReason': rejectionReason,
      'isOfficial': isOfficial,
      'likesCount': likesCount,
      'likedBy': likedBy,
    };
  }

  factory Recipe.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Recipe(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      category: RecipeCategory.values.firstWhere(
        (e) => e.name == data['category'],
        orElse: () => RecipeCategory.snack,
      ),
      ingredients: (data['ingredients'] as List<dynamic>?)
              ?.map((i) => RecipeIngredient.fromMap(i as Map<String, dynamic>))
              .toList() ??
          [],
      instructions: (data['instructions'] as List<dynamic>?)?.cast<String>() ?? [],
      steps: (data['steps'] as List<dynamic>?)
              ?.map((s) => RecipeStep.fromMap(s as Map<String, dynamic>))
              .toList(),
      servings: data['servings'] ?? 1,
      cookingTimeMinutes: data['cookingTimeMinutes'] ?? 0,
      phePer100g: (data['phePer100g'] ?? 0).toDouble(),
      proteinPer100g: (data['proteinPer100g'] ?? 0).toDouble(),
      fatPer100g: data['fatPer100g']?.toDouble(),
      carbsPer100g: data['carbsPer100g']?.toDouble(),
      caloriesPer100g: data['caloriesPer100g']?.toDouble(),
      imageUrl: data['imageUrl'],
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? 'Аноним',
      status: RecipeStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => RecipeStatus.pending,
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      approvedAt: (data['approvedAt'] as Timestamp?)?.toDate(),
      rejectionReason: data['rejectionReason'],
      isOfficial: data['isOfficial'] ?? false,
      likesCount: data['likesCount'] ?? 0,
      likedBy: (data['likedBy'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }
}

class RecipeIngredient {
  final String name;
  final double amount;
  final String unit; // г, мл, шт, ч.л., ст.л.

  RecipeIngredient({
    required this.name,
    required this.amount,
    required this.unit,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'amount': amount,
      'unit': unit,
    };
  }

  factory RecipeIngredient.fromMap(Map<String, dynamic> map) {
    return RecipeIngredient(
      name: map['name'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      unit: map['unit'] ?? 'г',
    );
  }

  String get displayText => '$amount $unit $name';
}