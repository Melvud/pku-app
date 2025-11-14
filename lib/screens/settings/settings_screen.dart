import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';
import '../../providers/auth_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки'),
      ),
      body: Consumer<UserProvider>(
        builder: (context, userProvider, child) {
          final profile = userProvider.userProfile;
          
          return ListView(
            children: [
              // Profile Section
              if (profile != null)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            child: Text(
                              profile.name?.substring(0, 1).toUpperCase() ?? 
                              profile.email.substring(0, 1).toUpperCase(),
                              style: const TextStyle(fontSize: 32),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            profile.name ?? 'Пользователь',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            profile.email,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Settings
              _SettingsSection(
                title: 'Профиль',
                children: [
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: const Text('Редактировать профиль'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {},
                  ),
                  ListTile(
                    leading: const Icon(Icons.medical_information_outlined),
                    title: const Text('Медицинские данные'),
                    subtitle: Text('Лимит: ${profile?.dailyTolerancePhe.toStringAsFixed(0)} мг/день'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {},
                  ),
                ],
              ),

              _SettingsSection(
                title: 'Приложение',
                children: [
                  ListTile(
                    leading: const Icon(Icons.notifications_outlined),
                    title: const Text('Уведомления'),
                    trailing: Switch(
                      value: true,
                      onChanged: (value) {},
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.language),
                    title: const Text('Язык'),
                    subtitle: const Text('Русский'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {},
                  ),
                  ListTile(
                    leading: const Icon(Icons.cloud_outlined),
                    title: const Text('Синхронизация'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {},
                  ),
                ],
              ),

              _SettingsSection(
                title: 'Информация',
                children: [
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('О приложении'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {},
                  ),
                  ListTile(
                    leading: const Icon(Icons.help_outline),
                    title: const Text('Справка'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {},
                  ),
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: const Text('Политика конфиденциальности'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {},
                  ),
                ],
              ),

              _SettingsSection(
                title: 'Аккаунт',
                children: [
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text(
                      'Выйти',
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () async {
                      await AuthService.logout();
                      final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
                      await authProvider.logout();
                      if (context.mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (context) => const LoginScreen(),
                          ),
                          (route) => false,
                        );
                      }
                    },
                  ),
                ],
              ),

              const SizedBox(height: 16),
              Center(
                child: Text(
                  'PheTracker v1.0.0',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(children: children),
        ),
      ],
    );
  }
}