import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:core_data/core_data.dart';
import 'package:core_domain/core_domain.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../adaptive/adaptive_layout.dart';
import '../widgets/file_upload_widget.dart';

const _brand = Color(0xff215e3f);

/// Shared expenses screen — adaptive for web and mobile.
class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  Future<List<Expense>>? _expensesFuture;
  ExpenseCategory? _filterCategory;
  bool _showChart = false;
  final _currencyFormat = NumberFormat.currency(symbol: '₱', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  void _loadExpenses() {
    final appState = context.read<AppState>();
    final repo = context.read<ExpenseRepository>();
    if (appState.activeCommunityId != null) {
      setState(() {
        _expensesFuture = repo.getExpenses(
          appState.activeCommunityId!,
          category: _filterCategory,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isStaff = appState.isStaff;

    return Scaffold(
      body: Column(
        children: [
          // Chart toggle + filter
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(children: [
              TextButton.icon(
                onPressed: () => setState(() => _showChart = !_showChart),
                icon: Icon(_showChart ? Icons.expand_less : Icons.show_chart,
                    size: 18),
                label: Text(_showChart ? 'Hide Chart' : 'Show Trend'),
              ),
            ]),
          ),
          if (_showChart) _ExpenseTrendChart(currencyFormat: _currencyFormat),
          // Category filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(children: [
              _categoryChip('All', null),
              ...ExpenseCategory.values
                  .map((c) => _categoryChip(_categoryLabel(c), c)),
            ]),
          ),
          const Divider(height: 1),
          // Expense list
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _loadExpenses(),
              child: FutureBuilder<List<Expense>>(
                future: _expensesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  final expenses = snapshot.data ?? [];
                  if (expenses.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.account_balance_wallet_outlined,
                              size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          const Text('No expenses recorded yet',
                              style: TextStyle(fontSize: 18)),
                        ],
                      ),
                    );
                  }

                  return AdaptiveBuilder(
                    mobile: (_) => ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: expenses.length,
                      itemBuilder: (_, i) => _ExpenseCard(
                        expense: expenses[i],
                        currencyFormat: _currencyFormat,
                        onTap: () => _showExpenseDetails(context, expenses[i]),
                      ),
                    ),
                    desktop: (_) => GridView.builder(
                      padding: const EdgeInsets.all(24),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 450,
                        childAspectRatio: 2.8,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                      ),
                      itemCount: expenses.length,
                      itemBuilder: (_, i) => _ExpenseCard(
                        expense: expenses[i],
                        currencyFormat: _currencyFormat,
                        onTap: () => _showExpenseDetails(context, expenses[i]),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: isStaff
          ? FloatingActionButton.extended(
              onPressed: () => _showCreateExpenseSheet(context),
              icon: const Icon(Icons.add),
              label: const Text('Add Expense'),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _categoryChip(String label, ExpenseCategory? category) {
    final isSelected = _filterCategory == category;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: _brand.withValues(alpha: 0.15),
        checkmarkColor: _brand,
        onSelected: (_) {
          setState(() => _filterCategory = category);
          _loadExpenses();
        },
      ),
    );
  }

  String _categoryLabel(ExpenseCategory cat) =>
      cat.name[0].toUpperCase() + cat.name.substring(1);

  void _showCreateExpenseSheet(BuildContext context, {Expense? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _CreateExpenseSheet(
            onCreated: _loadExpenses, existingExpense: existing),
      ),
    );
  }

  void _showExpenseDetails(BuildContext context, Expense expense) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        expand: false,
        builder: (context, sc) => ListView(
          controller: sc,
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(expense.description,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _DetailRow(
                label: 'Category', value: _categoryLabel(expense.category)),
            _DetailRow(
                label: 'Amount', value: _currencyFormat.format(expense.amount)),
            _DetailRow(
                label: 'Date',
                value: DateFormat('MMM d, yyyy').format(expense.expenseDate)),
            if (expense.vendor != null)
              _DetailRow(label: 'Vendor', value: expense.vendor!),
            if (expense.notes != null)
              _DetailRow(label: 'Notes', value: expense.notes!),
            if (expense.receiptUrl != null) ...[
              const SizedBox(height: 16),
              const Text('Receipt / Proof',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () =>
                    _showReceiptFullScreen(context, expense.receiptUrl!),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    expense.receiptUrl!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Icon(Icons.broken_image,
                            size: 48, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text('Tap image to view full size',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            ],
            const SizedBox(height: 16),
            if (context.read<AppState>().isStaff)
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _showCreateExpenseSheet(context, existing: expense);
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _deleteExpense(context, expense),
                    icon: const Icon(Icons.delete),
                    label: const Text('Delete'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white),
                  ),
                ),
              ]),
          ],
        ),
      ),
    );
  }

  void _showReceiptFullScreen(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                children: [
                  const Text('Receipt / Proof',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 500, maxWidth: 600),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Container(
                      height: 200,
                      color: Colors.grey[200],
                      child: const Center(
                          child: Icon(Icons.broken_image,
                              size: 48, color: Colors.grey)),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteExpense(BuildContext context, Expense expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      try {
        final repo = context.read<ExpenseRepository>();
        await repo.deleteExpense(expense.id);
        if (mounted) {
          Navigator.of(context).pop();
          _loadExpenses();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }
}

// ─── Support Widgets ─────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 100,
          child: Text(label,
              style: TextStyle(
                  color: Colors.grey[600], fontWeight: FontWeight.w500)),
        ),
        Expanded(child: Text(value)),
      ]),
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  final Expense expense;
  final NumberFormat currencyFormat;
  final VoidCallback onTap;

  const _ExpenseCard({
    required this.expense,
    required this.currencyFormat,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: _brand.withValues(alpha: 0.1),
          child: Icon(_catIcon(expense.category), color: _brand, size: 20),
        ),
        title: Text(expense.description,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${expense.category.name.toUpperCase()} • ${DateFormat('MMM d').format(expense.expenseDate)}',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: Text(currencyFormat.format(expense.amount),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      ),
    );
  }

  IconData _catIcon(ExpenseCategory cat) => switch (cat) {
        ExpenseCategory.maintenance => Icons.build,
        ExpenseCategory.utilities => Icons.electrical_services,
        ExpenseCategory.supplies => Icons.inventory,
        _ => Icons.category,
      };
}

// ─── Trend Chart ─────────────────────────────────────────────────────────────

class _ExpenseTrendChart extends StatefulWidget {
  final NumberFormat currencyFormat;
  const _ExpenseTrendChart({required this.currencyFormat});

  @override
  State<_ExpenseTrendChart> createState() => _ExpenseTrendChartState();
}

class _ExpenseTrendChartState extends State<_ExpenseTrendChart> {
  List<_MonthlyData>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final appState = context.read<AppState>();
    final repo = context.read<ExpenseRepository>();
    final communityId = appState.activeCommunityId;
    if (communityId == null) return;

    try {
      final expenses = await repo.getExpenses(communityId);
      final now = DateTime.now();
      final months = <_MonthlyData>[];
      for (int i = 5; i >= 0; i--) {
        final month = DateTime(now.year, now.month - i, 1);
        final monthEnd = DateTime(month.year, month.month + 1, 0);
        double total = 0;
        for (final e in expenses) {
          if (!e.expenseDate.isBefore(month) &&
              !e.expenseDate.isAfter(monthEnd)) {
            total += e.amount;
          }
        }
        months.add(_MonthlyData(DateFormat('MMM').format(month), total));
      }
      if (mounted)
        setState(() {
          _data = months;
          _loading = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _data == null) {
      return const SizedBox(
          height: 150, child: Center(child: CircularProgressIndicator()));
    }
    final maxY =
        _data!.fold<double>(0, (m, d) => d.total > m ? d.total : m) * 1.2;

    return Container(
      height: 180,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: LineChart(
        LineChartData(
          maxY: maxY > 0 ? maxY : 1000,
          gridData: const FlGridData(show: false),
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
                getTitlesWidget: (value, _) {
                  final i = value.toInt();
                  if (i >= 0 && i < _data!.length) {
                    return Text(_data![i].label,
                        style: const TextStyle(fontSize: 11));
                  }
                  return const Text('');
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: _data!
                  .asMap()
                  .entries
                  .map((e) => FlSpot(e.key.toDouble(), e.value.total))
                  .toList(),
              isCurved: true,
              color: _brand,
              barWidth: 3,
              dotData: const FlDotData(show: true),
              belowBarData:
                  BarAreaData(show: true, color: _brand.withValues(alpha: 0.1)),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthlyData {
  final String label;
  final double total;
  _MonthlyData(this.label, this.total);
}

// ─── Create/Edit Expense Sheet ──────────────────────────────────────────────

class _CreateExpenseSheet extends StatefulWidget {
  final VoidCallback onCreated;
  final Expense? existingExpense;
  const _CreateExpenseSheet({required this.onCreated, this.existingExpense});

  @override
  State<_CreateExpenseSheet> createState() => _CreateExpenseSheetState();
}

class _CreateExpenseSheetState extends State<_CreateExpenseSheet> {
  final _descCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _vendorCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  ExpenseCategory _category = ExpenseCategory.maintenance;
  DateTime _date = DateTime.now();
  String? _receiptUrl;
  bool _isLoading = false;

  bool get _isEditing => widget.existingExpense != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final e = widget.existingExpense!;
      _descCtrl.text = e.description;
      _amountCtrl.text = e.amount.toString();
      _vendorCtrl.text = e.vendor ?? '';
      _notesCtrl.text = e.notes ?? '';
      _category = e.category;
      _date = e.expenseDate;
      _receiptUrl = e.receiptUrl;
    }
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _amountCtrl.dispose();
    _vendorCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_isEditing ? 'Edit Expense' : 'Add Expense',
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            DropdownButtonFormField<ExpenseCategory>(
              value: _category,
              decoration: const InputDecoration(
                  labelText: 'Category', border: OutlineInputBorder()),
              items: ExpenseCategory.values
                  .map((c) => DropdownMenuItem(
                      value: c,
                      child:
                          Text(c.name[0].toUpperCase() + c.name.substring(1))))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _category = v);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                  labelText: 'Description', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount (₱)',
                border: OutlineInputBorder(),
                prefixText: '₱ ',
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: Text(DateFormat('MMM d, yyyy').format(_date)),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (d != null) setState(() => _date = d);
              },
            ),
            TextField(
              controller: _vendorCtrl,
              decoration: const InputDecoration(
                  labelText: 'Vendor (optional)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            const Text('Receipt / Proof (optional)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            if (_receiptUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  children: [
                    Image.network(
                      _receiptUrl!,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 180,
                        color: Colors.grey[200],
                        child: const Center(
                            child:
                                Icon(Icons.broken_image, color: Colors.grey)),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: IconButton(
                        onPressed: () => setState(() => _receiptUrl = null),
                        icon: const Icon(Icons.close, color: Colors.white),
                        style: IconButton.styleFrom(
                            backgroundColor: Colors.black54),
                        iconSize: 18,
                      ),
                    ),
                  ],
                ),
              )
            else
              ImageUploadWidget(
                bucket: 'expense-receipts',
                folder: Supabase.instance.client.auth.currentUser?.id,
                onUploadComplete: (url) {
                  if (url.isNotEmpty) {
                    setState(() => _receiptUrl = url);
                  }
                },
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                    backgroundColor: _brand, foregroundColor: Colors.white),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_isEditing ? 'Update' : 'Add Expense'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (_descCtrl.text.trim().isEmpty || _amountCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Description and amount are required')),
      );
      return;
    }
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount')),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final appState = context.read<AppState>();
      final repo = context.read<ExpenseRepository>();
      if (_isEditing) {
        await repo.updateExpense(
          id: widget.existingExpense!.id,
          category: _category,
          description: _descCtrl.text.trim(),
          amount: amount,
          expenseDate: _date,
          vendor:
              _vendorCtrl.text.trim().isEmpty ? null : _vendorCtrl.text.trim(),
          receiptUrl: _receiptUrl,
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        );
      } else {
        await repo.createExpense(
          communityId: appState.activeCommunityId!,
          category: _category,
          description: _descCtrl.text.trim(),
          amount: amount,
          expenseDate: _date,
          vendor:
              _vendorCtrl.text.trim().isEmpty ? null : _vendorCtrl.text.trim(),
          receiptUrl: _receiptUrl,
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        );
      }
      if (mounted) {
        Navigator.of(context).pop();
        widget.onCreated();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
