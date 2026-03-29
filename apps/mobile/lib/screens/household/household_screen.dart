import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:core_data/core_data.dart';
import 'package:core_domain/core_domain.dart';

class HouseholdScreen extends StatefulWidget {
  const HouseholdScreen({super.key});

  @override
  State<HouseholdScreen> createState() => _HouseholdScreenState();
}

class _HouseholdScreenState extends State<HouseholdScreen> {
  Future<List<Unit>>? _unitsFuture;
  Future<int>? _memberCountFuture;
  Unit? _selectedUnit;

  @override
  void initState() {
    super.initState();
    _loadUnits();
  }

  void _loadUnits() {
    final appState = context.read<AppState>();
    final repo = context.read<HouseholdRepository>();
    final communityId = appState.activeCommunityId;
    if (communityId == null) return;

    final unitsFuture = appState.isStaff
        ? repo.getUnits(communityId)
        : repo.getMyUnits(communityId);

    setState(() {
      _unitsFuture = unitsFuture;
      _selectedUnit = null;
      _memberCountFuture = appState.isStaff
          ? repo.getTotalMemberCount(communityId)
          : unitsFuture.then((units) =>
              repo.getMemberCountForUnits(units.map((u) => u.id).toList()));
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isStaff = appState.isStaff;

    if (_selectedUnit != null) {
      return _UnitDetailScreen(
        unit: _selectedUnit!,
        isStaff: isStaff,
        onBack: () => setState(() => _selectedUnit = null),
        onRefresh: _loadUnits,
      );
    }

    return FutureBuilder<List<Unit>>(
      future: _unitsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _loadUnits,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final units = snapshot.data ?? [];

        if (units.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.home_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No household found'),
                SizedBox(height: 8),
                Text(
                  'Contact your community admin to be added to a unit',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        // Non-staff with a single unit → go straight to detail
        if (!isStaff && units.length == 1) {
          return _UnitDetailBody(
            unit: units.first,
            isStaff: false,
            onRefresh: _loadUnits,
          );
        }

        return _buildUnitList(units);
      },
    );
  }

  Widget _buildUnitList(List<Unit> units) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Badges row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${units.length} units',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FutureBuilder<int>(
                future: _memberCountFuture,
                builder: (context, snap) {
                  final count = snap.data;
                  if (count == null) return const SizedBox.shrink();
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$count members',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        // Unit list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: units.length,
            itemBuilder: (context, index) {
              final unit = units[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      unit.unitNo.length > 2
                          ? unit.unitNo.substring(0, 2)
                          : unit.unitNo,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(
                    'Unit ${unit.unitNo}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: unit.unitType != null ? Text(unit.unitType!) : null,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => setState(() => _selectedUnit = unit),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ============ UNIT DETAIL (full screen with AppBar) ============

class _UnitDetailScreen extends StatelessWidget {
  final Unit unit;
  final bool isStaff;
  final VoidCallback onBack;
  final VoidCallback onRefresh;

  const _UnitDetailScreen({
    required this.unit,
    required this.isStaff,
    required this.onBack,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: onBack,
        ),
        title: Text('Unit ${unit.unitNo}'),
      ),
      body: _UnitDetailBody(unit: unit, isStaff: isStaff, onRefresh: onRefresh),
    );
  }
}

// ============ UNIT DETAIL BODY (shared) ============

class _UnitDetailBody extends StatefulWidget {
  final Unit unit;
  final bool isStaff;
  final VoidCallback onRefresh;

  const _UnitDetailBody({
    required this.unit,
    required this.isStaff,
    required this.onRefresh,
  });

  @override
  State<_UnitDetailBody> createState() => _UnitDetailBodyState();
}

class _UnitDetailBodyState extends State<_UnitDetailBody> {
  Future<List<HouseholdMember>>? _membersFuture;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  void _loadMembers() {
    final repo = context.read<HouseholdRepository>();
    setState(() {
      _membersFuture = repo.getHouseholdMembers(widget.unit.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Unit header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary,
                theme.colorScheme.primary.withOpacity(0.7),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.home, color: Colors.white70, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Unit ${widget.unit.unitNo}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (widget.unit.unitType != null)
                Text(
                  widget.unit.unitType!,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
            ],
          ),
        ),

        // Members list
        Expanded(
          child: FutureBuilder<List<HouseholdMember>>(
            future: _membersFuture,
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
                          size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Error: ${snapshot.error}'),
                    ],
                  ),
                );
              }

              final members = snapshot.data ?? [];

              if (members.isEmpty) {
                return const Center(
                  child: Text('No members in this unit'),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: members.length,
                itemBuilder: (context, index) {
                  final member = members[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          member.displayName.substring(0, 1).toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(
                        member.displayName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(_getRoleLabel(member.memberRole)),
                          if (member.relationship != null)
                            Text(
                              member.relationship!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                        ],
                      ),
                      trailing: Chip(
                        label: Text(
                          _getRoleLabel(member.memberRole),
                          style: const TextStyle(fontSize: 11),
                        ),
                        backgroundColor:
                            _getRoleColor(member.memberRole).withOpacity(0.2),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  String _getRoleLabel(HouseholdRole role) {
    switch (role) {
      case HouseholdRole.primary:
        return 'Primary';
      case HouseholdRole.member:
        return 'Member';
      case HouseholdRole.child:
        return 'Child';
      case HouseholdRole.tenant:
        return 'Tenant';
      case HouseholdRole.other:
        return 'Other';
    }
  }

  Color _getRoleColor(HouseholdRole role) {
    switch (role) {
      case HouseholdRole.primary:
        return Colors.purple;
      case HouseholdRole.member:
        return Colors.blue;
      case HouseholdRole.child:
        return Colors.orange;
      case HouseholdRole.tenant:
        return const Color.fromRGBO(39, 99, 67, 1);
      case HouseholdRole.other:
        return Colors.grey;
    }
  }
}
