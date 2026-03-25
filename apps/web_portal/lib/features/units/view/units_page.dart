import 'package:flutter/material.dart';
import '../data/unit_mock.dart';
import '../widgets/units_table.dart';
import '../../../core/widgets/empty_state.dart';

/// Admin page for managing community units.
/// Includes search, status filter, and DataTable2 table.
class UnitsPage extends StatefulWidget {
  const UnitsPage({super.key});

  @override
  State<UnitsPage> createState() => _UnitsPageState();
}

class _UnitsPageState extends State<UnitsPage> {
  final _searchController = TextEditingController();
  UnitStatus? _statusFilter;
  bool _isLoading = true;
  List<UnitMock> _units = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) {
      setState(() {
        _units = mockUnits;
        _isLoading = false;
      });
    }
  }

  List<UnitMock> get _filtered {
    var result = _units;
    final query = _searchController.text.toLowerCase();
    if (query.isNotEmpty) {
      result = result
          .where((u) =>
              u.id.toLowerCase().contains(query) ||
              u.address.toLowerCase().contains(query))
          .toList();
    }
    if (_statusFilter != null) {
      result = result.where((u) => u.status == _statusFilter).toList();
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filtered = _filtered;

    return Column(
      children: [
        // Toolbar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 260,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search units…',
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              DropdownButton<UnitStatus?>(
                value: _statusFilter,
                hint: const Text('All Status'),
                underline: const SizedBox.shrink(),
                items: [
                  const DropdownMenuItem(
                      value: null, child: Text('All Status')),
                  ...UnitStatus.values.map((s) =>
                      DropdownMenuItem(value: s, child: Text(statusLabel(s)))),
                ],
                onChanged: (v) => setState(() => _statusFilter = v),
              ),
              FilledButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context)
                    ..clearSnackBars()
                    ..showSnackBar(const SnackBar(
                      content: Text('Add Unit tapped (demo)'),
                      behavior: SnackBarBehavior.floating,
                    ));
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Unit'),
              ),
            ],
          ),
        ),

        // Table
        Expanded(
          child: filtered.isEmpty
              ? EmptyState(
                  icon: Icons.apartment,
                  title: 'No units found',
                  subtitle: 'Try adjusting your search or filter.',
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: UnitsTable(units: filtered),
                ),
        ),
      ],
    );
  }
}
