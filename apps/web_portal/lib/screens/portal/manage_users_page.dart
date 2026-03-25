import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:core_data/core_data.dart';
import 'package:core_domain/core_domain.dart';
import 'package:core_ui/core_ui.dart';
import 'package:intl/intl.dart';

class ManageUsersPage extends StatefulWidget {
  const ManageUsersPage({super.key});

  @override
  State<ManageUsersPage> createState() => _ManageUsersPageState();
}

class _ManageUsersPageState extends State<ManageUsersPage> {
  Future<List<UserRole>>? _rolesFuture;
  Map<String, UserProfile> _userProfiles = {};
  String? _lastLoadedCommunityId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRoles();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload if community changed
    final appState = context.read<AppState>();
    if (appState.activeCommunityId != null &&
        appState.activeCommunityId != _lastLoadedCommunityId) {
      _lastLoadedCommunityId = appState.activeCommunityId;
      _loadRoles();
    }
  }

  void _loadRoles() async {
    final appState = context.read<AppState>();
    final repo = context.read<CommunityRepository>();
    final client = SupabaseClientManager.instance;

    if (appState.activeCommunityId != null) {
      setState(() {
        _rolesFuture = repo.getCommunityUserRoles(appState.activeCommunityId!);
      });

      // Load user profiles for each role
      try {
        final roles =
            await repo.getCommunityUserRoles(appState.activeCommunityId!);
        final profiles = <String, UserProfile>{};

        for (final role in roles) {
          try {
            final response = await client
                .from('profiles')
                .select()
                .eq('user_id', role.userId)
                .eq('community_id', appState.activeCommunityId!)
                .maybeSingle();

            if (response != null) {
              profiles[role.userId] = UserProfile.fromJson(response);
            }
          } catch (e) {
            // If profile fetch fails, continue with others
            print('Failed to fetch profile for ${role.userId}: $e');
          }
        }

        if (mounted) {
          setState(() {
            _userProfiles = profiles;
          });
        }
      } catch (e) {
        print('Failed to load user profiles: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isAdmin = appState.activeRole?.isAdmin ?? false;

    if (!isAdmin) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              const Text(
                'Admin Access Required',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Only community administrators can manage users',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => _loadRoles(),
        child: FutureBuilder<List<UserRole>>(
          future: _rolesFuture,
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
                      onPressed: _loadRoles,
                    ),
                  ],
                ),
              );
            }

            final roles = snapshot.data ?? [];

            if (roles.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people_outline,
                        size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    const Text(
                      'No users yet',
                      style: TextStyle(fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Invite the first user to get started',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              );
            }

            // Group by role type
            final admins =
                roles.where((r) => r.role == Role.communityAdmin).toList();
            final officers =
                roles.where((r) => r.role == Role.hoaOfficer).toList();
            final guards = roles.where((r) => r.role == Role.guard).toList();
            final residents =
                roles.where((r) => r.role == Role.resident).toList();

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (admins.isNotEmpty) ...[
                  _SectionHeader(
                    title: 'Community Administrators',
                    count: admins.length,
                    icon: Icons.admin_panel_settings,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 8),
                  ...admins.map((role) => _UserRoleCard(
                        role: role,
                        userProfile: _userProfiles[role.userId],
                        onEdit: () => _showEditRoleDialog(context, role),
                        onDelete: () => _deleteRole(context, role),
                      )),
                  const SizedBox(height: 24),
                ],
                if (officers.isNotEmpty) ...[
                  _SectionHeader(
                    title: 'HOA Officers',
                    count: officers.length,
                    icon: Icons.badge,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 8),
                  ...officers.map((role) => _UserRoleCard(
                        role: role,
                        userProfile: _userProfiles[role.userId],
                        onEdit: () => _showEditRoleDialog(context, role),
                        onDelete: () => _deleteRole(context, role),
                      )),
                  const SizedBox(height: 24),
                ],
                if (guards.isNotEmpty) ...[
                  _SectionHeader(
                    title: 'Security Guards',
                    count: guards.length,
                    icon: Icons.security,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 8),
                  ...guards.map((role) => _UserRoleCard(
                        role: role,
                        userProfile: _userProfiles[role.userId],
                        onEdit: () => _showEditRoleDialog(context, role),
                        onDelete: () => _deleteRole(context, role),
                      )),
                  const SizedBox(height: 24),
                ],
                if (residents.isNotEmpty) ...[
                  _SectionHeader(
                    title: 'Residents',
                    count: residents.length,
                    icon: Icons.home,
                    color: Color.fromRGBO(39, 99, 67, 1),
                  ),
                  const SizedBox(height: 8),
                  ...residents.map((role) => _UserRoleCard(
                        role: role,
                        userProfile: _userProfiles[role.userId],
                        onEdit: () => _showEditRoleDialog(context, role),
                        onDelete: () => _deleteRole(context, role),
                      )),
                ],
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showInviteDialog(context),
        icon: const Icon(Icons.person_add),
        label: const Text('Invite User'),
      ),
    );
  }

  void _showInviteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _InviteUserDialog(onInvited: _loadRoles),
    );
  }

  void _showEditRoleDialog(BuildContext context, UserRole role) {
    showDialog(
      context: context,
      builder: (context) => _EditRoleDialog(role: role, onSaved: _loadRoles),
    );
  }

  Future<void> _deleteRole(BuildContext context, UserRole role) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Colors.red, size: 24),
            const SizedBox(width: 12),
            const Text('Delete User',
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
          'This will permanently delete this user\'s account, profile, and all associated data. This action cannot be undone.\n\nAre you sure?',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete User',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final repo = context.read<CommunityRepository>();
        await repo.deleteUser(
          targetUserId: role.userId,
          communityId: role.communityId,
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User deleted successfully')),
          );
          _loadRoles();
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

// ============ SECTION HEADER ============

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;
  final Color color;

  const _SectionHeader({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

// ============ USER ROLE CARD ============

class _UserRoleCard extends StatelessWidget {
  final UserRole role;
  final UserProfile? userProfile;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _UserRoleCard({
    required this.role,
    this.userProfile,
    required this.onEdit,
    required this.onDelete,
  });

  Color _getRoleColor(Role role) {
    switch (role) {
      case Role.communityAdmin:
        return Colors.red;
      case Role.hoaOfficer:
        return Colors.blue;
      case Role.guard:
        return Colors.orange;
      case Role.resident:
        return Color.fromRGBO(39, 99, 67, 1);
    }
  }

  String _getRoleDisplayName(Role role) {
    switch (role) {
      case Role.communityAdmin:
        return 'Community Admin';
      case Role.hoaOfficer:
        return 'HOA Officer';
      case Role.guard:
        return 'Security Guard';
      case Role.resident:
        return 'Resident';
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: _getRoleColor(role.role).withOpacity(0.2),
              child: Icon(
                Icons.person,
                color: _getRoleColor(role.role),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userProfile?.fullName ?? 'Unknown User',
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
                          color: _getRoleColor(role.role).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _getRoleDisplayName(role.role),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _getRoleColor(role.role),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Since ${dateFormat.format(role.createdAt)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton(
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 18),
                      SizedBox(width: 8),
                      Text('Edit Role'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'remove',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Remove', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'edit') {
                  onEdit();
                } else if (value == 'remove') {
                  onDelete();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ============ INVITE USER DIALOG ============

class _InviteUserDialog extends StatefulWidget {
  final VoidCallback onInvited;

  const _InviteUserDialog({required this.onInvited});

  @override
  State<_InviteUserDialog> createState() => _InviteUserDialogState();
}

class _InviteUserDialogState extends State<_InviteUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  Role _selectedRole = Role.resident;
  String? _selectedUnitId;
  bool _isInviting = false;

  Future<List<Unit>>? _unitsFuture;

  @override
  void initState() {
    super.initState();
    _loadUnits();
  }

  void _loadUnits() {
    final appState = context.read<AppState>();
    final repo = context.read<HouseholdRepository>();

    if (appState.activeCommunityId != null) {
      _unitsFuture = repo.getUnits(appState.activeCommunityId!);
    }
  }

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
          const Icon(Icons.person_add_outlined,
              color: Color(0xff215e3f), size: 24),
          const SizedBox(width: 12),
          const Text('Invite User',
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
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value?.isEmpty ?? true) return 'Required';
                    if (!value!.contains('@')) return 'Invalid email';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<Role>(
                  value: _selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    border: OutlineInputBorder(),
                  ),
                  items: Role.values.map((role) {
                    return DropdownMenuItem(
                      value: role,
                      child: Text(_getRoleDisplayName(role)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedRole = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                if (_selectedRole == Role.resident) ...[
                  const Text(
                    'Assign Unit (Optional)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  FutureBuilder<List<Unit>>(
                    future: _unitsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const LinearProgressIndicator();
                      }

                      final units = snapshot.data ?? [];

                      if (units.isEmpty) {
                        return const Text(
                          'No units available. Create units first in Households.',
                          style: TextStyle(color: Colors.orange, fontSize: 12),
                        );
                      }

                      return DropdownButtonFormField<String>(
                        value: _selectedUnitId,
                        decoration: const InputDecoration(
                          labelText: 'Unit',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('None'),
                          ),
                          ...units.map((unit) {
                            return DropdownMenuItem(
                              value: unit.id,
                              child: Text('Unit ${unit.unitNumber}'),
                            );
                          }),
                        ],
                        onChanged: (value) =>
                            setState(() => _selectedUnitId = value),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                ],
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
                          'An invitation link will be sent to the email address.',
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
      ),
      actions: [
        HOAppButton(
          label: _isInviting ? 'Sending...' : 'Send Invite',
          onPressed: _isInviting ? null : _sendInvite,
        ),
      ],
    );
  }

  String _getRoleDisplayName(Role role) {
    switch (role) {
      case Role.communityAdmin:
        return 'Community Admin';
      case Role.hoaOfficer:
        return 'HOA Officer';
      case Role.guard:
        return 'Security Guard';
      case Role.resident:
        return 'Resident';
    }
  }

  Future<void> _sendInvite() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isInviting = true);

    try {
      final appState = context.read<AppState>();
      final repo = context.read<CommunityRepository>();

      // Convert Role enum to string for API
      String roleString;
      switch (_selectedRole) {
        case Role.communityAdmin:
          roleString = 'community_admin';
          break;
        case Role.hoaOfficer:
          roleString = 'hoa_officer';
          break;
        case Role.guard:
          roleString = 'guard';
          break;
        case Role.resident:
          roleString = 'resident';
          break;
      }

      await repo.createInvite(
        communityId: appState.activeCommunityId!,
        email: _emailController.text,
        role: roleString,
        unitId: _selectedUnitId,
        inviteKind: 'role',
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invitation sent successfully'),
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

// ============ EDIT ROLE DIALOG ============

class _EditRoleDialog extends StatefulWidget {
  final UserRole role;
  final VoidCallback onSaved;

  const _EditRoleDialog({
    required this.role,
    required this.onSaved,
  });

  @override
  State<_EditRoleDialog> createState() => _EditRoleDialogState();
}

class _EditRoleDialogState extends State<_EditRoleDialog> {
  final _formKey = GlobalKey<FormState>();
  late Role _selectedRole;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.role.role;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.manage_accounts_outlined,
              color: Color(0xff215e3f), size: 24),
          const SizedBox(width: 12),
          const Text('Edit User Role',
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
            DropdownButtonFormField<Role>(
              value: _selectedRole,
              decoration: const InputDecoration(
                labelText: 'Role',
                border: OutlineInputBorder(),
              ),
              items: Role.values.map((role) {
                return DropdownMenuItem(
                  value: role,
                  child: Text(_getRoleDisplayName(role)),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedRole = value);
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        HOAppButton(
          label: _isUpdating ? 'Updating...' : 'Update',
          onPressed: _isUpdating ? null : _updateRole,
        ),
      ],
    );
  }

  String _getRoleDisplayName(Role role) {
    switch (role) {
      case Role.communityAdmin:
        return 'Community Admin';
      case Role.hoaOfficer:
        return 'HOA Officer';
      case Role.guard:
        return 'Security Guard';
      case Role.resident:
        return 'Resident';
    }
  }

  Future<void> _updateRole() async {
    setState(() => _isUpdating = true);

    try {
      final repo = context.read<CommunityRepository>();

      await repo.updateUserRole(
        roleId: widget.role.id,
        role: _selectedRole,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Role updated successfully')),
        );
        widget.onSaved();
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
