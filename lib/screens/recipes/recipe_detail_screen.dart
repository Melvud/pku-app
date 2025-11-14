import 'package:flutter/material.dart';
import '../../models/recipe.dart';

class RecipeDetailScreen extends StatelessWidget {
  final Recipe recipe;

  const RecipeDetailScreen({super.key, required this.recipe});

  Color _getCategoryColor() {
    switch (recipe.category) {
      case RecipeCategory.breakfast:
        return Colors.orange;
      case RecipeCategory.lunch:
        return Colors.blue;
      case RecipeCategory.dinner:
        return Colors.purple;
      case RecipeCategory.snack:
        return Colors.green;
      case RecipeCategory.dessert:
        return Colors.pink;
      case RecipeCategory.baking:
        return Colors.amber;
      case RecipeCategory.salad:
        return Colors.lightGreen;
      case RecipeCategory.soup:
        return Colors.teal;
    }
  }

  IconData _getCategoryIcon() {
    switch (recipe.category) {
      case RecipeCategory.breakfast:
        return Icons.wb_sunny;
      case RecipeCategory.lunch:
        return Icons.restaurant;
      case RecipeCategory.dinner:
        return Icons.dinner_dining;
      case RecipeCategory.snack:
        return Icons.cookie;
      case RecipeCategory.dessert:
        return Icons.cake;
      case RecipeCategory.baking:
        return Icons.bakery_dining;
      case RecipeCategory.salad:
        return Icons.grass;
      case RecipeCategory.soup:
        return Icons.soup_kitchen;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getCategoryColor();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Header with image
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color.withOpacity(0.7),
                      color,
                    ],
                  ),
                ),
                child: Center(
                  child: Icon(
                    _getCategoryIcon(),
                    size: 100,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and badges
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          recipe.name,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                      if (recipe.isOfficial)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified, size: 16, color: color),
                              const SizedBox(width: 4),
                              Text(
                                'Официальный',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      recipe.category.displayName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Description
                  Text(
                    recipe.description,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          height: 1.6,
                        ),
                  ),
                  const SizedBox(height: 24),

                  // Info cards
                  Row(
                    children: [
                      Expanded(
                        child: _InfoCard(
                          icon: Icons.access_time,
                          label: 'Время',
                          value: '${recipe.cookingTimeMinutes} мин',
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _InfoCard(
                          icon: Icons.restaurant_menu,
                          label: 'Порций',
                          value: '${recipe.servings}',
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Nutrition info
                  Text(
                    'Пищевая ценность (на 100г)',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.purple.shade200),
                    ),
                    child: Column(
                      children: [
                        _NutritionRow(
                          label: 'Фенилаланин (Phe)',
                          value: '${recipe.phePer100g.toStringAsFixed(0)} мг',
                          color: Colors.purple,
                          isHighlighted: true,
                        ),
                        const Divider(height: 24),
                        _NutritionRow(
                          label: 'Белок',
                          value: '${recipe.proteinPer100g.toStringAsFixed(1)} г',
                          color: Colors.blue,
                        ),
                        if (recipe.fatPer100g != null) ...[
                          const SizedBox(height: 12),
                          _NutritionRow(
                            label: 'Жиры',
                            value: '${recipe.fatPer100g!.toStringAsFixed(1)} г',
                            color: Colors.amber,
                          ),
                        ],
                        if (recipe.carbsPer100g != null) ...[
                          const SizedBox(height: 12),
                          _NutritionRow(
                            label: 'Углеводы',
                            value: '${recipe.carbsPer100g!.toStringAsFixed(1)} г',
                            color: Colors.green,
                          ),
                        ],
                        if (recipe.caloriesPer100g != null) ...[
                          const SizedBox(height: 12),
                          _NutritionRow(
                            label: 'Калории',
                            value: '${recipe.caloriesPer100g!.toStringAsFixed(0)} ккал',
                            color: Colors.orange,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Ingredients
                  Text(
                    'Ингредиенты',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  ...recipe.ingredients.asMap().entries.map((entry) {
                    final index = entry.key;
                    final ingredient = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              ingredient.displayText,
                              style: const TextStyle(fontSize: 15, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 32),

                  // Instructions
                  Text(
                    'Способ приготовления',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  ...recipe.instructions.asMap().entries.map((entry) {
                    final index = entry.key;
                    final instruction = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                instruction,
                                style: const TextStyle(fontSize: 15, height: 1.6),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 16),

                  // Author info
                  Card(
                    color: Colors.grey.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: color.withOpacity(0.2),
                            child: Icon(Icons.person, color: color),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Автор рецепта',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  recipe.authorName,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _NutritionRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isHighlighted;

  const _NutritionRow({
    required this.label,
    required this.value,
    required this.color,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: isHighlighted ? 16 : 15,
              fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isHighlighted ? 18 : 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}