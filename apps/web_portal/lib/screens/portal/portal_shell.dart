import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:core_data/core_data.dart';
import 'package:core_domain/core_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'onboarding_tour.dart';
import 'chatbot/chatbot_widget.dart';

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
  bool _showTour = false;
  int _lastBadgeVersion = 0;

  // Badge notification counts (staff)
  int _pendingPayments = 0;
  int _openTickets = 0;
  int _pendingViolations = 0;
  int _openFeedback = 0;
  int _pendingBookings = 0;
  int _newAnnouncements = 0;

  int get _totalNotifications =>
      _pendingPayments +
      _openTickets +
      _pendingViolations +
      _openFeedback +
      _pendingBookings +
      _newAnnouncements;

  @override
  void initState() {
    super.initState();
    _loadCommunity();
  }

  @override
  void didUpdateWidget(covariant PortalShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Refresh badge counts when the route (child) changes
    if (oldWidget.child != widget.child) {
      _loadBadgeCounts();
    }
  }

  void _checkBadgeRefresh(AppState appState) {
    if (appState.badgeRefreshVersion != _lastBadgeVersion) {
      _lastBadgeVersion = appState.badgeRefreshVersion;
      _loadBadgeCounts();
    }
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
        _updateFavicon(community);

        // Load user roles
        final user = authRepo.currentUser;
        if (user != null) {
          final userId = user.id;
          if (userId.isNotEmpty) {
            try {
              final roles = await communityRepo.getUserRoles(userId);
              appState.setUserRoles(roles);

              // Check platform admin role
              final isPlatformAdmin = await communityRepo.isPlatformAdmin();
              appState.setPlatformAdmin(isPlatformAdmin);

              // Check if user has a unit assigned
              final memberRows = await Supabase.instance.client
                  .from('household_members')
                  .select('unit_id')
                  .eq('user_id', userId)
                  .eq('community_id', community.id)
                  .limit(1);
              appState.setHasUnit((memberRows as List).isNotEmpty);

              // Load all communities user belongs to (for community switcher)
              try {
                final userCommunities =
                    await communityRepo.getUserCommunities();
                appState.setUserCommunities(userCommunities);
              } catch (e) {
                print('Error loading user communities: $e');
              }
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
        _checkTour();
        _loadBadgeCounts();
      }
    }
  }

  void _updateFavicon(Community community) {
    final logoUrl = community.logoUrl;
    if (logoUrl != null && logoUrl.isNotEmpty) {
      // Update all icon links
      final icons = html.document
          .querySelectorAll("link[rel='icon'], link[rel='apple-touch-icon']");
      for (var i = 0; i < icons.length; i++) {
        final link = icons[i] as html.LinkElement;
        link.href = logoUrl;
      }
    }
  }

  Future<void> _loadBadgeCounts() async {
    final appState = context.read<AppState>();
    final communityId = appState.activeCommunityId;
    if (communityId == null) return;

    final client = Supabase.instance.client;

    try {
      // Announcements badge: only count unread (published after user's last read)
      final userId = client.auth.currentUser?.id;
      String? lastReadAt;
      if (userId != null) {
        final readRow = await client
            .from('announcement_reads')
            .select('last_read_at')
            .eq('user_id', userId)
            .eq('community_id', communityId)
            .maybeSingle();
        lastReadAt = readRow?['last_read_at'] as String?;
      }

      var announcementQuery = client
          .from('announcements')
          .select('id')
          .eq('community_id', communityId)
          .lte('publish_at', DateTime.now().toIso8601String());
      if (lastReadAt != null) {
        announcementQuery = announcementQuery.gt('publish_at', lastReadAt);
      }
      final announcementResult =
          await announcementQuery.count(CountOption.exact);

      if (mounted) {
        setState(() => _newAnnouncements = announcementResult.count);
      }

      // Staff-only badges
      if (!appState.isStaff) return;

      final results = await Future.wait([
        client
            .from('payments')
            .select('id')
            .eq('community_id', communityId)
            .eq('status', 'submitted')
            .count(CountOption.exact),
        client
            .from('tickets')
            .select('id')
            .eq('community_id', communityId)
            .eq('status', 'open')
            .count(CountOption.exact),
        client
            .from('violations')
            .select('id')
            .eq('community_id', communityId)
            .neq('status', 'resolved')
            .count(CountOption.exact),
        client
            .from('feedback')
            .select('id')
            .eq('community_id', communityId)
            .eq('status', 'open')
            .count(CountOption.exact),
        client
            .from('amenity_bookings')
            .select('id')
            .eq('community_id', communityId)
            .eq('status', 'pending')
            .count(CountOption.exact),
      ]);

      if (mounted) {
        setState(() {
          _pendingPayments = results[0].count;
          _openTickets = results[1].count;
          _pendingViolations = results[2].count;
          _openFeedback = results[3].count;
          _pendingBookings = results[4].count;
        });
      }
    } catch (e) {
      print('Error loading badge counts: $e');
    }
  }

  Future<void> _checkTour() async {
    final user = context.read<AuthRepository>().currentUser;
    if (user?.id == null) return;
    final show = await OnboardingTour.shouldShow(user!.id);
    if (show && mounted) {
      setState(() => _showTour = true);
    }
  }

  void _dismissTour() {
    final user = context.read<AuthRepository>().currentUser;
    if (user?.id != null) {
      OnboardingTour.markCompleted(user!.id);
    }
    setState(() => _showTour = false);
  }

  void _replayTour() {
    setState(() => _showTour = true);
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    _checkBadgeRefresh(appState);
    final authRepo = context.watch<AuthRepository>();
    final user = authRepo.currentUser;
    print(
        'PortalShell build: user=${user?.email}, community=${appState.activeCommunity?.name} role=${appState.activeRole?.role}, hasUnit=${appState.hasUnit}');
    final isStaff = appState.isStaff;
    final isAdmin = appState.isAdmin;
    final isGuard = appState.activeRole?.role == Role.guard;
    final isMaintenance = appState.activeRole?.role == Role.maintenance;
    final isResident = appState.activeRole?.role == Role.resident;
    final isPro = appState.isProfessional;
    print('isMaintenance: $isMaintenance');

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
    } else if (currentPath.contains('/financial-reports')) {
      pageTitle = 'Financial Reports';
    } else if (currentPath.contains('/expenses')) {
      pageTitle = 'Expense Tracker';
    } else if (currentPath.contains('/registered-swimmers')) {
      pageTitle = 'Registered Swimmers';
    } else if (currentPath.contains('/pool-access')) {
      pageTitle = 'Pool Access';
    } else if (currentPath.contains('/households')) {
      pageTitle = isStaff ? 'Households' : 'My Household';
    } else if (currentPath.contains('/manage-users')) {
      pageTitle = 'Manage Users';
    } else if (currentPath.contains('/settings')) {
      pageTitle = 'Settings';
    } else if (currentPath.contains('/security-pass')) {
      pageTitle = 'Security Pass';
    } else if (currentPath.contains('/qr-scanner')) {
      pageTitle = 'QR Pass Scanner';
    } else if (currentPath.contains('/feedback')) {
      pageTitle = 'Feedback';
    } else if (currentPath.contains('/notifications')) {
      pageTitle = 'Notifications';
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
                    ? _buildSidebar(context, user, appState, isStaff, isAdmin,
                        isGuard, isMaintenance, isResident, isPro, currentPath)
                    : const SizedBox.shrink(),
              ),
              // Main content
              Expanded(
                child: Scaffold(
                  appBar: PreferredSize(
                    preferredSize: const Size.fromHeight(70),
                    child: AppBar(
                      backgroundColor: _getSidebarColor(appState),
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
                  body: Stack(
                    children: [
                      _isCommunityLoaded
                          ? widget.child
                          : const Center(child: CircularProgressIndicator()),
                      if (_showTour && _isCommunityLoaded)
                        OnboardingTour(
                          isStaff: isStaff,
                          isAdmin: isAdmin,
                          isPro: isPro,
                          isGuard: isGuard,
                          communityName: appState.activeCommunity?.name ??
                              widget.communitySlug,
                          onDismiss: _dismissTour,
                        ),
                      if (_isCommunityLoaded)
                        PortalChatbot(
                          communitySlug: widget.communitySlug,
                          currentPath: currentPath,
                          userRole: appState.activeRole?.role.name,
                        ),
                    ],
                  ),
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
              backgroundColor: _getSidebarColor(appState),
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
          drawer: _buildDrawer(context, user, appState, isStaff, isAdmin,
              isGuard, isMaintenance, isResident, isPro, currentPath),
          body: Stack(
            children: [
              _isCommunityLoaded
                  ? widget.child
                  : const Center(child: CircularProgressIndicator()),
              if (_showTour && _isCommunityLoaded)
                OnboardingTour(
                  isStaff: isStaff,
                  isAdmin: isAdmin,
                  isPro: isPro,
                  isGuard: isGuard,
                  communityName:
                      appState.activeCommunity?.name ?? widget.communitySlug,
                  onDismiss: _dismissTour,
                ),
              if (_isCommunityLoaded)
                PortalChatbot(
                  communitySlug: widget.communitySlug,
                  currentPath: currentPath,
                  userRole: appState.activeRole?.role.name,
                ),
            ],
          ),
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
        if (value == 'profile') {
          if (context.mounted) {
            _showProfileDialog(context, appState);
          }
        } else if (value == 'change_password') {
          if (context.mounted) {
            _showChangePasswordDialog(context);
          }
        } else if (value == 'replay_tour') {
          _replayTour();
        } else if (value == 'notifications') {
          if (context.mounted) {
            context.go('/${widget.communitySlug}/notifications');
          }
        } else if (value == 'platform_admin') {
          if (context.mounted) context.go('/admin');
        } else if (value == 'switch_community') {
          if (context.mounted) context.go('/select-community');
        } else if (value == 'signout') {
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
          value: 'profile',
          child: Row(
            children: [
              Icon(Icons.person_outline, size: 18, color: Colors.blueGrey),
              SizedBox(width: 8),
              Text('My Profile'),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'change_password',
          child: Row(
            children: [
              Icon(Icons.lock_outline, size: 18, color: Colors.blueGrey),
              SizedBox(width: 8),
              Text('Change Password'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'notifications',
          child: Row(
            children: [
              const Icon(Icons.notifications_outlined,
                  size: 18, color: Colors.blueGrey),
              const SizedBox(width: 8),
              const Expanded(child: Text('Notifications')),
              if (_totalNotifications > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _totalNotifications > 99 ? '99+' : '$_totalNotifications',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'replay_tour',
          child: Row(
            children: [
              Icon(Icons.help_outline, size: 18, color: Colors.blueGrey),
              SizedBox(width: 8),
              Text('Help / Tour'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'switch_community',
          child: Row(
            children: [
              Icon(Icons.swap_horiz, size: 18, color: Colors.blueGrey),
              SizedBox(width: 8),
              Text('Switch Community'),
            ],
          ),
        ),
        if (appState.isPlatformAdmin) ...[
          const PopupMenuDivider(),
          PopupMenuItem<String>(
            value: 'platform_admin',
            child: Row(
              children: [
                Icon(Icons.admin_panel_settings,
                    size: 18, color: Theme.of(context).colorScheme.primary),
                SizedBox(width: 8),
                Text('Platform Admin',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    )),
              ],
            ),
          ),
        ],
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

  void _showProfileDialog(BuildContext context, AppState appState) {
    showDialog(
      context: context,
      builder: (_) => _ProfileDialog(communityId: appState.activeCommunityId!),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const _ChangePasswordDialog(),
    );
  }

  // ============ DARK SIDEBAR (Desktop) ============

  static const _defaultSidebarDark = Color(0xff215e3f);

  Color _getSidebarColor(AppState appState) {
    final community = appState.activeCommunity;
    if (community != null) {
      try {
        return Color(
            int.parse(community.primaryColor.replaceFirst('#', '0xff')));
      } catch (_) {}
    }
    return _defaultSidebarDark;
  }

  Widget _buildSidebar(
      BuildContext context,
      dynamic user,
      AppState appState,
      bool isStaff,
      bool isAdmin,
      bool isGuard,
      bool isMaintenance,
      bool isResident,
      bool isPro,
      String currentPath) {
    final hasUnit = appState.hasUnit || isStaff || isGuard;
    final email = user?.email ?? '';
    final roleBadge = appState.activeRole != null && hasUnit
        ? _formatRole(appState.activeRole!.role)
        : _isCommunityLoaded
            ? 'User (contact Admin to assign unit)'
            : '';
    final sidebarColor = _getSidebarColor(appState);
    final sidebarLight = Color.lerp(sidebarColor, Colors.white, 0.35)!;

    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.topLeft,
        maxWidth: 250,
        child: Container(
          width: 250,
          margin: const EdgeInsets.fromLTRB(0, 0, 1, 0),
          decoration: BoxDecoration(
            color: sidebarColor,
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
                child: appState.activeCommunity?.logoUrl != null
                    ? Image.network(
                        appState.activeCommunity!.logoUrl!,
                        fit: BoxFit.contain,
                        height: 70,
                        errorBuilder: (_, __, ___) => Image.asset(
                          'assets/images/hoapp-logo.png',
                          fit: BoxFit.contain,
                          height: 70,
                        ),
                      )
                    : Image.asset(
                        'assets/images/hoapp-logo.png',
                        fit: BoxFit.contain,
                        height: 70,
                      ),
              ),
              // User header
              Container(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: sidebarLight, width: 1),
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
                                color: Colors.white70,
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
                child: !_isCommunityLoaded
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white70,
                          strokeWidth: 2,
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        children: [
                          _buildSidebarItem(
                              context,
                              'Announcements',
                              Icons.announcement_outlined,
                              '/announcements',
                              currentPath,
                              badge: _newAnnouncements),
                          if (isResident && hasUnit) ...[
                            _buildSidebarItem(
                                context,
                                'My Household',
                                Icons.family_restroom_outlined,
                                '/households',
                                currentPath),
                          ],
                          _buildSidebarItem(context, 'Billing & Payments',
                              Icons.payment_outlined, '/billing', currentPath,
                              badge: _pendingPayments),
                          _buildSidebarItem(context, 'Tickets',
                              Icons.support_outlined, '/tickets', currentPath,
                              badge: _openTickets),
                          _buildSidebarItem(context, 'Violations',
                              Icons.report_outlined, '/violations', currentPath,
                              badge: _pendingViolations),
                          _buildSidebarItem(context, 'Amenities',
                              Icons.pool_outlined, '/amenities', currentPath,
                              badge: _pendingBookings),
                          if (isPro && (hasUnit || isStaff)) ...[
                            ...(!isGuard && !isMaintenance
                                ? [
                                    _buildSidebarItem(
                                        context,
                                        'Pool Access',
                                        Icons.accessibility_outlined,
                                        '/pool-access',
                                        currentPath),
                                  ]
                                : []),
                            ...(!isResident
                                ? [
                                    _buildSidebarItem(
                                        context,
                                        'Registered Swimmers',
                                        Icons.pool_outlined,
                                        '/registered-swimmers',
                                        currentPath),
                                  ]
                                : []),
                          ],
                          if (isPro && (hasUnit || isStaff))
                            _buildSidebarItem(
                                context,
                                'Security Pass',
                                Icons.badge_outlined,
                                '/security-pass',
                                currentPath),
                          if ((isGuard || isMaintenance) && isPro)
                            _buildSidebarItem(
                                context,
                                'QR Pass Scanner',
                                Icons.qr_code_scanner,
                                '/qr-scanner',
                                currentPath),
                          if (!isGuard &&
                              !isMaintenance &&
                              (hasUnit || isStaff) &&
                              isPro) ...[
                            _buildSidebarItem(
                                context,
                                'Community Expenses',
                                Icons.account_balance_wallet_outlined,
                                '/expenses',
                                currentPath),
                            _buildSidebarItem(
                                context,
                                'Financial Reports',
                                Icons.analytics_outlined,
                                '/financial-reports',
                                currentPath),
                          ],
                          if (isStaff) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 12),
                              child: Divider(color: sidebarLight, height: 1),
                            ),
                            _buildSidebarItem(
                                context,
                                'Households',
                                Icons.family_restroom_outlined,
                                '/households',
                                currentPath),
                          ],
                          if (isAdmin) ...[
                            _buildSidebarItem(
                                context,
                                'Manage Users',
                                Icons.people_outlined,
                                '/manage-users',
                                currentPath),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 12),
                              child: Divider(color: sidebarLight, height: 1),
                            ),
                            _buildSidebarItem(
                                context,
                                'Settings',
                                Icons.settings_outlined,
                                '/settings',
                                currentPath),
                          ],
                          _buildSidebarItem(context, 'Feedback',
                              Icons.feedback_outlined, '/feedback', currentPath,
                              badge: _openFeedback),
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
      String pathSuffix, String currentPath,
      {int badge = 0}) {
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
                if (badge > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badge > 99 ? '99+' : '$badge',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
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

  Widget _buildDrawer(
      BuildContext context,
      dynamic user,
      AppState appState,
      bool isStaff,
      bool isAdmin,
      bool isGuard,
      bool isMaintenance,
      bool isResident,
      bool isPro,
      String currentPath) {
    final hasUnit = appState.hasUnit || isStaff || isGuard;
    return Drawer(
      backgroundColor: Colors.white,
      child: ListTileTheme(
        tileColor: Colors.white,
        child: ListView(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                image: appState.activeCommunity?.logoUrl == null
                    ? const DecorationImage(
                        image:
                            AssetImage('assets/images/hoapp-logo-with-bg.png'),
                        fit: BoxFit.cover,
                      )
                    : null,
                color: appState.activeCommunity?.logoUrl != null
                    ? Colors.white
                    : null,
              ),
              child: appState.activeCommunity?.logoUrl != null
                  ? Center(
                      child: Image.network(
                        appState.activeCommunity!.logoUrl!,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Image.asset(
                          'assets/images/hoapp-logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
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
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                  ],
                ),
              ),
            const Divider(height: 1),
            if (!_isCommunityLoaded)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else ...[
              _buildMenuItem(context, 'Announcements', Icons.announcement,
                  '/${widget.communitySlug}/announcements', currentPath,
                  badge: _newAnnouncements),
              if (isResident && hasUnit) ...[
                _buildMenuItem(context, 'My Household', Icons.family_restroom,
                    '/${widget.communitySlug}/households', currentPath),
              ],
              _buildMenuItem(context, 'Billing & Payments', Icons.payment,
                  '/${widget.communitySlug}/billing', currentPath,
                  badge: _pendingPayments),
              _buildMenuItem(context, 'Tickets', Icons.support,
                  '/${widget.communitySlug}/tickets', currentPath,
                  badge: _openTickets),
              _buildMenuItem(context, 'Violations', Icons.report,
                  '/${widget.communitySlug}/violations', currentPath,
                  badge: _pendingViolations),
              _buildMenuItem(context, 'Amenities', Icons.pool,
                  '/${widget.communitySlug}/amenities', currentPath,
                  badge: _pendingBookings),
              if (isPro && (hasUnit || isStaff)) ...[
                if (!isGuard && !isMaintenance)
                  _buildMenuItem(context, 'Pool Access', Icons.accessibility,
                      '/${widget.communitySlug}/pool-access', currentPath),
                if (!isResident)
                  _buildMenuItem(
                      context,
                      'Registered Swimmers',
                      Icons.pool,
                      '/${widget.communitySlug}/registered-swimmers',
                      currentPath),
              ],
              if (isPro && (hasUnit || isStaff))
                _buildMenuItem(context, 'Security Pass', Icons.badge,
                    '/${widget.communitySlug}/security-pass', currentPath),
              if ((isGuard || isMaintenance) && isPro)
                _buildMenuItem(
                    context,
                    'QR Pass Scanner',
                    Icons.qr_code_scanner,
                    '/${widget.communitySlug}/qr-scanner',
                    currentPath),
              if (!isGuard &&
                  !isMaintenance &&
                  (hasUnit || isStaff) &&
                  isPro) ...[
                _buildMenuItem(
                    context,
                    'Community Expenses',
                    Icons.account_balance_wallet,
                    '/${widget.communitySlug}/expenses',
                    currentPath),
                _buildMenuItem(context, 'Financial Reports', Icons.analytics,
                    '/${widget.communitySlug}/financial-reports', currentPath),
              ],
              if (isStaff) ...[
                const Divider(),
                _buildMenuItem(context, 'Households', Icons.family_restroom,
                    '/${widget.communitySlug}/households', currentPath),
              ],
              if (isAdmin) ...[
                _buildMenuItem(context, 'Manage Users', Icons.people,
                    '/${widget.communitySlug}/manage-users', currentPath),
                const Divider(),
                _buildMenuItem(context, 'Settings', Icons.settings,
                    '/${widget.communitySlug}/settings', currentPath),
              ],
              _buildMenuItem(context, 'Feedback', Icons.feedback,
                  '/${widget.communitySlug}/feedback', currentPath,
                  badge: _openFeedback),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, String title, IconData icon,
      String route, String currentPath,
      {int badge = 0}) {
    final routeSegment = route.split('/').last;
    final pathSegments = currentPath.split('/');
    final isActive = pathSegments.contains(routeSegment);
    return ListTile(
      leading: Icon(icon,
          color: isActive ? Theme.of(context).colorScheme.primary : null),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
          color: isActive ? Theme.of(context).colorScheme.primary : null,
        ),
      ),
      trailing: badge > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                badge > 99 ? '99+' : '$badge',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : null,
      tileColor: isActive
          ? Theme.of(context).colorScheme.primary.withOpacity(0.08)
          : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
        return 'Security Guard';
      case Role.resident:
        return 'Resident';
      case Role.maintenance:
        return 'Maintenance';
    }
  }
}

// ============================================================
// PROFILE DIALOG
// ============================================================

class _ProfileDialog extends StatefulWidget {
  final String communityId;

  const _ProfileDialog({required this.communityId});

  @override
  State<_ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<_ProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _authEmail;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final client = SupabaseClientManager.instance;
    final userId = client.auth.currentUser?.id;
    _authEmail = client.auth.currentUser?.email;

    if (userId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final row = await client
        .from('profiles')
        .select()
        .eq('user_id', userId)
        .eq('community_id', widget.communityId)
        .maybeSingle();

    if (mounted) {
      if (row != null) {
        _nameController.text = (row['full_name'] as String?) ?? '';
        _phoneController.text = (row['phone'] as String?) ?? '';
        _emailController.text = (row['email'] as String?) ?? _authEmail ?? '';
      } else {
        _emailController.text = _authEmail ?? '';
      }
      setState(() => _loading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final client = SupabaseClientManager.instance;
      final userId = client.auth.currentUser?.id;
      if (userId == null) throw Exception('Not authenticated');

      await client.from('profiles').upsert({
        'user_id': userId,
        'community_id': widget.communityId,
        'full_name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: EdgeInsets.zero,
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Color(0xff2e8b57)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.person, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'My Profile',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'View and edit your information',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // Body
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Full Name',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: Theme.of(context).colorScheme.primary,
                                width: 1.5),
                          ),
                          prefixIcon: const Icon(Icons.person_outline),
                        ),
                        validator: (v) =>
                            (v?.isEmpty ?? true) ? 'Required' : null,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _phoneController,
                        decoration: InputDecoration(
                          labelText: 'Phone Number',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: Theme.of(context).colorScheme.primary,
                                width: 1.5),
                          ),
                          prefixIcon: const Icon(Icons.phone_outlined),
                        ),
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: Theme.of(context).colorScheme.primary,
                                width: 1.5),
                          ),
                          prefixIcon: const Icon(Icons.email_outlined),
                          filled: _authEmail != null && _authEmail!.isNotEmpty,
                          fillColor: Colors.grey.shade100,
                        ),
                        enabled: _authEmail == null || _authEmail!.isEmpty,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton.icon(
                          onPressed: _saving ? null : _saveProfile,
                          icon: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(
                                  Icons.save,
                                  color: Colors.white,
                                ),
                          label: Text(_saving ? 'Saving...' : 'Save Profile'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// CHANGE PASSWORD DIALOG
// ============================================================

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _saving = false;
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final authRepo = context.read<AuthRepository>();
      await authRepo.changePassword(
        oldPassword: _oldPasswordController.text,
        newPassword: _newPasswordController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password changed successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: EdgeInsets.zero,
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Color(0xff2e8b57)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.lock_outline,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Change Password',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Verify your identity and set a new password',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // Body
            Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _oldPasswordController,
                      obscureText: _obscureOld,
                      decoration: InputDecoration(
                        labelText: 'Current Password',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 1.5),
                        ),
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureOld
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () =>
                              setState(() => _obscureOld = !_obscureOld),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        return null;
                      },
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _newPasswordController,
                      obscureText: _obscureNew,
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 1.5),
                        ),
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureNew
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () =>
                              setState(() => _obscureNew = !_obscureNew),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        if (v.length < 6) return 'At least 6 characters';
                        return null;
                      },
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirm,
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 1.5),
                        ),
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureConfirm
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () => setState(
                              () => _obscureConfirm = !_obscureConfirm),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        if (v != _newPasswordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _changePassword(),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _changePassword,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.check, color: Colors.white),
                        label:
                            Text(_saving ? 'Changing...' : 'Change Password'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
