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
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _InviteUserSheet(onInvited: _loadRoles),
      ),
    );
  }

  void _showEditRoleDialog(UserRole role) {
    Role? selectedRole = role.role;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Role'),
        content: DropdownButtonFormField<Role>(
          value: selectedRole,
          items: Role.values
              .map((r) =>
                  DropdownMenuItem(value: r, child: Text(_roleDisplayName(r))))
              .toList(),
          onChanged: (v) {
            if (v != null) selectedRole = v;
          },
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          ElevatedButton(
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
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDeleteUser(UserRole role) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove User?'),
        content: const Text(
            'This will remove the user from the community. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Remove')),
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
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Invite User',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                  labelText: 'Email', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<Role>(
              value: _role,
              decoration: const InputDecoration(
                  labelText: 'Role', border: OutlineInputBorder()),
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
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleInvite,
                style: ElevatedButton.styleFrom(
                    backgroundColor: _brand, foregroundColor: Colors.white),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Send Invite'),
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
