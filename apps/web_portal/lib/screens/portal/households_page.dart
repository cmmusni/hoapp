import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:core_data/core_data.dart';
import 'package:core_domain/core_domain.dart';
import 'package:core_ui/core_ui.dart';
import 'package:data_table_2/data_table_2.dart';

class HouseholdsPage extends StatefulWidget {
  const HouseholdsPage({super.key});

  @override
  State<HouseholdsPage> createState() => _HouseholdsPageState();
}

class _HouseholdsPageState extends State<HouseholdsPage> {
  Future<List<Unit>>? _unitsFuture;
  Unit? _selectedUnit;

  @override
  void initState() {
    super.initState();
    _loadUnits();
  }

  void _loadUnits() {
    final appState = context.read<AppState>();
    final repo = context.read<HouseholdRepository>();

    if (appState.activeCommunityId != null) {
      setState(() {
        _unitsFuture = repo.getUnits(appState.activeCommunityId!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 1000;

        if (isWide) {
          // Two-column layout for wide screens
          return Row(
            children: [
              SizedBox(
                width: 300,
                child: _UnitList(
                  unitsFuture: _unitsFuture,
                  selectedUnit: _selectedUnit,
                  onUnitSelected: (unit) {
                    setState(() => _selectedUnit = unit);
                  },
                  onRefresh: _loadUnits,
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: _selectedUnit != null
                    ? _HouseholdDetail(
                        unit: _selectedUnit!,
                        onRefresh: _loadUnits,
                      )
                    : const Center(
                        child: Text('Select a unit to view household'),
                      ),
              ),
            ],
          );
        }

        // Single column for narrow screens
        if (_selectedUnit != null) {
          return _HouseholdDetailPage(
            unit: _selectedUnit!,
            onBack: () => setState(() => _selectedUnit = null),
            onRefresh: _loadUnits,
          );
        }

        return _UnitList(
          unitsFuture: _unitsFuture,
          selectedUnit: _selectedUnit,
          onUnitSelected: (unit) {
            setState(() => _selectedUnit = unit);
          },
          onRefresh: _loadUnits,
        );
      },
    );
  }
}

// ============ UNIT LIST ============

class _UnitList extends StatefulWidget {
  final Future<List<Unit>>? unitsFuture;
  final Unit? selectedUnit;
  final Function(Unit) onUnitSelected;
  final VoidCallback onRefresh;

  const _UnitList({
    required this.unitsFuture,
    required this.selectedUnit,
    required this.onUnitSelected,
    required this.onRefresh,
  });

  @override
  State<_UnitList> createState() => _UnitListState();
}

class _UnitListState extends State<_UnitList> {
  String _searchQuery = '';
  int _sortColumnIndex = 0;
  bool _sortAscending = true;

  List<Unit> _filterAndSort(List<Unit> units) {
    var filtered = units;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = units.where((u) {
        return u.unitNo.toLowerCase().contains(q) ||
            (u.unitType?.toLowerCase().contains(q) ?? false);
      }).toList();
    }
    filtered = List.of(filtered);
    switch (_sortColumnIndex) {
      case 0:
        filtered.sort((a, b) => _sortAscending
            ? a.unitNo.compareTo(b.unitNo)
            : b.unitNo.compareTo(a.unitNo));
      case 1:
        filtered.sort((a, b) => _sortAscending
            ? (a.unitType ?? '').compareTo(b.unitType ?? '')
            : (b.unitType ?? '').compareTo(a.unitType ?? ''));
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isStaff = appState.isStaff;
    final theme = Theme.of(context);

    return FutureBuilder<List<Unit>>(
      future: widget.unitsFuture,
      builder: (context, snapshot) {
        final units = snapshot.data ?? [];

        return Scaffold(
          body: Column(
            children: [
              // Search toolbar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search units…',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 10),
                          isDense: true,
                        ),
                        onChanged: (v) => setState(() => _searchQuery = v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: widget.onRefresh,
                      tooltip: 'Refresh',
                    ),
                  ],
                ),
              ),
              // Unit count badge
              if (units.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_filterAndSort(units).length} units',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              // DataTable2 or loading/error/empty states
              Expanded(
                child: _buildBody(context, snapshot, units, isStaff, theme),
              ),
            ],
          ),
          floatingActionButton: isStaff
              ? FloatingActionButton.extended(
                  onPressed: () => _showCreateUnitDialog(context, units),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Unit'),
                )
              : null,
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    AsyncSnapshot<List<Unit>> snapshot,
    List<Unit> units,
    bool isStaff,
    ThemeData theme,
  ) {
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
            HOAppButton(label: 'Retry', onPressed: widget.onRefresh),
          ],
        ),
      );
    }

    if (units.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.home_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text('No units yet', style: TextStyle(fontSize: 18)),
            if (isStaff) ...[
              const SizedBox(height: 8),
              Text('Create the first unit to get started',
                  style: TextStyle(color: Colors.grey[600])),
            ],
          ],
        ),
      );
    }

    final filtered = _filterAndSort(units);

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text('No units matching "$_searchQuery"',
                style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }

    return DataTable2(
      columnSpacing: 12,
      horizontalMargin: 16,
      minWidth: 300,
      sortColumnIndex: _sortColumnIndex,
      sortAscending: _sortAscending,
      headingRowColor: WidgetStateProperty.all(
        theme.colorScheme.surfaceContainerHighest,
      ),
      columns: [
        DataColumn2(
          label:
              const Text('Unit', style: TextStyle(fontWeight: FontWeight.w600)),
          size: ColumnSize.S,
          onSort: (col, asc) => setState(() {
            _sortColumnIndex = col;
            _sortAscending = asc;
          }),
        ),
        DataColumn2(
          label:
              const Text('Type', style: TextStyle(fontWeight: FontWeight.w600)),
          size: ColumnSize.L,
          onSort: (col, asc) => setState(() {
            _sortColumnIndex = col;
            _sortAscending = asc;
          }),
        ),
      ],
      rows: filtered.map((unit) {
        final isSelected = widget.selectedUnit?.id == unit.id;
        return DataRow2(
          selected: isSelected,
          color: isSelected
              ? WidgetStateProperty.all(
                  theme.colorScheme.primary.withOpacity(0.08))
              : null,
          onTap: () => widget.onUnitSelected(unit),
          cells: [
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.home, size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(unit.unitNo,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            DataCell(
              Text(
                unit.unitType ?? '—',
                style: TextStyle(
                  color: unit.unitType != null ? null : Colors.grey[400],
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  void _showCreateUnitDialog(BuildContext context, List<Unit> existingUnits) {
    showDialog(
      context: context,
      builder: (context) => _CreateUnitDialog(
        onCreate: widget.onRefresh,
        existingUnits: existingUnits,
      ),
    );
  }
}

// ============ HOUSEHOLD DETAIL (Embedded) ============

class _HouseholdDetail extends StatefulWidget {
  final Unit unit;
  final VoidCallback onRefresh;

  const _HouseholdDetail({
    required this.unit,
    required this.onRefresh,
  });

  @override
  State<_HouseholdDetail> createState() => _HouseholdDetailState();
}

class _HouseholdDetailState extends State<_HouseholdDetail> {
  Future<List<HouseholdMember>>? _membersFuture;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  @override
  void didUpdateWidget(_HouseholdDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.unit.id != widget.unit.id) {
      _loadMembers();
    }
  }

  void _loadMembers() {
    final repo = context.read<HouseholdRepository>();
    setState(() {
      _membersFuture = repo.getHouseholdMembers(widget.unit.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isStaff = appState.isStaff;

    return Scaffold(
      body: Column(
        children: [
          // Unit header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).primaryColor,
                  Theme.of(context).primaryColor.withOpacity(0.7),
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Unit ${widget.unit.unitNumber}',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (isStaff)
                      IconButton(
                        onPressed: () => _showUnitOptions(context),
                        icon: const Icon(Icons.more_vert, color: Colors.white),
                      ),
                  ],
                ),
                if (widget.unit.unitType != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.unit.unitType!,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Members list
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _loadMembers(),
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
                              size: 48, color: Colors.red),
                          const SizedBox(height: 16),
                          Text('Error: ${snapshot.error}'),
                          const SizedBox(height: 16),
                          HOAppButton(
                            label: 'Retry',
                            onPressed: _loadMembers,
                          ),
                        ],
                      ),
                    );
                  }

                  final members = snapshot.data ?? [];

                  if (members.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline,
                              size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          const Text(
                            'No household members yet',
                            style: TextStyle(fontSize: 18),
                          ),
                          if (isStaff) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Add members to this unit',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: members.length,
                    itemBuilder: (context, index) {
                      final member = members[index];
                      return _MemberCard(
                        member: member,
                        isStaff: isStaff,
                        onRefresh: _loadMembers,
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: isStaff
          ? FloatingActionButton.extended(
              onPressed: () => _showAddMemberDialog(context),
              icon: const Icon(Icons.person_add),
              label: const Text('Add Member'),
            )
          : null,
    );
  }

  void _showUnitOptions(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.settings_outlined,
                color: Color(0xff215e3f), size: 24),
            const SizedBox(width: 12),
            const Text('Unit Options',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Unit'),
              onTap: () {
                final parentContext = this.context;
                Navigator.of(context).pop();
                _deleteUnit(parentContext);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteUnit(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Colors.red, size: 24),
            const SizedBox(width: 12),
            const Text('Delete Unit',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(false),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete Unit ${widget.unit.unitNumber}? This will also remove all household members.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final repo = context.read<HouseholdRepository>();
        await repo.deleteUnit(widget.unit.id);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unit deleted')),
          );
          widget.onRefresh();
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  void _showAddMemberDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _AddMemberDialog(
        unit: widget.unit,
        onAdded: _loadMembers,
      ),
    );
  }
}

// ============ HOUSEHOLD DETAIL PAGE (Mobile) ============

class _HouseholdDetailPage extends StatefulWidget {
  final Unit unit;
  final VoidCallback onBack;
  final VoidCallback onRefresh;

  const _HouseholdDetailPage({
    required this.unit,
    required this.onBack,
    required this.onRefresh,
  });

  @override
  State<_HouseholdDetailPage> createState() => _HouseholdDetailPageState();
}

class _HouseholdDetailPageState extends State<_HouseholdDetailPage> {
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
    final appState = context.watch<AppState>();
    final isStaff = appState.isStaff;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
        title: Text('Unit ${widget.unit.unitNumber}'),
        actions: [
          if (isStaff)
            IconButton(
              onPressed: () => _showAddMemberDialog(context),
              icon: const Icon(Icons.person_add),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _loadMembers(),
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
                        size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error: ${snapshot.error}'),
                    const SizedBox(height: 16),
                    HOAppButton(
                      label: 'Retry',
                      onPressed: _loadMembers,
                    ),
                  ],
                ),
              );
            }

            final members = snapshot.data ?? [];

            if (members.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people_outline,
                        size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    const Text('No household members yet'),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: members.length,
              itemBuilder: (context, index) {
                final member = members[index];
                return _MemberCard(
                  member: member,
                  isStaff: isStaff,
                  onRefresh: _loadMembers,
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _showAddMemberDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _AddMemberDialog(
        unit: widget.unit,
        onAdded: _loadMembers,
      ),
    );
  }
}

// ============ MEMBER CARD ============

class _MemberCard extends StatelessWidget {
  final HouseholdMember member;
  final bool isStaff;
  final VoidCallback onRefresh;

  const _MemberCard({
    required this.member,
    required this.isStaff,
    required this.onRefresh,
  });

  Color _getRoleColor(MemberRole role) {
    switch (role) {
      case MemberRole.primary:
        return Colors.blue;
      case MemberRole.member:
        return Color.fromRGBO(39, 99, 67, 1);
      case MemberRole.child:
        return Colors.orange;
      case MemberRole.tenant:
        return Colors.purple;
      case MemberRole.other:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor:
                  _getRoleColor(member.memberRole).withOpacity(0.2),
              child: Icon(
                Icons.person,
                color: _getRoleColor(member.memberRole),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.displayName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              _getRoleColor(member.memberRole).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          member.memberRole.name.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _getRoleColor(member.memberRole),
                          ),
                        ),
                      ),
                      if (member.relationship != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          member.relationship!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (isStaff)
              PopupMenuButton(
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Text('Edit Role'),
                  ),
                  if (member.userId == null)
                    const PopupMenuItem(
                      value: 'invite',
                      child: Text('Invite to Sign Up'),
                    ),
                  const PopupMenuItem(
                    value: 'remove',
                    child: Text('Remove', style: TextStyle(color: Colors.red)),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'edit') {
                    _showEditMemberDialog(context);
                  } else if (value == 'invite') {
                    _inviteMember(context);
                  } else if (value == 'remove') {
                    _removeMember(context);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showEditMemberDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _EditMemberDialog(
        member: member,
        onUpdated: onRefresh,
      ),
    );
  }

  void _inviteMember(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _InviteMemberDialog(
        member: member,
        onInvited: onRefresh,
      ),
    );
  }

  Future<void> _removeMember(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.person_remove_outlined,
                color: Colors.red, size: 24),
            const SizedBox(width: 12),
            const Text('Remove Member',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(false),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        content: const Text(
            'Are you sure you want to remove this household member?'),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final repo = context.read<HouseholdRepository>();
        await repo.removeHouseholdMember(member.id);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Member removed')),
          );
          onRefresh();
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }
}

// ============ DIALOGS ============

class _InviteMemberDialog extends StatefulWidget {
  final HouseholdMember member;
  final VoidCallback onInvited;

  const _InviteMemberDialog({
    required this.member,
    required this.onInvited,
  });

  @override
  State<_InviteMemberDialog> createState() => _InviteMemberDialogState();
}

class _InviteMemberDialogState extends State<_InviteMemberDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isInviting = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.mail_outlined, color: Color(0xff215e3f), size: 24),
          const SizedBox(width: 12),
          const Text('Invite to Sign Up',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Send a sign-up invitation for ${widget.member.displayName}.',
                style: TextStyle(color: Colors.grey[700]),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Required';
                  if (!value!.contains('@')) return 'Invalid email';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 20, color: Colors.blue),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'An invitation link will be sent. Once they sign up, their account will be linked to this household member.',
                        style: TextStyle(fontSize: 12, color: Colors.blue),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        HOAppButton(
          label: _isInviting ? 'Sending...' : 'Send Invite',
          onPressed: _isInviting ? null : _sendInvite,
        ),
      ],
    );
  }

  Future<void> _sendInvite() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isInviting = true);

    try {
      final repo = context.read<CommunityRepository>();

      await repo.createInvite(
        communityId: widget.member.communityId,
        email: _emailController.text.trim(),
        role: 'resident',
        unitId: widget.member.unitId,
        inviteKind: 'household',
        householdMemberId: widget.member.id,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invitation sent to ${_emailController.text.trim()}'),
          ),
        );
        widget.onInvited();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isInviting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}

class _CreateUnitDialog extends StatefulWidget {
  final VoidCallback onCreate;
  final List<Unit> existingUnits;

  const _CreateUnitDialog({
    required this.onCreate,
    required this.existingUnits,
  });

  @override
  State<_CreateUnitDialog> createState() => _CreateUnitDialogState();
}

class _CreateUnitDialogState extends State<_CreateUnitDialog> {
  final _formKey = GlobalKey<FormState>();
  final _unitNoController = TextEditingController();
  final _customTypeController = TextEditingController();
  bool _isCreating = false;
  List<UnitType> _unitTypes = [];
  String? _selectedUnitType;
  static const _otherValue = '__other__';
  bool get _isOtherSelected => _selectedUnitType == _otherValue;

  @override
  void initState() {
    super.initState();
    _loadUnitTypes();
  }

  Future<void> _loadUnitTypes() async {
    final appState = context.read<AppState>();
    final repo = context.read<HouseholdRepository>();
    if (appState.activeCommunityId != null) {
      final types = await repo.getUnitTypes(appState.activeCommunityId!);
      if (mounted) setState(() => _unitTypes = types);
    }
  }

  @override
  void dispose() {
    _unitNoController.dispose();
    _customTypeController.dispose();
    super.dispose();
  }

  bool _isUnitNumberTaken(String unitNo) {
    return widget.existingUnits.any(
      (unit) => unit.unitNo.trim().toLowerCase() == unitNo.trim().toLowerCase(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.add_home_outlined,
              color: Color(0xff215e3f), size: 24),
          const SizedBox(width: 12),
          const Text('Create Unit',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _unitNoController,
              decoration: const InputDecoration(
                labelText: 'Unit Number',
                hintText: 'e.g., 101, A-201',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value?.isEmpty ?? true) return 'Required';
                if (_isUnitNumberTaken(value!)) {
                  return 'Unit $value already exists';
                }
                return null;
              },
              autovalidateMode: AutovalidateMode.onUserInteraction,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedUnitType,
              decoration: const InputDecoration(
                labelText: 'Unit Type (Optional)',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('None', style: TextStyle(color: Colors.grey)),
                ),
                ..._unitTypes.map((t) => DropdownMenuItem(
                      value: t.name,
                      child: Text(t.name),
                    )),
                const DropdownMenuItem<String>(
                  value: '__other__',
                  child: Text('Other...',
                      style: TextStyle(fontStyle: FontStyle.italic)),
                ),
              ],
              onChanged: (value) => setState(() {
                _selectedUnitType = value;
                if (value != _otherValue) _customTypeController.clear();
              }),
            ),
            if (_isOtherSelected) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _customTypeController,
                decoration: const InputDecoration(
                  labelText: 'Custom Unit Type',
                  hintText: 'e.g., Penthouse, Loft',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
                validator: (value) {
                  if (_isOtherSelected && (value?.trim().isEmpty ?? true)) {
                    return 'Please enter a unit type';
                  }
                  return null;
                },
              ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 20, color: Colors.blue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Unit numbers must be unique within the community.',
                      style: TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        HOAppButton(
          label: _isCreating ? 'Creating...' : 'Create',
          onPressed: _isCreating ? null : _createUnit,
        ),
      ],
    );
  }

  Future<void> _createUnit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isCreating = true);

    try {
      final appState = context.read<AppState>();
      final repo = context.read<HouseholdRepository>();
      final communityId = appState.activeCommunityId!;

      String? unitType = _selectedUnitType;

      // If "Other" was selected, create the new unit type first
      if (_isOtherSelected) {
        final customName = _customTypeController.text.trim();
        await repo.createUnitType(
          communityId: communityId,
          name: customName,
        );
        unitType = customName;
      }

      await repo.createUnit(
        communityId: communityId,
        unitNo: _unitNoController.text,
        unitType: unitType,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unit created successfully')),
        );
        // Small delay to ensure database has committed before refreshing
        await Future.delayed(const Duration(milliseconds: 100));
        widget.onCreate();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCreating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating unit: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}

class _AddMemberDialog extends StatefulWidget {
  final Unit unit;
  final VoidCallback onAdded;

  const _AddMemberDialog({
    required this.unit,
    required this.onAdded,
  });

  @override
  State<_AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends State<_AddMemberDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _relationshipController = TextEditingController();
  MemberRole _selectedRole = MemberRole.member;
  bool _isAdding = false;
  bool _isSearching = false;
  List<UserProfile> _searchResults = [];
  UserProfile? _selectedUser;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _nameController.dispose();
    _relationshipController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    // Clear selected user when typing changes
    if (_selectedUser != null && query != _selectedUser!.fullName) {
      setState(() {
        _selectedUser = null;
      });
    }

    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _searchUsers(query);
    });
  }

  Future<void> _searchUsers(String query) async {
    final trimmedQuery = query.trim();

    if (trimmedQuery.isEmpty) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _selectedUser = null;
          _isSearching = false;
        });
      }
      return;
    }

    // Require at least 2 characters before searching
    if (trimmedQuery.length < 2) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() => _isSearching = true);
    }

    try {
      final appState = context.read<AppState>();
      if (appState.activeCommunityId == null) {
        if (mounted) {
          setState(() => _isSearching = false);
        }
        return;
      }

      final client = SupabaseClientManager.instance;

      final response = await client
          .from('profiles')
          .select()
          .eq('community_id', appState.activeCommunityId!)
          .ilike('full_name', '%$trimmedQuery%')
          .limit(10);

      if (!mounted) return;

      final users = (response as List)
          .where((item) => item != null && item is Map<String, dynamic>)
          .map((item) {
            try {
              return UserProfile.fromJson(item as Map<String, dynamic>);
            } catch (e) {
              print('Error parsing user profile: $e');
              return null;
            }
          })
          .whereType<UserProfile>()
          .toList();

      if (mounted) {
        setState(() {
          _searchResults = users;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
        print('Error searching users: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.person_add_outlined,
              color: Color(0xff215e3f), size: 24),
          const SizedBox(width: 12),
          const Text('Add Household Member',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
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
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    hintText: 'Type any name or search existing users',
                    border: const OutlineInputBorder(),
                    helperText:
                        'Enter any name. Search results appear for registered users (2+ chars).',
                    helperMaxLines: 2,
                    suffixIcon: _isSearching
                        ? const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : _selectedUser != null
                            ? const Icon(Icons.check_circle,
                                color: Color.fromRGBO(39, 99, 67, 1))
                            : null,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a name';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    _onSearchChanged(value);
                  },
                ),
                if (_searchResults.isNotEmpty && _selectedUser == null) ...[
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final user = _searchResults[index];
                        return ListTile(
                          title: Text(user.fullName ?? 'Unnamed User'),
                          subtitle:
                              user.phone != null ? Text(user.phone!) : null,
                          onTap: () {
                            setState(() {
                              _selectedUser = user;
                              _nameController.text = user.fullName ?? '';
                              _searchResults = [];
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],
                if (_selectedUser != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Color.fromRGBO(139, 178, 134, 1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Color.fromRGBO(325, 77, 52, 1)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person,
                            color: Color.fromRGBO(39, 99, 67, 1)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedUser!.fullName ?? 'Unnamed User',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              if (_selectedUser!.phone != null)
                                Text(
                                  _selectedUser!.phone!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[700],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () {
                            setState(() {
                              _selectedUser = null;
                              _nameController.clear();
                            });
                          },
                          tooltip: 'Clear selection',
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                DropdownButtonFormField<MemberRole>(
                  value: _selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    border: OutlineInputBorder(),
                  ),
                  items: MemberRole.values.map((role) {
                    return DropdownMenuItem(
                      value: role,
                      child: Text(role.name.toUpperCase()),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedRole = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _relationshipController,
                  decoration: const InputDecoration(
                    labelText: 'Relationship (Optional)',
                    hintText: 'e.g., Spouse, Parent, Child',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        HOAppButton(
          label: _isAdding ? 'Adding...' : 'Add',
          onPressed: _isAdding ? null : _addMember,
        ),
      ],
    );
  }

  Future<void> _addMember() async {
    if (!_formKey.currentState!.validate()) return;

    final enteredName = _nameController.text.trim();
    if (enteredName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name')),
      );
      return;
    }

    setState(() => _isAdding = true);

    try {
      final appState = context.read<AppState>();
      final repo = context.read<HouseholdRepository>();

      // If user selected from list, use their userId; otherwise use free-form name
      await repo.addHouseholdMember(
        communityId: appState.activeCommunityId!,
        unitId: widget.unit.id,
        userId: _selectedUser?.userId,
        memberName: _selectedUser == null ? enteredName : null,
        memberRole: _selectedRole,
        relationship: _relationshipController.text.isNotEmpty
            ? _relationshipController.text
            : null,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _selectedUser != null
                  ? 'Registered user added successfully'
                  : 'Member added successfully',
            ),
          ),
        );
        widget.onAdded();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAdding = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}

class _EditMemberDialog extends StatefulWidget {
  final HouseholdMember member;
  final VoidCallback onUpdated;

  const _EditMemberDialog({
    required this.member,
    required this.onUpdated,
  });

  @override
  State<_EditMemberDialog> createState() => _EditMemberDialogState();
}

class _EditMemberDialogState extends State<_EditMemberDialog> {
  final _formKey = GlobalKey<FormState>();
  final _relationshipController = TextEditingController();
  late MemberRole _selectedRole;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.member.memberRole;
    _relationshipController.text = widget.member.relationship ?? '';
  }

  @override
  void dispose() {
    _relationshipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.edit_outlined, color: Color(0xff215e3f), size: 24),
          const SizedBox(width: 12),
          const Text('Edit Member Role',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<MemberRole>(
              value: _selectedRole,
              decoration: const InputDecoration(
                labelText: 'Role',
                border: OutlineInputBorder(),
              ),
              items: MemberRole.values.map((role) {
                return DropdownMenuItem(
                  value: role,
                  child: Text(role.name.toUpperCase()),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedRole = value);
                }
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _relationshipController,
              decoration: const InputDecoration(
                labelText: 'Relationship (Optional)',
                hintText: 'e.g., Spouse, Parent, Child',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        HOAppButton(
          label: _isUpdating ? 'Updating...' : 'Update',
          onPressed: _isUpdating ? null : _updateMember,
        ),
      ],
    );
  }

  Future<void> _updateMember() async {
    setState(() => _isUpdating = true);

    try {
      final repo = context.read<HouseholdRepository>();

      await repo.updateHouseholdMember(
        id: widget.member.id,
        memberRole: _selectedRole,
        relationship: _relationshipController.text.isNotEmpty
            ? _relationshipController.text
            : null,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Member updated successfully')),
        );
        widget.onUpdated();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUpdating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}
