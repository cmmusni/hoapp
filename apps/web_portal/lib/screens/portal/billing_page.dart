import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:core_data/core_data.dart';
import 'package:core_domain/core_domain.dart';
import 'package:core_ui/core_ui.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
      titlePadding: EdgeInsets.zero,
      title: Container(
        decoration: const BoxDecoration(
          color: Color(0xff215e3f),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                color:
                    widget.invoice.isOverdue ? Colors.red[200] : Colors.white60,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.55,
        ),
        child: SizedBox(
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
      ),
      actions: [
        if (widget.isAdmin)
          TextButton.icon(
            onPressed:
                _isDeleting ? null : () => _confirmDeleteInvoice(context),
            icon: _isDeleting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_outline, size: 18),
            label: Text(_isDeleting ? 'Deleting...' : 'Delete'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        const Spacer(),
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
          const SnackBar(
            content: Text('Invoice deleted successfully'),
            backgroundColor: Color(0xff215e3f),
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
                  border: const OutlineInputBorder(),
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
        decoration: const BoxDecoration(
          color: Color(0xff215e3f),
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
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Proof of Payment',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              ),
              const SizedBox(height: 8),
              MouseRegion(
                child: _proofUrl != null
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
                                onPressed: () =>
                                    setState(() => _proofUrl = null),
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
                        bucket: 'payment-proofs',
                        folder: Supabase.instance.client.auth.currentUser?.id,
                        onUploadComplete: (url) {
                          if (url.isNotEmpty) {
                            setState(() => _proofUrl = url);
                          }
                        },
                      ),
              ),
            ],
          ),
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

  void _recalcTotal() {
    if (_lineItems.isEmpty) return;
    double total = 0;
    for (final item in _lineItems) {
      total += double.tryParse(item.amountController.text) ?? 0;
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
      titlePadding: EdgeInsets.zero,
      title: Container(
        decoration: const BoxDecoration(
          color: Color(0xff215e3f),
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
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon,
                                size: 18,
                                color: isSelected
                                    ? const Color(0xff215e3f)
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
                                    ? const Color(0xff215e3f)
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
