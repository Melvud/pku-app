import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/admin_provider.dart';
import 'statistics_tab.dart';
import 'recipes_approval_tab.dart';
import 'recommended_recipes_tab.dart';
import 'articles_management_tab.dart';
import 'comments_moderation_tab.dart';
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
    _tabController = TabController(length: 5, vsync: this);
    
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
        ],
      ),
      floatingActionButton: _tabController.index == 2
          ? FloatingActionButton.extended(
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
}
