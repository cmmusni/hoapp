import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:core_data/core_data.dart';
import 'package:core_domain/core_domain.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class ExpenseIncomeChartPage extends StatefulWidget {
  const ExpenseIncomeChartPage({super.key});

  @override
  State<ExpenseIncomeChartPage> createState() => _ExpenseIncomeChartPageState();
}

class _ExpenseIncomeChartPageState extends State<ExpenseIncomeChartPage> {
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

    final billingRepo = context.read<BillingRepository>();
    final expenseRepo = context.read<ExpenseRepository>();
    final incomeRepo = context.read<IncomeRepository>();

    try {
      // Fetch all data in parallel
      final results = await Future.wait([
        billingRepo.getInvoices(communityId),
        expenseRepo.getExpenses(communityId),
        incomeRepo.getVerifiedPayments(communityId),
        incomeRepo.getManualIncome(communityId),
      ]);

      final invoices = results[0] as List<Invoice>;
      final expenses = results[1] as List<Expense>;
      final verifiedPayments = results[2] as List<Payment>;
      final manualIncome = results[3] as List<ManualIncome>;

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

        // Income: verified payments + manual income in this month
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
        // Also count paid invoices as income
        for (final inv in invoices) {
          if (inv.status == InvoiceStatus.paid &&
              !inv.dueDate.isBefore(month) &&
              !inv.dueDate.isAfter(monthEnd)) {
            income += inv.amount;
          }
        }

        // Expenses in this month
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
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    if (!appState.isStaff) {
      return const Scaffold(
        body: Center(
          child: Text('Only staff can access financial reports.'),
        ),
      );
    }

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final theme = Theme.of(context);
    final netBalance = _totalIncome - _totalExpenses;
    final isPositive = netBalance >= 0;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Period selector
            _buildPeriodSelector(theme),
            const SizedBox(height: 16),

            // Summary cards
            _buildSummaryCards(theme, netBalance, isPositive),
            const SizedBox(height: 24),

            // Bar chart: Income vs Expenses by month
            _buildSectionHeader(
                theme, Icons.bar_chart, 'Monthly Income vs Expenses'),
            const SizedBox(height: 8),
            SizedBox(
              height: 300,
              child: _buildBarChart(theme),
            ),
            const SizedBox(height: 24),

            // Line chart: Cumulative trend
            _buildSectionHeader(theme, Icons.show_chart, 'Cumulative Trend'),
            const SizedBox(height: 8),
            SizedBox(
              height: 280,
              child: _buildLineChart(theme),
            ),
            const SizedBox(height: 24),

            // Pie chart: Expense breakdown by category
            if (_expenseByCategory.isNotEmpty) ...[
              _buildSectionHeader(
                  theme, Icons.pie_chart, 'Expense Breakdown by Category'),
              const SizedBox(height: 8),
              SizedBox(
                height: 280,
                child: _buildPieChart(theme),
              ),
            ],
            const SizedBox(height: 24),

            // Monthly comparison table
            _buildSectionHeader(theme, Icons.table_chart, 'Monthly Summary'),
            const SizedBox(height: 8),
            _buildComparisonTable(theme),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ============ PERIOD SELECTOR ============

  Widget _buildPeriodSelector(ThemeData theme) {
    return Row(
      children: [
        Text('Period:',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(width: 12),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 6, label: Text('6 Months')),
            ButtonSegment(value: 12, label: Text('12 Months')),
          ],
          selected: {_monthRange},
          onSelectionChanged: (sel) {
            setState(() => _monthRange = sel.first);
            _loadData();
          },
          style: ButtonStyle(
            textStyle: WidgetStatePropertyAll(
              theme.textTheme.labelMedium,
            ),
          ),
        ),
      ],
    );
  }

  // ============ SUMMARY CARDS ============

  Widget _buildSummaryCards(
      ThemeData theme, double netBalance, bool isPositive) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        final cards = [
          _SummaryCard(
            title: 'Total Income',
            amount: _currencyFormat.format(_totalIncome),
            icon: Icons.trending_up,
            color: Colors.green.shade700,
            bgColor: Colors.green.shade50,
          ),
          _SummaryCard(
            title: 'Total Expenses',
            amount: _currencyFormat.format(_totalExpenses),
            icon: Icons.trending_down,
            color: Colors.red.shade700,
            bgColor: Colors.red.shade50,
          ),
          _SummaryCard(
            title: 'Net Balance',
            amount:
                '${isPositive ? '+' : ''}${_currencyFormat.format(netBalance)}',
            icon: isPositive ? Icons.savings : Icons.warning_amber,
            color: isPositive ? Colors.blue.shade700 : Colors.orange.shade700,
            bgColor: isPositive ? Colors.blue.shade50 : Colors.orange.shade50,
          ),
        ];

        if (isWide) {
          return Row(
            children: cards
                .map((c) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: c,
                      ),
                    ))
                .toList(),
          );
        }
        return Column(
          children: cards
              .map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: c,
                  ))
              .toList(),
        );
      },
    );
  }

  // ============ BAR CHART ============

  Widget _buildBarChart(ThemeData theme) {
    if (_monthlyData.isEmpty ||
        _monthlyData.every((m) => m.income == 0 && m.expense == 0)) {
      return Center(
        child: Text('No data to display',
            style: TextStyle(color: Colors.grey[500])),
      );
    }

    final maxY = _monthlyData.fold<double>(
      0,
      (prev, m) {
        final higher = m.income > m.expense ? m.income : m.expense;
        return higher > prev ? higher : prev;
      },
    );
    final ceilY = maxY == 0 ? 5000.0 : (maxY * 1.3);
    final barWidth = _monthRange <= 6 ? 14.0 : 8.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendDot(Colors.green.shade600, 'Income'),
              const SizedBox(width: 16),
              _legendDot(Colors.red.shade400, 'Expenses'),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
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
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 55,
                      interval: ceilY / 4,
                      getTitlesWidget: (value, meta) => Text(
                        '₱${NumberFormat.compact().format(value)}',
                        style: theme.textTheme.labelSmall,
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= _monthlyData.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            _monthlyData[idx].month,
                            style: theme.textTheme.labelSmall,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: ceilY / 4,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: theme.colorScheme.outlineVariant.withOpacity(0.4),
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
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4)),
                      ),
                      BarChartRodData(
                        toY: d.expense,
                        color: Colors.red.shade400,
                        width: barWidth,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4)),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============ LINE CHART (CUMULATIVE) ============

  Widget _buildLineChart(ThemeData theme) {
    if (_monthlyData.isEmpty) {
      return Center(
        child: Text('No data to display',
            style: TextStyle(color: Colors.grey[500])),
      );
    }

    // Build cumulative data
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

    final maxY = cumulativeData.fold<double>(
      0,
      (prev, m) {
        final higher = m.income > m.expense ? m.income : m.expense;
        return higher > prev ? higher : prev;
      },
    );
    final ceilY = maxY == 0 ? 5000.0 : (maxY * 1.3);

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendDot(Colors.green.shade600, 'Cumulative Income'),
              const SizedBox(width: 16),
              _legendDot(Colors.red.shade400, 'Cumulative Expenses'),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: ceilY / 4,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color:
                        theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 55,
                      interval: ceilY / 4,
                      getTitlesWidget: (value, meta) => Text(
                        '₱${NumberFormat.compact().format(value)}',
                        style: theme.textTheme.labelSmall,
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= cumulativeData.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            cumulativeData[idx].month,
                            style: theme.textTheme.labelSmall,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
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
                          fontSize: 12,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============ PIE CHART ============

  Widget _buildPieChart(ThemeData theme) {
    final sortedEntries = _expenseByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final total = sortedEntries.fold<double>(0, (prev, e) => prev + e.value);

    final colors = [
      Colors.red.shade400,
      Colors.orange.shade400,
      Colors.amber.shade600,
      Colors.teal.shade400,
      Colors.blue.shade400,
      Colors.purple.shade400,
      Colors.pink.shade300,
      Colors.indigo.shade400,
      Colors.grey.shade500,
    ];

    return Row(
      children: [
        // Pie chart
        Expanded(
          flex: 3,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: List.generate(sortedEntries.length, (i) {
                final entry = sortedEntries[i];
                final percentage = total > 0 ? (entry.value / total * 100) : 0;
                return PieChartSectionData(
                  value: entry.value,
                  title: percentage >= 5
                      ? '${percentage.toStringAsFixed(0)}%'
                      : '',
                  color: colors[i % colors.length],
                  radius: 60,
                  titleStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                );
              }),
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Legend
        Expanded(
          flex: 2,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(sortedEntries.length, (i) {
              final entry = sortedEntries[i];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: colors[i % colors.length],
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _expenseCategoryLabel(entry.key),
                        style: theme.textTheme.labelSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      _currencyFormat.format(entry.value),
                      style: theme.textTheme.labelSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  // ============ COMPARISON TABLE ============

  Widget _buildComparisonTable(ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStatePropertyAll(Colors.grey.shade100),
          columnSpacing: 24,
          columns: const [
            DataColumn(
                label: Text('Month',
                    style: TextStyle(fontWeight: FontWeight.w600))),
            DataColumn(
                label: Text('Income',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                numeric: true),
            DataColumn(
                label: Text('Expenses',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                numeric: true),
            DataColumn(
                label:
                    Text('Net', style: TextStyle(fontWeight: FontWeight.w600)),
                numeric: true),
          ],
          rows: _monthlyData.map((m) {
            final net = m.income - m.expense;
            return DataRow(cells: [
              DataCell(Text(m.fullLabel)),
              DataCell(Text(
                _currencyFormat.format(m.income),
                style: TextStyle(color: Colors.green.shade700),
              )),
              DataCell(Text(
                _currencyFormat.format(m.expense),
                style: TextStyle(color: Colors.red.shade700),
              )),
              DataCell(Text(
                '${net >= 0 ? '+' : ''}${_currencyFormat.format(net)}',
                style: TextStyle(
                  color:
                      net >= 0 ? Colors.blue.shade700 : Colors.orange.shade700,
                  fontWeight: FontWeight.w600,
                ),
              )),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  // ============ HELPER WIDGETS ============

  Widget _buildSectionHeader(ThemeData theme, IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style:
              theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
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
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

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
  final String title;
  final String amount;
  final IconData icon;
  final Color color;
  final Color bgColor;

  const _SummaryCard({
    required this.title,
    required this.amount,
    required this.icon,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: color.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      amount,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
