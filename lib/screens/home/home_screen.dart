import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/user_provider.dart';
import '../../providers/diary_provider.dart';
import '../../models/diary_entry.dart';
import '../products/product_selection_screen.dart';
import '../products/add_custom_product_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // По умолчанию 3 основных приема пищи
  final Set<MealType> _visibleMeals = {
    MealType.breakfast,
    MealType.lunch,
    MealType.dinner,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<UserProvider>(context, listen: false).loadUserProfile();
      // По умолчанию загружаем сегодняшний день
      Provider.of<DiaryProvider>(context, listen: false).loadEntriesForDate(DateTime.now());
    });
  }

  Future<void> _selectDate() async {
    final diaryProvider = Provider.of<DiaryProvider>(context, listen: false);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: diaryProvider.selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('ru'),
    );
    if (picked != null) {
      diaryProvider.setSelectedDate(picked);
    }
  }

  void _showMonthlyStats() async {
    final diaryProvider = Provider.of<DiaryProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    
    final now = DateTime.now();
    final stats = await diaryProvider.getMonthlyStats(now.year, now.month);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Статистика за ${DateFormat.MMMM('ru').format(now)}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatRow(
              label: 'Всего Phe',
              value: '${stats['totalPhe']?.toStringAsFixed(0) ?? '0'} мг',
            ),
            _StatRow(
              label: 'Средний Phe в день',
              value: '${stats['avgPhePerDay']?.toStringAsFixed(0) ?? '0'} мг',
            ),
            const Divider(),
            _StatRow(
              label: 'Всего белка',
              value: '${stats['totalProtein']?.toStringAsFixed(1) ?? '0'} г',
            ),
            _StatRow(
              label: 'Средний белок в день',
              value: '${stats['avgProteinPerDay']?.toStringAsFixed(1) ?? '0'} г',
            ),
            const Divider(),
            _StatRow(
              label: 'Всего калорий',
              value: '${stats['totalCalories']?.toStringAsFixed(0) ?? '0'} ккал',
            ),
            _StatRow(
              label: 'Средние калории в день',
              value: '${stats['avgCaloriesPerDay']?.toStringAsFixed(0) ?? '0'} ккал',
            ),
            if (userProvider.userProfile != null) ...[
              const Divider(),
              _StatRow(
                label: 'Дневной лимит Phe',
                value: '${userProvider.userProfile!.dailyTolerancePhe.toStringAsFixed(0)} мг',
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  void _showAddProductOptions(BuildContext context, MealType mealType) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Добавить в ${mealType.displayName}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.search),
              title: const Text('Выбрать из базы продуктов'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProductSelectionScreen(mealType: mealType),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_circle_outline),
              title: const Text('Добавить свой продукт'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddCustomProductScreen(mealType: mealType),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.qr_code_scanner),
              title: const Text('Сканировать QR код'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Функция в разработке')),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showMealManagementDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Управление приемами пищи'),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: MealType.values.map((meal) {
                final isVisible = _visibleMeals.contains(meal);
                return CheckboxListTile(
                  title: Text(meal.displayName),
                  value: isVisible,
                  onChanged: (value) {
                    setDialogState(() {
                      if (value == true) {
                        _visibleMeals.add(meal);
                      } else {
                        // Не позволяем убрать все приемы пищи
                        if (_visibleMeals.length > 1) {
                          _visibleMeals.remove(meal);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Должен быть хотя бы один прием пищи'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      }
                    });
                  },
                );
              }).toList(),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              setState(() {}); // Обновляем основной экран
              Navigator.pop(context);
            },
            child: const Text('Применить'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Дневник питания'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: _showMealManagementDialog,
            tooltip: 'Управление приемами пищи',
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: _showMonthlyStats,
            tooltip: 'Месячная статистика',
          ),
        ],
      ),
      body: Consumer2<UserProvider, DiaryProvider>(
        builder: (context, userProvider, diaryProvider, child) {
          final profile = userProvider.userProfile;

          if (profile == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: () async {
              await diaryProvider.loadEntriesForDate(diaryProvider.selectedDate);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  // Date Selector
                  Container(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: () {
                            final newDate = diaryProvider.selectedDate.subtract(const Duration(days: 1));
                            diaryProvider.setSelectedDate(newDate);
                          },
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: _selectDate,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 20,
                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _isToday(diaryProvider.selectedDate)
                                      ? 'Сегодня'
                                      : DateFormat('d MMMM, yyyy', 'ru').format(diaryProvider.selectedDate),
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: _isToday(diaryProvider.selectedDate)
                              ? null
                              : () {
                                  final newDate = diaryProvider.selectedDate.add(const Duration(days: 1));
                                  if (!newDate.isAfter(DateTime.now())) {
                                    diaryProvider.setSelectedDate(newDate);
                                  }
                                },
                        ),
                      ],
                    ),
                  ),

                  // Progress Indicator
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: _DailyProgressCard(
                      currentPhe: diaryProvider.totalPheToday,
                      limitPhe: profile.dailyTolerancePhe,
                      protein: diaryProvider.totalProteinToday,
                      calories: diaryProvider.totalCaloriesToday,
                    ),
                  ),

                  // Meals Section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      children: [
                        // Показываем только выбранные приемы пищи
                        ..._visibleMeals.map((mealType) => Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _MealSection(
                                mealType: mealType,
                                entries: diaryProvider.getEntriesForMeal(mealType),
                                onAddPressed: () => _showAddProductOptions(context, mealType),
                                onDeleteEntry: (entryId) => diaryProvider.deleteEntry(entryId),
                              ),
                            )),
                        
                        const SizedBox(height: 16),
                        
                        // Кнопка добавить прием пищи (если не все показаны)
                        if (_visibleMeals.length < MealType.values.length)
                          OutlinedButton.icon(
                            onPressed: _showMealManagementDialog,
                            icon: const Icon(Icons.add),
                            label: const Text('Добавить прием пищи'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                            ),
                          ),
                        
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// Daily Progress Card Widget
class _DailyProgressCard extends StatelessWidget {
  final double currentPhe;
  final double limitPhe;
  final double protein;
  final double calories;

  const _DailyProgressCard({
    required this.currentPhe,
    required this.limitPhe,
    required this.protein,
    required this.calories,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (currentPhe / limitPhe).clamp(0.0, 1.0);
    final remaining = limitPhe - currentPhe;

    Color progressColor;
    if (progress < 0.5) {
      progressColor = Colors.green;
    } else if (progress < 0.8) {
      progressColor = Colors.orange;
    } else {
      progressColor = Colors.red;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Circular Progress
            SizedBox(
              height: 160,
              width: 160,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    height: 160,
                    width: 160,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 12,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${currentPhe.toStringAsFixed(0)}',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: progressColor,
                            ),
                      ),
                      Text(
                        'из ${limitPhe.toStringAsFixed(0)} мг',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${(progress * 100).toStringAsFixed(0)}%',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Stats Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(
                  label: 'Осталось',
                  value: remaining > 0 ? '${remaining.toStringAsFixed(0)}' : '0',
                  unit: 'мг',
                  color: progressColor,
                ),
                _StatItem(
                  label: 'Белок',
                  value: protein.toStringAsFixed(1),
                  unit: 'г',
                  color: Colors.blue,
                ),
                _StatItem(
                  label: 'Калории',
                  value: calories.toStringAsFixed(0),
                  unit: 'ккал',
                  color: Colors.purple,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Stat Item Widget
class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
        Text(
          unit,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

// Meal Section Widget
class _MealSection extends StatelessWidget {
  final MealType mealType;
  final List<DiaryEntry> entries;
  final VoidCallback onAddPressed;
  final Function(String) onDeleteEntry;

  const _MealSection({
    required this.mealType,
    required this.entries,
    required this.onAddPressed,
    required this.onDeleteEntry,
  });

  IconData _getMealIcon() {
    switch (mealType) {
      case MealType.breakfast:
        return Icons.wb_sunny_outlined;
      case MealType.lunch:
        return Icons.wb_cloudy_outlined;
      case MealType.dinner:
        return Icons.nightlight_outlined;
      case MealType.snack:
        return Icons.local_cafe_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalPhe = entries.fold(0.0, (sum, entry) => sum + entry.pheInPortion);
    final totalProtein = entries.fold(0.0, (sum, entry) => sum + entry.proteinInPortion);

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(_getMealIcon(), color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mealType.displayName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      if (entries.isNotEmpty)
                        Text(
                          'Phe: ${totalPhe.toStringAsFixed(0)} мг • Белок: ${totalProtein.toStringAsFixed(1)} г',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: onAddPressed,
                  tooltip: 'Добавить продукт',
                ),
              ],
            ),
          ),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                'Нет продуктов',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else
            ...entries.map((entry) => _EntryTile(
                  entry: entry,
                  onDelete: () => onDeleteEntry(entry.id),
                )),
        ],
      ),
    );
  }
}

// Entry Tile Widget
class _EntryTile extends StatelessWidget {
  final DiaryEntry entry;
  final VoidCallback onDelete;

  const _EntryTile({
    required this.entry,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Удалить запись?'),
            content: Text('Удалить "${entry.productName}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Отмена'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Удалить'),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) => onDelete(),
      child: ListTile(
        title: Text(entry.productName),
        subtitle: Text(
          '${entry.portionG.toStringAsFixed(0)} г • Phe: ${entry.pheInPortion.toStringAsFixed(0)} мг',
        ),
        trailing: Text(
          '${entry.proteinInPortion.toStringAsFixed(1)} г',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ),
    );
  }
}

// Stat Row Widget for Dialog
class _StatRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}