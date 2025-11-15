import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/admin_provider.dart';
import '../../models/recipe_comment.dart';

class CommentsModerationTab extends StatelessWidget {
  const CommentsModerationTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminProvider>(
      builder: (context, adminProvider, child) {
        if (adminProvider.isLoadingComments) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Загрузка комментариев...'),
              ],
            ),
          );
        }

        final allComments = adminProvider.allComments;

        if (allComments.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.comment_outlined,
                  size: 80,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  'Нет комментариев',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Комментарии появятся здесь',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () => adminProvider.loadPendingComments(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Обновить'),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => adminProvider.loadPendingComments(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: allComments.length,
            itemBuilder: (context, index) {
              final comment = allComments[index];
              return _CommentCard(
                comment: comment,
                onApprove: () => _approveComment(context, comment),
                onReject: () => _rejectComment(context, comment),
                onReview: () => _reviewComment(context, comment),
                onDelete: () => _deleteComment(context, comment),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _reviewComment(BuildContext context, RecipeComment comment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Отметить как просмотренное?'),
        content: Text(
          'Комментарий от "${comment.authorName}" будет помечен как просмотренный и останется в общем доступе, но будет убран из модерации.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.blue,
            ),
            child: const Text('Просмотрено'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      try {
        await Provider.of<AdminProvider>(context, listen: false)
            .reviewComment(comment.id);
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Комментарий помечен как просмотренный'),
              backgroundColor: Colors.blue,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
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
  }

  Future<void> _approveComment(BuildContext context, RecipeComment comment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Одобрить комментарий?'),
        content: Text(
          'Комментарий от "${comment.authorName}" будет опубликован.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Одобрить'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      try {
        await Provider.of<AdminProvider>(context, listen: false)
            .approveComment(comment.id);
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Комментарий одобрен'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
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
  }

  Future<void> _rejectComment(BuildContext context, RecipeComment comment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Отклонить комментарий?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('От: ${comment.authorName}'),
            const SizedBox(height: 8),
            Text('Текст: "${comment.text}"'),
            const SizedBox(height: 16),
            const Text(
              'Комментарий будет скрыт и не будет опубликован.',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('Отклонить'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      try {
        await Provider.of<AdminProvider>(context, listen: false)
            .rejectComment(comment.id);
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Комментарий отклонен'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
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
  }

  Future<void> _deleteComment(BuildContext context, RecipeComment comment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить комментарий?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('От: ${comment.authorName}'),
            const SizedBox(height: 8),
            Text('Текст: "${comment.text}"'),
            const SizedBox(height: 16),
            const Text(
              'Это действие нельзя отменить. Комментарий будет удален навсегда.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      try {
        await Provider.of<AdminProvider>(context, listen: false)
            .deleteComment(comment.id);
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Комментарий удален'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
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
  }
}

class _CommentCard extends StatefulWidget {
  final RecipeComment comment;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onReview;
  final VoidCallback onDelete;

  const _CommentCard({
    required this.comment,
    required this.onApprove,
    required this.onReject,
    required this.onReview,
    required this.onDelete,
  });

  @override
  State<_CommentCard> createState() => _CommentCardState();
}

class _CommentCardState extends State<_CommentCard> {
  String _recipeName = '';
  bool _isLoadingRecipe = true;

  @override
  void initState() {
    super.initState();
    _loadRecipeName();
  }

  Future<void> _loadRecipeName() async {
    try {
      final recipeDoc = await FirebaseFirestore.instance
          .collection('recipes')
          .doc(widget.comment.recipeId)
          .get();
      
      if (recipeDoc.exists && mounted) {
        setState(() {
          _recipeName = recipeDoc.data()?['name'] ?? 'Неизвестный рецепт';
          _isLoadingRecipe = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _recipeName = 'Ошибка загрузки';
          _isLoadingRecipe = false;
        });
      }
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd.MM.yyyy HH:mm').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Compact Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: widget.comment.status == CommentStatus.approved
                  ? Colors.green.shade50
                  : widget.comment.status == CommentStatus.pending
                      ? Colors.amber.shade50
                      : widget.comment.status == CommentStatus.reviewed
                          ? Colors.blue.shade50
                          : Colors.red.shade50,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.person,
                  size: 18,
                  color: Colors.grey.shade700,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.comment.authorName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDate(widget.comment.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: widget.comment.status == CommentStatus.approved
                        ? Colors.green.shade100
                        : widget.comment.status == CommentStatus.pending
                            ? Colors.amber.shade100
                            : widget.comment.status == CommentStatus.reviewed
                                ? Colors.blue.shade100
                                : Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.comment.status.displayName,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: widget.comment.status == CommentStatus.approved
                          ? Colors.green.shade800
                          : widget.comment.status == CommentStatus.pending
                              ? Colors.amber.shade800
                              : widget.comment.status == CommentStatus.reviewed
                                  ? Colors.blue.shade800
                                  : Colors.red.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Recipe name (compact)
                if (!_isLoadingRecipe)
                  Row(
                    children: [
                      Icon(
                        Icons.restaurant_menu,
                        size: 14,
                        color: Colors.blue.shade700,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _recipeName,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 8),

                // Comment text
                Text(
                  widget.comment.text,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade800,
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Action buttons
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                if (widget.comment.status == CommentStatus.pending) ...[
                  Expanded(
                    child: TextButton.icon(
                      onPressed: widget.onReject,
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Отклонить', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.orange,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: widget.onReview,
                      icon: const Icon(Icons.visibility, size: 16),
                      label: const Text('Просмотрено', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: widget.onApprove,
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Одобрить', style: TextStyle(fontSize: 12)),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ],
                if (widget.comment.status != CommentStatus.pending) ...[
                  Expanded(
                    child: TextButton.icon(
                      onPressed: widget.onDelete,
                      icon: const Icon(Icons.delete, size: 16),
                      label: const Text('Удалить', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
