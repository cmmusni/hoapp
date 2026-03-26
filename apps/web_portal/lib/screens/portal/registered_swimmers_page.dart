import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:core_data/core_data.dart';
import 'package:intl/intl.dart';

const _brand = Color(0xff215e3f);

class RegisteredSwimmersPage extends StatefulWidget {
  const RegisteredSwimmersPage({super.key});

  @override
  State<RegisteredSwimmersPage> createState() => _RegisteredSwimmersPageState();
}

class _RegisteredSwimmersPageState extends State<RegisteredSwimmersPage> {
  List<Map<String, dynamic>> _allSwimmers = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  String? _error;
  final _searchController = TextEditingController();
  String _statusFilter = 'all'; // all, approved, pending

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
          // Search and filter bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              children: [
                // Summary row
                if (!_loading && _error == null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        _buildStatChip(
                          Icons.people,
                          '${_allSwimmers.length}',
                          'Total Swimmers',
                          _brand,
                        ),
                        const SizedBox(width: 12),
                        _buildStatChip(
                          Icons.check_circle_outline,
                          '${_allSwimmers.where((s) => (s['pool_access_registrations'] as Map?)?['approved'] == true).length}',
                          'Approved',
                          Colors.green,
                        ),
                        const SizedBox(width: 12),
                        _buildStatChip(
                          Icons.pending_outlined,
                          '${_allSwimmers.where((s) => (s['pool_access_registrations'] as Map?)?['approved'] != true).length}',
                          'Pending',
                          Colors.orange,
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
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
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'all', label: Text('All')),
                        ButtonSegment(
                            value: 'approved', label: Text('Approved')),
                        ButtonSegment(value: 'pending', label: Text('Pending')),
                      ],
                      selected: {_statusFilter},
                      onSelectionChanged: (val) {
                        _statusFilter = val.first;
                        _applyFilters();
                      },
                      style: ButtonStyle(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
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
                            Text('Error: $_error'),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _load,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.pool,
                                    size: 64, color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                Text(
                                  _searchController.text.isNotEmpty ||
                                          _statusFilter != 'all'
                                      ? 'No swimmers match your filters'
                                      : 'No registered swimmers yet',
                                  style: const TextStyle(fontSize: 18),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Swimmers will appear here once residents register for pool access',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: _buildSwimmersList(),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(
      IconData icon, String count, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(
            count,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: color.withOpacity(0.8)),
          ),
        ],
      ),
    );
  }

  Widget _buildSwimmersList() {
    final dateFormat = DateFormat('MMM dd, yyyy');

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _filtered.length,
      itemBuilder: (context, index) {
        final swimmer = _filtered[index];
        final name = swimmer['full_name'] as String? ?? 'Unknown';
        final birthdateStr = swimmer['birthdate'] as String?;
        final age = _calcAge(birthdateStr);
        final reg =
            swimmer['pool_access_registrations'] as Map<String, dynamic>?;
        final registrantName = reg?['full_name'] as String? ?? 'Unknown';
        final approved = reg?['approved'] == true;
        final createdAt = DateTime.tryParse(swimmer['created_at'] ?? '');

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: approved
                  ? _brand.withOpacity(0.1)
                  : Colors.orange.withOpacity(0.1),
              child: Icon(
                Icons.pool,
                color: approved ? _brand : Colors.orange,
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                if (age != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Age $age',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.person_outline,
                        size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      'Registered by: $registrantName',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                ),
                if (createdAt != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Registered: ${dateFormat.format(createdAt)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  ),
                ],
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: approved
                    ? Colors.green.withOpacity(0.1)
                    : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                approved ? 'APPROVED' : 'PENDING',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: approved ? Colors.green[700] : Colors.orange[700],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
