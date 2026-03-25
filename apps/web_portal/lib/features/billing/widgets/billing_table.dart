import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import '../data/billing_mock.dart';

/// Compact invoice table using DataTable2.
class BillingTable extends StatelessWidget {
  final List<InvoiceMock> invoices;
  const BillingTable({super.key, required this.invoices});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DataTable2(
      columnSpacing: 16,
      horizontalMargin: 16,
      minWidth: 500,
      headingRowColor: WidgetStateProperty.all(
        theme.colorScheme.surfaceContainerHighest,
      ),
      columns: const [
        DataColumn2(label: Text('Invoice #'), size: ColumnSize.M),
        DataColumn2(label: Text('Period'), size: ColumnSize.S),
        DataColumn2(label: Text('Amount'), size: ColumnSize.S, numeric: true),
        DataColumn2(label: Text('Status'), size: ColumnSize.S),
        DataColumn2(label: Text(''), size: ColumnSize.S, fixedWidth: 60),
      ],
      rows: invoices.map((inv) {
        return DataRow2(cells: [
          DataCell(Text(inv.id,
              style: const TextStyle(fontWeight: FontWeight.w600))),
          DataCell(Text(inv.period)),
          DataCell(Text('₱${inv.amount.toStringAsFixed(0)}')),
          DataCell(_InvoiceStatusBadge(status: inv.status)),
          DataCell(IconButton(
            icon: const Icon(Icons.download_outlined, size: 18),
            tooltip: 'Download',
            onPressed: () {
              ScaffoldMessenger.of(context)
                ..clearSnackBars()
                ..showSnackBar(SnackBar(
                  content: Text('Download ${inv.id} (demo)'),
                  behavior: SnackBarBehavior.floating,
                ));
            },
          )),
        ]);
      }).toList(),
    );
  }
}

class _InvoiceStatusBadge extends StatelessWidget {
  final InvoiceStatus status;
  const _InvoiceStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (status) {
      InvoiceStatus.paid => (Colors.green.shade50, Colors.green.shade800),
      InvoiceStatus.unpaid => (Colors.orange.shade50, Colors.orange.shade800),
      InvoiceStatus.overdue => (Colors.red.shade50, Colors.red.shade800),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        invoiceStatusLabel(status),
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}
