import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../providers/recipes_provider.dart';
import '../../models/recipe.dart';
import '../../models/product.dart';
import '../../models/meal_session.dart';
import '../../models/diary_entry.dart'; // For MealType
import '../products/edit_product_portion_screen.dart';

class RecipeSelectionScreen extends StatefulWidget {
  final MealType mealType;

  const RecipeSelectionScreen({
    super.key,
    required this.mealType,
  });

  @override
  State<RecipeSelectionScreen> createState() => _RecipeSelectionScreenState();
}

class _RecipeSelectionScreenState extends State<RecipeSelectionScreen> {
  RecipeCategory? _selectedCategory;
  String _searchQuery = '';
  bool _showMyRecipes = false;
  bool _showFavorites = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Load recipes when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<RecipesProvider>(context, listen: false);
      provider.loadApprovedRecipes();
      provider.loadMyRecipes();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onRecipeSelected(Recipe recipe) {
    // Convert Recipe to Product
    final product = Product(
      id: recipe
          .id, // Use recipe ID temporarily, but we pass recipeId separately
      name: recipe.name,
      category: 'other', // Default category for recipes
      proteinPer100g: recipe.proteinPer100g,
      pheMeasuredPer100g: null,
      pheEstimatedPer100g: recipe.phePer100g,
      fatPer100g: recipe.fatPer100g,
      carbsPer100g: recipe.carbsPer100g,
      caloriesPer100g: recipe.caloriesPer100g,
      notes: 'Рецепт: ${recipe.name}',
      source: 'Recipe',
      lastUpdated: DateTime.now(),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProductPortionScreen(
          product: product,
          mealType: widget.mealType,
          recipeId: recipe.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: Text(
          'Добавить рецепт в ${widget.mealType.displayName}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Consumer<RecipesProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          List<Recipe> filteredRecipes;

          if (_showMyRecipes) {
            filteredRecipes = _searchQuery.isNotEmpty
                ? provider.myRecipes.where((r) {
                    final lowerQuery = _searchQuery.toLowerCase();
                    return r.name.toLowerCase().contains(lowerQuery) ||
                        r.description.toLowerCase().contains(lowerQuery);
                  }).toList()
                : provider.myRecipes;
          } else if (_showFavorites) {
            final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
            final allRecipes = [...provider.recipes, ...provider.myRecipes];
            final uniqueRecipes = <String, Recipe>{};
            for (var r in allRecipes) {
              uniqueRecipes[r.id] = r;
            }

            filteredRecipes = uniqueRecipes.values.where((r) {
              final isLiked = r.likedBy.contains(userId);
              if (!isLiked) return false;

              if (_searchQuery.isNotEmpty) {
                final lowerQuery = _searchQuery.toLowerCase();
                return r.name.toLowerCase().contains(lowerQuery) ||
                    r.description.toLowerCase().contains(lowerQuery);
              }
              return true;
            }).toList();
          } else {
            filteredRecipes = _searchQuery.isNotEmpty
                ? provider.searchRecipes(_searchQuery)
                : provider.filterByCategory(_selectedCategory);
          }

          return Column(
            children: [
              // Search Bar
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Поиск рецептов...',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                ),
              ),

              // Categories
              Container(
                color: Colors.white,
                height: 50,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _CategoryChip(
                      label: 'Избранное',
                      isSelected: _selectedCategory == null &&
                          !_showMyRecipes &&
                          _showFavorites,
                      onTap: () {
                        setState(() {
                          _showFavorites = true;
                          _showMyRecipes = false;
                          _selectedCategory = null;
                        });
                      },
                    ),
                    _CategoryChip(
                      label: 'Мои рецепты',
                      isSelected: _showMyRecipes,
                      onTap: () {
                        setState(() {
                          _showMyRecipes = true;
                          _showFavorites = false;
                          _selectedCategory = null;
                        });
                        provider.loadMyRecipes();
                      },
                    ),
                    _CategoryChip(
                      label: 'Все',
                      isSelected: !_showMyRecipes &&
                          !_showFavorites &&
                          _selectedCategory == null,
                      onTap: () => setState(() {
                        _showMyRecipes = false;
                        _showFavorites = false;
                        _selectedCategory = null;
                      }),
                    ),
                    ...RecipeCategory.values.map((category) => _CategoryChip(
                          label: category.displayName,
                          isSelected: !_showMyRecipes &&
                              !_showFavorites &&
                              _selectedCategory == category,
                          onTap: () => setState(() {
                            _showMyRecipes = false;
                            _showFavorites = false;
                            _selectedCategory = category;
                          }),
                        )),
                  ],
                ),
              ),

              // Recipe List
              Expanded(
                child: filteredRecipes.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off,
                                size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text(
                              'Рецепты не найдены',
                              style: TextStyle(
                                  color: Colors.grey[500], fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredRecipes.length,
                        itemBuilder: (context, index) {
                          final recipe = filteredRecipes[index];
                          return _RecipeSelectionCard(
                            recipe: recipe,
                            onTap: () => _onRecipeSelected(recipe),
                          );
                        },
                      ),
              ),
            ],
          );
        },
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
      padding: const EdgeInsets.only(right: 8, bottom: 8),
      child: ActionChip(
        label: Text(label),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        backgroundColor:
            isSelected ? Theme.of(context).primaryColor : Colors.grey[100],
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isSelected ? Colors.transparent : Colors.grey[300]!,
              width: 1,
            )),
        onPressed: onTap,
      ),
    );
  }
}

class _RecipeSelectionCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onTap;

  const _RecipeSelectionCard({
    required this.recipe,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image or Placeholder
            Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                image: recipe.imageUrl != null
                    ? DecorationImage(
                        image: NetworkImage(recipe.imageUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: recipe.imageUrl == null
                  ? Icon(Icons.restaurant, size: 64, color: Colors.grey[400])
                  : null,
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          recipe.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (recipe.isOfficial)
                        const Icon(Icons.verified,
                            color: Colors.blue, size: 20),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _NutrientBadge(
                        label: 'Phe',
                        value: '${recipe.phePer100g.toStringAsFixed(1)} мг',
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      _NutrientBadge(
                        label: 'Белок',
                        value: '${recipe.proteinPer100g.toStringAsFixed(1)} г',
                        color: Colors.blue,
                      ),
                      const Spacer(),
                      const Icon(Icons.add_circle_outline, color: Colors.green),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NutrientBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _NutrientBadge({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}
