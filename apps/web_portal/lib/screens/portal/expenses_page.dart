import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:core_data/core_data.dart';
import 'package:core_domain/core_domain.dart';
import 'package:core_ui/core_ui.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ExpensesPage extends StatefulWidget {
  const ExpensesPage({super.key});

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  Future<List<Expense>>? _expensesFuture;
  ExpenseCategory? _filterCategory;

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

    if (!appState.isStaff) {
      return const Scaffold(
        body: Center(
          child: Text('Only staff can access expense tracking.'),
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          // Summary header
          _ExpenseSummaryHeader(
            expensesFuture: _expensesFuture,
          ),
          // Filter bar
          _FilterBar(
            selectedCategory: _filterCategory,
            onCategoryChanged: (cat) {
              setState(() => _filterCategory = cat);
              _loadExpenses();
            },
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
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline,
                              size: 48, color: Colors.red),
                          const SizedBox(height: 16),
                          Text('Error: ${snapshot.error}'),
                          const SizedBox(height: 16),
                          HOAppButton(
                            label: 'Retry',
                            onPressed: _loadExpenses,
                          ),
                        ],
                      ),
                    );
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
                          const Text(
                            'No expenses recorded yet',
                            style: TextStyle(fontSize: 18),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap the + button to add your first expense',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: expenses.length,
                    itemBuilder: (context, index) {
                      return _ExpenseCard(
                        expense: expenses[index],
                        isAdmin: appState.isAdmin,
                        onRefresh: _loadExpenses,
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateExpenseDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
      ),
    );
  }

  void _showCreateExpenseDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _CreateExpenseDialog(onRefresh: _loadExpenses),
    );
  }
}

// ============ SUMMARY HEADER ============

class _ExpenseSummaryHeader extends StatelessWidget {
  final Future<List<Expense>>? expensesFuture;

  const _ExpenseSummaryHeader({required this.expensesFuture});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '₱', decimalDigits: 2);

    return FutureBuilder<List<Expense>>(
      future: expensesFuture,
      builder: (context, snapshot) {
        double totalThisMonth = 0;
        double totalLastMonth = 0;
        int countThisMonth = 0;

        if (snapshot.hasData) {
          final now = DateTime.now();
          final thisMonthStart = DateTime(now.year, now.month, 1);
          final lastMonthStart = DateTime(now.year, now.month - 1, 1);

          for (final e in snapshot.data!) {
            if (e.expenseDate
                .isAfter(thisMonthStart.subtract(const Duration(days: 1)))) {
              totalThisMonth += e.amount;
              countThisMonth++;
            } else if (e.expenseDate
                .isAfter(lastMonthStart.subtract(const Duration(days: 1)))) {
              totalLastMonth += e.amount;
            }
          }
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          decoration: BoxDecoration(
            color: const Color(0xff215e3f).withOpacity(0.05),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This Month',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currencyFormat.format(totalThisMonth),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xff215e3f),
                      ),
                    ),
                    Text(
                      '$countThisMonth expense${countThisMonth == 1 ? '' : 's'}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 50,
                color: Colors.grey[300],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Last Month',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currencyFormat.format(totalLastMonth),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============ FILTER BAR ============

class _FilterBar extends StatelessWidget {
  final ExpenseCategory? selectedCategory;
  final ValueChanged<ExpenseCategory?> onCategoryChanged;

  const _FilterBar({
    required this.selectedCategory,
    required this.onCategoryChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildChip(context, 'All', null),
          const SizedBox(width: 8),
          ...ExpenseCategory.values.map((cat) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildChip(context, _categoryLabel(cat), cat),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildChip(
      BuildContext context, String label, ExpenseCategory? category) {
    final isSelected = selectedCategory == category;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onCategoryChanged(isSelected ? null : category),
      selectedColor: const Color(0xff215e3f).withOpacity(0.15),
      checkmarkColor: const Color(0xff215e3f),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        color: isSelected ? const Color(0xff215e3f) : Colors.grey[700],
      ),
    );
  }

  String _categoryLabel(ExpenseCategory cat) {
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

// ============ EXPENSE CARD ============

class _ExpenseCard extends StatelessWidget {
  final Expense expense;
  final bool isAdmin;
  final VoidCallback onRefresh;

  const _ExpenseCard({
    required this.expense,
    required this.isAdmin,
    required this.onRefresh,
  });

  IconData _getCategoryIcon(ExpenseCategory cat) {
    switch (cat) {
      case ExpenseCategory.maintenance:
        return Icons.build_outlined;
      case ExpenseCategory.utilities:
        return Icons.electrical_services_outlined;
      case ExpenseCategory.supplies:
        return Icons.inventory_2_outlined;
      case ExpenseCategory.services:
        return Icons.miscellaneous_services_outlined;
      case ExpenseCategory.repairs:
        return Icons.handyman_outlined;
      case ExpenseCategory.salaries:
        return Icons.people_outlined;
      case ExpenseCategory.insurance:
        return Icons.shield_outlined;
      case ExpenseCategory.taxes:
        return Icons.account_balance_outlined;
      case ExpenseCategory.other:
        return Icons.more_horiz;
    }
  }

  String _getCategoryLabel(ExpenseCategory cat) {
    switch (cat) {
      case ExpenseCategory.maintenance:
        return 'MAINTENANCE';
      case ExpenseCategory.utilities:
        return 'UTILITIES';
      case ExpenseCategory.supplies:
        return 'SUPPLIES';
      case ExpenseCategory.services:
        return 'SERVICES';
      case ExpenseCategory.repairs:
        return 'REPAIRS';
      case ExpenseCategory.salaries:
        return 'SALARIES';
      case ExpenseCategory.insurance:
        return 'INSURANCE';
      case ExpenseCategory.taxes:
        return 'TAXES';
      case ExpenseCategory.other:
        return 'OTHER';
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '₱', decimalDigits: 2);
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showExpenseDetails(context),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xff215e3f).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _getCategoryIcon(expense.category),
                  color: const Color(0xff215e3f),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _getCategoryLabel(expense.category),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey,
                          ),
                        ),
                        if (expense.receiptUrl != null) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.receipt_long,
                              size: 14, color: Colors.grey[400]),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      expense.description,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (expense.vendor != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        expense.vendor!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      dateFormat.format(expense.expenseDate),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                currencyFormat.format(expense.amount),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  void _showExpenseDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _ExpenseDetailsDialog(
        expense: expense,
        isAdmin: isAdmin,
        onRefresh: onRefresh,
      ),
    );
  }
}

// ============ EXPENSE DETAILS DIALOG ============

class _ExpenseDetailsDialog extends StatefulWidget {
  final Expense expense;
  final bool isAdmin;
  final VoidCallback onRefresh;

  const _ExpenseDetailsDialog({
    required this.expense,
    required this.isAdmin,
    required this.onRefresh,
  });

  @override
  State<_ExpenseDetailsDialog> createState() => _ExpenseDetailsDialogState();
}

class _ExpenseDetailsDialogState extends State<_ExpenseDetailsDialog> {
  bool _isDeleting = false;

  String _getCategoryLabel(ExpenseCategory cat) {
    switch (cat) {
      case ExpenseCategory.maintenance:
        return 'MAINTENANCE';
      case ExpenseCategory.utilities:
        return 'UTILITIES';
      case ExpenseCategory.supplies:
        return 'SUPPLIES';
      case ExpenseCategory.services:
        return 'SERVICES';
      case ExpenseCategory.repairs:
        return 'REPAIRS';
      case ExpenseCategory.salaries:
        return 'SALARIES';
      case ExpenseCategory.insurance:
        return 'INSURANCE';
      case ExpenseCategory.taxes:
        return 'TAXES';
      case ExpenseCategory.other:
        return 'OTHER';
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '₱', decimalDigits: 2);
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xff215e3f),
              ),
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _getCategoryLabel(widget.expense.category),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.of(context).pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    currencyFormat.format(widget.expense.amount),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateFormat.format(widget.expense.expenseDate),
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Description
                    Text(
                      widget.expense.description,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    if (widget.expense.vendor != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.store_outlined,
                              size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Text(
                            'Vendor: ${widget.expense.vendor}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],

                    if (widget.expense.notes != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.note_outlined,
                                size: 16, color: Colors.amber[700]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.expense.notes!,
                                style: TextStyle(
                                    fontSize: 13, color: Colors.amber[900]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Receipt / proof
                    if (widget.expense.receiptUrl != null) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.receipt_long,
                              size: 18, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Text(
                            'Receipt / Proof',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () => _showReceiptDialog(
                            context, widget.expense.receiptUrl!),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          height: 180,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200),
                            color: Colors.grey.shade50,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(7),
                            child: Image.network(
                              widget.expense.receiptUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.receipt_long,
                                        size: 36, color: Colors.grey[400]),
                                    const SizedBox(height: 8),
                                    Text('Tap to view receipt',
                                        style: TextStyle(
                                            color: Colors.grey[500],
                                            fontSize: 13)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),
                    Text(
                      'Added ${dateFormat.format(widget.expense.createdAt)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                    ),
                  ],
                ),
              ),
            ),

            // Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  if (widget.isAdmin)
                    TextButton.icon(
                      onPressed:
                          _isDeleting ? null : () => _confirmDelete(context),
                      icon: _isDeleting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: Colors.red,
                            ),
                      label: Text(_isDeleting ? 'Deleting...' : 'Delete'),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                    ),
                  const Spacer(),
                  SizedBox(
                    width: 140,
                    child: HOAppButton(
                      label: 'Edit',
                      onPressed: () {
                        Navigator.of(context).pop();
                        _showEditDialog(context);
                      },
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

  void _showReceiptDialog(BuildContext context, String url) {
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

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense'),
        content: const Text(
          'Are you sure you want to delete this expense? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isDeleting = true);
    try {
      final repo = context.read<ExpenseRepository>();
      await repo.deleteExpense(widget.expense.id);
      if (mounted) {
        Navigator.of(context).pop();
        widget.onRefresh();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Expense deleted successfully'),
            backgroundColor: Color(0xff215e3f),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete expense: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showEditDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _CreateExpenseDialog(
        expense: widget.expense,
        onRefresh: widget.onRefresh,
      ),
    );
  }
}

// ============ CREATE / EDIT EXPENSE DIALOG ============

class _CreateExpenseDialog extends StatefulWidget {
  final Expense? expense;
  final VoidCallback onRefresh;

  const _CreateExpenseDialog({
    this.expense,
    required this.onRefresh,
  });

  @override
  State<_CreateExpenseDialog> createState() => _CreateExpenseDialogState();
}

class _CreateExpenseDialogState extends State<_CreateExpenseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _vendorController = TextEditingController();
  final _notesController = TextEditingController();

  ExpenseCategory _selectedCategory = ExpenseCategory.other;
  DateTime _expenseDate = DateTime.now();
  String? _receiptUrl;
  bool _isSubmitting = false;

  bool get _isEditing => widget.expense != null;

  @override
  void initState() {
    super.initState();
    if (widget.expense != null) {
      final e = widget.expense!;
      _descriptionController.text = e.description;
      _amountController.text = e.amount.toStringAsFixed(2);
      _vendorController.text = e.vendor ?? '';
      _notesController.text = e.notes ?? '';
      _selectedCategory = e.category;
      _expenseDate = e.expenseDate;
      _receiptUrl = e.receiptUrl;
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _vendorController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: EdgeInsets.zero,
      title: Container(
        decoration: const BoxDecoration(
          color: Color(0xff215e3f),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
        child: Row(
          children: [
            const Icon(Icons.account_balance_wallet_outlined,
                color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Text(_isEditing ? 'Edit Expense' : 'Add Expense',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                )),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white70),
              onPressed: () => Navigator.of(context).pop(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category selection
                Text('Category',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    )),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ExpenseCategory.values.map((category) {
                    final isSelected = _selectedCategory == category;
                    return InkWell(
                      onTap: () => setState(() => _selectedCategory = category),
                      borderRadius: BorderRadius.circular(10),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xff215e3f).withOpacity(0.1)
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xff215e3f)
                                : Colors.grey.shade200,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Text(
                          _categoryDisplayLabel(category),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: isSelected
                                ? const Color(0xff215e3f)
                                : Colors.grey[700],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'e.g., Lobby cleaning supplies',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amountController,
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixText: '₱ ',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value?.isEmpty ?? true) return 'Required';
                    final amount = double.tryParse(value!);
                    if (amount == null || amount <= 0) {
                      return 'Invalid amount';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _vendorController,
                  decoration: const InputDecoration(
                    labelText: 'Vendor / Payee (Optional)',
                    hintText: 'e.g., ABC Cleaning Services',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _expenseDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 1)),
                    );
                    if (date != null) {
                      setState(() => _expenseDate = date);
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Expense Date',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(
                      DateFormat('MMM dd, yyyy').format(_expenseDate),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Receipt / Proof (Optional)',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                ),
                const SizedBox(height: 8),
                _receiptUrl != null
                    ? ClipRRect(
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
                                    child: Icon(Icons.broken_image,
                                        color: Colors.grey)),
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: IconButton(
                                onPressed: () =>
                                    setState(() => _receiptUrl = null),
                                icon: const Icon(Icons.close,
                                    color: Colors.white),
                                style: IconButton.styleFrom(
                                    backgroundColor: Colors.black54),
                                iconSize: 18,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ImageUploadWidget(
                        bucket: 'expense-receipts',
                        folder: Supabase.instance.client.auth.currentUser?.id,
                        onUploadComplete: (url) {
                          if (url.isNotEmpty) {
                            setState(() => _receiptUrl = url);
                          }
                        },
                      ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (Optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        HOAppButton(
          label: _isSubmitting
              ? (_isEditing ? 'Saving...' : 'Adding...')
              : (_isEditing ? 'Save' : 'Add Expense'),
          onPressed: _isSubmitting ? null : _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final appState = context.read<AppState>();
      final repo = context.read<ExpenseRepository>();
      final amount = double.parse(_amountController.text);

      if (_isEditing) {
        await repo.updateExpense(
          id: widget.expense!.id,
          category: _selectedCategory,
          description: _descriptionController.text.trim(),
          amount: amount,
          expenseDate: _expenseDate,
          vendor: _vendorController.text.trim().isNotEmpty
              ? _vendorController.text.trim()
              : null,
          receiptUrl: _receiptUrl,
          notes: _notesController.text.trim().isNotEmpty
              ? _notesController.text.trim()
              : null,
        );
      } else {
        await repo.createExpense(
          communityId: appState.activeCommunityId!,
          category: _selectedCategory,
          description: _descriptionController.text.trim(),
          amount: amount,
          expenseDate: _expenseDate,
          vendor: _vendorController.text.trim().isNotEmpty
              ? _vendorController.text.trim()
              : null,
          receiptUrl: _receiptUrl,
          notes: _notesController.text.trim().isNotEmpty
              ? _notesController.text.trim()
              : null,
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing
                ? 'Expense updated successfully'
                : 'Expense added successfully'),
          ),
        );
        widget.onRefresh();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  String _categoryDisplayLabel(ExpenseCategory cat) {
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
