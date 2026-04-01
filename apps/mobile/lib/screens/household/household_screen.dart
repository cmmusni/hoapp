import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  bool _isPrimary = false;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  void _loadMembers() {
    final repo = context.read<HouseholdRepository>();
    final userId = Supabase.instance.client.auth.currentUser?.id;
    setState(() {
      _membersFuture = repo.getHouseholdMembers(widget.unit.id).then((members) {
        if (mounted) {
          setState(() {
            _isPrimary = members.any(
              (m) => m.userId == userId && m.memberRole == MemberRole.primary,
            );
          });
        }
        return members;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canManage = widget.isStaff || _isPrimary;

    return Stack(
      children: [
        Column(
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

                  final currentUserId =
                      Supabase.instance.client.auth.currentUser?.id;

                  return ListView.builder(
                    padding:
                        EdgeInsets.fromLTRB(16, 16, 16, canManage ? 80 : 16),
                    itemCount: members.length,
                    itemBuilder: (context, index) {
                      final member = members[index];
                      final isCurrentUser = member.userId == currentUserId;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              member.displayName.substring(0, 1).toUpperCase(),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
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
                          trailing: canManage
                              ? PopupMenuButton<String>(
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'edit_name',
                                      child: Text('Edit Name'),
                                    ),
                                    if (!isCurrentUser &&
                                        member.memberRole != MemberRole.primary)
                                      const PopupMenuItem(
                                        value: 'remove',
                                        child: Text('Remove',
                                            style:
                                                TextStyle(color: Colors.red)),
                                      ),
                                  ],
                                  onSelected: (value) {
                                    if (value == 'edit_name') {
                                      _showEditNameSheet(member);
                                    } else if (value == 'remove') {
                                      _confirmRemoveMember(member);
                                    }
                                  },
                                )
                              : Chip(
                                  label: Text(
                                    _getRoleLabel(member.memberRole),
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  backgroundColor:
                                      _getRoleColor(member.memberRole)
                                          .withOpacity(0.2),
                                ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
        if (canManage)
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              onPressed: _showAddMemberSheet,
              child: const Icon(Icons.person_add),
            ),
          ),
      ],
    );
  }

  Future<void> _confirmRemoveMember(HouseholdMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
        actionsPadding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.person_remove_rounded,
                  color: Colors.red.shade600, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Remove Member',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(member.displayName,
                      style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                ],
              ),
            ),
          ],
        ),
        content: Text(
          'Remove ${member.displayName} from Unit ${widget.unit.unitNo}?',
          style: TextStyle(fontSize: 14, color: Colors.grey[700], height: 1.4),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.black87)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: const Text('Remove',
                style: TextStyle(fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final repo = context.read<HouseholdRepository>();
        await repo.removeHouseholdMember(member.id);
        _loadMembers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('${member.displayName} removed from this unit')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  void _showEditNameSheet(HouseholdMember member) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _EditNameSheet(
          member: member,
          onUpdated: _loadMembers,
        ),
      ),
    );
  }

  void _showAddMemberSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _AddMemberSheet(
          unit: widget.unit,
          onAdded: _loadMembers,
        ),
      ),
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

// ============ ADD MEMBER BOTTOM SHEET ============

const _brand = Color(0xff215e3f);

String _memberRoleLabel(MemberRole role) => switch (role) {
      MemberRole.primary => 'Primary',
      MemberRole.member => 'Member',
      MemberRole.child => 'Child',
      MemberRole.tenant => 'Tenant',
      MemberRole.other => 'Other',
    };

class _AddMemberSheet extends StatefulWidget {
  final Unit unit;
  final VoidCallback onAdded;

  const _AddMemberSheet({required this.unit, required this.onAdded});

  @override
  State<_AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends State<_AddMemberSheet> {
  final _nameCtrl = TextEditingController();
  final _relationshipCtrl = TextEditingController();
  MemberRole _role = MemberRole.member;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _relationshipCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _brand.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.person_add_rounded,
                      color: _brand, size: 24),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Add Member',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700)),
                    Text('Unit ${widget.unit.unitNo}',
                        style:
                            TextStyle(fontSize: 13, color: Colors.grey[500])),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Full Name',
                prefixIcon: const Icon(Icons.person_outline, size: 20),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _brand, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<MemberRole>(
              value: _role,
              decoration: InputDecoration(
                labelText: 'Role',
                prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _brand, width: 1.5),
                ),
              ),
              items: [
                MemberRole.member,
                MemberRole.child,
                MemberRole.tenant,
                MemberRole.other
              ]
                  .map((r) => DropdownMenuItem(
                      value: r, child: Text(_memberRoleLabel(r))))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _role = v);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _relationshipCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Relationship (optional)',
                hintText: 'e.g. Spouse, Parent, Sibling',
                prefixIcon: const Icon(Icons.family_restroom, size: 20),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _brand, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _handleAdd,
                icon: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_rounded),
                label: const Text('Add Member',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brand,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAdd() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final appState = context.read<AppState>();
      final repo = context.read<HouseholdRepository>();
      final relationship = _relationshipCtrl.text.trim();

      await repo.addHouseholdMember(
        communityId: appState.activeCommunityId!,
        unitId: widget.unit.id,
        memberName: name,
        memberRole: _role,
        relationship: relationship.isNotEmpty ? relationship : null,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name added to Unit ${widget.unit.unitNo}')),
        );
        widget.onAdded();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

// ============ EDIT NAME BOTTOM SHEET ============

class _EditNameSheet extends StatefulWidget {
  final HouseholdMember member;
  final VoidCallback onUpdated;

  const _EditNameSheet({required this.member, required this.onUpdated});

  @override
  State<_EditNameSheet> createState() => _EditNameSheetState();
}

class _EditNameSheetState extends State<_EditNameSheet> {
  late final TextEditingController _nameCtrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(
        text: widget.member.displayName != 'Unknown'
            ? widget.member.displayName
            : '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _brand.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child:
                      const Icon(Icons.edit_rounded, color: _brand, size: 24),
                ),
                const SizedBox(width: 14),
                const Text('Edit Name',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Full Name',
                prefixIcon: const Icon(Icons.person_outline, size: 20),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _brand, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _handleUpdate,
                icon: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_rounded),
                label: const Text('Update Name',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brand,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleUpdate() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final repo = context.read<HouseholdRepository>();
      await repo.updateHouseholdMember(
        id: widget.member.id,
        memberName: name,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Name updated successfully')),
        );
        widget.onUpdated();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
