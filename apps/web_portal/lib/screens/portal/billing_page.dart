import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:core_data/core_data.dart';
import 'package:core_domain/core_domain.dart';
import 'package:core_ui/core_ui.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';

String _unitLabel(Unit unit) {
  final label = 'Unit ${unit.unitNumber}';
  if (unit.unitType != null && unit.unitType!.isNotEmpty) {
    return '$label (${unit.unitType})';
  }
  return label;
}

Widget _buildUnitAutocomplete({
  required List<Unit> units,
  required String? selectedUnitId,
  required ValueChanged<String?> onSelected,
  required String? Function(String?) validator,
  Key? key,
}) {
  // Find the initial text for the selected unit
  final initialUnit = selectedUnitId != null
      ? units
          .cast<Unit?>()
          .firstWhere((u) => u!.id == selectedUnitId, orElse: () => null)
      : null;

  return Autocomplete<Unit>(
    key: key,
    initialValue: initialUnit != null
        ? TextEditingValue(text: _unitLabel(initialUnit))
        : TextEditingValue.empty,
    displayStringForOption: _unitLabel,
    optionsBuilder: (textEditingValue) {
      if (textEditingValue.text.isEmpty) return units;
      final query = textEditingValue.text.toLowerCase();
      return units.where((unit) {
        return unit.unitNo.toLowerCase().contains(query) ||
            (unit.unitType?.toLowerCase().contains(query) ?? false);
      });
    },
    onSelected: (unit) => onSelected(unit.id),
    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
      return TextFormField(
        controller: controller,
        focusNode: focusNode,
        decoration: InputDecoration(
          labelText: 'Unit',
          hintText: 'Type to search units...',
          prefixIcon: const Icon(Icons.apartment, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
                color: Theme.of(context).colorScheme.primary, width: 1.5),
          ),
        ),
        validator: validator,
        onChanged: (value) {
          // Clear selection if user edits text manually
          final match = units
              .cast<Unit?>()
              .firstWhere((u) => _unitLabel(u!) == value, orElse: () => null);
          if (match == null) onSelected(null);
        },
      );
    },
    optionsViewBuilder: (context, onAutoSelected, options) {
      return Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200, maxWidth: 400),
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: options.length,
              itemBuilder: (context, index) {
                final unit = options.elementAt(index);
                return ListTile(
                  leading: const Icon(Icons.apartment, size: 20),
                  title: Text(_unitLabel(unit)),
                  dense: true,
                  onTap: () => onAutoSelected(unit),
                );
              },
            ),
          ),
        ),
      );
    },
  );
}

class BillingPage extends StatefulWidget {
  const BillingPage({super.key});

  @override
  State<BillingPage> createState() => _BillingPageState();
}

class _BillingPageState extends State<BillingPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _showChart = true;
  int _myPendingCount = 0;
  int _allPendingCount = 0;
  int _dueRecurringCount = 0;

  @override
  void initState() {
    super.initState();
    final appState = context.read<AppState>();
    final isStaff = appState.isStaff;
    _tabController = TabController(length: isStaff ? 4 : 1, vsync: this);
    if (isStaff) {
      _loadTabBadges();
      _autoGenerateInvoices();
    }
  }

  Future<void> _loadTabBadges() async {
    final appState = context.read<AppState>();
    final communityId = appState.activeCommunityId;
    if (communityId == null) return;

    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;

    try {
      // All pending payments in community
      final allResult = await client
          .from('payments')
          .select('id')
          .eq('community_id', communityId)
          .eq('status', 'submitted')
          .count(CountOption.exact);

      int myCount = 0;
      if (userId != null) {
        // Get all units the user belongs to
        final householdRows = await client
            .from('household_members')
            .select('unit_id')
            .eq('user_id', userId);

        final unitIds = (householdRows as List)
            .map((e) => e['unit_id'] as String)
            .toSet()
            .toList();

        if (unitIds.isNotEmpty) {
          // Get invoice IDs for user's units
          final invoiceIds = await client
              .from('invoices')
              .select('id')
              .eq('community_id', communityId)
              .inFilter('unit_id', unitIds);
          final ids =
              (invoiceIds as List).map((e) => e['id'] as String).toList();
          if (ids.isNotEmpty) {
            final myResult = await client
                .from('payments')
                .select('id')
                .eq('community_id', communityId)
                .eq('status', 'submitted')
                .inFilter('invoice_id', ids)
                .count(CountOption.exact);
            myCount = myResult.count;
          }
        }
      }

      if (mounted) {
        setState(() {
          _allPendingCount = allResult.count;
          _myPendingCount = myCount;
        });
      }
    } catch (e) {
      // Silently fail — badges are non-critical
    }
  }

  Future<void> _autoGenerateInvoices() async {
    final appState = context.read<AppState>();
    final communityId = appState.activeCommunityId;
    if (communityId == null) return;

    try {
      final repo = context.read<RecurringBillingRepository>();
      final dueItems = await repo.getDueRecurringBillings(communityId);
      if (mounted) {
        setState(() => _dueRecurringCount = dueItems.length);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildTabLabel(String text, int count) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count > 99 ? '99+' : '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isStaff = appState.isStaff;

    return Scaffold(
      body: Column(
        children: [
          // Billing trend chart (collapsible)
          _BillingTrendChart(
            visible: _showChart,
            onToggle: () => setState(() => _showChart = !_showChart),
          ),
          if (isStaff)
            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabs: [
                _buildTabLabel('My Invoices', _myPendingCount),
                _buildTabLabel('All Invoices', _allPendingCount),
                _buildTabLabel('Recurring Invoices', _dueRecurringCount),
                const Tab(text: 'Income'),
              ],
            ),
          Expanded(
            child: isStaff
                ? TabBarView(
                    controller: _tabController,
                    children: [
                      const _InvoiceListView(showMyInvoices: true),
                      const _InvoiceListView(showMyInvoices: false),
                      _RecurringBillingView(
                        onInvoicesGenerated: () {
                          _loadTabBadges();
                          _autoGenerateInvoices();
                        },
                      ),
                      const _IncomeTrackerView(),
                    ],
                  )
                : const _InvoiceListView(showMyInvoices: true),
          ),
        ],
      ),
      floatingActionButton: isStaff
          ? FloatingActionButton.extended(
              onPressed: () => _showCreateInvoiceDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Create Invoice'),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  void _showCreateInvoiceDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _CreateInvoiceDialog(),
    );
  }
}

// ============ BILLING TREND CHART ============

class _BillingTrendChart extends StatefulWidget {
  final bool visible;
  final VoidCallback onToggle;

  const _BillingTrendChart({required this.visible, required this.onToggle});

  @override
  State<_BillingTrendChart> createState() => _BillingTrendChartState();
}

class _BillingTrendChartState extends State<_BillingTrendChart> {
  List<_MonthlyData>? _monthlyData;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadChartData();
  }

  Future<void> _loadChartData() async {
    final appState = context.read<AppState>();
    final repo = context.read<BillingRepository>();
    final communityId = appState.activeCommunityId;
    if (communityId == null) return;

    try {
      final invoices = appState.isStaff
          ? await repo.getInvoices(communityId)
          : await repo.getMyInvoices(communityId);
      // Aggregate by month (last 5 months + current + next)
      final now = DateTime.now();
      final months = <_MonthlyData>[];
      for (int i = 5; i >= -1; i--) {
        final month = DateTime(now.year, now.month - i, 1);
        final monthEnd = DateTime(month.year, month.month + 1, 0);
        final label = DateFormat('MMM').format(month);
        double charged = 0;
        double paid = 0;
        for (final inv in invoices) {
          if (inv.dueDate.isAfter(month.subtract(const Duration(days: 1))) &&
              inv.dueDate.isBefore(monthEnd.add(const Duration(days: 1)))) {
            charged += inv.amount;
            if (inv.status == InvoiceStatus.paid) {
              paid += inv.amount;
            }
          }
        }
        months.add(_MonthlyData(label, charged, paid));
      }
      if (mounted)
        setState(() {
          _monthlyData = months;
          _loading = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        InkWell(
          onTap: widget.onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.trending_up,
                    size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Billing Trend',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const Spacer(),
                Icon(
                  widget.visible ? Icons.expand_less : Icons.expand_more,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        ),
        if (widget.visible)
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            child: _loading
                ? const SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  )
                : (_monthlyData == null ||
                        _monthlyData!.every((m) => m.charged == 0))
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text('No billing data to display',
                            style: TextStyle(color: Colors.grey[500])),
                      )
                    : SizedBox(
                        height: 220,
                        child: _buildChart(theme),
                      ),
          ),
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildChart(ThemeData theme) {
    final data = _monthlyData!;
    final maxY = data.fold<double>(
        0,
        (prev, m) =>
            m.charged > prev ? m.charged : (m.paid > prev ? m.paid : prev));
    final ceilY = maxY == 0 ? 5000.0 : (maxY * 1.3);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 24, 8),
      child: Column(
        children: [
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendDot(Colors.orangeAccent, 'Charged'),
              const SizedBox(width: 16),
              _legendDot(theme.colorScheme.tertiary, 'Paid'),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: ceilY / 4,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: theme.colorScheme.outlineVariant.withOpacity(0.4),
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
                        if (idx < 0 || idx >= data.length)
                          return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(data[idx].month,
                              style: theme.textTheme.labelSmall),
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
                    spots: List.generate(data.length,
                        (i) => FlSpot(i.toDouble(), data[i].charged)),
                    isCurved: true,
                    color: theme.colorScheme.primary,
                    barWidth: 3,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                        radius: 3,
                        color: theme.colorScheme.primary,
                        strokeColor: Colors.white,
                        strokeWidth: 1.5,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: theme.colorScheme.primary.withOpacity(0.08),
                    ),
                  ),
                  LineChartBarData(
                    spots: List.generate(
                        data.length, (i) => FlSpot(i.toDouble(), data[i].paid)),
                    isCurved: true,
                    color: theme.colorScheme.tertiary,
                    barWidth: 3,
                    dashArray: [6, 4],
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                        radius: 3,
                        color: theme.colorScheme.tertiary,
                        strokeColor: Colors.white,
                        strokeWidth: 1.5,
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) => spots.map((s) {
                      final isCharged = s.barIndex == 0;
                      return LineTooltipItem(
                        '${isCharged ? "Charged" : "Paid"}: ₱${NumberFormat('#,##0').format(s.y)}',
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
}

class _MonthlyData {
  final String month;
  final double charged;
  final double paid;
  _MonthlyData(this.month, this.charged, this.paid);
}

class _InvoiceListView extends StatefulWidget {
  final bool showMyInvoices;

  const _InvoiceListView({required this.showMyInvoices});

  @override
  State<_InvoiceListView> createState() => _InvoiceListViewState();
}

class _InvoiceListViewState extends State<_InvoiceListView> {
  Future<List<Invoice>>? _invoicesFuture;

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  void _loadInvoices() {
    final appState = context.read<AppState>();
    final repo = context.read<BillingRepository>();

    if (appState.activeCommunityId != null) {
      setState(() {
        _invoicesFuture = widget.showMyInvoices
            ? repo.getMyInvoices(appState.activeCommunityId!)
            : repo.getInvoices(appState.activeCommunityId!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isStaff = appState.isStaff;

    return RefreshIndicator(
      onRefresh: () async => _loadInvoices(),
      child: FutureBuilder<List<Invoice>>(
        future: _invoicesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _loadInvoices,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            );
          }

          final invoices = snapshot.data ?? [];

          if (invoices.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    widget.showMyInvoices
                        ? 'No invoices yet'
                        : 'No invoices in the system',
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.showMyInvoices
                        ? 'Invoices will appear here when issued'
                        : 'Create the first invoice to get started',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: invoices.length,
            itemBuilder: (context, index) {
              final invoice = invoices[index];
              return _InvoiceCard(
                invoice: invoice,
                isStaff: isStaff,
                isAdmin: appState.isAdmin,
                onRefresh: _loadInvoices,
              );
            },
          );
        },
      ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  final Invoice invoice;
  final bool isStaff;
  final bool isAdmin;
  final VoidCallback onRefresh;

  const _InvoiceCard({
    required this.invoice,
    required this.isStaff,
    required this.isAdmin,
    required this.onRefresh,
  });

  Color _getStatusColor(Invoice invoice) {
    if (invoice.status == InvoiceStatus.paid)
      return Color.fromRGBO(39, 99, 67, 1);
    if (invoice.isOverdue) return Colors.red;
    return Colors.orange;
  }

  String _getStatusText(Invoice invoice) {
    if (invoice.status == InvoiceStatus.paid) return 'PAID';
    if (invoice.isOverdue) return 'OVERDUE';
    return 'UNPAID';
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '₱', decimalDigits: 2);
    final dateFormat = DateFormat('MMM dd, yyyy');

    String categoryLabel;
    switch (invoice.category) {
      case InvoiceCategory.dues:
        categoryLabel = 'MONTHLY DUES';
        break;
      case InvoiceCategory.water:
        categoryLabel = 'WATER BILLING';
        break;
      case InvoiceCategory.amenity:
        categoryLabel = 'AMENITY';
        break;
      case InvoiceCategory.insurance:
        categoryLabel = 'FIRE INSURANCE';
        break;
      case InvoiceCategory.other:
        categoryLabel = 'OTHER';
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showInvoiceDetails(context),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          categoryLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(invoice).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _getStatusText(invoice),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _getStatusColor(invoice),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (invoice.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        invoice.description!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                    if (invoice.periodStart != null &&
                        invoice.periodEnd != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${dateFormat.format(invoice.periodStart!)} – ${dateFormat.format(invoice.periodEnd!)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      currencyFormat.format(invoice.amount),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Due: ${dateFormat.format(invoice.dueDate)}',
                      style: TextStyle(
                        fontSize: 14,
                        color:
                            invoice.isOverdue ? Colors.red : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showInvoiceDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _InvoiceDetailsDialog(
        invoice: invoice,
        isStaff: isStaff,
        isAdmin: isAdmin,
        onRefresh: onRefresh,
      ),
    );
  }
}

class _InvoiceDetailsDialog extends StatefulWidget {
  final Invoice invoice;
  final bool isStaff;
  final bool isAdmin;
  final VoidCallback onRefresh;

  const _InvoiceDetailsDialog({
    required this.invoice,
    required this.isStaff,
    required this.isAdmin,
    required this.onRefresh,
  });

  @override
  State<_InvoiceDetailsDialog> createState() => _InvoiceDetailsDialogState();
}

class _InvoiceDetailsDialogState extends State<_InvoiceDetailsDialog> {
  Future<List<Payment>>? _paymentsFuture;
  Future<List<InvoiceLineItem>>? _lineItemsFuture;
  bool _isDeleting = false;
  bool _isPrinting = false;
  bool _isPrintingAR = false;
  String? _unitNo;
  late InvoiceStatus _currentStatus;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.invoice.status;
    _loadPayments();
    _loadLineItems();
    _loadUnitNo();
  }

  void _loadUnitNo() async {
    try {
      final result = await Supabase.instance.client
          .from('units')
          .select('unit_no')
          .eq('id', widget.invoice.unitId)
          .maybeSingle();
      if (result != null && mounted) {
        setState(() {
          _unitNo = result['unit_no'] as String?;
        });
      }
    } catch (_) {}
  }

  void _loadLineItems() {
    final repo = context.read<BillingRepository>();
    setState(() {
      _lineItemsFuture = repo.getLineItems(widget.invoice.id);
    });
  }

  void _loadPayments() {
    final repo = context.read<BillingRepository>();
    setState(() {
      _paymentsFuture = repo.getPaymentsForInvoice(widget.invoice.id);
    });
  }

  Future<void> _refreshInvoiceStatus() async {
    try {
      final row = await Supabase.instance.client
          .from('invoices')
          .select('status')
          .eq('id', widget.invoice.id)
          .single();
      if (mounted) {
        setState(() {
          final s = row['status'] as String;
          _currentStatus =
              s == 'paid' ? InvoiceStatus.paid : InvoiceStatus.unpaid;
        });
      }
    } catch (_) {}
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
        constraints: const BoxConstraints(maxWidth: 540),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Green header
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getCategoryLabel(widget.invoice.category),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          widget.invoice.status == InvoiceStatus.paid
                              ? 'PAID'
                              : widget.invoice.isOverdue
                                  ? 'OVERDUE'
                                  : 'UNPAID',
                          style: TextStyle(
                            color: widget.invoice.status == InvoiceStatus.paid
                                ? Colors.white
                                : widget.invoice.isOverdue
                                    ? Colors.red[200]
                                    : Colors.amber[200],
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.of(context).pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (_unitNo != null) ...[
                        Text(
                          'Unit $_unitNo',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Text(
                        'INV-${widget.invoice.id.substring(0, 8).toUpperCase()}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                          fontFamily: 'monospace',
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    currencyFormat.format(widget.invoice.amount),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Due ${dateFormat.format(widget.invoice.dueDate)}',
                    style: TextStyle(
                      color: widget.invoice.isOverdue
                          ? Colors.red[200]
                          : Colors.white60,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Period info
                    if (widget.invoice.periodStart != null ||
                        widget.invoice.periodEnd != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            if (widget.invoice.description != null)
                              Text(
                                widget.invoice.description!,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            if (widget.invoice.periodStart != null &&
                                widget.invoice.periodEnd != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Period: ${dateFormat.format(widget.invoice.periodStart!)} – ${dateFormat.format(widget.invoice.periodEnd!)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Line items breakdown
                    FutureBuilder<List<InvoiceLineItem>>(
                      future: _lineItemsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Center(
                                child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))),
                          );
                        }

                        final items = snapshot.data ?? [];

                        if (items.isEmpty) {
                          return _buildTotalRow(currencyFormat);
                        }

                        return Column(
                          children: [
                            ...items.map((item) => Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border:
                                        Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item.label,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            currencyFormat.format(item.amount),
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (item.description != null &&
                                          item.description!.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          item.description!,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                      if (item.periodStart != null &&
                                          item.periodEnd != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Period: ${dateFormat.format(item.periodStart!)} - ${dateFormat.format(item.periodEnd!)}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                )),
                            const Divider(height: 16),
                            _buildTotalRow(currencyFormat),
                          ],
                        );
                      },
                    ),

                    if (widget.invoice.notes != null) ...[
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
                                widget.invoice.notes!,
                                style: TextStyle(
                                    fontSize: 13, color: Colors.amber[900]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.payments_outlined,
                            size: 18, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text(
                          'Payment History',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FutureBuilder<List<Payment>>(
                      future: _paymentsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }

                        final payments = snapshot.data ?? [];

                        if (payments.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'No payments submitted yet',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          );
                        }

                        return Column(
                          children: payments.map((payment) {
                            return _PaymentCard(
                              payment: payment,
                              isStaff: widget.isStaff,
                              onRefresh: () {
                                _loadPayments();
                                _refreshInvoiceStatus();
                                widget.onRefresh();
                              },
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Actions bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  if (widget.isAdmin)
                    TextButton.icon(
                      onPressed: _isDeleting
                          ? null
                          : () => _confirmDeleteInvoice(context),
                      icon: _isDeleting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.delete_outline,
                              size: 18, color: Colors.red),
                      label: Text(_isDeleting ? 'Deleting...' : 'Delete'),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                    ),
                  TextButton.icon(
                    onPressed:
                        _isPrinting ? null : () => _printInvoice(context),
                    icon: _isPrinting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.print, size: 18),
                    label: Text(_isPrinting ? 'Preparing...' : 'Print Invoice'),
                  ),
                  if (_currentStatus == InvoiceStatus.paid)
                    TextButton.icon(
                      onPressed:
                          _isPrintingAR ? null : () => _generateOR(context),
                      icon: _isPrintingAR
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.receipt_long, size: 18),
                      label: Text(_isPrintingAR ? 'Preparing...' : 'Print AR'),
                    ),
                  const Spacer(),
                  if (_currentStatus == InvoiceStatus.unpaid)
                    SizedBox(
                      width: 180,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _showPaymentSubmissionDialog(context);
                        },
                        icon: const Icon(Icons.payment, color: Colors.white),
                        label: const Text('Submit Payment',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
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

  Future<void> _confirmDeleteInvoice(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Invoice'),
        content: const Text(
          'Are you sure you want to delete this invoice? This will also delete all associated payments and line items. This action cannot be undone.',
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
      final repo = context.read<BillingRepository>();
      await repo.deleteInvoice(widget.invoice.id);
      if (mounted) {
        Navigator.of(context).pop();
        widget.onRefresh();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invoice deleted successfully'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete invoice: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showPaymentSubmissionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _PaymentSubmissionDialog(
        invoice: widget.invoice,
        onRefresh: widget.onRefresh,
      ),
    );
  }

  /// Look up a user's full name from the profiles table by user ID and community.
  Future<String?> _lookupUserName(String? userId, {String? communityId}) async {
    if (userId == null) return null;
    try {
      // Try with community_id first (composite PK)
      if (communityId != null) {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('full_name')
            .eq('user_id', userId)
            .eq('community_id', communityId)
            .maybeSingle();
        final name = profile?['full_name'] as String?;
        if (name != null && name.trim().isNotEmpty) return name;
      }
      // Fall back: query without community_id (picks any community profile)
      final rows = await Supabase.instance.client
          .from('profiles')
          .select('full_name')
          .eq('user_id', userId)
          .limit(1);
      if (rows.isNotEmpty) {
        final name = rows.first['full_name'] as String?;
        if (name != null && name.trim().isNotEmpty) return name;
      }
    } catch (e) {
      debugPrint('_lookupUserName error for $userId: $e');
    }
    return null;
  }

  Future<void> _printInvoice(BuildContext context) async {
    setState(() => _isPrinting = true);
    try {
      final repo = context.read<BillingRepository>();

      // Load line items
      final lineItems = await repo.getLineItems(widget.invoice.id);

      // Load community
      final communityRow = await Supabase.instance.client
          .from('communities')
          .select()
          .eq('id', widget.invoice.communityId)
          .single();
      final community = Community.fromJson(communityRow);

      // Load owner name (primary household member, or any member as fallback)
      String? ownerName;
      final cid = widget.invoice.communityId;
      try {
        // Try primary member first
        var hm = await Supabase.instance.client
            .from('household_members')
            .select('user_id')
            .eq('unit_id', widget.invoice.unitId)
            .eq('member_role', 'primary')
            .maybeSingle();
        debugPrint(
            'Owner lookup - primary hm: $hm for unit ${widget.invoice.unitId}');
        // Fall back to any household member
        hm ??= await Supabase.instance.client
            .from('household_members')
            .select('user_id')
            .eq('unit_id', widget.invoice.unitId)
            .limit(1)
            .maybeSingle();
        debugPrint('Owner lookup - final hm: $hm');
        ownerName =
            await _lookupUserName(hm?['user_id'] as String?, communityId: cid);
        debugPrint('Owner lookup - ownerName: $ownerName');
      } catch (e) {
        debugPrint('Owner lookup error: $e');
      }

      // Prepared by = invoice creator (fall back to current user for old invoices)
      String? preparedBy =
          await _lookupUserName(widget.invoice.createdBy, communityId: cid);
      final currentUser = Supabase.instance.client.auth.currentUser;
      preparedBy ??= await _lookupUserName(currentUser?.id, communityId: cid);

      // Approved by = verifier of the verified payment (if any)
      String? approvedBy;
      try {
        final payments = await repo.getPaymentsForInvoice(widget.invoice.id);
        final verified =
            payments.where((p) => p.status == PaymentStatus.verified).toList();
        if (verified.isNotEmpty) {
          approvedBy = await _lookupUserName(verified.first.verifiedBy,
              communityId: cid);
        }
      } catch (_) {}

      final pdfService = PDFService();
      final pdfBytes = await pdfService.generateOfficialReceipt(
        community: community,
        invoice: widget.invoice,
        lineItems: lineItems,
        unitNo: _unitNo ?? '-',
        ownerName: ownerName,
        preparedBy: preparedBy,
        approvedBy: approvedBy,
        logoUrl: community.logoUrl,
        styleOverride: 'detailed',
      );

      await pdfService.previewPDF(
        pdfBytes,
        'INV-${widget.invoice.id.substring(0, 8).toUpperCase()}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to print invoice: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  Future<void> _generateOR(BuildContext context) async {
    // Show modal to collect AR details before printing
    final arDetails = await showDialog<_ARDetails>(
      context: context,
      builder: (ctx) => _ARDetailsDialog(
        defaultArNo: widget.invoice.id.substring(0, 8).toUpperCase(),
      ),
    );
    if (arDetails == null) return; // user cancelled

    setState(() => _isPrintingAR = true);
    try {
      final repo = context.read<BillingRepository>();

      // Load line items
      final lineItems = await repo.getLineItems(widget.invoice.id);

      // Load community
      final communityRow = await Supabase.instance.client
          .from('communities')
          .select()
          .eq('id', widget.invoice.communityId)
          .single();
      final community = Community.fromJson(communityRow);

      // Load name of the person who submitted the verified payment
      String? ownerName;
      final cid = widget.invoice.communityId;
      try {
        final payments = await repo.getPaymentsForInvoice(widget.invoice.id);
        final verified =
            payments.where((p) => p.status == PaymentStatus.verified).toList();
        if (verified.isNotEmpty) {
          ownerName =
              await _lookupUserName(verified.first.userId, communityId: cid);
        }
      } catch (_) {}
      // Fall back to primary household member if no verified payment found
      if (ownerName == null) {
        try {
          var hm = await Supabase.instance.client
              .from('household_members')
              .select('user_id')
              .eq('unit_id', widget.invoice.unitId)
              .eq('member_role', 'primary')
              .maybeSingle();
          hm ??= await Supabase.instance.client
              .from('household_members')
              .select('user_id')
              .eq('unit_id', widget.invoice.unitId)
              .limit(1)
              .maybeSingle();
          ownerName = await _lookupUserName(hm?['user_id'] as String?,
              communityId: cid);
        } catch (_) {}
      }

      final pdfService = PDFService();
      final pdfBytes = await pdfService.generateOfficialReceipt(
        community: community,
        invoice: widget.invoice,
        lineItems: lineItems,
        unitNo: _unitNo ?? '-',
        ownerName: ownerName,
        receivedBy: arDetails.receivedBy,
        arNumber: arDetails.arNo,
        paymentType: arDetails.paymentType,
        logoUrl: community.logoUrl,
        styleOverride: 'acknowledgement',
      );

      await pdfService.previewPDF(
        pdfBytes,
        'OR-${widget.invoice.id.substring(0, 8).toUpperCase()}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate OR: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPrintingAR = false);
    }
  }

  Widget _buildTotalRow(NumberFormat currencyFormat) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Total',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          currencyFormat.format(widget.invoice.amount),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }

  String _getCategoryLabel(InvoiceCategory category) {
    switch (category) {
      case InvoiceCategory.dues:
        return 'MONTHLY DUES';
      case InvoiceCategory.water:
        return 'WATER BILLING';
      case InvoiceCategory.amenity:
        return 'AMENITY';
      case InvoiceCategory.insurance:
        return 'FIRE INSURANCE';
      case InvoiceCategory.other:
        return 'OTHER';
    }
  }
}

// ── AR Details for Print AR modal ──

class _ARDetails {
  final String arNo;
  final String paymentType;
  final String receivedBy;
  _ARDetails({
    required this.arNo,
    required this.paymentType,
    required this.receivedBy,
  });
}

class _ARDetailsDialog extends StatefulWidget {
  final String defaultArNo;
  const _ARDetailsDialog({required this.defaultArNo});

  @override
  State<_ARDetailsDialog> createState() => _ARDetailsDialogState();
}

class _ARDetailsDialogState extends State<_ARDetailsDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _arNoController;
  late final TextEditingController _receivedByController;
  String _paymentType = 'CASH PAYMENT';

  @override
  void initState() {
    super.initState();
    _arNoController = TextEditingController(text: widget.defaultArNo);
    _receivedByController = TextEditingController();
  }

  @override
  void dispose() {
    _arNoController.dispose();
    _receivedByController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('AR Details'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _arNoController,
              decoration: const InputDecoration(
                labelText: 'AR No.',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _paymentType,
              decoration: const InputDecoration(
                labelText: 'Payment Type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                    value: 'CASH PAYMENT', child: Text('Cash Payment')),
                DropdownMenuItem(
                    value: 'ONLINE PAYMENT', child: Text('Online Payment')),
                DropdownMenuItem(
                    value: 'BANK OR CHECK', child: Text('Bank or Check')),
              ],
              onChanged: (v) => setState(() => _paymentType = v!),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _receivedByController,
              decoration: const InputDecoration(
                labelText: 'Received by',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.of(context).pop(_ARDetails(
                arNo: _arNoController.text.trim(),
                paymentType: _paymentType,
                receivedBy: _receivedByController.text.trim(),
              ));
            }
          },
          child: const Text('Print'),
        ),
      ],
    );
  }
}

class _PaymentCard extends StatefulWidget {
  final Payment payment;
  final bool isStaff;
  final VoidCallback onRefresh;

  const _PaymentCard({
    required this.payment,
    required this.isStaff,
    required this.onRefresh,
  });

  @override
  State<_PaymentCard> createState() => _PaymentCardState();
}

class _PaymentCardState extends State<_PaymentCard> {
  bool _isProcessing = false;

  Payment get payment => widget.payment;
  bool get isStaff => widget.isStaff;

  Color _getPaymentStatusColor() {
    switch (payment.status) {
      case PaymentStatus.verified:
        return Color.fromRGBO(39, 99, 67, 1);
      case PaymentStatus.rejected:
        return Colors.red;
      case PaymentStatus.submitted:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '₱', decimalDigits: 2);
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  currencyFormat.format(payment.amount),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getPaymentStatusColor().withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    payment.status.name.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _getPaymentStatusColor(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Posted: ${dateFormat.format(payment.postedAt)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            if (payment.proofUrl != null) ...[
              const SizedBox(height: 10),
              InkWell(
                onTap: () => _showProofDialog(context, payment.proofUrl!),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 72,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                    color: Colors.grey.shade50,
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(7)),
                        child: Image.network(
                          payment.proofUrl!,
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 72,
                            color: Colors.grey[200],
                            child: const Icon(Icons.receipt_long,
                                color: Colors.grey, size: 28),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Payment Proof',
                                style: TextStyle(
                                    fontWeight: FontWeight.w500, fontSize: 13)),
                            const SizedBox(height: 2),
                            Text('Tap to view full image',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey[500])),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Icon(Icons.open_in_new,
                            size: 16, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (payment.status == PaymentStatus.rejected &&
                payment.rejectionReason != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        payment.rejectionReason!,
                        style: const TextStyle(fontSize: 12, color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (isStaff && payment.status == PaymentStatus.submitted) ...[
              const SizedBox(height: 8),
              if (_isProcessing)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 10),
                        Text('Processing...',
                            style: TextStyle(fontSize: 13, color: Colors.grey)),
                      ],
                    ),
                  ),
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _rejectPayment(context),
                      icon:
                          const Icon(Icons.close, size: 16, color: Colors.red),
                      label: const Text('Reject'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _verifyPayment(context),
                      icon: const Icon(Icons.check,
                          size: 16, color: Colors.white),
                      label: const Text('Verify'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color.fromRGBO(39, 99, 67, 1),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _verifyPayment(BuildContext context) async {
    setState(() => _isProcessing = true);
    try {
      final repo = context.read<BillingRepository>();
      await repo.verifyPayment(paymentId: payment.id, verified: true);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment verified successfully')),
        );
        widget.onRefresh();
      }
    } catch (e) {
      if (mounted) setState(() => _isProcessing = false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showProofDialog(BuildContext context, String url) {
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
                  const Text('Payment Proof',
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

  Future<void> _rejectPayment(BuildContext context) async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: EdgeInsets.zero,
        title: Container(
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded,
                    color: Colors.red, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Reject Payment',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        )),
                    SizedBox(height: 2),
                    Text('This action cannot be undone',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red,
                        )),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(false),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Please provide a reason for rejection:',
                  style: TextStyle(fontSize: 14)),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Enter reason...',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 1.5),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.close, size: 18, color: Colors.white),
            label: const Text('Reject Payment'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      setState(() => _isProcessing = true);
      try {
        final repo = context.read<BillingRepository>();
        await repo.verifyPayment(
          paymentId: payment.id,
          verified: false,
          rejectionReason: reasonController.text,
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Payment rejected')),
          );
          widget.onRefresh();
        }
      } catch (e) {
        if (mounted) setState(() => _isProcessing = false);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }

    reasonController.dispose();
  }
}

class _PaymentSubmissionDialog extends StatefulWidget {
  final Invoice invoice;
  final VoidCallback onRefresh;

  const _PaymentSubmissionDialog({
    required this.invoice,
    required this.onRefresh,
  });

  @override
  State<_PaymentSubmissionDialog> createState() =>
      _PaymentSubmissionDialogState();
}

class _PaymentSubmissionDialogState extends State<_PaymentSubmissionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  String? _proofUrl;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.invoice.amount.toString();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '₱', decimalDigits: 2);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: EdgeInsets.zero,
      title: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Submit Payment',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      )),
                  const SizedBox(height: 4),
                  Text(
                    'Invoice: ${currencyFormat.format(widget.invoice.amount)}',
                    style: const TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                ],
              ),
            ),
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
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: 'Amount Paid',
                  prefixText: '₱ ',
                  prefixIcon: const Icon(Icons.payments_outlined, size: 20),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 1.5),
                  ),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Required';
                  final amount = double.tryParse(value!);
                  if (amount == null) return 'Invalid amount';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Proof of Payment',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              ),
              const SizedBox(height: 8),
              _proofUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(
                        children: [
                          Image.network(
                            _proofUrl!,
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
                              onPressed: () => setState(() => _proofUrl = null),
                              icon:
                                  const Icon(Icons.close, color: Colors.white),
                              style: IconButton.styleFrom(
                                  backgroundColor: Colors.black54),
                              iconSize: 18,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ImageUploadWidget(
                      bucket: 'payment-proofs',
                      folder: Supabase.instance.client.auth.currentUser?.id,
                      onUploadComplete: (url) {
                        if (url.isNotEmpty) {
                          setState(() => _proofUrl = url);
                        }
                      },
                    ),
            ],
          ),
        ),
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _isSubmitting ? null : _submitPayment,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_rounded, color: Colors.white),
            label: Text(_isSubmitting ? 'Submitting...' : 'Submit',
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _submitPayment() async {
    if (!_formKey.currentState!.validate()) return;

    if (_proofUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload proof of payment')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final appState = context.read<AppState>();
      final repo = context.read<BillingRepository>();

      final amount = double.parse(_amountController.text);

      await repo.submitPayment(
        invoiceId: widget.invoice.id,
        communityId: appState.activeCommunityId!,
        amount: amount,
        proofUrl: _proofUrl!,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Payment submitted successfully. Awaiting verification.'),
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
}

class _CreateInvoiceDialog extends StatefulWidget {
  const _CreateInvoiceDialog();

  @override
  State<_CreateInvoiceDialog> createState() => _CreateInvoiceDialogState();
}

class _CreateInvoiceDialogState extends State<_CreateInvoiceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  String? _selectedUnitId;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));
  bool _isCreating = false;
  bool _isScanning = false;

  // Category entries (replaces single category + flat line items)
  final List<_CategoryEntry> _entries = [];

  Future<List<Unit>>? _unitsFuture;

  @override
  void initState() {
    super.initState();
    _loadUnits();
    // Start with one default entry
    _addEntry();
  }

  void _recalcTotal() {
    double total = 0;
    for (final e in _entries) {
      total += double.tryParse(e.amountController.text) ?? 0;
    }
    _amountController.text = total > 0 ? total.toStringAsFixed(2) : '';
  }

  void _loadUnits() {
    final appState = context.read<AppState>();
    final repo = context.read<HouseholdRepository>();

    if (appState.activeCommunityId != null) {
      _unitsFuture = repo.getUnits(appState.activeCommunityId!);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    for (final e in _entries) {
      e.descriptionController.dispose();
      e.amountController.removeListener(_recalcTotal);
      e.amountController.dispose();
    }
    super.dispose();
  }

  void _addEntry() {
    final amtCtrl = TextEditingController();
    amtCtrl.addListener(_recalcTotal);
    setState(() {
      _entries.add(_CategoryEntry(
        descriptionController: TextEditingController(),
        amountController: amtCtrl,
      ));
    });
  }

  void _removeEntry(int index) {
    _entries[index].descriptionController.dispose();
    _entries[index].amountController.removeListener(_recalcTotal);
    _entries[index].amountController.dispose();
    setState(() => _entries.removeAt(index));
    _recalcTotal();
  }

  String _categoryLabel(InvoiceCategory cat) {
    switch (cat) {
      case InvoiceCategory.dues:
        return 'Monthly Dues';
      case InvoiceCategory.water:
        return 'Water';
      case InvoiceCategory.amenity:
        return 'Amenity';
      case InvoiceCategory.insurance:
        return 'Insurance';
      case InvoiceCategory.other:
        return 'Other';
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy');

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: EdgeInsets.zero,
      title: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
        child: Row(
          children: [
            const Icon(Icons.receipt_outlined, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            const Text('Create Invoice',
                style: TextStyle(
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
        width: 540,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Scan invoice image button
                _buildScanInvoiceButton(context),
                const SizedBox(height: 16),

                // Unit selector
                FutureBuilder<List<Unit>>(
                  future: _unitsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const LinearProgressIndicator();
                    }
                    final units = snapshot.data ?? [];
                    if (units.isEmpty) {
                      return const Text(
                        'No units available. Create units first.',
                        style: TextStyle(color: Colors.red),
                      );
                    }
                    return _buildUnitAutocomplete(
                      units: units,
                      selectedUnitId: _selectedUnitId,
                      onSelected: (id) => setState(() => _selectedUnitId = id),
                      key: ValueKey(_selectedUnitId),
                      validator: (value) {
                        if (_selectedUnitId == null) return 'Required';
                        return null;
                      },
                    );
                  },
                ),
                const SizedBox(height: 20),

                // Billing Items header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Billing Items',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _addEntry,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Item'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Category entry cards
                for (var i = 0; i < _entries.length; i++)
                  _buildEntryCard(i, dateFormat),

                const SizedBox(height: 16),

                // Total (read-only)
                TextFormField(
                  controller: _amountController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Total',
                    prefixText: '₱ ',
                    prefixIcon: const Icon(Icons.payments_outlined, size: 20),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  validator: (value) {
                    if (value?.isEmpty ?? true)
                      return 'Add at least one billing item';
                    final amount = double.tryParse(value!);
                    if (amount == null || amount <= 0)
                      return 'Total must be > 0';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Due date
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _dueDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) setState(() => _dueDate = date);
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Due Date',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      suffixIcon: const Icon(Icons.calendar_today),
                    ),
                    child: Text(dateFormat.format(_dueDate)),
                  ),
                ),
                const SizedBox(height: 16),

                // Notes
                TextFormField(
                  controller: _notesController,
                  decoration: InputDecoration(
                    labelText: 'Notes (Optional)',
                    prefixIcon: const Icon(Icons.notes_outlined, size: 20),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _isCreating ? null : _createInvoice,
            icon: _isCreating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.receipt_long_rounded),
            label: Text(_isCreating ? 'Creating...' : 'Create',
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEntryCard(int index, DateFormat dateFormat) {
    final entry = _entries[index];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: category chips + remove
            Row(
              children: [
                Text('Item ${index + 1}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    )),
                const Spacer(),
                if (_entries.length > 1)
                  IconButton(
                    onPressed: () => _removeEntry(index),
                    icon: const Icon(Icons.close, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    color: Colors.red[400],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // Category selector
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: InvoiceCategory.values.map((cat) {
                final isSelected = entry.category == cat;
                return InkWell(
                  onTap: () => setState(() => entry.category = cat),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.1)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey.shade200,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Text(
                      _categoryLabel(cat),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey[700],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            // Description
            TextFormField(
              controller: entry.descriptionController,
              decoration: InputDecoration(
                hintText: 'Description (Optional)',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 10),
            // Period Start / End
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: entry.periodStart ??
                            DateTime.now().subtract(const Duration(days: 30)),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        setState(() => entry.periodStart = date);
                      }
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Period Start',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        suffixIcon: const Icon(Icons.calendar_today, size: 16),
                      ),
                      child: Text(
                        entry.periodStart != null
                            ? dateFormat.format(entry.periodStart!)
                            : 'Optional',
                        style: TextStyle(
                          fontSize: 12,
                          color: entry.periodStart != null ? null : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: entry.periodEnd ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        setState(() => entry.periodEnd = date);
                      }
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Period End',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        suffixIcon: const Icon(Icons.calendar_today, size: 16),
                      ),
                      child: Text(
                        entry.periodEnd != null
                            ? dateFormat.format(entry.periodEnd!)
                            : 'Optional',
                        style: TextStyle(
                          fontSize: 12,
                          color: entry.periodEnd != null ? null : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Amount
            TextFormField(
              controller: entry.amountController,
              decoration: InputDecoration(
                hintText: 'Amount',
                prefixText: '₱ ',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 13),
              validator: (value) {
                if (value?.isEmpty ?? true) return 'Required';
                final amt = double.tryParse(value!);
                if (amt == null || amt <= 0) return 'Invalid';
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createInvoice() async {
    if (!_formKey.currentState!.validate()) return;
    if (_entries.isEmpty) return;

    setState(() => _isCreating = true);

    try {
      final appState = context.read<AppState>();
      final repo = context.read<BillingRepository>();

      final amount = double.parse(_amountController.text);
      final metadata = <String, dynamic>{};

      if (_notesController.text.isNotEmpty) {
        metadata['notes'] = _notesController.text;
      }

      // Build description from category labels
      final categoryLabels =
          _entries.map((e) => _categoryLabel(e.category)).toSet().toList();
      final description = categoryLabels.join(' + ');

      // Use first entry's category as invoice-level category
      final primaryCategory = _entries.first.category;

      final lineItems = _entries
          .map((e) => {
                'label': _categoryLabel(e.category),
                'amount': double.tryParse(e.amountController.text) ?? 0,
                'category': e.category.name,
                if (e.descriptionController.text.isNotEmpty)
                  'description': e.descriptionController.text.trim(),
                if (e.periodStart != null)
                  'period_start':
                      e.periodStart!.toIso8601String().split('T').first,
                if (e.periodEnd != null)
                  'period_end': e.periodEnd!.toIso8601String().split('T').first,
              })
          .toList();

      await repo.createInvoice(
        communityId: appState.activeCommunityId!,
        unitId: _selectedUnitId!,
        category: primaryCategory,
        amount: amount,
        dueDate: _dueDate,
        description: description,
        metadata: metadata.isNotEmpty ? metadata : null,
        lineItems: lineItems,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice created successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCreating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Widget _buildScanInvoiceButton(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(
          color: _isScanning
              ? Theme.of(context).colorScheme.primary
              : Colors.grey.shade300,
          style: BorderStyle.solid,
        ),
        borderRadius: BorderRadius.circular(12),
        color: _isScanning
            ? Theme.of(context).colorScheme.primary.withOpacity(0.04)
            : Colors.grey.shade50,
      ),
      child: InkWell(
        onTap: _isScanning ? null : _scanImage,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            if (_isScanning) ...[
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(height: 8),
              const Text('Analyzing invoice image...',
                  style: TextStyle(fontSize: 13, color: Colors.grey)),
            ] else ...[
              Icon(Icons.document_scanner_outlined,
                  size: 32, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 8),
              Text('Upload Invoice Image',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  )),
              const SizedBox(height: 4),
              Text('Auto-fill form from an invoice photo',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _scanImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) return;

      setState(() => _isScanning = true);

      final repo = context.read<BillingRepository>();
      final data = await repo.scanInvoiceImage(file.bytes!);

      if (!mounted) return;

      // Match unit_number from scan to loaded units
      final scannedUnitNo = data['unit_number'] as String?;
      String? matchedUnitId;
      if (scannedUnitNo != null && _unitsFuture != null) {
        final units = await _unitsFuture!;
        final match = units.cast<Unit?>().firstWhere(
              (u) => u!.unitNo.toLowerCase() == scannedUnitNo.toLowerCase(),
              orElse: () => null,
            );
        matchedUnitId = match?.id;
      }

      if (!mounted) return;

      setState(() {
        // Clear existing entries
        for (final e in _entries) {
          e.descriptionController.dispose();
          e.amountController.removeListener(_recalcTotal);
          e.amountController.dispose();
        }
        _entries.clear();

        final pStart = data['period_start'] as String?;
        final pEnd = data['period_end'] as String?;
        final lineItems = data['line_items'] as List<dynamic>?;

        // If AI returned multiple line items, create a category entry for each
        if (lineItems != null && lineItems.length > 1) {
          for (final item in lineItems) {
            final itemMap = item as Map<String, dynamic>;
            final itemCat = itemMap['category'] as String?;
            final itemLabel = itemMap['label'] as String? ?? '';
            final itemAmount = itemMap['amount'] as num?;

            final amtCtrl = TextEditingController(
              text: itemAmount?.toDouble().toStringAsFixed(2) ?? '',
            );
            amtCtrl.addListener(_recalcTotal);

            _entries.add(_CategoryEntry(
              category: itemCat != null
                  ? InvoiceCategory.values.firstWhere(
                      (c) => c.name == itemCat,
                      orElse: () => _inferCategory(itemLabel),
                    )
                  : _inferCategory(itemLabel),
              descriptionController: TextEditingController(text: itemLabel),
              amountController: amtCtrl,
              periodStart: pStart != null ? DateTime.tryParse(pStart) : null,
              periodEnd: pEnd != null ? DateTime.tryParse(pEnd) : null,
            ));
          }
        } else {
          // Single entry from top-level scan data
          final cat = data['category'] as String?;
          final amount = data['amount'] as num?;
          final desc = data['description'] as String?;

          final amtCtrl = TextEditingController(
            text: amount?.toDouble().toStringAsFixed(2) ?? '',
          );
          amtCtrl.addListener(_recalcTotal);

          _entries.add(_CategoryEntry(
            category: cat != null
                ? InvoiceCategory.values.firstWhere(
                    (c) => c.name == cat,
                    orElse: () => InvoiceCategory.other,
                  )
                : InvoiceCategory.dues,
            descriptionController: TextEditingController(text: desc ?? ''),
            amountController: amtCtrl,
            periodStart: pStart != null ? DateTime.tryParse(pStart) : null,
            periodEnd: pEnd != null ? DateTime.tryParse(pEnd) : null,
          ));
        }

        if (data['due_date'] != null) {
          _dueDate = DateTime.tryParse(data['due_date']) ?? _dueDate;
        }
        if (data['notes'] != null) {
          _notesController.text = data['notes'];
        }
        if (matchedUnitId != null) {
          _selectedUnitId = matchedUnitId;
        }

        _recalcTotal();
        _isScanning = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invoice data extracted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isScanning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scan failed: $e')),
        );
      }
    }
  }

  InvoiceCategory _inferCategory(String label) {
    final lower = label.toLowerCase();
    if (lower.contains('water')) return InvoiceCategory.water;
    if (lower.contains('dues')) return InvoiceCategory.dues;
    if (lower.contains('amenity') ||
        lower.contains('pool') ||
        lower.contains('parking')) return InvoiceCategory.amenity;
    if (lower.contains('insurance')) return InvoiceCategory.insurance;
    return InvoiceCategory.other;
  }
}

class _CategoryEntry {
  InvoiceCategory category;
  final TextEditingController descriptionController;
  final TextEditingController amountController;
  DateTime? periodStart;
  DateTime? periodEnd;

  _CategoryEntry({
    this.category = InvoiceCategory.dues,
    required this.descriptionController,
    required this.amountController,
    this.periodStart,
    this.periodEnd,
  });
}

// ============ INCOME TRACKER ============

class _IncomeTrackerView extends StatefulWidget {
  const _IncomeTrackerView();

  @override
  State<_IncomeTrackerView> createState() => _IncomeTrackerViewState();
}

class _IncomeTrackerViewState extends State<_IncomeTrackerView> {
  bool _loading = true;
  double _verifiedTotal = 0;
  double _manualTotal = 0;
  List<Payment> _verifiedPayments = [];
  List<ManualIncome> _manualEntries = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final appState = context.read<AppState>();
    final communityId = appState.activeCommunityId;
    if (communityId == null) return;

    final repo = context.read<IncomeRepository>();

    // Load verified payments (from existing payments table)
    try {
      final vPayments = await repo.getVerifiedPayments(communityId);
      final vTotal = await repo.getTotalVerifiedIncome(communityId);
      if (mounted) {
        setState(() {
          _verifiedPayments = vPayments;
          _verifiedTotal = vTotal;
        });
      }
    } catch (_) {}

    // Load manual income (table may not be deployed yet)
    try {
      final mEntries = await repo.getManualIncome(communityId);
      final mTotal = await repo.getTotalManualIncome(communityId);
      if (mounted) {
        setState(() {
          _manualEntries = mEntries;
          _manualTotal = mTotal;
        });
      }
    } catch (_) {}

    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final currencyFormat = NumberFormat.currency(symbol: '₱', decimalDigits: 2);
    final grandTotal = _verifiedTotal + _manualTotal;

    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _loading = true);
        await _loadData();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Summary cards
          _IncomeSummaryCards(
            grandTotal: grandTotal,
            verifiedTotal: _verifiedTotal,
            manualTotal: _manualTotal,
            currencyFormat: currencyFormat,
          ),
          const SizedBox(height: 20),

          // Manual Income section
          Row(
            children: [
              Icon(Icons.edit_note, size: 20, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(
                'Manual Income Entries',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _showAddManualIncomeDialog(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Income'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_manualEntries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.account_balance_wallet_outlined,
                        size: 48, color: Colors.grey[300]),
                    const SizedBox(height: 8),
                    Text('No manual income entries yet',
                        style: TextStyle(color: Colors.grey[500])),
                  ],
                ),
              ),
            )
          else
            ...(_manualEntries.map((entry) => _ManualIncomeCard(
                  entry: entry,
                  currencyFormat: currencyFormat,
                  onDeleted: _loadData,
                ))),

          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),

          // Verified Payments section
          Row(
            children: [
              Icon(Icons.verified_outlined, size: 20, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(
                'Invoice Income (Verified Payments)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_verifiedPayments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.payments_outlined,
                        size: 48, color: Colors.grey[300]),
                    const SizedBox(height: 8),
                    Text('No verified payments yet',
                        style: TextStyle(color: Colors.grey[500])),
                  ],
                ),
              ),
            )
          else
            ...(_verifiedPayments.map((payment) => _VerifiedPaymentCard(
                  payment: payment,
                  currencyFormat: currencyFormat,
                ))),
        ],
      ),
    );
  }

  void _showAddManualIncomeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _AddManualIncomeDialog(
        onCreated: _loadData,
      ),
    );
  }
}

class _IncomeSummaryCards extends StatelessWidget {
  final double grandTotal;
  final double verifiedTotal;
  final double manualTotal;
  final NumberFormat currencyFormat;

  const _IncomeSummaryCards({
    required this.grandTotal,
    required this.verifiedTotal,
    required this.manualTotal,
    required this.currencyFormat,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            label: 'Total Income',
            amount: currencyFormat.format(grandTotal),
            icon: Icons.trending_up,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
            label: 'From Invoices',
            amount: currencyFormat.format(verifiedTotal),
            icon: Icons.receipt_long,
            color: Colors.blue.shade700,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
            label: 'Manual Entries',
            amount: currencyFormat.format(manualTotal),
            icon: Icons.edit_note,
            color: Colors.orange.shade700,
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String amount;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              amount,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManualIncomeCard extends StatelessWidget {
  final ManualIncome entry;
  final NumberFormat currencyFormat;
  final VoidCallback onDeleted;

  const _ManualIncomeCard({
    required this.entry,
    required this.currencyFormat,
    required this.onDeleted,
  });

  String _getCategoryLabel(IncomeCategory cat) {
    switch (cat) {
      case IncomeCategory.dues:
        return 'DUES';
      case IncomeCategory.water:
        return 'WATER';
      case IncomeCategory.amenity:
        return 'AMENITY';
      case IncomeCategory.insurance:
        return 'INSURANCE';
      case IncomeCategory.rental:
        return 'RENTAL';
      case IncomeCategory.fee:
        return 'FEE';
      case IncomeCategory.donation:
        return 'DONATION';
      case IncomeCategory.other:
        return 'OTHER';
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.account_balance_wallet,
                  size: 20, color: Colors.orange.shade700),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.description,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _getCategoryLabel(entry.category),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        dateFormat.format(entry.incomeDate),
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                      if (entry.source != null) ...[
                        Text(' • ',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[400])),
                        Text(
                          entry.source!,
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  currencyFormat.format(entry.amount),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                InkWell(
                  onTap: () => _confirmDelete(context),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.delete_outline,
                        size: 16, color: Colors.red[300]),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Income Entry'),
        content: const Text(
            'Are you sure you want to delete this income entry? This action cannot be undone.'),
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

    if (confirmed == true && context.mounted) {
      try {
        final repo = context.read<IncomeRepository>();
        await repo.deleteManualIncome(entry.id);
        onDeleted();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Income entry deleted'),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

class _VerifiedPaymentCard extends StatelessWidget {
  final Payment payment;
  final NumberFormat currencyFormat;

  const _VerifiedPaymentCard({
    required this.payment,
    required this.currencyFormat,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.verified,
                  size: 20, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'INV-${payment.invoiceId.substring(0, 8).toUpperCase()}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          payment.method.replaceAll('_', ' ').toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        payment.verifiedAt != null
                            ? 'Verified ${dateFormat.format(payment.verifiedAt!)}'
                            : 'Posted ${dateFormat.format(payment.postedAt)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Text(
              currencyFormat.format(payment.amount),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============ ADD MANUAL INCOME DIALOG ============

class _AddManualIncomeDialog extends StatefulWidget {
  final VoidCallback onCreated;

  const _AddManualIncomeDialog({required this.onCreated});

  @override
  State<_AddManualIncomeDialog> createState() => _AddManualIncomeDialogState();
}

class _AddManualIncomeDialogState extends State<_AddManualIncomeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _sourceController = TextEditingController();
  final _notesController = TextEditingController();

  IncomeCategory _selectedCategory = IncomeCategory.other;
  DateTime _incomeDate = DateTime.now();
  bool _isCreating = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _sourceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: EdgeInsets.zero,
      title: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
        child: Row(
          children: [
            const Icon(Icons.add_card, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Add Manual Income',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      )),
                  SizedBox(height: 2),
                  Text('Record income not tied to an invoice',
                      style: TextStyle(color: Colors.white60, fontSize: 12)),
                ],
              ),
            ),
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
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    hintText: 'e.g., Clubhouse rental fee',
                    prefixIcon:
                        const Icon(Icons.description_outlined, size: 20),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 1.5),
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),
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
                  children: IncomeCategory.values.map((category) {
                    final isSelected = _selectedCategory == category;
                    IconData icon;
                    String label;
                    switch (category) {
                      case IncomeCategory.dues:
                        icon = Icons.home_outlined;
                        label = 'Dues';
                        break;
                      case IncomeCategory.water:
                        icon = Icons.water_drop_outlined;
                        label = 'Water';
                        break;
                      case IncomeCategory.amenity:
                        icon = Icons.pool_outlined;
                        label = 'Amenity';
                        break;
                      case IncomeCategory.insurance:
                        icon = Icons.shield_outlined;
                        label = 'Insurance';
                        break;
                      case IncomeCategory.rental:
                        icon = Icons.house_outlined;
                        label = 'Rental';
                        break;
                      case IncomeCategory.fee:
                        icon = Icons.monetization_on_outlined;
                        label = 'Fee';
                        break;
                      case IncomeCategory.donation:
                        icon = Icons.volunteer_activism_outlined;
                        label = 'Donation';
                        break;
                      case IncomeCategory.other:
                        icon = Icons.more_horiz;
                        label = 'Other';
                        break;
                    }
                    return InkWell(
                      onTap: () => setState(() => _selectedCategory = category),
                      borderRadius: BorderRadius.circular(10),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.1)
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey.shade200,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon,
                                size: 16,
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amountController,
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    prefixText: '₱ ',
                    prefixIcon: const Icon(Icons.payments_outlined, size: 20),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 1.5),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value?.isEmpty ?? true) return 'Required';
                    final amount = double.tryParse(value!);
                    if (amount == null || amount <= 0) {
                      return 'Enter a valid amount';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _incomeDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) setState(() => _incomeDate = date);
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Income Date',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 1.5),
                      ),
                      suffixIcon: const Icon(Icons.calendar_today, size: 18),
                    ),
                    child: Text(
                      DateFormat('MMM dd, yyyy').format(_incomeDate),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _sourceController,
                  decoration: InputDecoration(
                    labelText: 'Source (Optional)',
                    hintText: 'e.g., Unit 5A, External vendor',
                    prefixIcon: const Icon(Icons.source_outlined, size: 20),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  decoration: InputDecoration(
                    labelText: 'Notes (Optional)',
                    prefixIcon: const Icon(Icons.notes_outlined, size: 20),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 1.5),
                    ),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _isCreating ? null : _submit,
            icon: _isCreating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.add_circle_outline),
            label: Text(_isCreating ? 'Adding...' : 'Add Income',
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isCreating = true);

    try {
      final appState = context.read<AppState>();
      final repo = context.read<IncomeRepository>();

      await repo.createManualIncome(
        communityId: appState.activeCommunityId!,
        category: _selectedCategory,
        description: _descriptionController.text.trim(),
        amount: double.parse(_amountController.text),
        incomeDate: _incomeDate,
        source: _sourceController.text.trim().isNotEmpty
            ? _sourceController.text.trim()
            : null,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Income entry added successfully'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
        widget.onCreated();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCreating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// ============ RECURRING BILLING ============

class _RecurringBillingView extends StatefulWidget {
  final VoidCallback onInvoicesGenerated;

  const _RecurringBillingView({required this.onInvoicesGenerated});

  @override
  State<_RecurringBillingView> createState() => _RecurringBillingViewState();
}

class _RecurringBillingViewState extends State<_RecurringBillingView> {
  Future<List<RecurringBilling>>? _recurringFuture;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _loadRecurringBillings();
  }

  void _loadRecurringBillings() {
    final appState = context.read<AppState>();
    final repo = context.read<RecurringBillingRepository>();
    final communityId = appState.activeCommunityId;
    if (communityId != null) {
      setState(() {
        _recurringFuture = repo.getRecurringBillings(communityId);
      });
    }
  }

  Future<void> _generateDueInvoices() async {
    final appState = context.read<AppState>();
    final repo = context.read<RecurringBillingRepository>();
    final communityId = appState.activeCommunityId;
    if (communityId == null) return;

    setState(() => _isGenerating = true);
    try {
      final count = await repo.generateDueInvoices(communityId);
      if (mounted) {
        setState(() => _isGenerating = false);
        _loadRecurringBillings();
        widget.onInvoicesGenerated();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(count > 0
                ? '$count invoice(s) generated successfully'
                : 'No invoices are due for generation'),
            backgroundColor: count > 0
                ? Theme.of(context).colorScheme.primary
                : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGenerating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Action bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Icon(Icons.autorenew, size: 20, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(
                'Recurring Billing Templates',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _isGenerating ? null : _generateDueInvoices,
                icon: _isGenerating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow, size: 18),
                label: Text(_isGenerating ? 'Generating...' : 'Generate Due'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 4),
              FilledButton.icon(
                onPressed: () => _showCreateRecurringBillingDialog(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New Template'),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // List
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => _loadRecurringBillings(),
            child: FutureBuilder<List<RecurringBilling>>(
              future: _recurringFuture,
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
                        ElevatedButton.icon(
                          onPressed: _loadRecurringBillings,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final items = snapshot.data ?? [];

                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.repeat, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        const Text(
                          'No recurring billings yet',
                          style: TextStyle(fontSize: 18),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Set up templates to auto-generate invoices',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, index) => _RecurringBillingCard(
                    billing: items[index],
                    onRefresh: _loadRecurringBillings,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  void _showCreateRecurringBillingDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _CreateRecurringBillingDialog(
        onCreated: _loadRecurringBillings,
      ),
    );
  }
}

class _RecurringBillingCard extends StatefulWidget {
  final RecurringBilling billing;
  final VoidCallback onRefresh;

  const _RecurringBillingCard({
    required this.billing,
    required this.onRefresh,
  });

  @override
  State<_RecurringBillingCard> createState() => _RecurringBillingCardState();
}

class _RecurringBillingCardState extends State<_RecurringBillingCard> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final billing = widget.billing;
    final currencyFormat = NumberFormat.currency(symbol: '₱', decimalDigits: 2);
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Category chip
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    billing.categoryLabel.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Frequency chip
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    billing.frequencyLabel.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (billing.isDue)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'DUE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ),
                const Spacer(),
                // Active toggle
                Switch(
                  value: billing.isActive,
                  onChanged: _isProcessing ? null : _toggleActive,
                  activeColor: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
            if (billing.description != null) ...[
              const SizedBox(height: 8),
              Text(
                billing.description!,
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  currencyFormat.format(billing.amount),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      billing.applyToAll
                          ? 'All Units'
                          : billing.unitNumber != null
                              ? 'Unit ${billing.unitNumber}'
                              : 'Specific Unit',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                    Text(
                      'Day ${billing.dayOfMonth} of month',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.schedule, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  'Next: ${dateFormat.format(billing.nextRunDate)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                if (billing.lastRunDate != null) ...[
                  const SizedBox(width: 16),
                  Icon(Icons.check_circle_outline,
                      size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    'Last: ${dateFormat.format(billing.lastRunDate!)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
                const Spacer(),
                TextButton.icon(
                  onPressed:
                      _isProcessing ? null : () => _confirmDelete(context),
                  icon: const Icon(Icons.delete_outline,
                      size: 16, color: Colors.red),
                  label: const Text('Delete'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleActive(bool value) async {
    setState(() => _isProcessing = true);
    try {
      final repo = context.read<RecurringBillingRepository>();
      await repo.toggleActive(widget.billing.id, value);
      widget.onRefresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Recurring Billing'),
        content: const Text(
          'Are you sure you want to delete this recurring billing template? '
          'Previously generated invoices will not be affected.',
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

    setState(() => _isProcessing = true);
    try {
      final repo = context.read<RecurringBillingRepository>();
      await repo.deleteRecurringBilling(widget.billing.id);
      if (mounted) {
        widget.onRefresh();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Recurring billing deleted'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

class _CreateRecurringBillingDialog extends StatefulWidget {
  final VoidCallback onCreated;

  const _CreateRecurringBillingDialog({required this.onCreated});

  @override
  State<_CreateRecurringBillingDialog> createState() =>
      _CreateRecurringBillingDialogState();
}

class _CreateRecurringBillingDialogState
    extends State<_CreateRecurringBillingDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _notesController = TextEditingController();
  final _dayOfMonthController = TextEditingController(text: '1');
  final _dueDayOffsetController = TextEditingController(text: '15');

  InvoiceCategory _selectedCategory = InvoiceCategory.dues;
  RecurringFrequency _selectedFrequency = RecurringFrequency.monthly;
  String? _selectedUnitId;
  bool _applyToAll = false;
  bool _isCreating = false;
  DateTime _nextRunDate = DateTime(
    DateTime.now().year,
    DateTime.now().month + 1,
    1,
  );

  // Line items
  final List<_LineItemEntry> _lineItems = [];
  Future<List<Unit>>? _unitsFuture;

  @override
  void initState() {
    super.initState();
    _loadUnits();
  }

  void _loadUnits() {
    final appState = context.read<AppState>();
    final repo = context.read<HouseholdRepository>();
    if (appState.activeCommunityId != null) {
      _unitsFuture = repo.getUnits(appState.activeCommunityId!);
    }
  }

  void _recalcTotal() {
    if (_lineItems.isEmpty) return;
    double total = 0;
    for (final item in _lineItems) {
      total += double.tryParse(item.amountController.text) ?? 0;
    }
    _amountController.text = total > 0 ? total.toStringAsFixed(2) : '';
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    _dayOfMonthController.dispose();
    _dueDayOffsetController.dispose();
    for (final item in _lineItems) {
      item.labelController.dispose();
      item.amountController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: EdgeInsets.zero,
      title: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
        child: Row(
          children: [
            const Icon(Icons.autorenew, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Create Recurring Billing',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  )),
            ),
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
                // Apply to all toggle
                SwitchListTile(
                  title: const Text('Apply to all units',
                      style: TextStyle(fontSize: 14)),
                  subtitle: const Text(
                    'Invoice will be generated for every unit',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _applyToAll,
                  onChanged: (v) => setState(() => _applyToAll = v),
                  activeColor: Theme.of(context).colorScheme.primary,
                  contentPadding: EdgeInsets.zero,
                ),
                // Unit picker (if not apply to all)
                if (!_applyToAll) ...[
                  const SizedBox(height: 8),
                  FutureBuilder<List<Unit>>(
                    future: _unitsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const LinearProgressIndicator();
                      }
                      final units = snapshot.data ?? [];
                      if (units.isEmpty) {
                        return const Text(
                          'No units available. Create units first.',
                          style: TextStyle(color: Colors.red),
                        );
                      }
                      return _buildUnitAutocomplete(
                        units: units,
                        selectedUnitId: _selectedUnitId,
                        onSelected: (id) =>
                            setState(() => _selectedUnitId = id),
                        validator: (value) {
                          if (!_applyToAll && _selectedUnitId == null)
                            return 'Required';
                          return null;
                        },
                      );
                    },
                  ),
                ],
                const SizedBox(height: 16),
                // Category
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
                  children: InvoiceCategory.values.map((category) {
                    final isSelected = _selectedCategory == category;
                    IconData icon;
                    String label;
                    switch (category) {
                      case InvoiceCategory.dues:
                        icon = Icons.home_outlined;
                        label = 'Monthly Dues';
                        break;
                      case InvoiceCategory.water:
                        icon = Icons.water_drop_outlined;
                        label = 'Water';
                        break;
                      case InvoiceCategory.amenity:
                        icon = Icons.pool_outlined;
                        label = 'Amenity';
                        break;
                      case InvoiceCategory.insurance:
                        icon = Icons.shield_outlined;
                        label = 'Insurance';
                        break;
                      case InvoiceCategory.other:
                        icon = Icons.more_horiz;
                        label = 'Other';
                        break;
                    }
                    return InkWell(
                      onTap: () => setState(() => _selectedCategory = category),
                      borderRadius: BorderRadius.circular(10),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.1)
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey.shade200,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon,
                                size: 18,
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey),
                            const SizedBox(width: 6),
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                // Frequency
                Text('Frequency',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    )),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: RecurringFrequency.values.map((freq) {
                    final isSelected = _selectedFrequency == freq;
                    return ChoiceChip(
                      label: Text(
                          freq.name[0].toUpperCase() + freq.name.substring(1)),
                      selected: isSelected,
                      onSelected: (_) =>
                          setState(() => _selectedFrequency = freq),
                      selectedColor: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.15),
                      labelStyle: TextStyle(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey[700],
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                // Description
                TextFormField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    labelText: 'Description (Optional)',
                    hintText: 'e.g., Monthly HOA Dues',
                    prefixIcon:
                        const Icon(Icons.description_outlined, size: 20),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Amount
                TextFormField(
                  controller: _amountController,
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    prefixText: '₱ ',
                    prefixIcon: const Icon(Icons.payments_outlined, size: 20),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 1.5),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value?.isEmpty ?? true) return 'Required';
                    final amount = double.tryParse(value!);
                    if (amount == null || amount <= 0) return 'Invalid amount';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Day of month and due offset
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _dayOfMonthController,
                        decoration: InputDecoration(
                          labelText: 'Day of Month',
                          hintText: '1-28',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: Theme.of(context).colorScheme.primary,
                                width: 1.5),
                          ),
                          helperText: 'Invoice generated on this day',
                          helperMaxLines: 2,
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value?.isEmpty ?? true) return 'Required';
                          final day = int.tryParse(value!);
                          if (day == null || day < 1 || day > 28) {
                            return '1-28';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _dueDayOffsetController,
                        decoration: InputDecoration(
                          labelText: 'Due Day Offset',
                          hintText: 'Days',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: Theme.of(context).colorScheme.primary,
                                width: 1.5),
                          ),
                          helperText: 'Days after generation until due',
                          helperMaxLines: 2,
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value?.isEmpty ?? true) return 'Required';
                          final days = int.tryParse(value!);
                          if (days == null || days < 1 || days > 90) {
                            return '1-90';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Next run date
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _nextRunDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) setState(() => _nextRunDate = date);
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'First Invoice Date',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 1.5),
                      ),
                      suffixIcon: const Icon(Icons.calendar_today, size: 18),
                      helperText: 'When the first invoice will be generated',
                    ),
                    child: Text(
                      DateFormat('MMM dd, yyyy').format(_nextRunDate),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Line items section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Line Items (Template)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _addLineItem,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Item'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  ],
                ),
                if (_lineItems.isNotEmpty) ...[
                  for (var i = 0; i < _lineItems.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: _lineItems[i].labelController,
                              decoration: InputDecoration(
                                hintText: 'Item label',
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      width: 1.5),
                                ),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _lineItems[i].amountController,
                              decoration: InputDecoration(
                                hintText: '0.00',
                                prefixText: '₱ ',
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      width: 1.5),
                                ),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            onPressed: () => _removeLineItem(i),
                            icon: const Icon(Icons.close, size: 18),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            color: Colors.red[400],
                          ),
                        ],
                      ),
                    ),
                ],
                const SizedBox(height: 8),
                TextFormField(
                  controller: _notesController,
                  decoration: InputDecoration(
                    labelText: 'Notes (Optional)',
                    prefixIcon: const Icon(Icons.notes_outlined, size: 20),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 1.5),
                    ),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _isCreating ? null : _createRecurringBilling,
            icon: _isCreating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.repeat_rounded),
            label: Text(_isCreating ? 'Creating...' : 'Create',
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _createRecurringBilling() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_applyToAll && _selectedUnitId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a unit or apply to all')),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      final appState = context.read<AppState>();
      final repo = context.read<RecurringBillingRepository>();

      await repo.createRecurringBilling(
        communityId: appState.activeCommunityId!,
        unitId: _applyToAll ? null : _selectedUnitId,
        category: _selectedCategory.name,
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        amount: double.parse(_amountController.text),
        frequency: _selectedFrequency,
        dayOfMonth: int.parse(_dayOfMonthController.text),
        dueDayOffset: int.parse(_dueDayOffsetController.text),
        applyToAll: _applyToAll,
        lineItems: _lineItems.isNotEmpty
            ? _lineItems
                .where((item) => item.labelController.text.isNotEmpty)
                .map((item) => {
                      'label': item.labelController.text.trim(),
                      'amount':
                          double.tryParse(item.amountController.text) ?? 0,
                    })
                .toList()
            : null,
        nextRunDate: _nextRunDate,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Recurring billing created successfully'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
        widget.onCreated();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCreating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _addLineItem() {
    final amtCtrl = TextEditingController();
    amtCtrl.addListener(_recalcTotal);
    setState(() {
      _lineItems.add(_LineItemEntry(
        labelController: TextEditingController(),
        amountController: amtCtrl,
      ));
    });
  }

  void _removeLineItem(int index) {
    _lineItems[index].labelController.dispose();
    _lineItems[index].amountController.removeListener(_recalcTotal);
    _lineItems[index].amountController.dispose();
    setState(() {
      _lineItems.removeAt(index);
    });
    _recalcTotal();
  }
}

class _LineItemEntry {
  final TextEditingController labelController;
  final TextEditingController amountController;

  _LineItemEntry({
    required this.labelController,
    required this.amountController,
  });
}
