// lib/screens/home/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/user_provider.dart';
import '../../providers/diary_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/diary_entry.dart';
import '../../models/meal_session.dart';
import '../products/product_selection_screen.dart';
import '../products/add_custom_product_screen.dart';
import '../products/qr_scanner_screen.dart';
import '../statistics/statistics_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // Check if we already have data loaded
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final diaryProvider = Provider.of<DiaryProvider>(context, listen: false);
      
      // If we already have profile and diary entries for today, skip loading
      final hasProfile = userProvider.userProfile != null;
      final today = DateTime.now();
      final hasEntries = diaryProvider.selectedDate.year == today.year &&
                        diaryProvider.selectedDate.month == today.month &&
                        diaryProvider.selectedDate.day == today.day;
      
      if (hasProfile && hasEntries && _isLoading) {
        // Data already loaded, just update UI state
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }
      
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
      final profile = await authProvider.getUserProfile().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('⚠️ Profile loading timeout');
          return null;
        },
      );

      if (profile != null && mounted) {
        userProvider.updateUserProfile(profile);
      }

      if (mounted) {
        await diaryProvider
            .loadEntriesForDate(DateTime.now())
            .timeout(
          const Duration(seconds: 10),
          onTimeout: () => debugPrint('⚠️ Diary loading timeout'),
        );
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('❌ Error loading data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Ошибка загрузки данных. Проверьте подключение к интернету.';
        });
      }
    }
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

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  void _showAddProductOptions(BuildContext context, MealSession session) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Добавить в ${session.displayName}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.search,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                title: const Text('Выбрать из базы продуктов'),
                subtitle: const Text('Поиск по названию'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ProductSelectionScreen(mealType: session.type),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.qr_code_scanner, color: Colors.purple),
                ),
                title: const Text('Сканировать QR-код'),
                subtitle: const Text('Быстрое добавление'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          QRScannerScreen(mealType: session.type),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.add_circle_outline, color: Colors.green),
                ),
                title: const Text('Добавить свой продукт'),
                subtitle: const Text('Ввести данные вручную'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          AddCustomProductScreen(mealType: session.type),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddMealDialog() {
    final TextEditingController nameController = TextEditingController();
    MealType selectedType = MealType.custom;
    TimeOfDay selectedTime = TimeOfDay.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Добавить прием пищи'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Название',
                  hintText: 'Например: Второй завтрак',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<MealType>(
                value: selectedType,
                decoration: const InputDecoration(
                  labelText: 'Тип',
                  border: OutlineInputBorder(),
                ),
                items: MealType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type.displayName),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => selectedType = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Время'),
                subtitle: Text(selectedTime.format(context)),
                leading: const Icon(Icons.access_time),
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: selectedTime,
                  );
                  if (time != null) {
                    setDialogState(() => selectedTime = time);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () async {
                if (nameController.text.isNotEmpty) {
                  final now = DateTime.now();
                  final time = DateTime(
                    now.year,
                    now.month,
                    now.day,
                    selectedTime.hour,
                    selectedTime.minute,
                  );
                  
                  await Provider.of<DiaryProvider>(context, listen: false)
                      .addMealSession(
                    type: selectedType,
                    customName: nameController.text,
                    time: time,
                  );
                  
                  if (mounted) {
                    Navigator.pop(context);
                  }
                }
              },
              child: const Text('Добавить'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editMealTime(MealSession session) async {
    final initialTime = session.time != null
        ? TimeOfDay.fromDateTime(session.time!)
        : TimeOfDay.now();

    final time = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (time != null && mounted) {
      final now = DateTime.now();
      final dateTime = DateTime(
        now.year,
        now.month,
        now.day,
        time.hour,
        time.minute,
      );

      await Provider.of<DiaryProvider>(context, listen: false)
          .updateMealSessionTime(session.id, dateTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Загрузка данных...'),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _loadData,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Повторить'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Consumer2<UserProvider, DiaryProvider>(
        builder: (context, userProvider, diaryProvider, child) {
          final profile = userProvider.userProfile;
          final sessions = diaryProvider.mealSessions;

          return RefreshIndicator(
            onRefresh: _loadData,
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 140,
                  floating: false,
                  pinned: true,
                  elevation: 0,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Theme.of(context).colorScheme.primary,
                            Theme.of(context).colorScheme.secondary,
                          ],
                        ),
                      ),
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Дневник питания',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                profile != null
                                    ? 'Привет, ${profile.name}!'
                                    : 'Добро пожаловать!',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.bar_chart, color: Colors.white),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const StatisticsScreen(),
                          ),
                        );
                      },
                      tooltip: 'Статистика',
                    ),
                  ],
                ),

                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left),
                            onPressed: () {
                              final newDate = diaryProvider.selectedDate
                                  .subtract(const Duration(days: 1));
                              diaryProvider.setSelectedDate(newDate);
                            },
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: _selectDate,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 16,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.calendar_today,
                                      size: 20,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _isToday(diaryProvider.selectedDate)
                                          ? 'Сегодня (${DateFormat('d MMM', 'ru').format(diaryProvider.selectedDate)})'
                                          : DateFormat('d MMMM, yyyy', 'ru')
                                              .format(diaryProvider.selectedDate),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: _isToday(diaryProvider.selectedDate)
                                ? null
                                : () {
                                    final newDate = diaryProvider.selectedDate
                                        .add(const Duration(days: 1));
                                    if (!newDate.isAfter(DateTime.now())) {
                                      diaryProvider.setSelectedDate(newDate);
                                    }
                                  },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _NutritionOverviewCard(
                      calories: diaryProvider.totalCaloriesToday,
                      protein: diaryProvider.totalProteinToday,
                      fat: diaryProvider.totalFatToday,
                      carbs: diaryProvider.totalCarbsToday,
                      phe: diaryProvider.totalPheToday,
                      limitPhe: profile?.dailyTolerancePhe ?? 0,
                    ),
                  ),
                ),

                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index >= sessions.length) {
                          return null;
                        }
                        final session = sessions[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _MealCard(
                            session: session,
                            entries: diaryProvider.getEntriesForMealSession(session.id),
                            mealNumber: index + 1,
                            onAddPressed: () =>
                                _showAddProductOptions(context, session),
                            onDeleteEntry: (entryId) =>
                                diaryProvider.deleteEntry(entryId),
                            onDeleteMeal: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Удалить прием пищи?'),
                                  content: Text(
                                      'Удалить "${session.displayName}"?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Отмена'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.red,
                                      ),
                                      child: const Text('Удалить'),
                                    ),
                                  ],
                                ),
                              );
                              
                              if (confirm == true) {
                                await diaryProvider.removeMealSession(session.id);
                              }
                            },
                            onEditTime: () => _editMealTime(session),
                            onToggleFormula: () => diaryProvider.toggleMealSessionFormula(session.id),
                          ),
                        );
                      },
                      childCount: sessions.length,
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: OutlinedButton.icon(
                      onPressed: _showAddMealDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Добавить прием пищи'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: 80),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _NutritionOverviewCard extends StatelessWidget {
  final double calories;
  final double protein;
  final double fat;
  final double carbs;
  final double phe;
  final double limitPhe;

  const _NutritionOverviewCard({
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbs,
    required this.phe,
    required this.limitPhe,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _MainPheIndicator(current: phe, limit: limitPhe),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NutrientIndicator(
                label: 'Ккал',
                value: calories.toStringAsFixed(0),
                icon: Icons.local_fire_department,
                color: Colors.orange,
              ),
              _NutrientIndicator(
                label: 'Белок',
                value: protein.toStringAsFixed(1),
                unit: 'г',
                icon: Icons.egg,
                color: Colors.blue,
              ),
              _NutrientIndicator(
                label: 'Жир',
                value: fat.toStringAsFixed(1),
                unit: 'г',
                icon: Icons.water_drop,
                color: Colors.amber,
              ),
              _NutrientIndicator(
                label: 'Угл',
                value: carbs.toStringAsFixed(1),
                unit: 'г',
                icon: Icons.grain,
                color: Colors.green,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MainPheIndicator extends StatelessWidget {
  final double current;
  final double limit;

  const _MainPheIndicator({
    required this.current,
    required this.limit,
  });

  @override
  Widget build(BuildContext context) {
    final progress = limit > 0 ? (current / limit).clamp(0.0, 1.0) : 0.0;
    final remaining = limit - current;

    Color color;
    if (progress < 0.5) {
      color = Colors.green;
    } else if (progress < 0.8) {
      color = Colors.orange;
    } else {
      color = Colors.red;
    }

    return Column(
      children: [
        Row(
          children: [
            Text(
              'Фенилаланин (Phe)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const Spacer(),
            Text(
              '${(progress * 100).toStringAsFixed(0)}%',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 24,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${current.toStringAsFixed(0)} мг',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              'Лимит: ${limit.toStringAsFixed(0)} мг',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        if (remaining > 0) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Осталось: ${remaining.toStringAsFixed(0)} мг',
              style: TextStyle(
                fontSize: 13,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _NutrientIndicator extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final IconData icon;
  final Color color;

  const _NutrientIndicator({
    required this.label,
    required this.value,
    this.unit,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          unit != null ? '$value $unit' : value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _MealCard extends StatelessWidget {
  final MealSession session;
  final List<DiaryEntry> entries;
  final int mealNumber;
  final VoidCallback onAddPressed;
  final Function(String) onDeleteEntry;
  final VoidCallback onDeleteMeal;
  final VoidCallback onEditTime;
  final VoidCallback onToggleFormula;

  const _MealCard({
    required this.session,
    required this.entries,
    required this.mealNumber,
    required this.onAddPressed,
    required this.onDeleteEntry,
    required this.onDeleteMeal,
    required this.onEditTime,
    required this.onToggleFormula,
  });

  @override
  Widget build(BuildContext context) {
    final totalPhe = entries.fold(0.0, (sum, entry) => sum + entry.pheInPortion);
    final totalProtein =
        entries.fold(0.0, (sum, entry) => sum + entry.proteinInPortion);
    final color = session.getColor(context);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$mealNumber',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(session.icon, size: 20, color: color),
                          const SizedBox(width: 6),
                          Text(
                            session.displayName,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                      if (session.time != null) ...[
                        const SizedBox(height: 2),
                        InkWell(
                          onTap: onEditTime,
                          child: Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 14,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                TimeOfDay.fromDateTime(session.time!)
                                    .format(context),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (entries.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Phe: ${totalPhe.toStringAsFixed(0)} мг • Белок: ${totalProtein.toStringAsFixed(1)} г',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: onDeleteMeal,
                      icon: const Icon(Icons.delete_outline, size: 20),
                      tooltip: 'Удалить прием',
                      color: Colors.red,
                    ),
                    IconButton(
                      onPressed: onAddPressed,
                      icon: Icon(Icons.add_circle, color: color, size: 28),
                      tooltip: 'Добавить продукт',
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Formula checkbox
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: InkWell(
              onTap: onToggleFormula,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: session.drankFormula 
                      ? color.withOpacity(0.1)
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: session.drankFormula 
                        ? color
                        : Colors.grey.shade300,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      session.drankFormula 
                          ? Icons.check_box 
                          : Icons.check_box_outline_blank,
                      color: session.drankFormula 
                          ? color 
                          : Colors.grey.shade600,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Смесь',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: session.drankFormula 
                              ? FontWeight.w600 
                              : FontWeight.normal,
                          color: session.drankFormula 
                              ? color 
                              : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(
                    Icons.restaurant_menu,
                    size: 48,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Продукты не выбраны',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: entries.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: Colors.grey.shade200,
              ),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return Dismissible(
                  key: Key(entry.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: index == entries.length - 1
                          ? const BorderRadius.vertical(
                              bottom: Radius.circular(20))
                          : null,
                    ),
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
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Отмена'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            child: const Text('Удалить'),
                          ),
                        ],
                      ),
                    );
                  },
                  onDismissed: (direction) => onDeleteEntry(entry.id),
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    title: Text(
                      entry.productName,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      '${entry.portionG.toStringAsFixed(0)} г • Phe: ${entry.pheInPortion.toStringAsFixed(0)} мг',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${entry.proteinInPortion.toStringAsFixed(1)} г',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}