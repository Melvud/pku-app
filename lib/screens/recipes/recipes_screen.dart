import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/recipes_provider.dart';
import '../../models/recipe.dart';
import '../../widgets/app_header.dart';
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
  bool _showMyRecipes = false; // Track if showing my recipes
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<RecipesProvider>(context, listen: false);
      // Load recipes only if not already loaded
      if (provider.recipes.isEmpty) {
        provider.loadApprovedRecipes();
      }
      if (provider.myRecipes.isEmpty) {
        provider.loadMyRecipes();
      }
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
          AppHeader(
            title: 'Рецепты',
            subtitle: 'Вкусные и полезные рецепты',
            expandedHeight: 120,
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
                    label: 'Мои рецепты',
                    isSelected: _showMyRecipes,
                    onTap: () {
                      setState(() {
                        _showMyRecipes = true;
                        _selectedCategory = null;
                      });
                      // Reload my recipes when switching to this tab
                      Provider.of<RecipesProvider>(context, listen: false).loadMyRecipes();
                    },
                  ),
                  _CategoryChip(
                    label: 'Все',
                    isSelected: !_showMyRecipes && _selectedCategory == null,
                    onTap: () => setState(() {
                      _showMyRecipes = false;
                      _selectedCategory = null;
                    }),
                  ),
                  ...RecipeCategory.values.map((category) => _CategoryChip(
                        label: category.displayName,
                        isSelected: !_showMyRecipes && _selectedCategory == category,
                        onTap: () => setState(() {
                          _showMyRecipes = false;
                          _selectedCategory = category;
                        }),
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

              List<Recipe> filteredRecipes;
              
              if (_showMyRecipes) {
                // Show my recipes (all statuses)
                filteredRecipes = _searchQuery.isNotEmpty
                    ? provider.myRecipes.where((r) {
                        final lowerQuery = _searchQuery.toLowerCase();
                        return r.name.toLowerCase().contains(lowerQuery) ||
                               r.description.toLowerCase().contains(lowerQuery);
                      }).toList()
                    : provider.myRecipes;
              } else {
                // Show approved recipes with filters
                filteredRecipes = _searchQuery.isNotEmpty
                    ? provider.searchRecipes(_searchQuery)
                    : provider.filterByCategory(_selectedCategory);
              }

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
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final recipe = filteredRecipes[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _RecipeCard(
                          recipe: recipe,
                          showStatus: _showMyRecipes,
                        ),
                      );
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
  final bool showStatus;

  const _RecipeCard({
    required this.recipe,
    this.showStatus = false,
  });

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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image or Placeholder
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                gradient: recipe.imageUrl == null
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          color.withOpacity(0.7),
                          color,
                        ],
                      )
                    : null,
              ),
              child: Stack(
                children: [
                  // Show image if available, otherwise show icon
                  if (recipe.imageUrl != null)
                    Image.network(
                      recipe.imageUrl!,
                      width: 140,
                      height: 140,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        // Fallback to icon if image fails to load
                        return Container(
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
                              size: 48,
                              color: Colors.white,
                            ),
                          ),
                        );
                      },
                    )
                  else
                    Center(
                      child: Icon(
                        _getCategoryIcon(),
                        size: 48,
                        color: Colors.white,
                      ),
                    ),
                  if (recipe.isOfficial && !showStatus)
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
                  // Status badges - only show when showStatus is true
                  if (showStatus && recipe.status == RecipeStatus.pending)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              Icons.hourglass_empty,
                              size: 12,
                              color: Colors.white,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'На проверке',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (showStatus && recipe.status == RecipeStatus.rejected)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              Icons.close,
                              size: 12,
                              color: Colors.white,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Отклонено',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (showStatus && recipe.status == RecipeStatus.approved && !recipe.isOfficial)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              Icons.check_circle,
                              size: 12,
                              color: Colors.white,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Опубликовано',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      recipe.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
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
                        const SizedBox(width: 12),
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
                    const SizedBox(height: 8),
                    // Ingredients
                    if (recipe.ingredients.isNotEmpty) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.shopping_basket,
                            size: 14,
                            color: Colors.grey.shade700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Ингредиенты:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        recipe.ingredients.take(3).map((i) => i.name).join(', ') +
                            (recipe.ingredients.length > 3 ? '...' : ''),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                    ],
                    // Nutrition info
                    Row(
                      children: [
                        if (recipe.likesCount > 0) ...[
                          Icon(
                            Icons.favorite,
                            size: 14,
                            color: Colors.red.shade400,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${recipe.likesCount}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Phe: ${recipe.phePer100g.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple.shade700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Б: ${recipe.proteinPer100g.toStringAsFixed(1)}г',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                      ],
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