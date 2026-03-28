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

    final billingRepo = context.read<BillingRepository>();
    final expenseRepo = context.read<ExpenseRepository>();
    final incomeRepo = context.read<IncomeRepository>();

    try {
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
        for (final inv in invoices) {
          if (inv.status == InvoiceStatus.paid &&
              !inv.dueDate.isBefore(month) &&
              !inv.dueDate.isAfter(monthEnd)) {
            income += inv.amount;
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
        months.add(_MonthlyComparison(label, income, expense));
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
    final appState = context.watch<AppState>();
    if (!appState.isStaff) {
      return const Center(child: Text('Staff access required'));
    }

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final net = _totalIncome - _totalExpenses;
    final netColor = net >= 0 ? _brand : Colors.red;

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
                color: _brand,
                icon: Icons.trending_up,
              ),
              const SizedBox(width: 8),
              _SummaryCard(
                label: 'Expenses',
                value: _currencyFormat.format(_totalExpenses),
                color: Colors.red,
                icon: Icons.trending_down,
              ),
              const SizedBox(width: 8),
              _SummaryCard(
                label: 'Net',
                value: _currencyFormat.format(net),
                color: netColor,
                icon: net >= 0 ? Icons.check_circle : Icons.warning,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Bar chart
          const Text('Monthly Comparison',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: _buildBarChart(),
          ),
          const SizedBox(height: 24),

          // Expense breakdown by category
          if (_expenseByCategory.isNotEmpty) ...[
            const Text('Expense Breakdown',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            ...(_expenseByCategory.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value)))
                .map((entry) => ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: _brand.withOpacity(0.1),
                        child: Icon(Icons.category, size: 16, color: _brand),
                      ),
                      title: Text(
                        entry.key.name[0].toUpperCase() +
                            entry.key.name.substring(1),
                      ),
                      trailing: Text(
                        _currencyFormat.format(entry.value),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    )),
          ],
        ],
      ),
    );
  }

  Widget _buildBarChart() {
    if (_monthlyData.isEmpty) {
      return const Center(child: Text('No data'));
    }

    final maxY = _monthlyData.fold<double>(
            0,
            (m, d) =>
                [m, d.income, d.expense].reduce((a, b) => a > b ? a : b)) *
        1.2;

    return BarChart(
      BarChartData(
        maxY: maxY > 0 ? maxY : 1000,
        barGroups: _monthlyData.asMap().entries.map((e) {
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(toY: e.value.income, color: _brand, width: 10),
              BarChartRodData(
                  toY: e.value.expense, color: Colors.red[300]!, width: 10),
            ],
          );
        }).toList(),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i >= 0 && i < _monthlyData.length) {
                  return Text(_monthlyData[i].label,
                      style: const TextStyle(fontSize: 11));
                }
                return const Text('');
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthlyComparison {
  final String label;
  final double income;
  final double expense;
  _MonthlyComparison(this.label, this.income, this.expense);
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: 4),
                  Text(label,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
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
