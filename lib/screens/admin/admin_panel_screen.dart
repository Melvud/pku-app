import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/admin_provider.dart';
import 'statistics_tab.dart';
import 'recipes_approval_tab.dart';
import 'recommended_recipes_tab.dart';
import 'articles_management_tab.dart';
import 'comments_moderation_tab.dart';
import 'products_moderation_tab.dart';
import 'add_admin_recipe_screen.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);

    // Listen to tab changes to update FAB
    _tabController.addListener(() {
      setState(() {});
    });

    // Load initial data only if not already loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final adminProvider = Provider.of<AdminProvider>(context, listen: false);

      // Load stats only if empty
      if (adminProvider.appStats.isEmpty) {
        adminProvider.loadAppStats();
      }

      // Load pending recipes only if empty
      if (adminProvider.pendingRecipes.isEmpty) {
        adminProvider.loadPendingRecipes();
      }

      // Load articles only if empty
      if (adminProvider.articles.isEmpty) {
        adminProvider.loadArticles();
      }

      // Load pending comments only if empty
      if (adminProvider.pendingComments.isEmpty) {
        adminProvider.loadPendingComments();
      }

      // Load pending products only if empty
      if (adminProvider.pendingProducts.isEmpty) {
        adminProvider.loadPendingProducts();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Панель администратора'),
        actions: [
          if (_tabController.index == 2)
            IconButton(
              icon: const Icon(Icons.cloud_upload),
              tooltip: 'Загрузить рецепты из JSON',
              onPressed: _loadRecipesFromJSON,
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Theme.of(context).colorScheme.primary,
          indicatorWeight: 3,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
          tabs: const [
            Tab(
              icon: Icon(Icons.bar_chart, size: 18),
              text: 'Статистика',
            ),
            Tab(
              icon: Icon(Icons.restaurant_menu, size: 18),
              text: 'Рецепты',
            ),
            Tab(
              icon: Icon(Icons.star, size: 18),
              text: 'Рекомендации',
            ),
            Tab(
              icon: Icon(Icons.article, size: 18),
              text: 'Статьи',
            ),
            Tab(
              icon: Icon(Icons.comment, size: 18),
              text: 'Комментарии',
            ),
            Tab(
              icon: Icon(Icons.inventory_2, size: 18),
              text: 'Продукты',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          StatisticsTab(),
          RecipesApprovalTab(),
          RecommendedRecipesTab(),
          ArticlesManagementTab(),
          CommentsModerationTab(),
          ProductsModerationTab(),
        ],
      ),
      floatingActionButton: _tabController.index == 2
          ? FloatingActionButton.extended(
              heroTag: 'add_admin_recipe_fab',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddAdminRecipeScreen(),
                  ),
                ).then((_) {
                  // Refresh recommended recipes after adding new one
                  Provider.of<AdminProvider>(context, listen: false)
                      .loadRecommendedRecipes();
                });
              },
              icon: const Icon(Icons.add),
              label: const Text('Создать рецепт'),
              backgroundColor: Colors.amber.shade700,
            )
          : null,
    );
  }

  Future<void> _loadRecipesFromJSON() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Загрузка рецептов'),
        content: const Text(
            'Вы уверены, что хотите загрузить рецепты из JSON файла? Это может занять некоторое время.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Загрузить'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _LoadingDialog(),
    );
  }
}

class _LoadingDialog extends StatefulWidget {
  const _LoadingDialog();

  @override
  State<_LoadingDialog> createState() => _LoadingDialogState();
}

class _LoadingDialogState extends State<_LoadingDialog> {
  String _status = 'Подготовка...';
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _startLoading();
  }

  Future<void> _startLoading() async {
    try {
      final provider = Provider.of<AdminProvider>(context, listen: false);
      await provider.loadRecipesFromJSON(
        onProgress: (status, progress) {
          if (mounted) {
            setState(() {
              _status = status;
              _progress = progress;
            });
          }
        },
      );

      if (mounted) {
        Navigator.pop(context); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Рецепты успешно загружены'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Загрузка рецептов'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_status),
          const SizedBox(height: 16),
          LinearProgressIndicator(value: _progress),
          const SizedBox(height: 8),
          Text('${(_progress * 100).toInt()}%'),
        ],
      ),
    );
  }
}
