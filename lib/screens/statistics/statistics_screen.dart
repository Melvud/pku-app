import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/diary_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/export_service.dart';
import '../../widgets/app_header.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late PageController _monthPageController;
  DateTime _selectedMonth = DateTime.now();
  int _currentMonthIndex = 0;
  bool _isLoading = true;
  Map<String, dynamic>? _stats;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Calculate initial month index (from 2020 to now)
    final startDate = DateTime(2020, 1);
    final monthsDiff = (_selectedMonth.year - startDate.year) * 12 +
                       (_selectedMonth.month - startDate.month);
    _currentMonthIndex = monthsDiff;

    _monthPageController = PageController(initialPage: _currentMonthIndex);
    _loadStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _monthPageController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);

    final diaryProvider = Provider.of<DiaryProvider>(context, listen: false);
    final stats = await diaryProvider.getMonthlyStats(
      _selectedMonth.year,
      _selectedMonth.month,
    );

    setState(() {
      _stats = stats;
      _isLoading = false;
    });
  }

  void _changeMonth(int delta) {
    final newDate = DateTime(_selectedMonth.year, _selectedMonth.month + delta);
    if (newDate.isAfter(DateTime.now())) return;
    if (newDate.year < 2020) return;

    setState(() => _selectedMonth = newDate);
    _loadStats();
  }

  void _onMonthPageChanged(int index) {
    final startDate = DateTime(2020, 1);
    final newDate = DateTime(startDate.year, startDate.month + index);

    if (newDate.isAfter(DateTime.now())) return;

    setState(() {
      _currentMonthIndex = index;
      _selectedMonth = newDate;
    });
    _loadStats();
  }

  Future<void> _showDateRangePickerAndExport(String format) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: DateTime(_selectedMonth.year, _selectedMonth.month, 1),
        end: DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0),
      ),
      locale: const Locale('ru'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).colorScheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      await _exportData(format, picked.start, picked.end);
    }
  }

  Future<void> _exportData(String format, DateTime startDate, DateTime endDate) async {
    try {
      final exportService = ExportService();
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final diaryProvider = Provider.of<DiaryProvider>(context, listen: false);
      final profile = userProvider.userProfile;

      setState(() => _isLoading = true);

      // Get stats for the date range
      final rangeStats = await diaryProvider.getDateRangeStats(startDate, endDate);

      String? filePath;
      if (format == 'pdf') {
        filePath = await exportService.exportToPDFWithRange(
          stats: rangeStats,
          startDate: startDate,
          endDate: endDate,
          userName: profile?.name ?? 'Пользователь',
          dailyLimit: profile?.dailyTolerancePhe ?? 0,
        );
      } else if (format == 'excel') {
        filePath = await exportService.exportToExcelWithRange(
          stats: rangeStats,
          startDate: startDate,
          endDate: endDate,
          userName: profile?.name ?? 'Пользователь',
          dailyLimit: profile?.dailyTolerancePhe ?? 0,
        );
      }

      setState(() => _isLoading = false);

      if (mounted && filePath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Экспортировано: ${filePath.split('/').last}'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка экспорта: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showExportDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
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
              Text(
                'Экспорт статистики',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.picture_as_pdf, color: Colors.red.shade700),
                ),
                title: const Text('Экспорт в PDF'),
                subtitle: const Text('Выберите диапазон дат'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.pop(context);
                  _showDateRangePickerAndExport('pdf');
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.table_chart, color: Colors.green.shade700),
                ),
                title: const Text('Экспорт в Excel'),
                subtitle: const Text('Выберите диапазон дат'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.pop(context);
                  _showDateRangePickerAndExport('excel');
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canGoPrevious = _selectedMonth.year > 2020 ||
                          (_selectedMonth.year == 2020 && _selectedMonth.month > 1);
    final canGoNext = _selectedMonth.isBefore(
      DateTime(DateTime.now().year, DateTime.now().month),
    );

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App Bar with month navigation
          AppHeader(
            title: 'Статистика',
            subtitle: '',
            expandedHeight: 140,
            actions: [
              IconButton(
                icon: const Icon(Icons.file_download, color: Colors.white),
                onPressed: _showExportDialog,
                tooltip: 'Экспорт',
              ),
            ],
            bottom: Container(
              color: Theme.of(context).colorScheme.surface,
              child: Column(
                children: [
                  // Month navigation
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.chevron_left,
                            color: canGoPrevious ? Theme.of(context).colorScheme.primary : Colors.grey,
                          ),
                          onPressed: canGoPrevious ? () => _changeMonth(-1) : null,
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              DateFormat('LLLL yyyy', 'ru').format(_selectedMonth),
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.chevron_right,
                            color: canGoNext ? Theme.of(context).colorScheme.primary : Colors.grey,
                          ),
                          onPressed: canGoNext ? () => _changeMonth(1) : null,
                        ),
                      ],
                    ),
                  ),
                  TabBar(
                    controller: _tabController,
                    labelColor: Theme.of(context).colorScheme.primary,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Theme.of(context).colorScheme.primary,
                    indicatorWeight: 3,
                    labelStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    tabs: const [
                      Tab(text: 'Обзор'),
                      Tab(text: 'По дням'),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Content
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_stats == null)
            const SliverFillRemaining(
              child: Center(child: Text('Нет данных за выбранный месяц')),
            )
          else
            SliverFillRemaining(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _OverviewTab(stats: _stats!),
                  _DailyTab(stats: _stats!, month: _selectedMonth),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// Overview Tab - показывает месячную статистику
class _OverviewTab extends StatelessWidget {
  final Map<String, dynamic> stats;

  const _OverviewTab({required this.stats});

  @override
  Widget build(BuildContext context) {
    final dailyStats = stats['dailyStats'] as List<Map<String, dynamic>>? ?? [];

    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        final profile = userProvider.userProfile;
        final dailyLimit = profile?.dailyTolerancePhe ?? 0;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary Cards Grid
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.3,
                children: [
                  _ModernSummaryCard(
                    title: 'Среднее Phe',
                    value: '${(stats['avgPhePerDay'] ?? 0).toStringAsFixed(0)}',
                    unit: 'мг/день',
                    subtitle: 'Всего: ${(stats['totalPhe'] ?? 0).toStringAsFixed(0)} мг',
                    color: Colors.purple,
                    icon: Icons.medical_information_outlined,
                    progress: dailyLimit > 0 ? ((stats['avgPhePerDay'] ?? 0) / dailyLimit).clamp(0.0, 1.0) : 0.0,
                  ),
                  _ModernSummaryCard(
                    title: 'Активных дней',
                    value: '${stats['activeDays'] ?? 0}',
                    unit: 'дней',
                    subtitle: 'из ${stats['totalDays'] ?? 0} дней',
                    color: Colors.green,
                    icon: Icons.calendar_today_outlined,
                    progress: (stats['totalDays'] ?? 0) > 0
                        ? (stats['activeDays'] ?? 0) / (stats['totalDays'] ?? 1)
                        : 0.0,
                  ),
                  _ModernSummaryCard(
                    title: 'Средний белок',
                    value: '${(stats['avgProteinPerDay'] ?? 0).toStringAsFixed(1)}',
                    unit: 'г/день',
                    subtitle: 'Всего: ${(stats['totalProtein'] ?? 0).toStringAsFixed(1)} г',
                    color: Colors.blue,
                    icon: Icons.egg_outlined,
                  ),
                  _ModernSummaryCard(
                    title: 'Средние калории',
                    value: '${(stats['avgCaloriesPerDay'] ?? 0).toStringAsFixed(0)}',
                    unit: 'ккал/день',
                    subtitle: 'Всего: ${(stats['totalCalories'] ?? 0).toStringAsFixed(0)} ккал',
                    color: Colors.orange,
                    icon: Icons.local_fire_department_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Phe Trend Chart
              _SectionHeader(
                title: 'Динамика Phe за месяц',
                icon: Icons.show_chart,
              ),
              const SizedBox(height: 16),
              _ModernPheChart(dailyStats: dailyStats, dailyLimit: dailyLimit),
              const SizedBox(height: 24),

              // Nutrition Distribution
              _SectionHeader(
                title: 'Распределение БЖУ',
                icon: Icons.pie_chart_outline,
              ),
              const SizedBox(height: 16),
              _ModernNutritionPieChart(stats: stats),
              const SizedBox(height: 24),

              // Weekly comparison
              _SectionHeader(
                title: 'Сравнение по неделям',
                icon: Icons.bar_chart,
              ),
              const SizedBox(height: 16),
              _WeeklyComparisonChart(dailyStats: dailyStats, dailyLimit: dailyLimit),
              const SizedBox(height: 80),
            ],
          ),
        );
      },
    );
  }
}

// Daily Tab - показывает детализацию по дням
class _DailyTab extends StatelessWidget {
  final Map<String, dynamic> stats;
  final DateTime month;

  const _DailyTab({required this.stats, required this.month});

  @override
  Widget build(BuildContext context) {
    final dailyStats = stats['dailyStats'] as List<Map<String, dynamic>>? ?? [];

    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        final profile = userProvider.userProfile;
        final dailyLimit = profile?.dailyTolerancePhe ?? 0;

        if (dailyStats.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.calendar_month_outlined, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'Нет данных за этот месяц',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: dailyStats.length,
          itemBuilder: (context, index) {
            final dayStat = dailyStats[index];
            final day = dayStat['day'] as int;
            final phe = (dayStat['phe'] as num).toDouble();
            final protein = (dayStat['protein'] as num).toDouble();
            final fat = (dayStat['fat'] as num? ?? 0).toDouble();
            final carbs = (dayStat['carbs'] as num? ?? 0).toDouble();
            final calories = (dayStat['calories'] as num).toDouble();
            final entriesCount = dayStat['entriesCount'] as int;

            final date = DateTime(month.year, month.month, day);
            final isToday = _isToday(date);
            final progress = dailyLimit > 0 ? (phe / dailyLimit).clamp(0.0, 1.0) : 0.0;

            Color progressColor;
            if (progress < 0.5) {
              progressColor = Colors.green;
            } else if (progress < 0.8) {
              progressColor = Colors.orange;
            } else {
              progressColor = Colors.red;
            }

            if (entriesCount == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: ListTile(
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '$day',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      DateFormat('EEEE, d MMMM', 'ru').format(date),
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    subtitle: Text(
                      'Нет записей',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: isToday ? progressColor.withOpacity(0.05) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isToday ? progressColor : Colors.grey.shade200,
                    width: isToday ? 2 : 1,
                  ),
                  boxShadow: isToday ? [
                    BoxShadow(
                      color: progressColor.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ] : null,
                ),
                child: Theme(
                  data: Theme.of(context).copyWith(
                    dividerColor: Colors.transparent,
                  ),
                  child: ExpansionTile(
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: progressColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: progressColor, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          '$day',
                          style: TextStyle(
                            color: progressColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            DateFormat('EEEE, d MMMM', 'ru').format(date),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (isToday)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: progressColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Сегодня',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.medical_information, size: 14, color: progressColor),
                            const SizedBox(width: 4),
                            Text(
                              '${phe.toStringAsFixed(0)} мг',
                              style: TextStyle(
                                color: progressColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${(progress * 100).toStringAsFixed(0)}% лимита',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 8,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation(progressColor),
                          ),
                        ),
                      ],
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _MiniStatCard(
                                    icon: Icons.egg_outlined,
                                    label: 'Белок',
                                    value: '${protein.toStringAsFixed(1)} г',
                                    color: Colors.blue,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _MiniStatCard(
                                    icon: Icons.water_drop_outlined,
                                    label: 'Жиры',
                                    value: '${fat.toStringAsFixed(1)} г',
                                    color: Colors.amber,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _MiniStatCard(
                                    icon: Icons.grain_outlined,
                                    label: 'Углеводы',
                                    value: '${carbs.toStringAsFixed(1)} г',
                                    color: Colors.green,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _MiniStatCard(
                                    icon: Icons.local_fire_department_outlined,
                                    label: 'Калории',
                                    value: '${calories.toStringAsFixed(0)} ккал',
                                    color: Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.restaurant, size: 16, color: Colors.grey.shade600),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Записей: $entriesCount',
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }
}

// Modern Summary Card
class _ModernSummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final String subtitle;
  final Color color;
  final IconData icon;
  final double? progress;

  const _ModernSummaryCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.subtitle,
    required this.color,
    required this.icon,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.1),
            color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              if (progress != null)
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 3,
                  backgroundColor: color.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
            ],
          ),
          const Spacer(),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  unit,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// Mini Stat Card for daily details
class _MiniStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MiniStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// Section Header
class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }
}

// Modern Phe Chart with gradient
class _ModernPheChart extends StatelessWidget {
  final List<Map<String, dynamic>> dailyStats;
  final double dailyLimit;

  const _ModernPheChart({required this.dailyStats, required this.dailyLimit});

  @override
  Widget build(BuildContext context) {
    final spots = dailyStats
        .asMap()
        .entries
        .where((entry) => (entry.value['phe'] as num).toDouble() > 0)
        .map((entry) {
      final day = entry.value['day'] as int;
      final phe = (entry.value['phe'] as num).toDouble();
      return FlSpot(day.toDouble(), phe);
    }).toList();

    if (spots.isEmpty) {
      return Container(
        height: 250,
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.show_chart, size: 48, color: Colors.grey),
              SizedBox(height: 8),
              Text('Нет данных для отображения'),
            ],
          ),
        ),
      );
    }

    final maxPhe = spots.map((e) => e.y).reduce((a, b) => a > b ? a : b);
    final maxY = (maxPhe > dailyLimit ? maxPhe : dailyLimit) * 1.2;

    return Container(
      height: 280,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY / 5,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.grey.shade200,
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 45,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 5,
                getTitlesWidget: (value, meta) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      value.toInt().toString(),
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                    ),
                  );
                },
              ),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          minX: 1,
          maxX: dailyStats.length.toDouble(),
          minY: 0,
          maxY: maxY,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              gradient: LinearGradient(
                colors: [Colors.purple.shade400, Colors.purple.shade600],
              ),
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 4,
                    color: Colors.white,
                    strokeWidth: 2,
                    strokeColor: Colors.purple.shade600,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    Colors.purple.withOpacity(0.3),
                    Colors.purple.withOpacity(0.05),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(
                y: dailyLimit,
                color: Colors.red.withOpacity(0.6),
                strokeWidth: 2,
                dashArray: [8, 4],
                label: HorizontalLineLabel(
                  show: true,
                  labelResolver: (line) => 'Лимит',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                  alignment: Alignment.topRight,
                ),
              ),
            ],
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              backgroundColor: Colors.purple.shade700,
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  return LineTooltipItem(
                    '${spot.y.toStringAsFixed(0)} мг\nДень ${spot.x.toInt()}',
                    const TextStyle(color: Colors.white, fontSize: 12),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }
}

// Modern Nutrition Pie Chart
class _ModernNutritionPieChart extends StatelessWidget {
  final Map<String, dynamic> stats;

  const _ModernNutritionPieChart({required this.stats});

  @override
  Widget build(BuildContext context) {
    final protein = (stats['totalProtein'] ?? 0).toDouble();
    final fat = (stats['totalFat'] ?? 0).toDouble();
    final carbs = (stats['totalCarbs'] ?? 0).toDouble();

    final total = protein + fat + carbs;
    if (total == 0) {
      return Container(
        height: 250,
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.pie_chart_outline, size: 48, color: Colors.grey),
              SizedBox(height: 8),
              Text('Нет данных для отображения'),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 280,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: PieChart(
              PieChartData(
                sections: [
                  PieChartSectionData(
                    value: protein,
                    title: '${(protein / total * 100).toStringAsFixed(0)}%',
                    color: Colors.blue.shade400,
                    radius: 70,
                    titleStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  PieChartSectionData(
                    value: fat,
                    title: '${(fat / total * 100).toStringAsFixed(0)}%',
                    color: Colors.amber.shade400,
                    radius: 70,
                    titleStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  PieChartSectionData(
                    value: carbs,
                    title: '${(carbs / total * 100).toStringAsFixed(0)}%',
                    color: Colors.green.shade400,
                    radius: 70,
                    titleStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
                sectionsSpace: 3,
                centerSpaceRadius: 45,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LegendItem(
                color: Colors.blue.shade400,
                label: 'Белок',
                value: '${protein.toStringAsFixed(1)} г',
              ),
              const SizedBox(height: 12),
              _LegendItem(
                color: Colors.amber.shade400,
                label: 'Жиры',
                value: '${fat.toStringAsFixed(1)} г',
              ),
              const SizedBox(height: 12),
              _LegendItem(
                color: Colors.green.shade400,
                label: 'Углеводы',
                value: '${carbs.toStringAsFixed(1)} г',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final String value;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// Weekly Comparison Chart
class _WeeklyComparisonChart extends StatelessWidget {
  final List<Map<String, dynamic>> dailyStats;
  final double dailyLimit;

  const _WeeklyComparisonChart({
    required this.dailyStats,
    required this.dailyLimit,
  });

  @override
  Widget build(BuildContext context) {
    // Group by weeks
    final weeks = <int, List<Map<String, dynamic>>>{};
    for (var stat in dailyStats) {
      if ((stat['entriesCount'] as int) == 0) continue;
      final day = stat['day'] as int;
      final week = ((day - 1) / 7).floor();
      weeks.putIfAbsent(week, () => []);
      weeks[week]!.add(stat);
    }

    if (weeks.isEmpty) {
      return Container(
        height: 250,
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bar_chart, size: 48, color: Colors.grey),
              SizedBox(height: 8),
              Text('Нет данных для отображения'),
            ],
          ),
        ),
      );
    }

    final weeklyAverages = weeks.entries.map((entry) {
      final weekStats = entry.value;
      final avgPhe = weekStats
              .map((s) => (s['phe'] as num).toDouble())
              .reduce((a, b) => a + b) /
          weekStats.length;

      Color barColor;
      final progress = dailyLimit > 0 ? (avgPhe / dailyLimit) : 0.0;
      if (progress < 0.5) {
        barColor = Colors.green.shade400;
      } else if (progress < 0.8) {
        barColor = Colors.orange.shade400;
      } else {
        barColor = Colors.red.shade400;
      }

      return BarChartGroupData(
        x: entry.key,
        barRods: [
          BarChartRodData(
            toY: avgPhe,
            gradient: LinearGradient(
              colors: [barColor, barColor.withOpacity(0.7)],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
            width: 24,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          ),
        ],
      );
    }).toList();

    final maxY = weeklyAverages
        .map((g) => g.barRods.first.toY)
        .reduce((a, b) => a > b ? a : b) * 1.2;

    return Container(
      height: 280,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: BarChart(
        BarChartData(
          barGroups: weeklyAverages,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY / 5,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.grey.shade200,
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 45,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Нед ${value.toInt() + 1}',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                    ),
                  );
                },
              ),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              backgroundColor: Colors.purple.shade700,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  'Неделя ${group.x + 1}\n${rod.toY.toStringAsFixed(0)} мг',
                  const TextStyle(color: Colors.white, fontSize: 12),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
