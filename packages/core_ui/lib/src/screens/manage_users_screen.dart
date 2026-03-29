import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:core_data/core_data.dart';
import 'package:core_domain/core_domain.dart';

const _brand = Color(0xff215e3f);

String _roleDisplayName(Role role) => switch (role) {
      Role.communityAdmin => 'Community Admin',
      Role.hoaOfficer => 'HOA Officer',
      Role.guard => 'Security Guard',
      Role.maintenance => 'Maintenance',
      Role.resident => 'Resident',
    };

/// Shared manage-users screen — adaptive for web and mobile.
class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  Future<List<UserRole>>? _rolesFuture;
  Map<String, UserProfile> _userProfiles = {};
  bool _isLoadingProfiles = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRoles());
  }

  Future<void> _loadRoles() async {
    final appState = context.read<AppState>();
    final repo = context.read<CommunityRepository>();
    final client = SupabaseClientManager.instance;

    if (appState.activeCommunityId == null) return;

    setState(() {
      _isLoadingProfiles = true;
      _rolesFuture = repo.getCommunityUserRoles(appState.activeCommunityId!);
    });

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
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _userProfiles = profiles;
          _isLoadingProfiles = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingProfiles = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    if (!appState.isAdmin) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Admin Access Required',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Only administrators can manage users'),
          ],
        ),
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => _loadRoles(),
        child: FutureBuilder<List<UserRole>>(
          future: _rolesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting ||
                _isLoadingProfiles) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            final roles = snapshot.data ?? [];
            if (roles.isEmpty) {
              return const Center(child: Text('No users yet'));
            }

            final grouped = <Role, List<UserRole>>{};
            for (final r in roles) {
              grouped.putIfAbsent(r.role, () => []).add(r);
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final entry in grouped.entries)
                  _RoleSection(
                    role: entry.key,
                    roles: entry.value,
                    profiles: _userProfiles,
                    onEdit: _showEditRoleDialog,
                    onDelete: _handleDeleteUser,
                  ),
                const SizedBox(height: 80),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showInviteDialog(),
        icon: const Icon(Icons.person_add),
        label: const Text('Invite User'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  void _showInviteDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _InviteUserSheet(onInvited: _loadRoles),
      ),
    );
  }

  void _showEditRoleDialog(UserRole role) {
    Role? selectedRole = role.role;
    final userName = _userProfiles[role.userId]?.fullName ?? 'this user';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
        actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _brand.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child:
                  const Icon(Icons.swap_horiz_rounded, color: _brand, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Change Role',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('Update role for $userName',
                      style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                ],
              ),
            ),
          ],
        ),
        content: DropdownButtonFormField<Role>(
          value: selectedRole,
          decoration: InputDecoration(
            labelText: 'Role',
            prefixIcon: const Icon(Icons.badge_outlined, size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _brand, width: 1.5),
            ),
          ),
          items: Role.values
              .map((r) =>
                  DropdownMenuItem(value: r, child: Text(_roleDisplayName(r))))
              .toList(),
          onChanged: (v) {
            if (v != null) selectedRole = v;
          },
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              side: BorderSide(color: Colors.grey.shade300),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.black87)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              try {
                final repo = context.read<CommunityRepository>();
                await repo.updateUserRole(roleId: role.id, role: selectedRole!);
                if (mounted) {
                  Navigator.of(ctx).pop();
                  _loadRoles();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            icon:
                const Icon(Icons.check_rounded, size: 18, color: Colors.white),
            label: const Text('Save Changes',
                style: TextStyle(fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _brand,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDeleteUser(UserRole role) async {
    final userName = _userProfiles[role.userId]?.fullName ?? 'this user';
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
                  const Text('Remove User',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(userName,
                      style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                ],
              ),
            ),
          ],
        ),
        content: Text(
          'This will permanently remove $userName from the community. '
          'This action cannot be undone.',
          style: TextStyle(fontSize: 14, color: Colors.grey[700], height: 1.4),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              side: BorderSide(color: Colors.grey.shade300),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      try {
        final appState = context.read<AppState>();
        final repo = context.read<CommunityRepository>();
        await repo.deleteUser(
            targetUserId: role.userId,
            communityId: appState.activeCommunityId!);
        _loadRoles();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }
}

// ─── Role Section ────────────────────────────────────────────────────────────

class _RoleSection extends StatelessWidget {
  final Role role;
  final List<UserRole> roles;
  final Map<String, UserProfile> profiles;
  final void Function(UserRole) onEdit;
  final void Function(UserRole) onDelete;

  const _RoleSection({
    required this.role,
    required this.roles,
    required this.profiles,
    required this.onEdit,
    required this.onDelete,
  });

  Color get _roleColor => switch (role) {
        Role.communityAdmin => Colors.red,
        Role.hoaOfficer => Colors.blue,
        Role.guard => Colors.orange,
        Role.maintenance => Colors.teal,
        _ => _brand,
      };

  IconData get _roleIcon => switch (role) {
        Role.communityAdmin => Icons.admin_panel_settings,
        Role.hoaOfficer => Icons.badge,
        Role.guard => Icons.security,
        Role.maintenance => Icons.build,
        _ => Icons.home,
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            Icon(_roleIcon, size: 20, color: _roleColor),
            const SizedBox(width: 8),
            Text('${_roleDisplayName(role)} (${roles.length})',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _roleColor)),
          ]),
        ),
        ...roles.map((r) {
          final profile = profiles[r.userId];
          final name = profile?.fullName ?? 'Unknown User';
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: _roleColor.withValues(alpha: 0.1),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style:
                      TextStyle(color: _roleColor, fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(name),
              subtitle: Text(_roleDisplayName(r.role),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              trailing: PopupMenuButton<String>(
                onSelected: (action) {
                  if (action == 'edit') onEdit(r);
                  if (action == 'delete') onDelete(r);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                      value: 'edit', child: Text('Change Role')),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Remove', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ─── Invite User Sheet ──────────────────────────────────────────────────────

class _InviteUserSheet extends StatefulWidget {
  final VoidCallback onInvited;
  const _InviteUserSheet({required this.onInvited});

  @override
  State<_InviteUserSheet> createState() => _InviteUserSheetState();
}

class _InviteUserSheetState extends State<_InviteUserSheet> {
  final _emailCtrl = TextEditingController();
  Role _role = Role.resident;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
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
                    color: _brand.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.person_add_rounded,
                      color: _brand, size: 24),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Invite User',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700)),
                    Text('Send an invite to join your community',
                        style:
                            TextStyle(fontSize: 13, color: Colors.grey[500])),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: const Icon(Icons.email_outlined, size: 20),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _brand, width: 1.5),
                  )),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<Role>(
              value: _role,
              decoration: InputDecoration(
                  labelText: 'Role',
                  prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _brand, width: 1.5),
                  )),
              items: Role.values
                  .map((r) => DropdownMenuItem(
                      value: r, child: Text(_roleDisplayName(r))))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _role = v);
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _handleInvite,
                icon: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded),
                label: const Text('Send Invite',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: _brand,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleInvite() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid email')),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final appState = context.read<AppState>();
      final repo = context.read<CommunityRepository>();
      await repo.createInvite(
        communityId: appState.activeCommunityId!,
        email: email,
        role: _role.name,
        inviteKind: 'email',
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invite sent successfully')),
        );
        widget.onInvited();
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
