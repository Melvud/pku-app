import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import '../../providers/admin_provider.dart';
import '../../models/article.dart';
import 'package:intl/intl.dart';

class ArticlesManagementTab extends StatelessWidget {
  const ArticlesManagementTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminProvider>(
      builder: (context, adminProvider, child) {
        if (adminProvider.isLoadingArticles) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Загрузка статей...'),
              ],
            ),
          );
        }

        final articles = adminProvider.articles;

        return Column(
          children: [
            // Add article button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: FilledButton.icon(
                onPressed: () => _showAddArticleDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('Добавить статью'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ),

            // Articles list
            Expanded(
              child: articles.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.article_outlined,
                            size: 80,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Нет статей',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade600,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Добавьте первую статью',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () => adminProvider.loadArticles(),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: articles.length,
                        itemBuilder: (context, index) {
                          final article = articles[index];
                          return _ArticleCard(
                            article: article,
                            onDelete: () =>
                                _deleteArticle(context, article),
                          );
                        },
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showAddArticleDialog(BuildContext context) async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    File? selectedFile;
    String? fileName;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Добавить статью'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Название статьи',
                    hintText: 'Введите название...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Описание (необязательно)',
                    hintText: 'Краткое описание статьи...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () async {
                    FilePickerResult? result =
                        await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['pdf'],
                    );

                    if (result != null && result.files.single.path != null) {
                      setState(() {
                        selectedFile = File(result.files.single.path!);
                        fileName = result.files.single.name;
                      });
                    }
                  },
                  icon: const Icon(Icons.upload_file),
                  label: Text(
                    fileName ?? 'Выбрать PDF файл',
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
                if (fileName != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle,
                            color: Colors.green.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            fileName!,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.green.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                titleController.dispose();
                descriptionController.dispose();
                Navigator.pop(context);
              },
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () async {
                final title = titleController.text.trim();
                if (title.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Введите название статьи'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                if (selectedFile == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Выберите PDF файл'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                // Сохраняем BuildContext перед async операциями
                final navigator = Navigator.of(context);
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                final adminProvider = Provider.of<AdminProvider>(context, listen: false);
                
                navigator.pop();

                // Показываем диалог загрузки
                UploadTask? uploadTask;
                
                navigator.push(
                  MaterialPageRoute(
                    builder: (dialogContext) => PopScope(
                      canPop: false,
                      child: Scaffold(
                        backgroundColor: Colors.black54,
                        body: Center(
                          child: Card(
                            margin: const EdgeInsets.all(32),
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const CircularProgressIndicator(),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Загрузка файла...',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Не закрывайте это окно',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );

                try {
                  // Upload PDF to Firebase Storage
                  final storageRef = FirebaseStorage.instance
                      .ref()
                      .child('articles')
                      .child('${DateTime.now().millisecondsSinceEpoch}.pdf');
                  
                  // Create and track the upload task
                  uploadTask = storageRef.putFile(selectedFile);
                  
                  // Wait for upload to complete
                  final snapshot = await uploadTask;
                  
                  // Get download URL only after successful upload
                  final pdfUrl = await snapshot.ref.getDownloadURL();

                  // Create article
                  final currentUser = FirebaseAuth.instance.currentUser;
                  final article = Article(
                    id: '',
                    title: title,
                    pdfUrl: pdfUrl,
                    description: descriptionController.text.trim().isEmpty
                        ? null
                        : descriptionController.text.trim(),
                    createdAt: DateTime.now(),
                    createdBy: currentUser?.uid ?? '',
                    createdByName: currentUser?.email ?? 'Админ',
                  );

                  await adminProvider.addArticle(article);

                  // Закрываем диалог загрузки
                  navigator.pop();
                  
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text('Статья успешно добавлена'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } on FirebaseException catch (e) {
                  debugPrint('Firebase error uploading PDF: ${e.code} - ${e.message}');
                  
                  // Безопасно закрываем диалог
                  navigator.pop();
                  
                  String errorMessage = 'Ошибка загрузки файла';
                  if (e.code == 'canceled') {
                    errorMessage = 'Загрузка отменена';
                  } else if (e.code == 'unauthorized') {
                    errorMessage = 'Нет прав для загрузки файла. Проверьте настройки Firebase Storage.';
                  } else if (e.code == 'unknown') {
                    errorMessage = 'Проверьте подключение к интернету';
                  } else if (e.message != null) {
                    errorMessage = 'Ошибка: ${e.message}';
                  }
                  
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text(errorMessage),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 5),
                    ),
                  );
                } catch (e) {
                  debugPrint('Error uploading PDF: $e');
                  
                  // Безопасно закрываем диалог
                  navigator.pop();
                  
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text('Непредвиденная ошибка: $e'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 5),
                    ),
                  );
                } finally {
                  // Clear the upload task reference
                  uploadTask = null;
                }

                titleController.dispose();
                descriptionController.dispose();
              },
              child: const Text('Добавить'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteArticle(BuildContext context, Article article) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить статью?'),
        content: Text('Удалить статью "${article.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      try {
        await Provider.of<AdminProvider>(context, listen: false)
            .deleteArticle(article.id);
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Статья удалена'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ошибка удаления: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }
}

class _ArticleCard extends StatelessWidget {
  final Article article;
  final VoidCallback onDelete;

  const _ArticleCard({
    required this.article,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () {
          // Open PDF viewer (will be implemented in articles screen)
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.picture_as_pdf,
                  color: Theme.of(context).colorScheme.primary,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    if (article.description != null) ...[
                      Text(
                        article.description!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                    ],
                    Row(
                      children: [
                        Icon(
                          Icons.person,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          article.createdByName,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('dd.MM.yyyy').format(article.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
                color: Colors.red,
                tooltip: 'Удалить статью',
              ),
            ],
          ),
        ),
      ),
    );
  }
}