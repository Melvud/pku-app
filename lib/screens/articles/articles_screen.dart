import 'package:flutter/material.dart';

class ArticlesScreen extends StatelessWidget {
  const ArticlesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Статьи о ФКУ'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ArticleCard(
            title: 'Что такое фенилкетонурия?',
            description: 'Основная информация о заболевании',
            icon: Icons.info_outline,
            onTap: () {},
          ),
          _ArticleCard(
            title: 'Диета при ФКУ',
            description: 'Рекомендации по питанию',
            icon: Icons.restaurant_menu,
            onTap: () {},
          ),
          _ArticleCard(
            title: 'Лечебные смеси',
            description: 'Виды и применение',
            icon: Icons.medical_services_outlined,
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _ArticleCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  const _ArticleCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(icon),
        ),
        title: Text(title),
        subtitle: Text(description),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}