import 'package:flutter/material.dart';
import '../data/billing_mock.dart';
import '../widgets/billing_table.dart';
import '../widgets/billing_chart.dart';

/// Billing page with invoice table and trend chart.
class BillingPage extends StatefulWidget {
  const BillingPage({super.key});

  @override
  State<BillingPage> createState() => _BillingPageState();
}

class _BillingPageState extends State<BillingPage> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width > 900;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _buildTable(theme)),
                const SizedBox(width: 24),
                Expanded(flex: 2, child: _buildChart(theme)),
              ],
            )
          else ...[
            _buildChart(theme),
            const SizedBox(height: 24),
            _buildTable(theme),
          ],
        ],
      ),
    );
  }

  Widget _buildTable(ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                Icon(Icons.receipt_long, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Invoices', style: theme.textTheme.titleMedium),
              ],
            ),
          ),
          SizedBox(
            height: 500,
            child: BillingTable(invoices: mockInvoices),
          ),
        ],
      ),
    );
  }

  Widget _buildChart(ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('12-Month Trend', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                _LegendDot(color: theme.colorScheme.primary, label: 'Charged'),
                const SizedBox(width: 16),
                _LegendDot(color: theme.colorScheme.tertiary, label: 'Paid'),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 260,
              child: const BillingChart(),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
