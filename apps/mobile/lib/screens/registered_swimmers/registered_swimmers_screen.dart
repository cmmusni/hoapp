import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:core_data/core_data.dart';
import 'package:intl/intl.dart';

const _brand = Color(0xff215e3f);

class RegisteredSwimmersScreen extends StatefulWidget {
  const RegisteredSwimmersScreen({super.key});

  @override
  State<RegisteredSwimmersScreen> createState() =>
      _RegisteredSwimmersScreenState();
}

class _RegisteredSwimmersScreenState extends State<RegisteredSwimmersScreen> {
  List<Map<String, dynamic>> _allSwimmers = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  String? _error;
  final _searchController = TextEditingController();
  String _statusFilter = 'all';

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
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final appState = context.read<AppState>();
      final communityId = appState.activeCommunityId;
      if (communityId == null) throw Exception('No community selected');

      final repo = context.read<PoolAccessRepository>();
      final data = await repo.getAllSwimmers(communityId);
      if (mounted) {
        setState(() {
          _allSwimmers = data;
          _loading = false;
        });
        _applyFilters();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filtered = _allSwimmers.where((s) {
        final name = (s['full_name'] as String? ?? '').toLowerCase();
        final reg = s['pool_access_registrations'] as Map<String, dynamic>?;
        final registrantName =
            (reg?['full_name'] as String? ?? '').toLowerCase();
        final approved = reg?['approved'] == true;

        final matchesSearch = query.isEmpty ||
            name.contains(query) ||
            registrantName.contains(query);

        final matchesStatus = _statusFilter == 'all' ||
            (_statusFilter == 'approved' && approved) ||
            (_statusFilter == 'pending' && !approved);

        return matchesSearch && matchesStatus;
      }).toList();
    });
  }

  int? _calcAge(String? birthdateStr) {
    if (birthdateStr == null) return null;
    final birthdate = DateTime.tryParse(birthdateStr);
    if (birthdate == null) return null;
    final now = DateTime.now();
    int years = now.year - birthdate.year;
    if (now.month < birthdate.month ||
        (now.month == birthdate.month && now.day < birthdate.day)) {
      years--;
    }
    return years;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Summary stats
          if (!_loading && _error == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  _StatChip(
                    icon: Icons.people,
                    count: '${_allSwimmers.length}',
                    label: 'Total',
                    color: _brand,
                  ),
                  const SizedBox(width: 12),
                  _StatChip(
                    icon: Icons.check_circle_outline,
                    count:
                        '${_allSwimmers.where((s) => (s['pool_access_registrations'] as Map?)?['approved'] == true).length}',
                    label: 'Approved',
                    color: Colors.green,
                  ),
                  const SizedBox(width: 12),
                  _StatChip(
                    icon: Icons.pending_outlined,
                    count:
                        '${_allSwimmers.where((s) => (s['pool_access_registrations'] as Map?)?['approved'] != true).length}',
                    label: 'Pending',
                    color: Colors.orange,
                  ),
                ],
              ),
            ),

          // Search + filter
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (_) => _applyFilters(),
                  decoration: InputDecoration(
                    hintText: 'Search by swimmer or registrant name...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _applyFilters();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'all', label: Text('All')),
                    ButtonSegment(value: 'approved', label: Text('Approved')),
                    ButtonSegment(value: 'pending', label: Text('Pending')),
                  ],
                  selected: {_statusFilter},
                  onSelectionChanged: (val) {
                    _statusFilter = val.first;
                    _applyFilters();
                  },
                  style:
                      const ButtonStyle(visualDensity: VisualDensity.compact),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline,
                                size: 48, color: Colors.red),
                            const SizedBox(height: 16),
                            Text(_error!),
                            const SizedBox(height: 16),
                            ElevatedButton(
                                onPressed: _load, child: const Text('Retry')),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: _filtered.isEmpty
                            ? ListView(
                                children: [
                                  const SizedBox(height: 80),
                                  Icon(Icons.pool,
                                      size: 64, color: Colors.grey[400]),
                                  const SizedBox(height: 16),
                                  Center(
                                    child: Text(
                                      _searchController.text.isNotEmpty ||
                                              _statusFilter != 'all'
                                          ? 'No swimmers match your filters'
                                          : 'No registered swimmers yet',
                                      style: const TextStyle(fontSize: 18),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Center(
                                    child: Text(
                                      'Swimmers will appear here once residents register for pool access',
                                      style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              )
                            : ListView.builder(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                itemCount: _filtered.length,
                                itemBuilder: (context, index) {
                                  final swimmer = _filtered[index];
                                  return _SwimmerCard(
                                    swimmer: swimmer,
                                    calcAge: _calcAge,
                                  );
                                },
                              ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String count;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.count,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(count,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: color)),
                Text(label,
                    style: TextStyle(fontSize: 10, color: Colors.grey[600])),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SwimmerCard extends StatelessWidget {
  final Map<String, dynamic> swimmer;
  final int? Function(String?) calcAge;

  const _SwimmerCard({required this.swimmer, required this.calcAge});

  @override
  Widget build(BuildContext context) {
    final name = swimmer['full_name'] as String? ?? 'Unknown';
    final birthdate = swimmer['birthdate'] as String?;
    final age = calcAge(birthdate);
    final reg = swimmer['pool_access_registrations'] as Map<String, dynamic>?;
    final registrantName = reg?['full_name'] as String? ?? 'Unknown';
    final approved = reg?['approved'] == true;
    final createdAt = swimmer['created_at'] != null
        ? DateTime.tryParse(swimmer['created_at'])
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: approved
              ? Colors.green.withOpacity(0.1)
              : Colors.orange.withOpacity(0.1),
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: TextStyle(
              color: approved ? Colors.green : Colors.orange,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (age != null)
              Text('Age: $age',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            Text('By: $registrantName',
                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            if (createdAt != null)
              Text(
                'Registered: ${DateFormat('MMM d, yyyy').format(createdAt)}',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
          ],
        ),
        trailing: Chip(
          label: Text(
            approved ? 'APPROVED' : 'PENDING',
            style: TextStyle(
              fontSize: 10,
              color: approved ? Colors.green : Colors.orange,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: approved
              ? Colors.green.withOpacity(0.1)
              : Colors.orange.withOpacity(0.1),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        isThreeLine: true,
      ),
    );
  }
}
