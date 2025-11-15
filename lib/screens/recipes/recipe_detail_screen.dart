import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/recipe.dart';
import '../../models/recipe_comment.dart';
import '../../providers/recipes_provider.dart';
import '../../providers/user_provider.dart';

class RecipeDetailScreen extends StatefulWidget {
  final Recipe recipe;

  const RecipeDetailScreen({super.key, required this.recipe});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  List<RecipeComment> _comments = [];
  bool _isLoadingComments = false;
  final TextEditingController _commentController = TextEditingController();
  String? _replyingToCommentId;
  String? _replyingToAuthorName;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() => _isLoadingComments = true);
    final provider = Provider.of<RecipesProvider>(context, listen: false);
    final comments = await provider.getCommentsForRecipe(widget.recipe.id);
    if (mounted) {
      setState(() {
        _comments = comments;
        _isLoadingComments = false;
      });
    }
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) return;

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final recipesProvider = Provider.of<RecipesProvider>(context, listen: false);
    
    try {
      await recipesProvider.addComment(
        recipeId: widget.recipe.id,
        text: _commentController.text.trim(),
        authorName: userProvider.userProfile?.name ?? 'Аноним',
        parentCommentId: _replyingToCommentId,
      );
      
      _commentController.clear();
      setState(() {
        _replyingToCommentId = null;
        _replyingToAuthorName = null;
      });
      
      // Small delay to ensure Firestore write completes
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Reload comments immediately
      await _loadComments();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Комментарий опубликован'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _toggleLike() async {
    final recipesProvider = Provider.of<RecipesProvider>(context, listen: false);
    try {
      await recipesProvider.toggleLike(widget.recipe.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Color _getCategoryColor() {
    switch (widget.recipe.category) {
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
    switch (widget.recipe.category) {
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
          // Compact Header with cover image
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: widget.recipe.imageUrl != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          widget.recipe.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildDefaultCover(color);
                          },
                        ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.7),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : _buildDefaultCover(color),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and Category Badge
                  Text(
                    widget.recipe.name,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          widget.recipe.category.displayName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      ),
                      if (widget.recipe.isOfficial) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified, size: 14, color: Colors.blue.shade700),
                              const SizedBox(width: 4),
                              Text(
                                'Официальный',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (widget.recipe.isRecommended) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star, size: 14, color: Colors.amber.shade700),
                              const SizedBox(width: 4),
                              Text(
                                'Рекомендация',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Description
                  Text(
                    widget.recipe.description,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          height: 1.5,
                          color: Colors.grey.shade700,
                        ),
                  ),
                  const SizedBox(height: 20),

                  // Unified Info Card: Author, Time, Servings, Likes, Comments
                  Consumer<RecipesProvider>(
                    builder: (context, provider, child) {
                      Recipe currentRecipe = widget.recipe;
                      final updatedRecipe = provider.recipes
                          .firstWhere((r) => r.id == widget.recipe.id, orElse: () => widget.recipe);
                      if (updatedRecipe.id == widget.recipe.id) {
                        currentRecipe = updatedRecipe;
                      } else {
                        final myRecipe = provider.myRecipes
                            .firstWhere((r) => r.id == widget.recipe.id, orElse: () => widget.recipe);
                        if (myRecipe.id == widget.recipe.id) {
                          currentRecipe = myRecipe;
                        }
                      }

                      final isLiked = currentRecipe.likedBy.contains(
                        FirebaseAuth.instance.currentUser?.uid ?? '',
                      );

                      return Card(
                        elevation: 0,
                        color: Colors.grey.shade50,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              // Author Info
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: color.withOpacity(0.2),
                                    radius: 20,
                                    child: Icon(Icons.person, color: color, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          widget.recipe.authorName,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _formatDate(widget.recipe.createdAt),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              const Divider(height: 1),
                              const SizedBox(height: 16),
                              
                              // Time and Servings
                              Row(
                                children: [
                                  Expanded(
                                    child: _CompactInfoChip(
                                      icon: Icons.access_time,
                                      label: '${widget.recipe.cookingTimeMinutes} мин',
                                      color: Colors.blue,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _CompactInfoChip(
                                      icon: Icons.restaurant_menu,
                                      label: '${widget.recipe.servings} порц.',
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              const Divider(height: 1),
                              const SizedBox(height: 16),
                              
                              // Likes and Comments
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  InkWell(
                                    onTap: widget.recipe.status == RecipeStatus.rejected ? null : _toggleLike,
                                    borderRadius: BorderRadius.circular(8),
                                    child: Opacity(
                                      opacity: widget.recipe.status == RecipeStatus.rejected ? 0.5 : 1.0,
                                      child: Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: Row(
                                          children: [
                                            Icon(
                                              isLiked ? Icons.favorite : Icons.favorite_border,
                                              color: isLiked ? Colors.red : Colors.grey.shade600,
                                              size: 22,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              '${currentRecipe.likesCount}',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.grey.shade800,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    height: 30,
                                    width: 1,
                                    color: Colors.grey.shade300,
                                  ),
                                  Opacity(
                                    opacity: widget.recipe.status == RecipeStatus.rejected ? 0.5 : 1.0,
                                    child: Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.comment_outlined,
                                            color: Colors.grey.shade600,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '${_comments.length}',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey.shade800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Nutrition info
                  Text(
                    'Пищевая ценность на 100г',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.purple.shade100),
                    ),
                    child: Column(
                      children: [
                        _NutritionRow(
                          label: 'Фенилаланин',
                          value: '${widget.recipe.phePer100g.toStringAsFixed(0)} мг',
                          color: Colors.purple,
                          isHighlighted: true,
                        ),
                        const SizedBox(height: 12),
                        _NutritionRow(
                          label: 'Белок',
                          value: '${widget.recipe.proteinPer100g.toStringAsFixed(1)} г',
                          color: Colors.blue,
                          isHighlighted: true,
                        ),
                        if (widget.recipe.fatPer100g != null) ...[
                          const SizedBox(height: 8),
                          _NutritionRow(
                            label: 'Жиры',
                            value: '${widget.recipe.fatPer100g!.toStringAsFixed(1)} г',
                            color: Colors.amber,
                          ),
                        ],
                        if (widget.recipe.carbsPer100g != null) ...[
                          const SizedBox(height: 8),
                          _NutritionRow(
                            label: 'Углеводы',
                            value: '${widget.recipe.carbsPer100g!.toStringAsFixed(1)} г',
                            color: Colors.green,
                          ),
                        ],
                        if (widget.recipe.caloriesPer100g != null) ...[
                          const SizedBox(height: 8),
                          _NutritionRow(
                            label: 'Калории',
                            value: '${widget.recipe.caloriesPer100g!.toStringAsFixed(0)} ккал',
                            color: Colors.orange,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Ingredients
                  Text(
                    'Ингредиенты',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  ...widget.recipe.ingredients.asMap().entries.map((entry) {
                    final index = entry.key;
                    final ingredient = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontSize: 13,
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
                  const SizedBox(height: 28),

                  // Instructions with Photos
                  Text(
                    'Приготовление',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  ...widget.recipe.recipeSteps.asMap().entries.map((entry) {
                    final index = entry.key;
                    final step = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Step header
                          Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
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
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Шаг ${index + 1}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: color,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          
                          // Step photo if available
                          if (step.imageUrl != null) ...[
                            GestureDetector(
                              onTap: () {
                                _showFullImage(context, step.imageUrl!);
                              },
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  step.imageUrl!,
                                  width: double.infinity,
                                  height: 200,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      width: double.infinity,
                                      height: 200,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        Icons.image_not_supported,
                                        color: Colors.grey.shade400,
                                        size: 48,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          
                          // Step instruction
                          Text(
                            step.instruction,
                            style: const TextStyle(fontSize: 15, height: 1.6),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 12),

                  // Comments section
                  const Divider(height: 32),
                  Row(
                    children: [
                      Text(
                        'Комментарии',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      if (_comments.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_comments.length}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Show notice if recipe is rejected
                  if (widget.recipe.status == RecipeStatus.rejected) ...[
                    Card(
                      elevation: 0,
                      color: Colors.red.shade50,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.red.shade700),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Этот рецепт отклонен. Лайки и комментарии отключены.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.red.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Add comment field - only show if recipe is not rejected
                  if (widget.recipe.status != RecipeStatus.rejected) ...[
                    Card(
                      elevation: 0,
                      color: Colors.grey.shade50,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_replyingToCommentId != null) ...[
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.reply, size: 16, color: color),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Ответ для $_replyingToAuthorName',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: color,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close, size: 18),
                                      onPressed: () {
                                        setState(() {
                                          _replyingToCommentId = null;
                                          _replyingToAuthorName = null;
                                        });
                                      },
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            TextField(
                              controller: _commentController,
                              maxLines: 2,
                              decoration: InputDecoration(
                                hintText: 'Написать комментарий...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                contentPadding: const EdgeInsets.all(12),
                                suffixIcon: IconButton(
                                  onPressed: _addComment,
                                  icon: Icon(Icons.send, color: color),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Comments list
                  if (_isLoadingComments)
                    const Center(child: CircularProgressIndicator())
                  else if (_comments.isEmpty)
                    Card(
                      elevation: 0,
                      color: Colors.grey.shade50,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            'Пока нет комментариев.\nБудьте первым!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    ..._buildCommentTree(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultCover(Color color) {
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
          size: 80,
          color: Colors.white.withOpacity(0.9),
        ),
      ),
    );
  }

  List<Widget> _buildCommentTree() {
    final topLevelComments = _comments.where((c) => c.parentCommentId == null).toList();
    final widgets = <Widget>[];
    
    for (final comment in topLevelComments) {
      widgets.add(_buildCommentCard(comment, 0));
      final replies = _comments.where((c) => c.parentCommentId == comment.id).toList();
      for (final reply in replies) {
        widgets.add(_buildCommentCard(reply, 1));
      }
    }
    
    return widgets;
  }

  Widget _buildCommentCard(RecipeComment comment, int level) {
    final color = _getCategoryColor();
    final isAuthor = comment.authorId == widget.recipe.authorId;
    
    return Padding(
      padding: EdgeInsets.only(
        left: level * 32.0,
        bottom: 8,
      ),
      child: Card(
        elevation: level == 0 ? 0 : 0,
        color: level == 0 ? Colors.white : Colors.grey.shade50,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: color.withOpacity(0.2),
                    radius: 16,
                    child: Icon(Icons.person, color: color, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              comment.authorName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            if (isAuthor) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Автор',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatDate(comment.createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                comment.text,
                style: const TextStyle(fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (level == 0)
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _replyingToCommentId = comment.id;
                          _replyingToAuthorName = comment.authorName;
                        });
                      },
                      icon: Icon(Icons.reply, size: 16, color: color),
                      label: Text(
                        'Ответить',
                        style: TextStyle(fontSize: 12, color: color),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        if (diff.inMinutes == 0) {
          return 'только что';
        }
        return '${diff.inMinutes} мин назад';
      }
      return '${diff.inHours} ч назад';
    } else if (diff.inDays == 1) {
      return 'вчера';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} дн назад';
    } else {
      return '${date.day}.${date.month}.${date.year}';
    }
  }

  void _showFullImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                panEnabled: true,
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Icon(
                        Icons.error_outline,
                        color: Colors.white,
                        size: 48,
                      ),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 32),
                onPressed: () => Navigator.pop(context),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _CompactInfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
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
              fontSize: isHighlighted ? 15 : 14,
              fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isHighlighted ? 16 : 15,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
