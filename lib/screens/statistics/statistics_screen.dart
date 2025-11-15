import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/diary_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/export_service.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedMonth = DateTime.now();
  bool _isLoading = true;
  Map<String, dynamic>? _stats;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
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

  Future<void> _selectMonth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('ru'),
    );
    
    if (picked != null) {
      setState(() => _selectedMonth = DateTime(picked.year, picked.month));
      await _loadStats();
    }
  }

  Future<void> _exportData(String format) async {
    if (_stats == null) return;

    try {
      final exportService = ExportService();
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final profile = userProvider.userProfile;

      setState(() => _isLoading = true);

      String? filePath;
      if (format == 'pdf') {
        filePath = await exportService.exportToPDF(
          stats: _stats!,
          month: _selectedMonth,
          userName: profile?.name ?? 'Пользователь',
          dailyLimit: profile?.dailyTolerancePhe ?? 0,
        );
      } else if (format == 'excel') {
        filePath = await exportService.exportToExcel(
          stats: _stats!,
          month: _selectedMonth,
          userName: profile?.name ?? 'Пользователь',
          dailyLimit: profile?.dailyTolerancePhe ?? 0,
        );
      }

      setState(() => _isLoading = false);

      if (mounted && filePath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Экспортировано: ${filePath.split('/').last}'),
            action: SnackBarAction(
              label: 'Открыть',
              onPressed: () {
                // Open file
              },
            ),
            behavior: SnackBarBehavior.floating,
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
                subtitle: const Text('Красивый отчет с графиками'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.pop(context);
                  _exportData('pdf');
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
                subtitle: const Text('Таблица для анализа данных'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.pop(context);
                  _exportData('excel');
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
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            expandedHeight: 100,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: Theme.of(context).colorScheme.primary,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: InkWell(
                onTap: _selectMonth,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Статистика',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.calendar_month,
                      color: Colors.white70,
                      size: 16,
                    ),
                  ],
                ),
              ),
              centerTitle: false,
              titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
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
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.file_download, color: Colors.white),
                onPressed: _showExportDialog,
                tooltip: 'Экспорт',
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: const [
                Tab(text: 'Обзор'),
                Tab(text: 'По дням'),
              ],
            ),
          ),

          // Content
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_stats == null)
            const SliverFillRemaining(
              child: Center(child: Text('Нет данных')),
            )
          else
            SliverFillRemaining(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Overview Tab
                  _OverviewTab(stats: _stats!),
                  // Daily Tab
                  _DailyTab(stats: _stats!, month: _selectedMonth),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// Overview Tab
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
              // Summary Cards
              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      title: 'Всего Phe',
                      value: '${(stats['totalPhe'] ?? 0).toStringAsFixed(0)} мг',
                      subtitle:
                          'Среднее: ${(stats['avgPhePerDay'] ?? 0).toStringAsFixed(0)} мг/день',
                      color: Colors.purple,
                      icon: Icons.medical_information,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      title: 'Активных дней',
                      value: '${stats['activeDays'] ?? 0}',
                      subtitle: 'из ${stats['totalDays'] ?? 0} дней',
                      color: Colors.green,
                      icon: Icons.calendar_today,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      title: 'Белок',
                      value:
                          '${(stats['totalProtein'] ?? 0).toStringAsFixed(1)} г',
                      subtitle:
                          'Среднее: ${(stats['avgProteinPerDay'] ?? 0).toStringAsFixed(1)} г/день',
                      color: Colors.blue,
                      icon: Icons.egg,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      title: 'Калории',
                      value:
                          '${(stats['totalCalories'] ?? 0).toStringAsFixed(0)}',
                      subtitle:
                          'Среднее: ${(stats['avgCaloriesPerDay'] ?? 0).toStringAsFixed(0)} ккал/день',
                      color: Colors.orange,
                      icon: Icons.local_fire_department,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Phe Chart
              Text(
                'Динамика Phe',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              _PheChart(dailyStats: dailyStats, dailyLimit: dailyLimit),
              const SizedBox(height: 24),

              // Nutrition Distribution
              Text(
                'Распределение питательных веществ',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              _NutritionPieChart(stats: stats),
              const SizedBox(height: 24),

              // Weekly Average
              Text(
                'Средние показатели по неделям',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              _WeeklyAverageChart(dailyStats: dailyStats),
            ],
          ),
        );
      },
    );
  }
}

// Daily Tab
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

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: dailyStats.length,
          itemBuilder: (context, index) {
            final dayStat = dailyStats[index];
            final day = dayStat['day'] as int;
            final phe = (dayStat['phe'] as num).toDouble();
            final protein = (dayStat['protein'] as num).toDouble();
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
                child: Card(
                  color: Colors.grey.shade50,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.grey.shade200,
                      child: Text(
                        '$day',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.bold,
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
              child: Card(
                elevation: isToday ? 4 : 1,
                child: Theme(
                  data: Theme.of(context).copyWith(
                    dividerColor: Colors.transparent,
                  ),
                  child: ExpansionTile(
                    leading: CircleAvatar(
                      backgroundColor: progressColor.withOpacity(0.1),
                      child: Text(
                        '$day',
                        style: TextStyle(
                          color: progressColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Row(
                      children: [
                        Text(
                          DateFormat('EEEE, d MMMM', 'ru').format(date),
                        ),
                        if (isToday) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Сегодня',
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          'Phe: ${phe.toStringAsFixed(0)} мг (${(progress * 100).toStringAsFixed(0)}%)',
                          style: TextStyle(color: progressColor),
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 6,
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
                            _DayDetailRow(
                              icon: Icons.medical_information,
                              label: 'Фенилаланин',
                              value: '${phe.toStringAsFixed(0)} мг',
                              color: Colors.purple,
                            ),
                            const SizedBox(height: 8),
                            _DayDetailRow(
                              icon: Icons.egg,
                              label: 'Белок',
                              value: '${protein.toStringAsFixed(1)} г',
                              color: Colors.blue,
                            ),
                            const SizedBox(height: 8),
                            _DayDetailRow(
                              icon: Icons.local_fire_department,
                              label: 'Калории',
                              value: '${calories.toStringAsFixed(0)} ккал',
                              color: Colors.orange,
                            ),
                            const SizedBox(height: 8),
                            _DayDetailRow(
                              icon: Icons.restaurant,
                              label: 'Записей',
                              value: '$entriesCount',
                              color: Colors.green,
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

// Summary Card
class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final IconData icon;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

// Phe Chart
class _PheChart extends StatelessWidget {
  final List<Map<String, dynamic>> dailyStats;
  final double dailyLimit;

  const _PheChart({required this.dailyStats, required this.dailyLimit});

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
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text('Нет данных для отображения'),
        ),
      );
    }

    final maxPhe = spots.map((e) => e.y).reduce((a, b) => a > b ? a : b);
    final maxY = (maxPhe > dailyLimit ? maxPhe : dailyLimit) * 1.2;

    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
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
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 5,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(fontSize: 10),
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
            // Daily Phe Line
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Colors.purple,
              barWidth: 3,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.purple.withOpacity(0.1),
              ),
            ),
          ],
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              // Daily Limit Line
              HorizontalLine(
                y: dailyLimit,
                color: Colors.red.withOpacity(0.5),
                strokeWidth: 2,
                dashArray: [5, 5],
                label: HorizontalLineLabel(
                  show: true,
                  labelResolver: (line) => 'Лимит',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.red,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Nutrition Pie Chart
class _NutritionPieChart extends StatelessWidget {
  final Map<String, dynamic> stats;

  const _NutritionPieChart({required this.stats});

  @override
  Widget build(BuildContext context) {
    final protein = (stats['totalProtein'] ?? 0).toDouble();
    final fat = (stats['totalFat'] ?? 0).toDouble();
    final carbs = (stats['totalCarbs'] ?? 0).toDouble();

    final total = protein + fat + carbs;
    if (total == 0) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text('Нет данных для отображения'),
        ),
      );
    }

    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
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
      child: Row(
        children: [
          Expanded(
            child: PieChart(
              PieChartData(
                sections: [
                  PieChartSectionData(
                    value: protein,
                    title: '${(protein / total * 100).toStringAsFixed(0)}%',
                    color: Colors.blue,
                    radius: 60,
                  ),
                  PieChartSectionData(
                    value: fat,
                    title: '${(fat / total * 100).toStringAsFixed(0)}%',
                    color: Colors.amber,
                    radius: 60,
                  ),
                  PieChartSectionData(
                    value: carbs,
                    title: '${(carbs / total * 100).toStringAsFixed(0)}%',
                    color: Colors.green,
                    radius: 60,
                  ),
                ],
                sectionsSpace: 2,
                centerSpaceRadius: 40,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Legend(
                color: Colors.blue,
                label: 'Белок',
                value: '${protein.toStringAsFixed(1)} г',
              ),
              const SizedBox(height: 8),
              _Legend(
                color: Colors.amber,
                label: 'Жир',
                value: '${fat.toStringAsFixed(1)} г',
              ),
              const SizedBox(height: 8),
              _Legend(
                color: Colors.green,
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

// Weekly Average Chart
class _WeeklyAverageChart extends StatelessWidget {
  final List<Map<String, dynamic>> dailyStats;

  const _WeeklyAverageChart({required this.dailyStats});

  @override
  Widget build(BuildContext context) {
    // Group by weeks
    final weeks = <int, List<Map<String, dynamic>>>{};
    for (var stat in dailyStats) {
      final day = stat['day'] as int;
      final week = ((day - 1) / 7).floor();
      weeks.putIfAbsent(week, () => []);
      weeks[week]!.add(stat);
    }

    final weeklyAverages = weeks.entries.map((entry) {
      final weekStats = entry.value;
      final avgPhe = weekStats
              .map((s) => (s['phe'] as num).toDouble())
              .reduce((a, b) => a + b) /
          weekStats.length;
      return BarChartGroupData(
        x: entry.key,
        barRods: [
          BarChartRodData(
            toY: avgPhe,
            color: Colors.purple,
            width: 16,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    }).toList();

    if (weeklyAverages.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text('Нет данных для отображения'),
        ),
      );
    }

    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
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
      child: BarChart(
        BarChartData(
          barGroups: weeklyAverages,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 100,
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
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Text(
                    'Нед ${value.toInt() + 1}',
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }
}

// Legend
class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  final String value;

  const _Legend({
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
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// Day Detail Row
class _DayDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _DayDetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}