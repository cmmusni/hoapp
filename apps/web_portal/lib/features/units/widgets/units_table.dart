import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import '../data/unit_mock.dart';

/// DataTable2-based units table with sticky header and sortable columns.
class UnitsTable extends StatefulWidget {
  final List<UnitMock> units;

  const UnitsTable({super.key, required this.units});

  @override
  State<UnitsTable> createState() => _UnitsTableState();
}

class _UnitsTableState extends State<UnitsTable> {
  int _sortColumnIndex = 0;
  bool _sortAscending = true;

  late List<UnitMock> _sorted;

  @override
  void initState() {
    super.initState();
    _sorted = List.of(widget.units);
  }

  @override
  void didUpdateWidget(UnitsTable old) {
    super.didUpdateWidget(old);
    if (old.units != widget.units) {
      _sorted = List.of(widget.units);
      _applySort();
    }
  }

  void _sort<T>(
      Comparable<T> Function(UnitMock u) getField, int col, bool asc) {
    _sorted.sort((a, b) {
      final va = getField(a);
      final vb = getField(b);
      return asc ? Comparable.compare(va, vb) : Comparable.compare(vb, va);
    });
    setState(() {
      _sortColumnIndex = col;
      _sortAscending = asc;
    });
  }

  void _applySort() {
    switch (_sortColumnIndex) {
      case 0:
        _sort((u) => u.id, 0, _sortAscending);
      case 1:
        _sort((u) => u.address, 1, _sortAscending);
      case 2:
        _sort((u) => u.status.index, 2, _sortAscending);
      case 3:
        _sort((u) => u.balance, 3, _sortAscending);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DataTable2(
      columnSpacing: 16,
      horizontalMargin: 16,
      fixedLeftColumns: 1,
      minWidth: 600,
      sortColumnIndex: _sortColumnIndex,
      sortAscending: _sortAscending,
      headingRowColor: WidgetStateProperty.all(
        theme.colorScheme.surfaceContainerHighest,
      ),
      columns: [
        DataColumn2(
          label: const Text('Unit ID'),
          size: ColumnSize.S,
          onSort: (col, asc) => _sort((u) => u.id, col, asc),
        ),
        DataColumn2(
          label: const Text('Address'),
          size: ColumnSize.L,
          onSort: (col, asc) => _sort((u) => u.address, col, asc),
        ),
        DataColumn2(
          label: const Text('Status'),
          size: ColumnSize.S,
          onSort: (col, asc) => _sort((u) => u.status.index, col, asc),
        ),
        DataColumn2(
          label: const Text('Balance'),
          size: ColumnSize.S,
          numeric: true,
          onSort: (col, asc) => _sort((u) => u.balance, col, asc),
        ),
        const DataColumn2(
          label: Text('Actions'),
          size: ColumnSize.S,
          fixedWidth: 130,
        ),
      ],
      rows: _sorted.map((u) {
        return DataRow2(
          cells: [
            DataCell(Text(u.id,
                style: const TextStyle(fontWeight: FontWeight.w600))),
            DataCell(Text(u.address)),
            DataCell(_StatusBadge(status: u.status)),
            DataCell(Text(
              u.balance > 0 ? '₱${u.balance.toStringAsFixed(0)}' : '—',
              style: TextStyle(
                color: u.balance > 0 ? theme.colorScheme.error : null,
                fontWeight: u.balance > 0 ? FontWeight.w600 : null,
              ),
            )),
            DataCell(Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  tooltip: 'View',
                  onPressed: () => _action(context, 'View ${u.id}'),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  tooltip: 'Edit',
                  onPressed: () => _action(context, 'Edit ${u.id}'),
                ),
                IconButton(
                  icon: const Icon(Icons.archive_outlined, size: 18),
                  tooltip: 'Archive',
                  onPressed: () => _action(context, 'Archive ${u.id}'),
                ),
              ],
            )),
          ],
        );
      }).toList(),
    );
  }

  void _action(BuildContext context, String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ));
  }
}

class _StatusBadge extends StatelessWidget {
  final UnitStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (status) {
      UnitStatus.occupied => (Colors.green.shade50, Colors.green.shade800),
      UnitStatus.vacant => (Colors.orange.shade50, Colors.orange.shade800),
      UnitStatus.maintenance => (Colors.red.shade50, Colors.red.shade800),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        statusLabel(status),
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}
