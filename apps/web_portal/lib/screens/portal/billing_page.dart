import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:core_data/core_data.dart';
import 'package:core_domain/core_domain.dart';
import 'package:core_ui/core_ui.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class BillingPage extends StatefulWidget {
  const BillingPage({super.key});

  @override
  State<BillingPage> createState() => _BillingPageState();
}

class _BillingPageState extends State<BillingPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _showChart = true;

  @override
  void initState() {
    super.initState();
    final appState = context.read<AppState>();
    final isStaff = appState.isStaff;
    _tabController = TabController(length: isStaff ? 2 : 1, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
              tabs: const [
                Tab(text: 'My Invoices'),
                Tab(text: 'All Invoices'),
              ],
            ),
          Expanded(
            child: isStaff
                ? TabBarView(
                    controller: _tabController,
                    children: const [
                      _InvoiceListView(showMyInvoices: true),
                      _InvoiceListView(showMyInvoices: false),
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
      final invoices = await repo.getInvoices(communityId);
      // Aggregate by month (last 6 months)
      final now = DateTime.now();
      final months = <_MonthlyData>[];
      for (int i = 5; i >= 0; i--) {
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
              _legendDot(theme.colorScheme.primary, 'Charged'),
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
                  HOAppButton(
                    label: 'Retry',
                    onPressed: _loadInvoices,
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
  final VoidCallback onRefresh;

  const _InvoiceCard({
    required this.invoice,
    required this.isStaff,
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
        onRefresh: onRefresh,
      ),
    );
  }
}

class _InvoiceDetailsDialog extends StatefulWidget {
  final Invoice invoice;
  final bool isStaff;
  final VoidCallback onRefresh;

  const _InvoiceDetailsDialog({
    required this.invoice,
    required this.isStaff,
    required this.onRefresh,
  });

  @override
  State<_InvoiceDetailsDialog> createState() => _InvoiceDetailsDialogState();
}

class _InvoiceDetailsDialogState extends State<_InvoiceDetailsDialog> {
  Future<List<Payment>>? _paymentsFuture;
  Future<List<InvoiceLineItem>>? _lineItemsFuture;

  @override
  void initState() {
    super.initState();
    _loadPayments();
    _loadLineItems();
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

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '₱', decimalDigits: 2);
    final dateFormat = DateFormat('MMM dd, yyyy');

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.receipt_long_outlined,
              color: Color(0xff215e3f), size: 24),
          const SizedBox(width: 12),
          const Text('Invoice Details',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
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

              // Summary row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getCategoryLabel(widget.invoice.category),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Due: ${dateFormat.format(widget.invoice.dueDate)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: widget.invoice.isOverdue
                              ? Colors.red
                              : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: (widget.invoice.status == InvoiceStatus.paid
                              ? const Color(0xff215e3f)
                              : widget.invoice.isOverdue
                                  ? Colors.red
                                  : Colors.orange)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      widget.invoice.status == InvoiceStatus.paid
                          ? 'PAID'
                          : widget.invoice.isOverdue
                              ? 'OVERDUE'
                              : 'UNPAID',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: widget.invoice.status == InvoiceStatus.paid
                            ? const Color(0xff215e3f)
                            : widget.invoice.isOverdue
                                ? Colors.red
                                : Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // Line items breakdown
              FutureBuilder<List<InvoiceLineItem>>(
                future: _lineItemsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Center(
                          child: SizedBox(
                              width: 20,
                              height: 20,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2))),
                    );
                  }

                  final items = snapshot.data ?? [];

                  if (items.isEmpty) {
                    // No line items — just show the total
                    return _buildTotalRow(currencyFormat);
                  }

                  return Column(
                    children: [
                      ...items.map((item) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.label,
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                      if (item.metadata != null &&
                                          item.metadata!['detail'] != null)
                                        Text(
                                          item.metadata!['detail'] as String,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Text(
                                  currencyFormat.format(item.amount),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
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
                          style:
                              TextStyle(fontSize: 13, color: Colors.amber[900]),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'Payments',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              FutureBuilder<List<Payment>>(
                future: _paymentsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
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
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        if (widget.invoice.status == InvoiceStatus.unpaid)
          HOAppButton(
            label: 'Submit Payment',
            onPressed: () {
              Navigator.of(context).pop();
              _showPaymentSubmissionDialog(context);
            },
          ),
      ],
    );
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
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xff215e3f),
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

class _PaymentCard extends StatelessWidget {
  final Payment payment;
  final bool isStaff;
  final VoidCallback onRefresh;

  const _PaymentCard({
    required this.payment,
    required this.isStaff,
    required this.onRefresh,
  });

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
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  // Open proof URL in new tab or dialog
                },
                icon: const Icon(Icons.receipt, size: 16),
                label: const Text('View Proof'),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _rejectPayment(context),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Reject'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _verifyPayment(context),
                    icon: const Icon(Icons.check, size: 16),
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
    try {
      final repo = context.read<BillingRepository>();
      await repo.verifyPayment(paymentId: payment.id, verified: true);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment verified successfully')),
        );
        onRefresh();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _rejectPayment(BuildContext context) async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.cancel_outlined, color: Colors.red, size: 24),
            const SizedBox(width: 12),
            const Text('Reject Payment',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(false),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for rejection:'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Rejection Reason',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
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
          onRefresh();
        }
      } catch (e) {
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
  final _proofUrlController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.invoice.amount.toString();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _proofUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '₱', decimalDigits: 2);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.payment_outlined,
              color: Color(0xff215e3f), size: 24),
          const SizedBox(width: 12),
          const Text('Submit Payment',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Invoice Amount: ${currencyFormat.format(widget.invoice.amount)}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Amount Paid',
                prefixText: '₱ ',
                border: OutlineInputBorder(),
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
            TextFormField(
              controller: _proofUrlController,
              decoration: const InputDecoration(
                labelText: 'Proof of Payment URL',
                hintText: 'Upload receipt to file storage and paste link',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value?.isEmpty ?? true) return 'Required';
                return null;
              },
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 20, color: Colors.blue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Upload your receipt/screenshot to a file storage service and paste the public link here.',
                      style: TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        HOAppButton(
          label: _isSubmitting ? 'Submitting...' : 'Submit',
          onPressed: _isSubmitting ? null : _submitPayment,
        ),
      ],
    );
  }

  Future<void> _submitPayment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final appState = context.read<AppState>();
      final repo = context.read<BillingRepository>();

      final amount = double.parse(_amountController.text);

      await repo.submitPayment(
        invoiceId: widget.invoice.id,
        communityId: appState.activeCommunityId!,
        amount: amount,
        proofUrl: _proofUrlController.text,
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
  final _descriptionController = TextEditingController();

  InvoiceCategory _selectedCategory = InvoiceCategory.dues;
  String? _selectedUnitId;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));
  DateTime? _periodStart;
  DateTime? _periodEnd;
  bool _isCreating = false;

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

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    _descriptionController.dispose();
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
      title: Row(
        children: [
          const Icon(Icons.receipt_outlined,
              color: Color(0xff215e3f), size: 24),
          const SizedBox(width: 12),
          const Text('Create Invoice',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
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

                    return DropdownButtonFormField<String>(
                      value: _selectedUnitId,
                      decoration: const InputDecoration(
                        labelText: 'Unit',
                        border: OutlineInputBorder(),
                      ),
                      items: units.map((unit) {
                        return DropdownMenuItem(
                          value: unit.id,
                          child: Text('Unit ${unit.unitNumber}'),
                        );
                      }).toList(),
                      onChanged: (value) =>
                          setState(() => _selectedUnitId = value),
                      validator: (value) => value == null ? 'Required' : null,
                    );
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<InvoiceCategory>(
                  value: _selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: InvoiceCategory.values.map((category) {
                    String label;
                    switch (category) {
                      case InvoiceCategory.dues:
                        label = 'Monthly Dues';
                        break;
                      case InvoiceCategory.water:
                        label = 'Water Billing';
                        break;
                      case InvoiceCategory.amenity:
                        label = 'Amenity';
                        break;
                      case InvoiceCategory.insurance:
                        label = 'Fire Insurance';
                        break;
                      case InvoiceCategory.other:
                        label = 'Other';
                        break;
                    }
                    return DropdownMenuItem(
                      value: category,
                      child: Text(label),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedCategory = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    hintText: 'e.g., March 2026 Water Billing',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                // Period dates
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _periodStart ??
                                DateTime.now()
                                    .subtract(const Duration(days: 30)),
                            firstDate: DateTime(2020),
                            lastDate:
                                DateTime.now().add(const Duration(days: 365)),
                          );
                          if (date != null) setState(() => _periodStart = date);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Period Start',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.calendar_today, size: 18),
                          ),
                          child: Text(
                            _periodStart != null
                                ? DateFormat('MMM dd, yyyy')
                                    .format(_periodStart!)
                                : 'Optional',
                            style: TextStyle(
                              color: _periodStart != null ? null : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _periodEnd ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate:
                                DateTime.now().add(const Duration(days: 365)),
                          );
                          if (date != null) setState(() => _periodEnd = date);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Period End',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.calendar_today, size: 18),
                          ),
                          child: Text(
                            _periodEnd != null
                                ? DateFormat('MMM dd, yyyy').format(_periodEnd!)
                                : 'Optional',
                            style: TextStyle(
                              color: _periodEnd != null ? null : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
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
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _dueDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      setState(() => _dueDate = date);
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Due Date',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(
                      DateFormat('MMM dd, yyyy').format(_dueDate),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Line items section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Line Items',
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
                                border: const OutlineInputBorder(),
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
                              decoration: const InputDecoration(
                                hintText: '0.00',
                                prefixText: '₱ ',
                                border: OutlineInputBorder(),
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
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
                  const SizedBox(height: 4),
                ],
                const SizedBox(height: 8),
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
          label: _isCreating ? 'Creating...' : 'Create',
          onPressed: _isCreating ? null : _createInvoice,
        ),
      ],
    );
  }

  Future<void> _createInvoice() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isCreating = true);

    try {
      final appState = context.read<AppState>();
      final repo = context.read<BillingRepository>();

      final amount = double.parse(_amountController.text);
      final metadata = <String, dynamic>{};

      if (_notesController.text.isNotEmpty) {
        metadata['notes'] = _notesController.text;
      }

      await repo.createInvoice(
        communityId: appState.activeCommunityId!,
        unitId: _selectedUnitId!,
        category: _selectedCategory,
        amount: amount,
        dueDate: _dueDate,
        description: _descriptionController.text.isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        periodStart: _periodStart,
        periodEnd: _periodEnd,
        metadata: metadata.isNotEmpty ? metadata : null,
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

  void _addLineItem() {
    setState(() {
      _lineItems.add(_LineItemEntry(
        labelController: TextEditingController(),
        amountController: TextEditingController(),
      ));
    });
  }

  void _removeLineItem(int index) {
    setState(() {
      _lineItems[index].labelController.dispose();
      _lineItems[index].amountController.dispose();
      _lineItems.removeAt(index);
    });
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
