import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:core_data/core_data.dart';
import 'package:core_domain/core_domain.dart';
import 'package:core_ui/core_ui.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:file_picker/file_picker.dart';

const _brandColor = Color(0xff215e3f);

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
        ),
        validator: validator,
        onChanged: (value) {
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
            constraints: const BoxConstraints(maxHeight: 200),
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
  int _refreshKey = 0;

  int _tabCount(AppState appState) {
    if (!appState.isStaff) return 1;
    return appState.hasUnit ? 3 : 2;
  }

  @override
  void initState() {
    super.initState();
    final appState = context.read<AppState>();
    _tabController = TabController(length: _tabCount(appState), vsync: this);
    if (appState.isStaff) _loadTabBadges();
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
      List<String> unitIds = [];
      if (userId != null) {
        final householdRows = await client
            .from('household_members')
            .select('unit_id')
            .eq('user_id', userId);
        unitIds = (householdRows as List)
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

    final neededLength = _tabCount(appState);
    if (_tabController.length != neededLength) {
      _tabController.dispose();
      _tabController = TabController(length: neededLength, vsync: this);
    }

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
                if (appState.hasUnit)
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
                      if (appState.hasUnit)
                        _InvoiceListView(
                          key: ValueKey('my_$_refreshKey'),
                          showMyInvoices: true,
                          onRefresh: _loadTabBadges,
                        ),
                      _InvoiceListView(
                        key: ValueKey('all_$_refreshKey'),
                        showMyInvoices: false,
                        onRefresh: _loadTabBadges,
                      ),
                      const _IncomeTrackerView(),
                    ],
                  )
                : _InvoiceListView(
                    key: ValueKey('my_$_refreshKey'),
                    showMyInvoices: true,
                    onRefresh: () async {},
                  ),
          ),
        ],
      ),
      floatingActionButton: isStaff
          ? FloatingActionButton(
              onPressed: () => _showCreateInvoiceDialog(context),
              child: const Icon(Icons.add),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  void _showCreateInvoiceDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _CreateInvoiceSheet(
        onCreated: () {
          _loadTabBadges();
          setState(() => _refreshKey++);
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
    super.key,
    required this.showMyInvoices,
    required this.onRefresh,
  });

  @override
  State<_InvoiceListView> createState() => _InvoiceListViewState();
}

class _InvoiceListViewState extends State<_InvoiceListView> {
  Future<List<Invoice>>? _invoicesFuture;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Map<String, String> _unitNoMap = {};

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadInvoices() {
    final appState = context.read<AppState>();
    final repo = context.read<BillingRepository>();

    if (appState.activeCommunityId != null) {
      final future = widget.showMyInvoices
          ? repo.getMyInvoices(appState.activeCommunityId!)
          : repo.getInvoices(appState.activeCommunityId!);
      setState(() {
        _invoicesFuture = future;
      });
      // Batch-fetch unit numbers so search can match on them.
      future.then(_loadUnitNumbers).catchError((_) {});
    }
  }

  Future<void> _loadUnitNumbers(List<Invoice> invoices) async {
    final unitIds = invoices.map((i) => i.unitId).toSet().toList();
    if (unitIds.isEmpty) return;
    try {
      final rows = await Supabase.instance.client
          .from('units')
          .select('id, unit_no')
          .inFilter('id', unitIds);
      final map = <String, String>{};
      for (final r in (rows as List)) {
        final id = r['id'] as String?;
        final no = r['unit_no'] as String?;
        if (id != null && no != null) map[id] = no;
      }
      if (mounted) setState(() => _unitNoMap = map);
    } catch (_) {}
  }

  bool _matchesSearch(Invoice inv) {
    if (_searchQuery.isEmpty) return true;
    final q = _searchQuery.toLowerCase();
    final unitNo = _unitNoMap[inv.unitId] ?? '';
    final shortId = inv.id.length >= 8 ? inv.id.substring(0, 8) : inv.id;
    final status = inv.status == InvoiceStatus.paid
        ? 'paid'
        : (inv.isOverdue ? 'overdue' : 'unpaid');
    final fields = <String>[
      inv.description ?? '',
      inv.amount.toStringAsFixed(2),
      inv.category.name,
      status,
      shortId,
      unitNo,
    ];
    return fields.any((s) => s.toLowerCase().contains(q));
  }

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search by unit, description, amount, status...',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          isDense: true,
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _brandColor, width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onChanged: (value) => setState(() => _searchQuery = value),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isStaff = appState.isStaff;
    final isAdmin = appState.isAdmin;

    return Column(
      children: [
        _buildSearchBar(context),
        Expanded(
          child: RefreshIndicator(
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
                        const Icon(Icons.error_outline,
                            size: 48, color: Colors.red),
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

                final filtered = invoices.where(_matchesSearch).toList();

                if (filtered.isEmpty && _searchQuery.isNotEmpty) {
                  return ListView(
                    children: [
                      const SizedBox(height: 120),
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text('No invoices match "$_searchQuery"',
                              style: TextStyle(color: Colors.grey[500])),
                        ),
                      ),
                    ],
                  );
                }

                // Calculate summary for My Invoices tab (based on filtered list)
                final totalDue = widget.showMyInvoices
                    ? filtered
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
                              style: TextStyle(
                                  fontSize: 13, color: Colors.white70),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              NumberFormat.currency(
                                      symbol: '₱', decimalDigits: 2)
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
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final invoice = filtered[index];
                          // Admins can always submit payment; for My Invoices tab, everyone can.
                          final canSubmitPayment =
                              widget.showMyInvoices || isAdmin;
                          return _InvoiceCard(
                            key: ValueKey(invoice.id),
                            invoice: invoice,
                            unitNo: _unitNoMap[invoice.unitId],
                            isStaff: isStaff,
                            isAdmin: isAdmin,
                            canSubmitPayment: canSubmitPayment,
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
          ),
        ),
      ],
    );
  }
}

// ============ INVOICE CARD ============

class _InvoiceCard extends StatefulWidget {
  final Invoice invoice;
  final String? unitNo;
  final bool isStaff;
  final bool isAdmin;
  final bool canSubmitPayment;
  final VoidCallback onRefresh;

  const _InvoiceCard({
    super.key,
    required this.invoice,
    required this.unitNo,
    required this.isStaff,
    required this.isAdmin,
    required this.canSubmitPayment,
    required this.onRefresh,
  });

  @override
  State<_InvoiceCard> createState() => _InvoiceCardState();
}

class _InvoiceCardState extends State<_InvoiceCard> {
  bool _hasSubmittedPayment = false;
  bool _hasRejectedPayment = false;

  Invoice get invoice => widget.invoice;
  String? get _unitNo => widget.unitNo;

  @override
  void initState() {
    super.initState();
    if (invoice.status == InvoiceStatus.unpaid) {
      _checkLatestPaymentStatus();
    }
  }

  Future<void> _checkLatestPaymentStatus() async {
    try {
      final result = await Supabase.instance.client
          .from('payments')
          .select('id, status')
          .eq('invoice_id', invoice.id)
          .order('created_at', ascending: false)
          .limit(1);
      if (mounted && (result as List).isNotEmpty) {
        final status = result.first['status'] as String;
        setState(() {
          _hasSubmittedPayment = status == 'submitted';
          _hasRejectedPayment = status == 'rejected';
        });
      }
    } catch (_) {}
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
              if (_unitNo != null) ...[
                Text(
                  'Unit $_unitNo',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
              ],
              Row(
                children: [
                  Text(
                    invoice.description != null &&
                            invoice.description!.contains('+')
                        ? invoice.description!.toUpperCase()
                        : _getCategoryLabel(invoice.category),
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
              if (_hasSubmittedPayment) ...[
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.schedule,
                          size: 12, color: Colors.blue.shade700),
                      const SizedBox(width: 4),
                      Text(
                        'PAYMENT SUBMITTED',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (_hasRejectedPayment) ...[
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cancel, size: 12, color: Colors.red.shade700),
                      const SizedBox(width: 4),
                      Text(
                        'PAYMENT REJECTED',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
              if (invoice.status == InvoiceStatus.unpaid &&
                  widget.canSubmitPayment) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => PaymentProofUploadDialog(
                          invoice: invoice,
                          onPaymentSubmitted: widget.onRefresh,
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
        unitNo: widget.unitNo,
        isStaff: widget.isStaff,
        isAdmin: widget.isAdmin,
        canSubmitPayment: widget.canSubmitPayment,
        onRefresh: widget.onRefresh,
      ),
    );
  }
}

// ============ INVOICE DETAILS BOTTOM SHEET ============

class _InvoiceDetailsSheet extends StatefulWidget {
  final Invoice invoice;
  final String? unitNo;
  final bool isStaff;
  final bool isAdmin;
  final bool canSubmitPayment;
  final VoidCallback onRefresh;

  const _InvoiceDetailsSheet({
    required this.invoice,
    required this.unitNo,
    required this.isStaff,
    required this.isAdmin,
    required this.canSubmitPayment,
    required this.onRefresh,
  });

  @override
  State<_InvoiceDetailsSheet> createState() => _InvoiceDetailsSheetState();
}

class _InvoiceDetailsSheetState extends State<_InvoiceDetailsSheet> {
  Future<List<Payment>>? _paymentsFuture;
  Future<List<InvoiceLineItem>>? _lineItemsFuture;
  bool _isDeleting = false;

  String? get _unitNo => widget.unitNo;

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
                          widget.invoice.description != null &&
                                  widget.invoice.description!.contains('+')
                              ? widget.invoice.description!.toUpperCase()
                              : _getCategoryLabel(widget.invoice.category),
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
                        ...items.map((item) => Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                if (widget.invoice.status == InvoiceStatus.unpaid &&
                    widget.canSubmitPayment)
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
                    child: OutlinedButton.icon(
                      onPressed: () => _generateOR(context),
                      icon: const Icon(Icons.receipt_long, size: 18),
                      label: const Text('Generate OR'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _brandColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
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

  Future<void> _generateOR(BuildContext context) async {
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

      // Load owner name: household_members → profiles (two-step, no FK)
      String? ownerName;
      try {
        final hm = await Supabase.instance.client
            .from('household_members')
            .select('user_id')
            .eq('unit_id', widget.invoice.unitId)
            .eq('member_role', 'primary')
            .maybeSingle();
        final ownerId = hm?['user_id'] as String?;
        if (ownerId != null) {
          final profile = await Supabase.instance.client
              .from('profiles')
              .select('full_name')
              .eq('user_id', ownerId)
              .maybeSingle();
          ownerName = profile?['full_name'] as String?;
        }
      } catch (_) {}

      // Current user display name as "Prepared by"
      final currentUser = Supabase.instance.client.auth.currentUser;
      final preparedBy = currentUser?.userMetadata?['full_name'] as String?;

      final pdfService = PDFService();
      final pdfBytes = await pdfService.generateOfficialReceipt(
        community: community,
        invoice: widget.invoice,
        lineItems: lineItems,
        unitNo: _unitNo ?? '-',
        ownerName: ownerName,
        preparedBy: preparedBy,
        logoUrl: community.logoUrl,
      );

      await pdfService.sharePDF(
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
                        backgroundColor: Theme.of(context).colorScheme.primary,
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

  String? _selectedUnitId;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));
  bool _isCreating = false;
  bool _isScanning = false;

  final List<_CategoryEntry> _entries = [];
  Future<List<Unit>>? _unitsFuture;

  @override
  void initState() {
    super.initState();
    _loadUnits();
    _addEntry();
  }

  void _loadUnits() {
    final appState = context.read<AppState>();
    final repo = context.read<HouseholdRepository>();
    if (appState.activeCommunityId != null) {
      _unitsFuture = repo.getUnits(appState.activeCommunityId!);
    }
  }

  void _recalcTotal() {
    double total = 0;
    for (final e in _entries) {
      total += double.tryParse(e.amountController.text) ?? 0;
    }
    _amountController.text = total > 0 ? total.toStringAsFixed(2) : '';
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
                    // Scan invoice image button
                    _buildScanInvoiceButton(),
                    const SizedBox(height: 16),

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
                        return _buildUnitAutocomplete(
                          units: units,
                          selectedUnitId: _selectedUnitId,
                          onSelected: (id) =>
                              setState(() => _selectedUnitId = id),
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
                        Text('Billing Items',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                            )),
                        TextButton.icon(
                          onPressed: _addEntry,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Item'),
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
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      validator: (value) {
                        if (value?.isEmpty ?? true) {
                          return 'Add at least one billing item';
                        }
                        final amount = double.tryParse(value!);
                        if (amount == null || amount <= 0) {
                          return 'Total must be > 0';
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
                        if (date != null) setState(() => _dueDate = date);
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
            // Header
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
            // Category chips
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: InvoiceCategory.values.map((cat) {
                final isSelected = entry.category == cat;
                return ChoiceChip(
                  label: Text(_chipLabel(cat)),
                  selected: isSelected,
                  onSelected: (_) => setState(() => entry.category = cat),
                  selectedColor: _brandColor.withOpacity(0.15),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    color: isSelected ? _brandColor : Colors.grey[700],
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
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
          _entries.map((e) => _chipLabel(e.category)).toSet().toList();
      final description = categoryLabels.join(' + ');

      // Use first entry's category as invoice-level category
      final primaryCategory = _entries.first.category;

      final lineItems = _entries
          .map((e) => {
                'label': _chipLabel(e.category),
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

  Widget _buildScanInvoiceButton() {
    return GestureDetector(
      onTap: _isScanning ? null : _scanImage,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: _isScanning ? _brandColor : Colors.grey.shade300,
          ),
          borderRadius: BorderRadius.circular(12),
          color:
              _isScanning ? _brandColor.withOpacity(0.04) : Colors.grey.shade50,
        ),
        child: Column(
          children: [
            if (_isScanning) ...[
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(height: 8),
              const Text('Analyzing invoice image...',
                  style: TextStyle(fontSize: 13, color: Colors.grey)),
            ] else ...[
              const Icon(Icons.document_scanner_outlined,
                  size: 28, color: _brandColor),
              const SizedBox(height: 8),
              const Text('Upload Invoice Image',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _brandColor,
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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _incomeCategoryLabel(IncomeCategory c) {
    switch (c) {
      case IncomeCategory.dues:
        return 'Monthly Dues';
      case IncomeCategory.water:
        return 'Water';
      case IncomeCategory.amenity:
        return 'Amenity';
      case IncomeCategory.insurance:
        return 'Insurance';
      case IncomeCategory.rental:
        return 'Rental';
      case IncomeCategory.fee:
        return 'Fee';
      case IncomeCategory.donation:
        return 'Donation';
      case IncomeCategory.other:
        return 'Other';
    }
  }

  bool _matchesManual(ManualIncome e) {
    if (_searchQuery.isEmpty) return true;
    final q = _searchQuery.toLowerCase();
    return [
      e.description,
      e.source ?? '',
      e.notes ?? '',
      e.amount.toStringAsFixed(2),
      _incomeCategoryLabel(e.category),
    ].any((s) => s.toLowerCase().contains(q));
  }

  bool _matchesPayment(Payment p) {
    if (_searchQuery.isEmpty) return true;
    final q = _searchQuery.toLowerCase();
    final shortId = p.id.length >= 8 ? p.id.substring(0, 8) : p.id;
    return [
      p.amount.toStringAsFixed(2),
      DateFormat('MMM dd, yyyy').format(p.postedAt),
      p.status.name,
      shortId,
    ].any((s) => s.toLowerCase().contains(q));
  }

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search income by description, amount, category...',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          isDense: true,
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _brandColor, width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onChanged: (value) => setState(() => _searchQuery = value),
      ),
    );
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
    final filteredManual = _manualEntries.where(_matchesManual).toList();
    final filteredPayments = _verifiedPayments.where(_matchesPayment).toList();

    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _loading = true);
        await _loadData();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSearchBar(context),
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
          else if (filteredManual.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text('No manual entries match "$_searchQuery"',
                    style: TextStyle(color: Colors.grey[500])),
              ),
            )
          else
            ...(filteredManual.map((entry) => _ManualIncomeCard(
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
          else if (filteredPayments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text('No payments match "$_searchQuery"',
                    style: TextStyle(color: Colors.grey[500])),
              ),
            )
          else
            ...(filteredPayments.map((payment) => _VerifiedPaymentCard(
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
