// lib/screens/admin/products_moderation_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/admin_provider.dart';
import '../../models/pending_product.dart';

class ProductsModerationTab extends StatefulWidget {
  const ProductsModerationTab({super.key});

  @override
  State<ProductsModerationTab> createState() => _ProductsModerationTabState();
}

class _ProductsModerationTabState extends State<ProductsModerationTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AdminProvider>(context, listen: false).loadPendingProducts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminProvider>(
      builder: (context, adminProvider, child) {
        if (adminProvider.isLoadingProducts) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Загрузка продуктов на модерацию...'),
              ],
            ),
          );
        }

        if (adminProvider.pendingProducts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, size: 64, color: Colors.green.shade300),
                const SizedBox(height: 16),
                const Text(
                  'Нет продуктов на проверке',
                  style: TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  'Все продукты обработаны',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => adminProvider.loadPendingProducts(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Обновить'),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => adminProvider.loadPendingProducts(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: adminProvider.pendingProducts.length,
            itemBuilder: (context, index) {
              final product = adminProvider.pendingProducts[index];
              return _ProductModerationCard(
                product: product,
                onApprove: () => _showApproveDialog(context, product),
                onReject: () => _showRejectDialog(context, product),
                onEdit: () => _showEditDialog(context, product),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _showApproveDialog(BuildContext context, PendingProduct product) async {
    final notesController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Одобрить продукт?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Продукт "${product.name}" будет добавлен в общую базу.'),
            const SizedBox(height: 16),
            if (product.isPheCalculated)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.amber.shade900, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Phe был рассчитан автоматически',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Заметки (опционально)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
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
            child: const Text('Одобрить'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      try {
        await Provider.of<AdminProvider>(context, listen: false).approveProduct(
          product.id,
          adminNotes: notesController.text.isNotEmpty ? notesController.text : null,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Продукт "${product.name}" одобрен'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ошибка: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _showRejectDialog(BuildContext context, PendingProduct product) async {
    final reasonController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Отклонить продукт?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Продукт "${product.name}" будет отклонен.'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Причина отклонения *',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              if (reasonController.text.trim().isNotEmpty) {
                Navigator.pop(context, true);
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Отклонить'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      try {
        await Provider.of<AdminProvider>(context, listen: false).rejectProduct(
          product.id,
          reasonController.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Продукт "${product.name}" отклонен'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ошибка: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _showEditDialog(BuildContext context, PendingProduct product) async {
    final nameController = TextEditingController(text: product.name);
    final proteinController = TextEditingController(text: product.proteinPer100g.toStringAsFixed(1));
    final pheController = TextEditingController(text: product.pheToUse.toStringAsFixed(1));
    final fatController = TextEditingController(text: product.fatPer100g?.toStringAsFixed(1) ?? '');
    final carbsController = TextEditingController(text: product.carbsPer100g?.toStringAsFixed(1) ?? '');
    final caloriesController = TextEditingController(text: product.caloriesPer100g?.toStringAsFixed(1) ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Редактировать продукт'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Название',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: proteinController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Белок (на 100г)',
                  suffixText: 'г',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pheController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
                ],
                decoration: InputDecoration(
                  labelText: 'Фенилаланин (на 100г)',
                  suffixText: 'мг',
                  border: const OutlineInputBorder(),
                  helperText: product.isPheCalculated ? 'Был рассчитан автоматически' : null,
                  helperStyle: TextStyle(color: Colors.orange.shade700),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: fatController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Жиры (на 100г)',
                  suffixText: 'г',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: carbsController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Углеводы (на 100г)',
                  suffixText: 'г',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: caloriesController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Калории (на 100г)',
                  suffixText: 'ккал',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      try {
        final updatedProduct = product.copyWith(
          name: nameController.text.trim(),
          proteinPer100g: double.tryParse(proteinController.text) ?? product.proteinPer100g,
          pheEstimatedPer100g: double.tryParse(pheController.text) ?? product.pheEstimatedPer100g,
          pheMeasuredPer100g: double.tryParse(pheController.text), // Admin edited, so it's now measured
          isPheCalculated: false, // Admin verified/edited
          fatPer100g: fatController.text.isNotEmpty ? double.tryParse(fatController.text) : null,
          carbsPer100g: carbsController.text.isNotEmpty ? double.tryParse(carbsController.text) : null,
          caloriesPer100g: caloriesController.text.isNotEmpty ? double.tryParse(caloriesController.text) : null,
        );

        await Provider.of<AdminProvider>(context, listen: false).updatePendingProduct(updatedProduct);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Продукт обновлен'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ошибка: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

class _ProductModerationCard extends StatelessWidget {
  final PendingProduct product;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onEdit;

  const _ProductModerationCard({
    required this.product,
    required this.onApprove,
    required this.onReject,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: product.action == PendingProductAction.add
                                  ? Colors.green.shade100
                                  : Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              product.actionDisplayName,
                              style: TextStyle(
                                fontSize: 11,
                                color: product.action == PendingProductAction.add
                                    ? Colors.green.shade900
                                    : Colors.blue.shade900,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'от ${product.userName}',
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
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit),
                  tooltip: 'Редактировать',
                ),
              ],
            ),
          ),

          // Phe warning
          if (product.isPheCalculated)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.amber.shade50,
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.amber.shade900, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Phe рассчитан автоматически (${product.proteinPer100g.toStringAsFixed(1)}г белка × 50 = ${product.pheToUse.toStringAsFixed(0)}мг)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Nutrition info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(label: 'Белок', value: '${product.proteinPer100g.toStringAsFixed(1)} г'),
                _InfoRow(
                  label: 'Фенилаланин',
                  value: '${product.pheToUse.toStringAsFixed(1)} мг',
                  hasWarning: product.isPheCalculated,
                ),
                if (product.fatPer100g != null)
                  _InfoRow(label: 'Жиры', value: '${product.fatPer100g!.toStringAsFixed(1)} г'),
                if (product.carbsPer100g != null)
                  _InfoRow(label: 'Углеводы', value: '${product.carbsPer100g!.toStringAsFixed(1)} г'),
                if (product.caloriesPer100g != null)
                  _InfoRow(label: 'Калории', value: '${product.caloriesPer100g!.toStringAsFixed(0)} ккал'),
                if (product.barcode != null) ...[
                  const Divider(),
                  _InfoRow(label: 'Штрих-код', value: product.barcode!, isMono: true),
                ],
                if (product.notes != null && product.notes!.isNotEmpty) ...[
                  const Divider(),
                  Text(
                    'Заметки: ${product.notes}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Actions
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Отклонить'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Одобрить'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool hasWarning;
  final bool isMono;

  const _InfoRow({
    required this.label,
    required this.value,
    this.hasWarning = false,
    this.isMono = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
                ),
                if (hasWarning) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.warning_amber, size: 14, color: Colors.orange.shade700),
                ],
              ],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              fontFamily: isMono ? 'monospace' : null,
            ),
          ),
        ],
      ),
    );
  }
}
