import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:core_data/core_data.dart';
import 'package:core_domain/core_domain.dart';
import 'package:core_ui/core_ui.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';

const _brandColor = Color(0xff215e3f);

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _myPendingCount = 0;
  int _allPendingCount = 0;
  bool _showChart = true;

  @override
  void initState() {
    super.initState();
    final appState = context.read<AppState>();
    final isStaff = appState.isStaff;
    _tabController = TabController(length: isStaff ? 3 : 1, vsync: this);
    if (isStaff) _loadTabBadges();
  }

  Future<void> _loadTabBadges() async {
    final appState = context.read<AppState>();
    final communityId = appState.activeCommunityId;
    if (communityId == null) return;

    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;

    try {
      final allResult = await client
          .from('payments')
          .select('id')
          .eq('community_id', communityId)
          .eq('status', 'submitted')
          .count(CountOption.exact);

      int myCount = 0;
      if (userId != null) {
        final householdRows = await client
            .from('household_members')
            .select('unit_id')
            .eq('user_id', userId);
        final unitIds = (householdRows as List)
            .map((e) => e['unit_id'] as String)
            .toSet()
            .toList();
        if (unitIds.isNotEmpty) {
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
                const Tab(text: 'Income'),
              ],
            ),
          Expanded(
            child: isStaff
                ? TabBarView(
                    controller: _tabController,
                    children: [
                      _InvoiceListView(
                        showMyInvoices: true,
                        onRefresh: _loadTabBadges,
                      ),
                      _InvoiceListView(
                        showMyInvoices: false,
                        onRefresh: _loadTabBadges,
                      ),
                      const _IncomeTrackerView(),
                    ],
                  )
                : _InvoiceListView(
                    showMyInvoices: true,
                    onRefresh: () async {},
                  ),
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _CreateInvoiceSheet(
        onCreated: () {
          _loadTabBadges();
          // Force rebuild of tab views
          setState(() {});
        },
      ),
    );
  }
}

// ============ INVOICE LIST VIEW ============

class _InvoiceListView extends StatefulWidget {
  final bool showMyInvoices;
  final VoidCallback onRefresh;

  const _InvoiceListView({
    required this.showMyInvoices,
    required this.onRefresh,
  });

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
    final isAdmin = appState.isAdmin;

    return RefreshIndicator(
      onRefresh: () async {
        _loadInvoices();
        widget.onRefresh();
      },
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
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brandColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          }

          final invoices = snapshot.data ?? [];

          if (invoices.isEmpty) {
            return ListView(
              children: [
                const SizedBox(height: 120),
                Center(
                  child: Column(
                    children: [
                      Icon(Icons.receipt_long,
                          size: 64, color: Colors.grey[400]),
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
                ),
              ],
            );
          }

          // Calculate summary for My Invoices tab
          final totalDue = widget.showMyInvoices
              ? invoices
                  .where((i) => i.status == InvoiceStatus.unpaid)
                  .fold(0.0, (sum, i) => sum + i.amount)
              : 0.0;

          return Column(
            children: [
              if (widget.showMyInvoices && totalDue > 0)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _brandColor,
                        _brandColor.withOpacity(0.7),
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Outstanding',
                        style: TextStyle(fontSize: 13, color: Colors.white70),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        NumberFormat.currency(symbol: '₱', decimalDigits: 2)
                            .format(totalDue),
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: invoices.length,
                  itemBuilder: (context, index) {
                    final invoice = invoices[index];
                    return _InvoiceCard(
                      invoice: invoice,
                      isStaff: isStaff,
                      isAdmin: isAdmin,
                      onRefresh: () {
                        _loadInvoices();
                        widget.onRefresh();
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ============ INVOICE CARD ============

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

  Color _getStatusColor() {
    if (invoice.status == InvoiceStatus.paid) {
      return const Color.fromRGBO(39, 99, 67, 1);
    }
    if (invoice.isOverdue) return Colors.red;
    return Colors.orange;
  }

  String _getStatusText() {
    if (invoice.status == InvoiceStatus.paid) return 'PAID';
    if (invoice.status == InvoiceStatus.void_) return 'VOID';
    if (invoice.status == InvoiceStatus.refunded) return 'REFUNDED';
    if (invoice.isOverdue) return 'OVERDUE';
    return 'UNPAID';
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '₱', decimalDigits: 2);
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showInvoiceDetails(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    _getCategoryLabel(invoice.category),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getStatusColor().withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _getStatusText(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(),
                      ),
                    ),
                  ),
                ],
              ),
              if (invoice.description != null) ...[
                const SizedBox(height: 4),
                Text(
                  invoice.description!,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
              if (invoice.periodStart != null && invoice.periodEnd != null) ...[
                const SizedBox(height: 2),
                Text(
                  '${dateFormat.format(invoice.periodStart!)} – ${dateFormat.format(invoice.periodEnd!)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    currencyFormat.format(invoice.amount),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Due: ${dateFormat.format(invoice.dueDate)}',
                    style: TextStyle(
                      fontSize: 13,
                      color: invoice.isOverdue ? Colors.red : Colors.grey[600],
                    ),
                  ),
                ],
              ),
              if (invoice.status == InvoiceStatus.unpaid) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => PaymentProofUploadDialog(
                          invoice: invoice,
                          onPaymentSubmitted: onRefresh,
                        ),
                      );
                    },
                    icon: const Icon(Icons.payment, size: 18),
                    label: const Text('Submit Payment'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brandColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showInvoiceDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _InvoiceDetailsSheet(
        invoice: invoice,
        isStaff: isStaff,
        isAdmin: isAdmin,
        onRefresh: onRefresh,
      ),
    );
  }
}

// ============ INVOICE DETAILS BOTTOM SHEET ============

class _InvoiceDetailsSheet extends StatefulWidget {
  final Invoice invoice;
  final bool isStaff;
  final bool isAdmin;
  final VoidCallback onRefresh;

  const _InvoiceDetailsSheet({
    required this.invoice,
    required this.isStaff,
    required this.isAdmin,
    required this.onRefresh,
  });

  @override
  State<_InvoiceDetailsSheet> createState() => _InvoiceDetailsSheetState();
}

class _InvoiceDetailsSheetState extends State<_InvoiceDetailsSheet> {
  Future<List<Payment>>? _paymentsFuture;
  Future<List<InvoiceLineItem>>? _lineItemsFuture;
  bool _isDeleting = false;
  String? _unitNo;

  @override
  void initState() {
    super.initState();
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
        setState(() => _unitNo = result['unit_no'] as String?);
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

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '₱', decimalDigits: 2);
    final dateFormat = DateFormat('MMM dd, yyyy');

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          // Green header
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: _brandColor,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _getCategoryLabel(widget.invoice.category),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
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
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (_unitNo != null) ...[
                        Text(
                          'Unit $_unitNo',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
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
          ),

          // Scrollable content
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
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
                                fontSize: 13, color: Colors.grey[600]),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Line items
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
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
                    }
                    final items = snapshot.data ?? [];
                    if (items.isEmpty) return _buildTotalRow(currencyFormat);
                    return Column(
                      children: [
                        ...items.map((item) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(item.label,
                                            style:
                                                const TextStyle(fontSize: 14)),
                                        if (item.metadata != null &&
                                            item.metadata!['detail'] != null)
                                          Text(
                                            item.metadata!['detail'] as String,
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[500]),
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

                // Payment history header
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

                // Payments list
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
                      children: payments
                          .map((payment) => _PaymentCard(
                                payment: payment,
                                isStaff: widget.isStaff,
                                onRefresh: () {
                                  _loadPayments();
                                  widget.onRefresh();
                                },
                              ))
                          .toList(),
                    );
                  },
                ),

                const SizedBox(height: 16),

                // Action buttons
                if (widget.invoice.status == InvoiceStatus.unpaid)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        showDialog(
                          context: context,
                          builder: (ctx) => PaymentProofUploadDialog(
                            invoice: widget.invoice,
                            onPaymentSubmitted: widget.onRefresh,
                          ),
                        );
                      },
                      icon: const Icon(Icons.payment),
                      label: const Text('Submit Payment'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _brandColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),

                if (widget.isAdmin) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed:
                          _isDeleting ? null : () => _confirmDelete(context),
                      icon: _isDeleting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.delete_outline,
                              size: 18, color: Colors.red),
                      label:
                          Text(_isDeleting ? 'Deleting...' : 'Delete Invoice'),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                    ),
                  ),
                ],

                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(NumberFormat currencyFormat) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Total',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Text(
          currencyFormat.format(widget.invoice.amount),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: _brandColor,
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Invoice'),
        content: const Text(
          'Are you sure? This will also delete all associated payments and line items. This action cannot be undone.',
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
        context.read<AppState>().requestBadgeRefresh();
        Navigator.of(context).pop();
        widget.onRefresh();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invoice deleted'),
            backgroundColor: _brandColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
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

// ============ PAYMENT CARD ============

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

  Color _getPaymentStatusColor() {
    switch (widget.payment.status) {
      case PaymentStatus.verified:
        return const Color.fromRGBO(39, 99, 67, 1);
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
    final payment = widget.payment;

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
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

            // Payment proof thumbnail
            if (payment.proofUrl != null) ...[
              const SizedBox(height: 10),
              InkWell(
                onTap: () => _showProofDialog(context, payment.proofUrl!),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 64,
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
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 64,
                            color: Colors.grey[200],
                            child: const Icon(Icons.receipt_long,
                                color: Colors.grey, size: 24),
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
                            Text('Tap to view',
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

            // Rejection reason
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

            // Staff verify/reject buttons
            if (widget.isStaff &&
                payment.status == PaymentStatus.submitted) ...[
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
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _verifyPayment(context),
                      icon: const Icon(Icons.check,
                          size: 16, color: Colors.white),
                      label: const Text('Verify'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromRGBO(39, 99, 67, 1),
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
      await repo.verifyPayment(paymentId: widget.payment.id, verified: true);
      if (context.mounted) {
        context.read<AppState>().requestBadgeRefresh();
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

  Future<void> _rejectPayment(BuildContext context) async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for rejection:'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Enter reason...',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      setState(() => _isProcessing = true);
      try {
        final repo = context.read<BillingRepository>();
        await repo.verifyPayment(
          paymentId: widget.payment.id,
          verified: false,
          rejectionReason: reasonController.text,
        );
        if (context.mounted) {
          context.read<AppState>().requestBadgeRefresh();
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
              constraints: const BoxConstraints(maxHeight: 400),
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
                            size: 48, color: Colors.grey),
                      ),
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
}

// ============ CREATE INVOICE (STAFF) ============

class _CreateInvoiceSheet extends StatefulWidget {
  final VoidCallback onCreated;

  const _CreateInvoiceSheet({required this.onCreated});

  @override
  State<_CreateInvoiceSheet> createState() => _CreateInvoiceSheetState();
}

class _CreateInvoiceSheetState extends State<_CreateInvoiceSheet> {
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
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: _brandColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              child: Row(
                children: [
                  const Icon(Icons.receipt_outlined,
                      color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Create Invoice',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        )),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Form
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Unit selector
                    FutureBuilder<List<Unit>>(
                      future: _unitsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
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
                          decoration: InputDecoration(
                            labelText: 'Unit',
                            prefixIcon: const Icon(Icons.apartment, size: 20),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          items: units
                              .map((unit) => DropdownMenuItem(
                                    value: unit.id,
                                    child: Text('Unit ${unit.unitNumber}'),
                                  ))
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _selectedUnitId = value),
                          validator: (v) => v == null ? 'Required' : null,
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // Category chips
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
                        return ChoiceChip(
                          label: Text(_chipLabel(category)),
                          selected: isSelected,
                          onSelected: (_) =>
                              setState(() => _selectedCategory = category),
                          selectedColor: _brandColor.withOpacity(0.15),
                          labelStyle: TextStyle(
                            color: isSelected ? _brandColor : Colors.grey[700],
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
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
                        hintText: 'e.g., March 2026 Water Billing',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
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
                                lastDate: DateTime.now()
                                    .add(const Duration(days: 365)),
                              );
                              if (date != null) {
                                setState(() => _periodStart = date);
                              }
                            },
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'Period Start',
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                suffixIcon:
                                    const Icon(Icons.calendar_today, size: 18),
                              ),
                              child: Text(
                                _periodStart != null
                                    ? dateFormat.format(_periodStart!)
                                    : 'Optional',
                                style: TextStyle(
                                  color:
                                      _periodStart != null ? null : Colors.grey,
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
                                lastDate: DateTime.now()
                                    .add(const Duration(days: 365)),
                              );
                              if (date != null) {
                                setState(() => _periodEnd = date);
                              }
                            },
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'Period End',
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                suffixIcon:
                                    const Icon(Icons.calendar_today, size: 18),
                              ),
                              child: Text(
                                _periodEnd != null
                                    ? dateFormat.format(_periodEnd!)
                                    : 'Optional',
                                style: TextStyle(
                                  color:
                                      _periodEnd != null ? null : Colors.grey,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Amount
                    TextFormField(
                      controller: _amountController,
                      decoration: InputDecoration(
                        labelText: 'Amount',
                        prefixText: '₱ ',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
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

                    // Due date
                    InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _dueDate,
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) {
                          setState(() => _dueDate = date);
                        }
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Due Date',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          suffixIcon: const Icon(Icons.calendar_today),
                        ),
                        child: Text(dateFormat.format(_dueDate)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Line items
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Line Items',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            )),
                        TextButton.icon(
                          onPressed: _addLineItem,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Item'),
                        ),
                      ],
                    ),
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
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            IconButton(
                              onPressed: () => _removeLineItem(i),
                              icon: const Icon(Icons.close, size: 18),
                              color: Colors.red[400],
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),

                    // Notes
                    TextFormField(
                      controller: _notesController,
                      decoration: InputDecoration(
                        labelText: 'Notes (Optional)',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),

                    // Submit
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
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.receipt_long_rounded),
                        label: Text(_isCreating ? 'Creating...' : 'Create',
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _brandColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
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
          const SnackBar(
            content: Text('Invoice created successfully'),
            backgroundColor: _brandColor,
          ),
        );
        widget.onCreated();
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
    setState(() => _lineItems.removeAt(index));
    _recalcTotal();
  }

  String _chipLabel(InvoiceCategory cat) {
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
}

class _LineItemEntry {
  final TextEditingController labelController;
  final TextEditingController amountController;

  _LineItemEntry({
    required this.labelController,
    required this.amountController,
  });
}

/// Payment Proof Upload Dialog
class PaymentProofUploadDialog extends StatefulWidget {
  final Invoice invoice;
  final VoidCallback onPaymentSubmitted;

  const PaymentProofUploadDialog({
    super.key,
    required this.invoice,
    required this.onPaymentSubmitted,
  });

  @override
  State<PaymentProofUploadDialog> createState() =>
      _PaymentProofUploadDialogState();
}

class _PaymentProofUploadDialogState extends State<PaymentProofUploadDialog> {
  final _amountController = TextEditingController();
  String? _proofUrl;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill with invoice amount
    _amountController.text = widget.invoice.amount.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_proofUrl == null || _proofUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload payment proof')),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final appState = context.read<AppState>();
      final repo = context.read<BillingRepository>();

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
            content: Text('Payment submitted for verification'),
            backgroundColor: Color.fromRGBO(39, 99, 67, 1),
          ),
        );
        widget.onPaymentSubmitted();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Upload Payment Proof'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Invoice info
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Invoice: ${widget.invoice.category.name.toUpperCase()}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Amount:'),
                        Text('₱${widget.invoice.amount.toStringAsFixed(2)}'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Payment amount
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Payment Amount',
                prefixText: '₱',
                border: OutlineInputBorder(),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),

            // Payment method info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Upload a clear photo of your GCash/bank receipt',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Image upload
            const Text(
              'Payment Proof',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ImageUploadWidget(
              bucket: 'payment-proofs',
              onUploadComplete: (url) {
                setState(() => _proofUrl = url.isNotEmpty ? url : null);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _isSubmitting ? null : _handleSubmit,
          icon: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.upload),
          label: Text(_isSubmitting ? 'Submitting...' : 'Submit'),
        ),
      ],
    );
  }
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
          _IncomeSummaryCard(
            label: 'Total Income',
            amount: currencyFormat.format(grandTotal),
            icon: Icons.trending_up,
            color: _brandColor,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _IncomeSummaryCard(
                  label: 'From Invoices',
                  amount: currencyFormat.format(_verifiedTotal),
                  icon: Icons.receipt_long,
                  color: Colors.blue.shade700,
                  compact: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _IncomeSummaryCard(
                  label: 'Manual Entries',
                  amount: currencyFormat.format(_manualTotal),
                  icon: Icons.edit_note,
                  color: Colors.orange.shade700,
                  compact: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Manual Income section
          Row(
            children: [
              Icon(Icons.edit_note, size: 20, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Manual Income Entries',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => _showAddManualIncomeDialog(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
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
                  onDeleted: () {
                    setState(() => _loading = true);
                    _loadData();
                  },
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
                'Invoice Income (Verified)',
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
        onCreated: () {
          setState(() => _loading = true);
          _loadData();
        },
      ),
    );
  }
}

// ============ INCOME SUMMARY CARD ============

class _IncomeSummaryCard extends StatelessWidget {
  final String label;
  final String amount;
  final IconData icon;
  final Color color;
  final bool compact;

  const _IncomeSummaryCard({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(compact ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: compact ? 16 : 18, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: compact ? 11 : 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              amount,
              style: TextStyle(
                fontSize: compact ? 16 : 22,
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

// ============ MANUAL INCOME CARD ============

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
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  currencyFormat.format(entry.amount),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: _brandColor,
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
        content: const Text('Are you sure? This action cannot be undone.'),
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
            const SnackBar(
              content: Text('Income entry deleted'),
              backgroundColor: _brandColor,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e')),
          );
        }
      }
    }
  }
}

// ============ VERIFIED PAYMENT CARD ============

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
                color: _brandColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.verified, size: 20, color: _brandColor),
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
                          color: _brandColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          payment.method.replaceAll('_', ' ').toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _brandColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          payment.verifiedAt != null
                              ? 'Verified ${dateFormat.format(payment.verifiedAt!)}'
                              : 'Posted ${dateFormat.format(payment.postedAt)}',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[500]),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Text(
              currencyFormat.format(payment.amount),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: _brandColor,
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
    final dateFormat = DateFormat('MMM dd, yyyy');

    return AlertDialog(
      title: const Text('Add Manual Income'),
      content: SizedBox(
        width: double.maxFinite,
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
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
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
                  spacing: 6,
                  runSpacing: 6,
                  children: IncomeCategory.values.map((category) {
                    final isSelected = _selectedCategory == category;
                    return ChoiceChip(
                      label: Text(
                        category.name[0].toUpperCase() +
                            category.name.substring(1),
                        style: TextStyle(fontSize: 12),
                      ),
                      selected: isSelected,
                      onSelected: (_) =>
                          setState(() => _selectedCategory = category),
                      selectedColor: _brandColor.withValues(alpha: 0.15),
                      labelStyle: TextStyle(
                        color: isSelected ? _brandColor : Colors.grey[700],
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
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
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
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

                // Income date
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
                      suffixIcon: const Icon(Icons.calendar_today, size: 18),
                    ),
                    child: Text(dateFormat.format(_incomeDate)),
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _sourceController,
                  decoration: InputDecoration(
                    labelText: 'Source (Optional)',
                    hintText: 'e.g., Unit 5A, External vendor',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _notesController,
                  decoration: InputDecoration(
                    labelText: 'Notes (Optional)',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  maxLines: 2,
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
        ElevatedButton.icon(
          onPressed: _isCreating ? null : _submit,
          icon: _isCreating
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.add_circle_outline),
          label: Text(_isCreating ? 'Adding...' : 'Add Income'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _brandColor,
            foregroundColor: Colors.white,
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
          const SnackBar(
            content: Text('Income entry added'),
            backgroundColor: _brandColor,
          ),
        );
        widget.onCreated();
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
      if (mounted) {
        setState(() {
          _monthlyData = months;
          _loading = false;
        });
      }
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
                        if (idx < 0 || idx >= data.length) {
                          return const SizedBox.shrink();
                        }
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
                      color: theme.colorScheme.primary.withValues(alpha: 0.08),
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
