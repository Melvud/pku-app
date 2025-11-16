import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as excel_lib;

class ExportService {
  // Export to PDF
  Future<String?> exportToPDF({
    required Map<String, dynamic> stats,
    required DateTime month,
    required String userName,
    required double dailyLimit,
  }) async {
    try {
      final pdf = pw.Document();
      final dailyStats = stats['dailyStats'] as List<Map<String, dynamic>>? ?? [];

      // Add page
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => [
            // Header
            pw.Header(
              level: 0,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Статистика питания',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    DateFormat('MMMM yyyy', 'ru').format(month),
                    style: const pw.TextStyle(fontSize: 16),
                  ),
                  pw.Text(
                    'Пользователь: $userName',
                    style: pw.TextStyle(
                      fontSize: 12,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Создан: ${DateFormat('d MMMM yyyy, HH:mm', 'ru').format(DateTime.now())}',
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 24),

            // Summary Section
            pw.Text(
              'Общие показатели',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.purple50,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(
                children: [
                  _buildSummaryRow('Всего Phe',
                      '${(stats['totalPhe'] ?? 0).toStringAsFixed(0)} мг'),
                  pw.SizedBox(height: 8),
                  _buildSummaryRow('Среднее Phe в день',
                      '${(stats['avgPhePerDay'] ?? 0).toStringAsFixed(0)} мг'),
                  pw.SizedBox(height: 8),
                  _buildSummaryRow('Дневной лимит', '${dailyLimit.toStringAsFixed(0)} мг'),
                  pw.SizedBox(height: 8),
                  _buildSummaryRow('Активных дней', '${stats['activeDays']} из ${stats['totalDays']}'),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // Nutrition Summary
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(
                children: [
                  _buildSummaryRow('Белок',
                      '${(stats['totalProtein'] ?? 0).toStringAsFixed(1)} г (среднее: ${(stats['avgProteinPerDay'] ?? 0).toStringAsFixed(1)} г/день)'),
                  pw.SizedBox(height: 8),
                  _buildSummaryRow('Жиры',
                      '${(stats['totalFat'] ?? 0).toStringAsFixed(1)} г (среднее: ${(stats['avgFatPerDay'] ?? 0).toStringAsFixed(1)} г/день)'),
                  pw.SizedBox(height: 8),
                  _buildSummaryRow('Углеводы',
                      '${(stats['totalCarbs'] ?? 0).toStringAsFixed(1)} г (среднее: ${(stats['avgCarbsPerDay'] ?? 0).toStringAsFixed(1)} г/день)'),
                  pw.SizedBox(height: 8),
                  _buildSummaryRow('Калории',
                      '${(stats['totalCalories'] ?? 0).toStringAsFixed(0)} ккал (среднее: ${(stats['avgCaloriesPerDay'] ?? 0).toStringAsFixed(0)} ккал/день)'),
                ],
              ),
            ),
            pw.SizedBox(height: 24),

            // Daily Stats Table
            pw.Text(
              'Детализация по дням',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: {
                0: const pw.FlexColumnWidth(1),
                1: const pw.FlexColumnWidth(1.5),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(1.5),
                4: const pw.FlexColumnWidth(1.5),
              },
              children: [
                // Header
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _buildTableCell('День', isHeader: true),
                    _buildTableCell('Phe (мг)', isHeader: true),
                    _buildTableCell('Белок (г)', isHeader: true),
                    _buildTableCell('Калории', isHeader: true),
                    _buildTableCell('Записей', isHeader: true),
                  ],
                ),
                // Data rows
                ...dailyStats
                    .where((stat) => (stat['entriesCount'] as int) > 0)
                    .map((stat) {
                  final day = stat['day'] as int;
                  final phe = (stat['phe'] as num).toDouble();
                  final protein = (stat['protein'] as num).toDouble();
                  final calories = (stat['calories'] as num).toDouble();
                  final entries = stat['entriesCount'] as int;
                  
                  final progress = dailyLimit > 0 ? (phe / dailyLimit) : 0.0;
                  final color = progress > 0.8
                      ? PdfColors.red50
                      : progress > 0.5
                          ? PdfColors.orange50
                          : PdfColors.green50;

                  return pw.TableRow(
                    decoration: pw.BoxDecoration(color: color),
                    children: [
                      _buildTableCell('$day'),
                      _buildTableCell(phe.toStringAsFixed(0)),
                      _buildTableCell(protein.toStringAsFixed(1)),
                      _buildTableCell(calories.toStringAsFixed(0)),
                      _buildTableCell('$entries'),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 24),

            // Footer
            pw.Text(
              'Примечания:',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey700,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              '• Цветовая индикация: зеленый - до 50% лимита, оранжевый - 50-80%, красный - выше 80%',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
            pw.Text(
              '• Дни без записей не включены в таблицу',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
          ],
        ),
      );

      // Save file
      final output = await getApplicationDocumentsDirectory();
      final fileName = 'statistics_${DateFormat('yyyy-MM').format(month)}.pdf';
      final file = File('${output.path}/$fileName');
      await file.writeAsBytes(await pdf.save());

      return file.path;
    } catch (e) {
      debugPrint('Error exporting to PDF: $e');
      rethrow;
    }
  }

  // Export to Excel
  Future<String?> exportToExcel({
    required Map<String, dynamic> stats,
    required DateTime month,
    required String userName,
    required double dailyLimit,
  }) async {
    try {
      final excel = excel_lib.Excel.createExcel();
      final sheet = excel['Статистика'];

      // Remove default sheet if exists
      if (excel.sheets.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }

      final dailyStats = stats['dailyStats'] as List<Map<String, dynamic>>? ?? [];

      int row = 0;

      // Header
      sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
          .value = 'Статистика питания' as excel_lib.CellValue;
      sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
          .cellStyle = excel_lib.CellStyle(
        bold: true,
        fontSize: 16,
      );
      row++;

      sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
          .value = DateFormat('MMMM yyyy', 'ru').format(month) as excel_lib.CellValue;
      row++;

      sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
          .value = 'Пользователь: $userName' as excel_lib.CellValue;
      row++;

      sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
          .value = 'Создан: ${DateFormat('d MMMM yyyy, HH:mm', 'ru').format(DateTime.now())}' as excel_lib.CellValue;
      row += 2;

      // Summary Section
      sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
          .value = 'Общие показатели' as excel_lib.CellValue;
      sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
          .cellStyle = excel_lib.CellStyle(bold: true);
      row++;

      final summaryData = [
        ['Показатель', 'Значение'],
        ['Всего Phe', '${(stats['totalPhe'] ?? 0).toStringAsFixed(0)} мг'],
        ['Среднее Phe в день', '${(stats['avgPhePerDay'] ?? 0).toStringAsFixed(0)} мг'],
        ['Дневной лимит', '${dailyLimit.toStringAsFixed(0)} мг'],
        ['Активных дней', '${stats['activeDays']} из ${stats['totalDays']}'],
        ['Всего белка', '${(stats['totalProtein'] ?? 0).toStringAsFixed(1)} г'],
        ['Среднее белка в день', '${(stats['avgProteinPerDay'] ?? 0).toStringAsFixed(1)} г'],
        ['Всего жиров', '${(stats['totalFat'] ?? 0).toStringAsFixed(1)} г'],
        ['Всего углеводов', '${(stats['totalCarbs'] ?? 0).toStringAsFixed(1)} г'],
        ['Всего калорий', '${(stats['totalCalories'] ?? 0).toStringAsFixed(0)} ккал'],
        ['Среднее калорий в день', '${(stats['avgCaloriesPerDay'] ?? 0).toStringAsFixed(0)} ккал'],
      ];

      for (var rowData in summaryData) {
        for (var i = 0; i < rowData.length; i++) {
          sheet
              .cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: row))
              .value = rowData[i] as excel_lib.CellValue;
        }
        row++;
      }

      row += 2;

      // Daily Stats Section
      sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
          .value = 'Детализация по дням' as excel_lib.CellValue;
      sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
          .cellStyle = excel_lib.CellStyle(bold: true);
      row++;

      // Daily table header
      final headers = ['День', 'Дата', 'Phe (мг)', '% лимита', 'Белок (г)', 'Жиры (г)', 'Углеводы (г)', 'Калории', 'Записей'];
      for (var i = 0; i < headers.length; i++) {
        final cell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: row));
        cell.value = headers[i] as excel_lib.CellValue;
        cell.cellStyle = excel_lib.CellStyle(
          bold: true,
          backgroundColorHex: excel_lib.ExcelColor.fromHexString('#DDDDDD'),
        );
      }
      row++;

      // Daily data
      for (var stat in dailyStats) {
        final day = stat['day'] as int;
        final date = DateTime(month.year, month.month, day);
        final phe = (stat['phe'] as num).toDouble();
        final protein = (stat['protein'] as num).toDouble();
        final fat = (stat['fat'] as num).toDouble();
        final carbs = (stat['carbs'] as num).toDouble();
        final calories = (stat['calories'] as num).toDouble();
        final entries = stat['entriesCount'] as int;
        
        final progress = dailyLimit > 0 ? (phe / dailyLimit * 100) : 0.0;

        final rowData = [
          day.toString(),
          DateFormat('EEEE, d MMM', 'ru').format(date),
          phe.toStringAsFixed(0),
          '${progress.toStringAsFixed(0)}%',
          protein.toStringAsFixed(1),
          fat.toStringAsFixed(1),
          carbs.toStringAsFixed(1),
          calories.toStringAsFixed(0),
          entries.toString(),
        ];

        // Color code based on progress
        excel_lib.ExcelColor? bgColor;
        if (entries > 0) {
          if (progress > 80) {
            bgColor = excel_lib.ExcelColor.fromHexString('#FFE6E6'); // Light red
          } else if (progress > 50) {
            bgColor = excel_lib.ExcelColor.fromHexString('#FFF4E6'); // Light orange
          } else {
            bgColor = excel_lib.ExcelColor.fromHexString('#E6FFE6'); // Light green
          }
        }

        for (var i = 0; i < rowData.length; i++) {
          final cell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: row));
          cell.value = rowData[i] as excel_lib.CellValue;
          if (bgColor != null) {
            cell.cellStyle = excel_lib.CellStyle(backgroundColorHex: bgColor);
          }
        }
        row++;
      }

      // Save file
      final output = await getApplicationDocumentsDirectory();
      final fileName = 'statistics_${DateFormat('yyyy-MM').format(month)}.xlsx';
      final file = File('${output.path}/$fileName');
      
      final bytes = excel.encode();
      if (bytes != null) {
        await file.writeAsBytes(bytes);
        return file.path;
      }
      
      return null;
    } catch (e) {
      debugPrint('Error exporting to Excel: $e');
      rethrow;
    }
  }

  // Helper methods for PDF
  pw.Widget _buildSummaryRow(String label, String value) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 12)),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 10 : 9,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  // Export to PDF with date range
  Future<String?> exportToPDFWithRange({
    required Map<String, dynamic> stats,
    required DateTime startDate,
    required DateTime endDate,
    required String userName,
    required double dailyLimit,
  }) async {
    try {
      final pdf = pw.Document();
      final dailyStats = stats['dailyStats'] as List<Map<String, dynamic>>? ?? [];
      final monthlyStats = stats['monthlyStats'] as List<Map<String, dynamic>>? ?? [];

      // Add page
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => [
            // Header
            pw.Header(
              level: 0,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Статистика питания',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Период: ${DateFormat('d MMMM yyyy', 'ru').format(startDate)} - ${DateFormat('d MMMM yyyy', 'ru').format(endDate)}',
                    style: const pw.TextStyle(fontSize: 16),
                  ),
                  pw.Text(
                    'Пользователь: $userName',
                    style: pw.TextStyle(
                      fontSize: 12,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Создан: ${DateFormat('d MMMM yyyy, HH:mm', 'ru').format(DateTime.now())}',
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 24),

            // Summary Section
            pw.Text(
              'Общие показатели за период',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.purple50,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(
                children: [
                  _buildSummaryRow('Всего Phe',
                      '${(stats['totalPhe'] ?? 0).toStringAsFixed(0)} мг'),
                  pw.SizedBox(height: 8),
                  _buildSummaryRow('Среднее Phe в день',
                      '${(stats['avgPhePerDay'] ?? 0).toStringAsFixed(0)} мг'),
                  pw.SizedBox(height: 8),
                  _buildSummaryRow('Дневной лимит', '${dailyLimit.toStringAsFixed(0)} мг'),
                  pw.SizedBox(height: 8),
                  _buildSummaryRow('Активных дней', '${stats['activeDays']} из ${stats['totalDays']}'),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // Nutrition Summary
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(
                children: [
                  _buildSummaryRow('Белок',
                      '${(stats['totalProtein'] ?? 0).toStringAsFixed(1)} г (среднее: ${(stats['avgProteinPerDay'] ?? 0).toStringAsFixed(1)} г/день)'),
                  pw.SizedBox(height: 8),
                  _buildSummaryRow('Жиры',
                      '${(stats['totalFat'] ?? 0).toStringAsFixed(1)} г (среднее: ${(stats['avgFatPerDay'] ?? 0).toStringAsFixed(1)} г/день)'),
                  pw.SizedBox(height: 8),
                  _buildSummaryRow('Углеводы',
                      '${(stats['totalCarbs'] ?? 0).toStringAsFixed(1)} г (среднее: ${(stats['avgCarbsPerDay'] ?? 0).toStringAsFixed(1)} г/день)'),
                  pw.SizedBox(height: 8),
                  _buildSummaryRow('Калории',
                      '${(stats['totalCalories'] ?? 0).toStringAsFixed(0)} ккал (среднее: ${(stats['avgCaloriesPerDay'] ?? 0).toStringAsFixed(0)} ккал/день)'),
                ],
              ),
            ),
            pw.SizedBox(height: 24),

            // Monthly Analysis if available
            if (monthlyStats.isNotEmpty) ...[
              pw.Text(
                'Анализ по месяцам',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2),
                  1: const pw.FlexColumnWidth(1.5),
                  2: const pw.FlexColumnWidth(1.5),
                  3: const pw.FlexColumnWidth(1.5),
                  4: const pw.FlexColumnWidth(1.5),
                },
                children: [
                  // Header
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _buildTableCell('Месяц', isHeader: true),
                      _buildTableCell('Phe (мг)', isHeader: true),
                      _buildTableCell('Среднее/день', isHeader: true),
                      _buildTableCell('Белок (г)', isHeader: true),
                      _buildTableCell('Записей', isHeader: true),
                    ],
                  ),
                  // Data rows
                  ...monthlyStats.map((monthStat) {
                    final year = monthStat['year'] as int;
                    final month = monthStat['month'] as int;
                    final monthDate = DateTime(year, month);
                    final totalPhe = (monthStat['totalPhe'] as num).toDouble();
                    final avgPhe = (monthStat['avgPhePerDay'] as num).toDouble();
                    final protein = (monthStat['totalProtein'] as num).toDouble();
                    final entries = monthStat['entriesCount'] as int;

                    final progress = dailyLimit > 0 ? (avgPhe / dailyLimit) : 0.0;
                    final color = progress > 0.8
                        ? PdfColors.red50
                        : progress > 0.5
                            ? PdfColors.orange50
                            : PdfColors.green50;

                    return pw.TableRow(
                      decoration: pw.BoxDecoration(color: color),
                      children: [
                        _buildTableCell(DateFormat('LLLL yyyy', 'ru').format(monthDate)),
                        _buildTableCell(totalPhe.toStringAsFixed(0)),
                        _buildTableCell(avgPhe.toStringAsFixed(0)),
                        _buildTableCell(protein.toStringAsFixed(1)),
                        _buildTableCell('$entries'),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 24),
            ],

            // Daily Stats Table
            pw.Text(
              'Детализация по дням',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(1.5),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(1.5),
                4: const pw.FlexColumnWidth(1),
              },
              children: [
                // Header
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _buildTableCell('Дата', isHeader: true),
                    _buildTableCell('Phe (мг)', isHeader: true),
                    _buildTableCell('Белок (г)', isHeader: true),
                    _buildTableCell('Калории', isHeader: true),
                    _buildTableCell('Записей', isHeader: true),
                  ],
                ),
                // Data rows
                ...dailyStats
                    .where((stat) => (stat['entriesCount'] as int) > 0)
                    .map((stat) {
                  final date = stat['date'] as DateTime;
                  final phe = (stat['phe'] as num).toDouble();
                  final protein = (stat['protein'] as num).toDouble();
                  final calories = (stat['calories'] as num).toDouble();
                  final entries = stat['entriesCount'] as int;

                  final progress = dailyLimit > 0 ? (phe / dailyLimit) : 0.0;
                  final color = progress > 0.8
                      ? PdfColors.red50
                      : progress > 0.5
                          ? PdfColors.orange50
                          : PdfColors.green50;

                  return pw.TableRow(
                    decoration: pw.BoxDecoration(color: color),
                    children: [
                      _buildTableCell(DateFormat('d MMM yyyy', 'ru').format(date)),
                      _buildTableCell(phe.toStringAsFixed(0)),
                      _buildTableCell(protein.toStringAsFixed(1)),
                      _buildTableCell(calories.toStringAsFixed(0)),
                      _buildTableCell('$entries'),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 24),

            // Footer
            pw.Text(
              'Примечания:',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey700,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              '• Цветовая индикация: зеленый - до 50% лимита, оранжевый - 50-80%, красный - выше 80%',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
            pw.Text(
              '• Дни без записей не включены в таблицу',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
          ],
        ),
      );

      // Save file
      final output = await getApplicationDocumentsDirectory();
      final fileName = 'statistics_${DateFormat('yyyy-MM-dd').format(startDate)}_to_${DateFormat('yyyy-MM-dd').format(endDate)}.pdf';
      final file = File('${output.path}/$fileName');
      await file.writeAsBytes(await pdf.save());

      return file.path;
    } catch (e) {
      debugPrint('Error exporting to PDF: $e');
      rethrow;
    }
  }

  // Export to Excel with date range
  Future<String?> exportToExcelWithRange({
    required Map<String, dynamic> stats,
    required DateTime startDate,
    required DateTime endDate,
    required String userName,
    required double dailyLimit,
  }) async {
    try {
      final excel = excel_lib.Excel.createExcel();
      final summarySheet = excel['Общее'];
      final monthlySheet = excel['По месяцам'];
      final dailySheet = excel['По дням'];

      // Remove default sheet
      if (excel.sheets.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }

      final dailyStats = stats['dailyStats'] as List<Map<String, dynamic>>? ?? [];
      final monthlyStats = stats['monthlyStats'] as List<Map<String, dynamic>>? ?? [];

      // ===== SUMMARY SHEET =====
      int row = 0;

      // Header
      summarySheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
          .value = 'Статистика питания' as excel_lib.CellValue;
      summarySheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
          .cellStyle = excel_lib.CellStyle(bold: true, fontSize: 16);
      row++;

      summarySheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
          .value = 'Период: ${DateFormat('d MMMM yyyy', 'ru').format(startDate)} - ${DateFormat('d MMMM yyyy', 'ru').format(endDate)}' as excel_lib.CellValue;
      row++;

      summarySheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
          .value = 'Пользователь: $userName' as excel_lib.CellValue;
      row++;

      summarySheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
          .value = 'Создан: ${DateFormat('d MMMM yyyy, HH:mm', 'ru').format(DateTime.now())}' as excel_lib.CellValue;
      row += 2;

      // Summary data
      final summaryData = [
        ['Показатель', 'Значение'],
        ['Всего Phe', '${(stats['totalPhe'] ?? 0).toStringAsFixed(0)} мг'],
        ['Среднее Phe в день', '${(stats['avgPhePerDay'] ?? 0).toStringAsFixed(0)} мг'],
        ['Дневной лимит', '${dailyLimit.toStringAsFixed(0)} мг'],
        ['Активных дней', '${stats['activeDays']} из ${stats['totalDays']}'],
        ['Всего белка', '${(stats['totalProtein'] ?? 0).toStringAsFixed(1)} г'],
        ['Среднее белка в день', '${(stats['avgProteinPerDay'] ?? 0).toStringAsFixed(1)} г'],
        ['Всего жиров', '${(stats['totalFat'] ?? 0).toStringAsFixed(1)} г'],
        ['Всего углеводов', '${(stats['totalCarbs'] ?? 0).toStringAsFixed(1)} г'],
        ['Всего калорий', '${(stats['totalCalories'] ?? 0).toStringAsFixed(0)} ккал'],
        ['Среднее калорий в день', '${(stats['avgCaloriesPerDay'] ?? 0).toStringAsFixed(0)} ккал'],
      ];

      for (var rowData in summaryData) {
        for (var i = 0; i < rowData.length; i++) {
          summarySheet
              .cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: row))
              .value = rowData[i] as excel_lib.CellValue;
        }
        row++;
      }

      // ===== MONTHLY SHEET =====
      row = 0;
      final monthlyHeaders = ['Месяц', 'Всего Phe (мг)', 'Среднее Phe/день (мг)', 'Белок (г)', 'Жиры (г)', 'Углеводы (г)', 'Калории', 'Записей'];
      for (var i = 0; i < monthlyHeaders.length; i++) {
        final cell = monthlySheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: row));
        cell.value = monthlyHeaders[i] as excel_lib.CellValue;
        cell.cellStyle = excel_lib.CellStyle(
          bold: true,
          backgroundColorHex: excel_lib.ExcelColor.fromHexString('#DDDDDD'),
        );
      }
      row++;

      for (var monthStat in monthlyStats) {
        final year = monthStat['year'] as int;
        final month = monthStat['month'] as int;
        final monthDate = DateTime(year, month);
        final totalPhe = (monthStat['totalPhe'] as num).toDouble();
        final avgPhe = (monthStat['avgPhePerDay'] as num).toDouble();
        final protein = (monthStat['totalProtein'] as num).toDouble();
        final fat = (monthStat['totalFat'] as num).toDouble();
        final carbs = (monthStat['totalCarbs'] as num).toDouble();
        final calories = (monthStat['totalCalories'] as num).toDouble();
        final entries = monthStat['entriesCount'] as int;

        final progress = dailyLimit > 0 ? (avgPhe / dailyLimit * 100) : 0.0;

        final rowData = [
          DateFormat('LLLL yyyy', 'ru').format(monthDate),
          totalPhe.toStringAsFixed(0),
          avgPhe.toStringAsFixed(0),
          protein.toStringAsFixed(1),
          fat.toStringAsFixed(1),
          carbs.toStringAsFixed(1),
          calories.toStringAsFixed(0),
          entries.toString(),
        ];

        excel_lib.ExcelColor? bgColor;
        if (progress > 80) {
          bgColor = excel_lib.ExcelColor.fromHexString('#FFE6E6');
        } else if (progress > 50) {
          bgColor = excel_lib.ExcelColor.fromHexString('#FFF4E6');
        } else {
          bgColor = excel_lib.ExcelColor.fromHexString('#E6FFE6');
        }

        for (var i = 0; i < rowData.length; i++) {
          final cell = monthlySheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: row));
          cell.value = rowData[i] as excel_lib.CellValue;
          cell.cellStyle = excel_lib.CellStyle(backgroundColorHex: bgColor);
        }
        row++;
      }

      // ===== DAILY SHEET =====
      row = 0;
      final dailyHeaders = ['Дата', 'Phe (мг)', '% лимита', 'Белок (г)', 'Жиры (г)', 'Углеводы (г)', 'Калории', 'Записей'];
      for (var i = 0; i < dailyHeaders.length; i++) {
        final cell = dailySheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: row));
        cell.value = dailyHeaders[i] as excel_lib.CellValue;
        cell.cellStyle = excel_lib.CellStyle(
          bold: true,
          backgroundColorHex: excel_lib.ExcelColor.fromHexString('#DDDDDD'),
        );
      }
      row++;

      for (var stat in dailyStats) {
        final date = stat['date'] as DateTime;
        final phe = (stat['phe'] as num).toDouble();
        final protein = (stat['protein'] as num).toDouble();
        final fat = (stat['fat'] as num).toDouble();
        final carbs = (stat['carbs'] as num).toDouble();
        final calories = (stat['calories'] as num).toDouble();
        final entries = stat['entriesCount'] as int;

        final progress = dailyLimit > 0 ? (phe / dailyLimit * 100) : 0.0;

        final rowData = [
          DateFormat('d MMM yyyy, EEEE', 'ru').format(date),
          phe.toStringAsFixed(0),
          '${progress.toStringAsFixed(0)}%',
          protein.toStringAsFixed(1),
          fat.toStringAsFixed(1),
          carbs.toStringAsFixed(1),
          calories.toStringAsFixed(0),
          entries.toString(),
        ];

        excel_lib.ExcelColor? bgColor;
        if (entries > 0) {
          if (progress > 80) {
            bgColor = excel_lib.ExcelColor.fromHexString('#FFE6E6');
          } else if (progress > 50) {
            bgColor = excel_lib.ExcelColor.fromHexString('#FFF4E6');
          } else {
            bgColor = excel_lib.ExcelColor.fromHexString('#E6FFE6');
          }
        }

        for (var i = 0; i < rowData.length; i++) {
          final cell = dailySheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: row));
          cell.value = rowData[i] as excel_lib.CellValue;
          if (bgColor != null) {
            cell.cellStyle = excel_lib.CellStyle(backgroundColorHex: bgColor);
          }
        }
        row++;
      }

      // Save file
      final output = await getApplicationDocumentsDirectory();
      final fileName = 'statistics_${DateFormat('yyyy-MM-dd').format(startDate)}_to_${DateFormat('yyyy-MM-dd').format(endDate)}.xlsx';
      final file = File('${output.path}/$fileName');

      final bytes = excel.encode();
      if (bytes != null) {
        await file.writeAsBytes(bytes);
        return file.path;
      }

      return null;
    } catch (e) {
      debugPrint('Error exporting to Excel: $e');
      rethrow;
    }
  }
}

void debugPrint(String message) {
  print(message);
}