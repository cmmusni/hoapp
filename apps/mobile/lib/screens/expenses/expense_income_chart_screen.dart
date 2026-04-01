import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:core_data/core_data.dart';
import 'package:core_domain/core_domain.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

const _brand = Color(0xff215e3f);

class ExpenseIncomeChartScreen extends StatefulWidget {
  const ExpenseIncomeChartScreen({super.key});

  @override
  State<ExpenseIncomeChartScreen> createState() =>
      _ExpenseIncomeChartScreenState();
}

class _ExpenseIncomeChartScreenState extends State<ExpenseIncomeChartScreen> {
  bool _loading = true;
  int _monthRange = 6;
  List<_MonthlyComparison> _monthlyData = [];
  double _totalIncome = 0;
  double _totalExpenses = 0;
  Map<ExpenseCategory, double> _expenseByCategory = {};
  final _currencyFormat = NumberFormat.currency(symbol: '₱', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    final appState = context.read<AppState>();
    final communityId = appState.activeCommunityId;
    if (communityId == null) return;

    final expenseRepo = context.read<ExpenseRepository>();
    final incomeRepo = context.read<IncomeRepository>();

    try {
      final results = await Future.wait([
        expenseRepo.getExpenses(communityId),
        incomeRepo.getVerifiedPayments(communityId),
        incomeRepo.getManualIncome(communityId),
      ]);

      final expenses = results[0] as List<Expense>;
      final verifiedPayments = results[1] as List<Payment>;
      final manualIncome = results[2] as List<ManualIncome>;

      final now = DateTime.now();
      final months = <_MonthlyComparison>[];
      double totalInc = 0;
      double totalExp = 0;
      final catMap = <ExpenseCategory, double>{};

      for (int i = _monthRange - 1; i >= 0; i--) {
        final month = DateTime(now.year, now.month - i, 1);
        final monthEnd = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
        final label = DateFormat('MMM').format(month);
        final yearLabel = DateFormat('MMM yy').format(month);

        double income = 0;
        for (final p in verifiedPayments) {
          if (p.verifiedAt != null &&
              !p.verifiedAt!.isBefore(month) &&
              !p.verifiedAt!.isAfter(monthEnd)) {
            income += p.amount;
          }
        }
        for (final m in manualIncome) {
          if (!m.incomeDate.isBefore(month) &&
              !m.incomeDate.isAfter(monthEnd)) {
            income += m.amount;
          }
        }

        double expense = 0;
        for (final e in expenses) {
          if (!e.expenseDate.isBefore(month) &&
              !e.expenseDate.isAfter(monthEnd)) {
            expense += e.amount;
            catMap[e.category] = (catMap[e.category] ?? 0) + e.amount;
          }
        }

        totalInc += income;
        totalExp += expense;
        months.add(_MonthlyComparison(
          month: label,
          fullLabel: yearLabel,
          income: income,
          expense: expense,
        ));
      }

      if (mounted) {
        setState(() {
          _monthlyData = months;
          _totalIncome = totalInc;
          _totalExpenses = totalExp;
          _expenseByCategory = catMap;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final net = _totalIncome - _totalExpenses;
    final isPositive = net >= 0;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Period selector
          Row(
            children: [
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 6, label: Text('6 months')),
                  ButtonSegment(value: 12, label: Text('12 months')),
                ],
                selected: {_monthRange},
                onSelectionChanged: (val) {
                  _monthRange = val.first;
                  _loadData();
                },
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Summary cards
          Row(
            children: [
              _SummaryCard(
                label: 'Income',
                value: _currencyFormat.format(_totalIncome),
                color: Colors.green.shade700,
                bgColor: Colors.green.shade50,
                icon: Icons.trending_up,
              ),
              const SizedBox(width: 8),
              _SummaryCard(
                label: 'Expenses',
                value: _currencyFormat.format(_totalExpenses),
                color: Colors.red.shade700,
                bgColor: Colors.red.shade50,
                icon: Icons.trending_down,
              ),
              const SizedBox(width: 8),
              _SummaryCard(
                label: 'Net',
                value: '${isPositive ? '+' : ''}${_currencyFormat.format(net)}',
                color:
                    isPositive ? Colors.blue.shade700 : Colors.orange.shade700,
                bgColor:
                    isPositive ? Colors.blue.shade50 : Colors.orange.shade50,
                icon: isPositive ? Icons.savings : Icons.warning_amber,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Bar chart: Income vs Expenses by month
          _buildSectionHeader(Icons.bar_chart, 'Monthly Income vs Expenses'),
          const SizedBox(height: 8),
          _buildLegendRow(),
          const SizedBox(height: 8),
          SizedBox(
            height: 240,
            child: _buildBarChart(),
          ),
          const SizedBox(height: 24),

          // Line chart: Cumulative trend
          _buildSectionHeader(Icons.show_chart, 'Cumulative Trend'),
          const SizedBox(height: 8),
          _buildCumulativeLegendRow(),
          const SizedBox(height: 8),
          SizedBox(
            height: 240,
            child: _buildLineChart(),
          ),
          const SizedBox(height: 24),

          // Pie chart: Expense breakdown by category
          if (_expenseByCategory.isNotEmpty) ...[
            _buildSectionHeader(Icons.pie_chart, 'Expense Breakdown'),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: _buildPieChart(),
            ),
            const SizedBox(height: 8),
            _buildPieLegend(),
          ],
          const SizedBox(height: 24),

          // Monthly summary table
          _buildSectionHeader(Icons.table_chart, 'Monthly Summary'),
          const SizedBox(height: 8),
          _buildComparisonTable(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ============ SECTION HEADER ============

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 20, color: _brand),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ],
    );
  }

  // ============ LEGEND ============

  Widget _buildLegendRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _legendDot(Colors.green.shade600, 'Income'),
        const SizedBox(width: 16),
        _legendDot(Colors.red.shade400, 'Expenses'),
      ],
    );
  }

  Widget _buildCumulativeLegendRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _legendDot(Colors.green.shade600, 'Cumulative Income'),
        const SizedBox(width: 12),
        _legendDot(Colors.red.shade400, 'Cumulative Expenses'),
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  // ============ BAR CHART ============

  Widget _buildBarChart() {
    if (_monthlyData.isEmpty ||
        _monthlyData.every((m) => m.income == 0 && m.expense == 0)) {
      return Center(
          child: Text('No data to display',
              style: TextStyle(color: Colors.grey[500])));
    }

    final maxY = _monthlyData.fold<double>(0, (prev, m) {
      final higher = m.income > m.expense ? m.income : m.expense;
      return higher > prev ? higher : prev;
    });
    final ceilY = maxY == 0 ? 5000.0 : (maxY * 1.3);
    final barWidth = _monthRange <= 6 ? 12.0 : 7.0;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: ceilY,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final isIncome = rodIndex == 0;
                return BarTooltipItem(
                  '${isIncome ? "Income" : "Expenses"}\n₱${NumberFormat('#,##0').format(rod.toY)}',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 48,
                interval: ceilY / 4,
                getTitlesWidget: (value, meta) => Text(
                  '₱${NumberFormat.compact().format(value)}',
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= _monthlyData.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(_monthlyData[idx].month,
                        style: const TextStyle(fontSize: 10)),
                  );
                },
              ),
            ),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: ceilY / 4,
            getDrawingHorizontalLine: (_) => FlLine(
              color: Colors.grey.shade300,
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(_monthlyData.length, (i) {
            final d = _monthlyData[i];
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: d.income,
                  color: Colors.green.shade600,
                  width: barWidth,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(4)),
                ),
                BarChartRodData(
                  toY: d.expense,
                  color: Colors.red.shade400,
                  width: barWidth,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  // ============ LINE CHART (CUMULATIVE) ============

  Widget _buildLineChart() {
    if (_monthlyData.isEmpty) {
      return Center(
          child: Text('No data to display',
              style: TextStyle(color: Colors.grey[500])));
    }

    double cumulativeIncome = 0;
    double cumulativeExpense = 0;
    final cumulativeData = <_CumulativePoint>[];
    for (final m in _monthlyData) {
      cumulativeIncome += m.income;
      cumulativeExpense += m.expense;
      cumulativeData.add(_CumulativePoint(
        month: m.month,
        income: cumulativeIncome,
        expense: cumulativeExpense,
      ));
    }

    final maxY = cumulativeData.fold<double>(0, (prev, m) {
      final higher = m.income > m.expense ? m.income : m.expense;
      return higher > prev ? higher : prev;
    });
    final ceilY = maxY == 0 ? 5000.0 : (maxY * 1.3);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: ceilY / 4,
            getDrawingHorizontalLine: (_) => FlLine(
              color: Colors.grey.shade300,
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 48,
                interval: ceilY / 4,
                getTitlesWidget: (value, meta) => Text(
                  '₱${NumberFormat.compact().format(value)}',
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= cumulativeData.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(cumulativeData[idx].month,
                        style: const TextStyle(fontSize: 10)),
                  );
                },
              ),
            ),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          minY: 0,
          maxY: ceilY,
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(
                cumulativeData.length,
                (i) => FlSpot(i.toDouble(), cumulativeData[i].income),
              ),
              isCurved: true,
              color: Colors.green.shade600,
              barWidth: 3,
              dotData: FlDotData(
                show: true,
                getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                  radius: 3,
                  color: Colors.green.shade600,
                  strokeColor: Colors.white,
                  strokeWidth: 1.5,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.green.shade600.withValues(alpha: 0.08),
              ),
            ),
            LineChartBarData(
              spots: List.generate(
                cumulativeData.length,
                (i) => FlSpot(i.toDouble(), cumulativeData[i].expense),
              ),
              isCurved: true,
              color: Colors.red.shade400,
              barWidth: 3,
              dashArray: [6, 4],
              dotData: FlDotData(
                show: true,
                getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                  radius: 3,
                  color: Colors.red.shade400,
                  strokeColor: Colors.white,
                  strokeWidth: 1.5,
                ),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots.map((s) {
                final isIncome = s.barIndex == 0;
                return LineTooltipItem(
                  '${isIncome ? "Income" : "Expenses"}: ₱${NumberFormat('#,##0').format(s.y)}',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  // ============ PIE CHART ============

  Widget _buildPieChart() {
    final sortedEntries = _expenseByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final total = sortedEntries.fold<double>(0, (prev, e) => prev + e.value);

    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 32,
        sections: List.generate(sortedEntries.length, (i) {
          final entry = sortedEntries[i];
          final percentage = total > 0 ? (entry.value / total * 100) : 0;
          return PieChartSectionData(
            value: entry.value,
            title: percentage >= 5 ? '${percentage.toStringAsFixed(0)}%' : '',
            color: _categoryColors[i % _categoryColors.length],
            radius: 50,
            titleStyle: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPieLegend() {
    final sortedEntries = _expenseByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: List.generate(sortedEntries.length, (i) {
        final entry = sortedEntries[i];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: _categoryColors[i % _categoryColors.length],
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _expenseCategoryLabel(entry.key),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              Text(
                _currencyFormat.format(entry.value),
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        );
      }),
    );
  }

  // ============ COMPARISON TABLE ============

  Widget _buildComparisonTable() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                headingRowColor: WidgetStatePropertyAll(Colors.grey.shade50),
                columnSpacing: 12,
                horizontalMargin: 16,
                dataRowMinHeight: 48,
                dataRowMaxHeight: 56,
                columns: const [
                  DataColumn(
                      label: Text('Month',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13))),
                  DataColumn(
                      label: Text('Income',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                      numeric: true),
                  DataColumn(
                      label: Text('Expenses',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                      numeric: true),
                  DataColumn(
                      label: Text('Net',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                      numeric: true),
                ],
                rows: _monthlyData.map((m) {
                  final net = m.income - m.expense;
                  return DataRow(cells: [
                    DataCell(Text(m.fullLabel,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500))),
                    DataCell(Text(
                      _currencyFormat.format(m.income),
                      style:
                          TextStyle(color: Colors.green.shade700, fontSize: 13),
                    )),
                    DataCell(Text(
                      _currencyFormat.format(m.expense),
                      style:
                          TextStyle(color: Colors.red.shade700, fontSize: 13),
                    )),
                    DataCell(Text(
                      '${net >= 0 ? '+' : ''}${_currencyFormat.format(net)}',
                      style: TextStyle(
                        color: net >= 0
                            ? Colors.blue.shade700
                            : Colors.orange.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    )),
                  ]);
                }).toList(),
              ),
            ),
          );
        },
      ),
    );
  }

  // ============ HELPERS ============

  String _expenseCategoryLabel(ExpenseCategory cat) {
    switch (cat) {
      case ExpenseCategory.maintenance:
        return 'Maintenance';
      case ExpenseCategory.utilities:
        return 'Utilities';
      case ExpenseCategory.supplies:
        return 'Supplies';
      case ExpenseCategory.services:
        return 'Services';
      case ExpenseCategory.repairs:
        return 'Repairs';
      case ExpenseCategory.salaries:
        return 'Salaries';
      case ExpenseCategory.insurance:
        return 'Insurance';
      case ExpenseCategory.taxes:
        return 'Taxes';
      case ExpenseCategory.other:
        return 'Other';
    }
  }

  static const _categoryColors = [
    Color(0xFFEF5350),
    Color(0xFFFFA726),
    Color(0xFFFFB300),
    Color(0xFF26A69A),
    Color(0xFF42A5F5),
    Color(0xFFAB47BC),
    Color(0xFFF06292),
    Color(0xFF5C6BC0),
    Color(0xFF9E9E9E),
  ];
}

// ============ DATA MODELS ============

class _MonthlyComparison {
  final String month;
  final String fullLabel;
  final double income;
  final double expense;
  _MonthlyComparison({
    required this.month,
    required this.fullLabel,
    required this.income,
    required this.expense,
  });
}

class _CumulativePoint {
  final String month;
  final double income;
  final double expense;
  _CumulativePoint({
    required this.month,
    required this.income,
    required this.expense,
  });
}

// ============ SUMMARY CARD ============

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color bgColor;
  final IconData icon;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
    required this.bgColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        elevation: 0,
        color: bgColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: color.withValues(alpha: 0.2)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 14, color: color),
                  const SizedBox(width: 4),
                  Text(label,
                      style: TextStyle(
                          fontSize: 11, color: color.withValues(alpha: 0.8))),
                ],
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(value,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: color)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
