import 'package:flutter/material.dart';
import '../../services/usda_sync_service.dart';

class USDASyncScreen extends StatefulWidget {
  const USDASyncScreen({super.key});

  @override
  State<USDASyncScreen> createState() => _USDASyncScreenState();
}

class _USDASyncScreenState extends State<USDASyncScreen> {
  final USDASyncService _syncService = USDASyncService();
  bool _isSyncing = false;
  String _status = '';
  double _progress = 0.0;
  int _selectedCount = 10000;

  final List<int> _productCounts = [
    1000,
    5000,
    10000,
    25000,
    50000,
    100000,
  ];

  Future<void> _startSync() async {
    setState(() {
      _isSyncing = true;
      _status = 'Начинаем синхронизацию...';
      _progress = 0.0;
    });

    try {
      final success = await _syncService.syncToGoogleSheets(
        maxProducts: _selectedCount,
        onProgress: (current, total, status) {
          setState(() {
            _progress = current / total;
            _status = status;
          });
        },
      );

      setState(() {
        _isSyncing = false;
        _status = success
            ? '✅ Синхронизация завершена успешно!'
            : '❌ Синхронизация не удалась';
        _progress = success ? 1.0 : 0.0;
      });

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Данные успешно загружены в Google Sheets!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isSyncing = false;
        _status = '❌ Ошибка: $e';
        _progress = 0.0;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка синхронизации: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Синхронизация USDA'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Информация',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Этот экран позволяет загрузить продукты из базы данных USDA FoodData Central в Google Sheets.',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'После загрузки данные будут автоматически синхронизированы с приложением.',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Загрузка большого количества продуктов может занять несколько минут',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Количество продуктов',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _productCounts.map((count) {
                final isSelected = _selectedCount == count;
                return ChoiceChip(
                  label: Text('${count ~/ 1000}K'),
                  selected: isSelected,
                  onSelected: _isSyncing
                      ? null
                      : (selected) {
                          if (selected) {
                            setState(() => _selectedCount = count);
                          }
                        },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            if (_isSyncing) ...[
              LinearProgressIndicator(
                value: _progress,
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
              ),
              const SizedBox(height: 16),
              Text(
                _status,
                style: const TextStyle(fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                '${(_progress * 100).toStringAsFixed(0)}%',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                textAlign: TextAlign.center,
              ),
            ] else if (_status.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _status.startsWith('✅')
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _status.startsWith('✅')
                        ? Colors.green.shade300
                        : Colors.red.shade300,
                  ),
                ),
                child: Text(
                  _status,
                  style: TextStyle(
                    fontSize: 14,
                    color: _status.startsWith('✅')
                        ? Colors.green.shade900
                        : Colors.red.shade900,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _isSyncing ? null : _startSync,
              icon: _isSyncing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Icon(Icons.cloud_download),
              label: Text(_isSyncing ? 'Загрузка...' : 'Начать синхронизацию'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
