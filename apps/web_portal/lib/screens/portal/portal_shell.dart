import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:core_data/core_data.dart';
import 'package:core_domain/core_domain.dart';

class PortalShell extends StatefulWidget {
  final String communitySlug;
  final Widget child;

  const PortalShell({
    super.key,
    required this.communitySlug,
    required this.child,
  });

  @override
  State<PortalShell> createState() => _PortalShellState();
}

class _PortalShellState extends State<PortalShell> {
  @override
  void initState() {
    super.initState();
    _loadCommunity();
  }

  Future<void> _loadCommunity() async {
    try {
      final communityRepo = context.read<CommunityRepository>();
      final authRepo = context.read<AuthRepository>();
      final appState = context.read<AppState>();
      
      final community = await communityRepo.getCommunityBySlug(widget.communitySlug);
      
      if (community != null) {
        appState.setActiveCommunity(community.id, community.slug);
        appState.setActiveCommunityData(community);
        
        print('DEBUG: Community loaded: ${community.name} (${community.id})');
        
        // Load user roles
        final user = authRepo.currentUser;
        print('DEBUG: Current user: ${user?.id}');
        
        if (user != null) {
          final userId = user.id;
          if (userId != null && userId.isNotEmpty) {
            try {
              final roles = await communityRepo.getUserRoles(userId);
              print('DEBUG: User roles loaded: ${roles.length} roles');
              for (var role in roles) {
                print('DEBUG: Role - ID: ${role.id}, Community: ${role.communityId}, Role: ${role.role}');
              }
              appState.setUserRoles(roles);
              print('DEBUG: Roles set in AppState');
            } catch (e) {
              print('Error loading user roles: $e');
            }
          } else {
            print('DEBUG: User ID is null or empty');
          }
        } else {
          print('DEBUG: No current user');
        }
      } else {
        print('DEBUG: Community not found for slug: ${widget.communitySlug}');
      }
    } catch (e) {
      print('Error loading community: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final authRepo = context.watch<AuthRepository>();
    final user = authRepo.currentUser;
    final isStaff = appState.isStaff;
    final isAdmin = appState.isAdmin;
    
    // Get the current route to determine page title
    final currentPath = GoRouter.of(context).routerDelegate.currentConfiguration.uri.path;
    String pageTitle = appState.activeCommunity?.name ?? widget.communitySlug;
    
    if (currentPath.contains('/announcements')) {
      pageTitle = 'Announcements';
    } else if (currentPath.contains('/violations')) {
      pageTitle = 'Violations';
    } else if (currentPath.contains('/tickets')) {
      pageTitle = 'Tickets';
    } else if (currentPath.contains('/amenities')) {
      pageTitle = 'Amenities';
    } else if (currentPath.contains('/billing')) {
      pageTitle = 'Billing & Payments';
    } else if (currentPath.contains('/pool-access')) {
      pageTitle = 'Pool Access';
    } else if (currentPath.contains('/households')) {
      pageTitle = 'Households';
    } else if (currentPath.contains('/manage-users')) {
      pageTitle = 'Manage Users';
    } else if (currentPath.contains('/settings')) {
      pageTitle = 'Settings';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(pageTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await context.read<AuthRepository>().signOut();
              if (context.mounted) {
                context.go('/login');
              }
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/hoapp-logo-with-bg.png'),
                  fit: BoxFit.cover,
                ),
              ),
              child: const SizedBox.shrink(),
            ),
            if (user?.email != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.grey.shade300,
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user!.email!,
                      style: TextStyle(
                        color: Colors.grey.shade800,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (appState.activeRole != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              _formatRole(appState.activeRole!.role),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      appState.activeCommunity?.name ?? '',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            const Divider(height: 1),
            _buildMenuItem(context, 'Announcements', Icons.announcement, '/${widget.communitySlug}/announcements'),
            _buildMenuItem(context, 'Violations', Icons.report, '/${widget.communitySlug}/violations'),
            _buildMenuItem(context, 'Tickets', Icons.support, '/${widget.communitySlug}/tickets'),
            _buildMenuItem(context, 'Amenities', Icons.pool, '/${widget.communitySlug}/amenities'),
            _buildMenuItem(context, 'Billing & Payments', Icons.payment, '/${widget.communitySlug}/billing'),
            _buildMenuItem(context, 'Pool Access', Icons.accessibility, '/${widget.communitySlug}/pool-access'),
            
            if (isStaff) ...[
              const Divider(),
              _buildMenuItem(context, 'Households', Icons.family_restroom, '/${widget.communitySlug}/households'),
              _buildMenuItem(context, 'Manage Users', Icons.people, '/${widget.communitySlug}/manage-users'),
            ],
            
            if (isAdmin) ...[
              const Divider(),
              _buildMenuItem(context, 'Settings', Icons.settings, '/${widget.communitySlug}/settings'),
            ],
          ],
        ),
      ),
      body: widget.child,
    );
  }

  Widget _buildMenuItem(BuildContext context, String title, IconData icon, String route) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: () {
        Navigator.of(context).pop();
        context.go(route);
      },
    );
  }

  String _formatRole(Role role) {
    switch (role) {
      case Role.communityAdmin:
        return 'Community Admin';
      case Role.hoaOfficer:
        return 'HOA Officer';
      case Role.guard:
        return 'Guard';
      case Role.resident:
        return 'Resident';
    }
  }
}
