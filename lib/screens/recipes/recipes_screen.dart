import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/recipes_provider.dart';
import '../../models/recipe.dart';
import 'recipe_detail_screen.dart';
import 'add_recipe_screen.dart';
import 'my_recipes_screen.dart';

class RecipesScreen extends StatefulWidget {
  const RecipesScreen({super.key});

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  RecipeCategory? _selectedCategory;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<RecipesProvider>(context, listen: false).loadApprovedRecipes();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            expandedHeight: 140,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: Theme.of(context).colorScheme.primary,
            title: Text(
              'Рецепты',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.secondary,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Рецепты при ФКУ',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Вкусные и безопасные блюда',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.book, color: Colors.white),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MyRecipesScreen(),
                    ),
                  );
                },
                tooltip: 'Мои рецепты',
              ),
            ],
          ),

          // Search Bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Поиск рецептов...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  filled: true,
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                },
              ),
            ),
          ),

          // Categories
          SliverToBoxAdapter(
            child: SizedBox(
              height: 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _CategoryChip(
                    label: 'Все',
                    isSelected: _selectedCategory == null,
                    onTap: () => setState(() => _selectedCategory = null),
                  ),
                  ...RecipeCategory.values.map((category) => _CategoryChip(
                        label: category.displayName,
                        isSelected: _selectedCategory == category,
                        onTap: () => setState(() => _selectedCategory = category),
                      )),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 8)),

          // Recipes Grid
          Consumer<RecipesProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (provider.error != null) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(provider.error!),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => provider.loadApprovedRecipes(),
                          child: const Text('Повторить'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              List<Recipe> filteredRecipes = _searchQuery.isNotEmpty
                  ? provider.searchRecipes(_searchQuery)
                  : provider.filterByCategory(_selectedCategory);

              if (filteredRecipes.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.restaurant_menu,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Рецепты не найдены',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Попробуйте изменить фильтры или\nдобавьте свой рецепт!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.75,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final recipe = filteredRecipes[index];
                      return _RecipeCard(recipe: recipe);
                    },
                    childCount: filteredRecipes.length,
                  ),
                ),
              );
            },
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddRecipeScreen(),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Добавить рецепт'),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
        selectedColor: Theme.of(context).colorScheme.primaryContainer,
        checkmarkColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  final Recipe recipe;

  const _RecipeCard({required this.recipe});

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

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RecipeDetailScreen(recipe: recipe),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image or Placeholder
            Container(
              height: 120,
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
              child: Stack(
                children: [
                  Center(
                    child: Icon(
                      _getCategoryIcon(),
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
                  if (recipe.isOfficial)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.verified,
                              size: 14,
                              color: color,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Официальный',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${recipe.cookingTimeMinutes} мин',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.restaurant_menu,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${recipe.servings} порц.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Phe: ${recipe.phePer100g.toStringAsFixed(0)} мг/100г',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}