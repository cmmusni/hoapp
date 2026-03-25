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
  bool _isCommunityLoaded = false;
  bool _sidebarOpen = true;

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

      final community =
          await communityRepo.getCommunityBySlug(widget.communitySlug);

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
                print(
                    'DEBUG: Role - ID: ${role.id}, Community: ${role.communityId}, Role: ${role.role}');
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
    } finally {
      if (mounted) {
        setState(() => _isCommunityLoaded = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final authRepo = context.watch<AuthRepository>();
    final user = authRepo.currentUser;
    print(
        'PortalShell build: user=${user?.email}, community=${appState.activeCommunity?.name}');
    final isStaff = appState.isStaff;
    final isAdmin = appState.isAdmin;

    // Get the current route to determine page title
    final currentPath =
        GoRouter.of(context).routerDelegate.currentConfiguration.uri.path;
    String pageTitle = appState.activeCommunity?.name ?? widget.communitySlug;
    String? communityName = appState.activeCommunity?.name;

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
    } else {
      communityName = null; // Don't show community name twice on home
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 900;

        if (isDesktop) {
          return Row(
            children: [
              // Animated dark sidebar
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                width: _sidebarOpen ? 250 : 0,
                child: _sidebarOpen
                    ? _buildSidebar(
                        context, user, appState, isStaff, isAdmin, currentPath)
                    : const SizedBox.shrink(),
              ),
              // Main content
              Expanded(
                child: Scaffold(
                  appBar: PreferredSize(
                    preferredSize: const Size.fromHeight(70),
                    child: AppBar(
                      backgroundColor: const Color(0xff215e3f),
                      foregroundColor: Colors.white,
                      toolbarHeight: 70,
                      leading: IconButton(
                        icon: Icon(_sidebarOpen ? Icons.menu_open : Icons.menu),
                        onPressed: () =>
                            setState(() => _sidebarOpen = !_sidebarOpen),
                        tooltip:
                            _sidebarOpen ? 'Close sidebar' : 'Open sidebar',
                      ),
                      title: Column(
                        children: [
                          Text(pageTitle,
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w600)),
                          if (communityName != null)
                            Text(communityName,
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                    color: Colors.white70)),
                        ],
                      ),
                      centerTitle: true,
                      automaticallyImplyLeading: false,
                      actions: [
                        _buildUserDropdown(context, user, appState),
                      ],
                    ),
                  ),
                  body: _isCommunityLoaded
                      ? widget.child
                      : const Center(child: CircularProgressIndicator()),
                ),
              ),
            ],
          );
        }

        // Mobile layout with drawer
        return Scaffold(
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(70),
            child: AppBar(
              backgroundColor: const Color(0xff215e3f),
              foregroundColor: Colors.white,
              toolbarHeight: 70,
              title: Column(
                children: [
                  Text(pageTitle,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w600)),
                  if (communityName != null)
                    Text(communityName,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: Colors.white70)),
                ],
              ),
              centerTitle: true,
              actions: [
                _buildUserDropdown(context, user, appState),
              ],
            ),
          ),
          drawer: _buildDrawer(context, user, appState, isStaff, isAdmin),
          body: _isCommunityLoaded
              ? widget.child
              : const Center(child: CircularProgressIndicator()),
        );
      },
    );
  }

  Widget _buildUserDropdown(
      BuildContext context, dynamic user, AppState appState) {
    final email = user?.email ?? '';
    final roleBadge = appState.activeRole != null
        ? _formatRole(appState.activeRole!.role)
        : null;
    final communityName = appState.activeCommunity?.name ?? '';

    return PopupMenuButton<String>(
      offset: const Offset(0, 48),
      onSelected: (value) async {
        if (value == 'signout') {
          await context.read<AuthRepository>().signOut();
          if (context.mounted) context.go('/login');
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                email,
                style: TextStyle(
                  color: Colors.grey.shade800,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              if (roleBadge != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    roleBadge,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (communityName.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  communityName,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'signout',
          child: Row(
            children: [
              Icon(Icons.logout, size: 18, color: Colors.red),
              SizedBox(width: 8),
              Text('Sign Out', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white24,
              child: Text(
                email.isNotEmpty ? email[0].toUpperCase() : '?',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 20),
          ],
        ),
      ),
    );
  }

  // ============ DARK SIDEBAR (Desktop) ============

  static const _sidebarDark = Color(0xff215e3f);
  static const _sidebarDarkLight = Color(0xFF61937A);

  Widget _buildSidebar(BuildContext context, dynamic user, AppState appState,
      bool isStaff, bool isAdmin, String currentPath) {
    final email = user?.email ?? '';
    final roleBadge = appState.activeRole != null
        ? _formatRole(appState.activeRole!.role)
        : null;

    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.topLeft,
        maxWidth: 250,
        child: Container(
          width: 250,
          margin: const EdgeInsets.fromLTRB(0, 0, 1, 0),
          decoration: BoxDecoration(
            color: _sidebarDark,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 20,
                offset: const Offset(2, 0),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Container(
                width: double.infinity,
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: Image.asset(
                  'assets/images/hoapp-logo.png',
                  fit: BoxFit.contain,
                  height: 38,
                ),
              ),
              // User header
              Container(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: _sidebarDarkLight, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.white24,
                      child:
                          Icon(Icons.person, size: 18, color: Colors.white70),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            email,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.none,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (roleBadge != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              roleBadge,
                              style: TextStyle(
                                color: Colors.greenAccent.shade200,
                                fontSize: 11,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Nav items
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  children: [
                    _buildSidebarItem(
                        context,
                        'Announcements',
                        Icons.announcement_outlined,
                        '/announcements',
                        currentPath),
                    _buildSidebarItem(context, 'Violations',
                        Icons.report_outlined, '/violations', currentPath),
                    _buildSidebarItem(context, 'Tickets',
                        Icons.support_outlined, '/tickets', currentPath),
                    _buildSidebarItem(context, 'Amenities', Icons.pool_outlined,
                        '/amenities', currentPath),
                    _buildSidebarItem(context, 'Billing & Payments',
                        Icons.payment_outlined, '/billing', currentPath),
                    _buildSidebarItem(
                        context,
                        'Pool Access',
                        Icons.accessibility_outlined,
                        '/pool-access',
                        currentPath),
                    if (isStaff) ...[
                      const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                        child: Divider(color: _sidebarDarkLight, height: 1),
                      ),
                      _buildSidebarItem(
                          context,
                          'Households',
                          Icons.family_restroom_outlined,
                          '/households',
                          currentPath),
                      _buildSidebarItem(context, 'Manage Users',
                          Icons.people_outlined, '/manage-users', currentPath),
                    ],
                    if (isAdmin) ...[
                      const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                        child: Divider(color: _sidebarDarkLight, height: 1),
                      ),
                      _buildSidebarItem(context, 'Settings',
                          Icons.settings_outlined, '/settings', currentPath),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarItem(BuildContext context, String title, IconData icon,
      String pathSuffix, String currentPath) {
    final isActive = currentPath.contains(pathSuffix);

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: isActive ? Colors.white.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          hoverColor: Colors.white.withOpacity(0.06),
          splashColor: Colors.white.withOpacity(0.1),
          onTap: () => context.go('/${widget.communitySlug}$pathSuffix'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(icon,
                    size: 20, color: isActive ? Colors.white : Colors.white60),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.white70,
                      fontSize: 14,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, dynamic user, AppState appState,
      bool isStaff, bool isAdmin) {
    return Drawer(
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
                border: Border.all(color: Colors.grey.shade300, width: 1),
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.3),
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
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ),
          const Divider(height: 1),
          _buildMenuItem(context, 'Announcements', Icons.announcement,
              '/${widget.communitySlug}/announcements'),
          _buildMenuItem(context, 'Violations', Icons.report,
              '/${widget.communitySlug}/violations'),
          _buildMenuItem(context, 'Tickets', Icons.support,
              '/${widget.communitySlug}/tickets'),
          _buildMenuItem(context, 'Amenities', Icons.pool,
              '/${widget.communitySlug}/amenities'),
          _buildMenuItem(context, 'Billing & Payments', Icons.payment,
              '/${widget.communitySlug}/billing'),
          _buildMenuItem(context, 'Pool Access', Icons.accessibility,
              '/${widget.communitySlug}/pool-access'),
          if (isStaff) ...[
            const Divider(),
            _buildMenuItem(context, 'Households', Icons.family_restroom,
                '/${widget.communitySlug}/households'),
            _buildMenuItem(context, 'Manage Users', Icons.people,
                '/${widget.communitySlug}/manage-users'),
          ],
          if (isAdmin) ...[
            const Divider(),
            _buildMenuItem(context, 'Settings', Icons.settings,
                '/${widget.communitySlug}/settings'),
          ],
        ],
      ),
    );
  }

  Widget _buildMenuItem(
      BuildContext context, String title, IconData icon, String route) {
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
