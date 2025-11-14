import 'package:flutter/material.dart';

class RecipesScreen extends StatelessWidget {
  const RecipesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Рецепты'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
        ],
      ),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(16),
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        children: [
          _RecipeCard(
            title: 'Низкобелковый хлеб',
            pheAmount: '15 мг',
            imageIcon: Icons.bakery_dining_outlined,
          ),
          _RecipeCard(
            title: 'Овощной суп',
            pheAmount: '25 мг',
            imageIcon: Icons.soup_kitchen_outlined,
          ),
          _RecipeCard(
            title: 'Фруктовый салат',
            pheAmount: '10 мг',
            imageIcon: Icons.set_meal_outlined,
          ),
        ],
      ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  final String title;
  final String pheAmount;
  final IconData imageIcon;

  const _RecipeCard({
    required this.title,
    required this.pheAmount,
    required this.imageIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {},
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Icon(
                  imageIcon,
                  size: 64,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    pheAmount,
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontSize: 12,
                    ),
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