import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:core_data/core_data.dart';
import 'package:core_domain/core_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'onboarding_tour.dart';
import 'chatbot/chatbot_widget.dart';
import '../../core/onesignal_web.dart';

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
  String? _profileName;

  /// Realtime channel for badge-count auto-refresh.
  RealtimeChannel? _badgeChannel;

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
  void dispose() {
    _badgeChannel?.unsubscribe();
    super.dispose();
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

              // Load profile name from profiles table
              try {
                final profileRow = await Supabase.instance.client
                    .from('profiles')
                    .select('full_name')
                    .eq('user_id', userId)
                    .eq('community_id', community.id)
                    .maybeSingle();
                if (profileRow != null && mounted) {
                  setState(() {
                    _profileName = profileRow['full_name'] as String?;
                  });
                }
              } catch (_) {}

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
        _registerOneSignal();
        _subscribeToBadgeUpdates();
      }
    }
  }

  /// Subscribe to Realtime changes on tables that drive badge counts so the
  /// UI updates automatically without a manual browser refresh.
  void _subscribeToBadgeUpdates() {
    final appState = context.read<AppState>();
    final communityId = appState.activeCommunityId;
    if (communityId == null) return;

    final client = Supabase.instance.client;

    _badgeChannel = client
        .channel('badge-counts')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'violations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'community_id',
            value: communityId,
          ),
          callback: (_) => _loadBadgeCounts(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'tickets',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'community_id',
            value: communityId,
          ),
          callback: (_) => _loadBadgeCounts(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'payments',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'community_id',
            value: communityId,
          ),
          callback: (_) => _loadBadgeCounts(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'feedback',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'community_id',
            value: communityId,
          ),
          callback: (_) => _loadBadgeCounts(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'amenity_bookings',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'community_id',
            value: communityId,
          ),
          callback: (_) => _loadBadgeCounts(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'announcements',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'community_id',
            value: communityId,
          ),
          callback: (_) => _loadBadgeCounts(),
        )
        .subscribe();
  }

  /// Register the current user with OneSignal for web push notifications.
  void _registerOneSignal() {
    try {
      final appState = context.read<AppState>();
      final user = context.read<AuthRepository>().currentUser;
      if (user == null) {
        print('OneSignal: skipped — no user');
        return;
      }

      print('OneSignal: registering user ${user.id}');
      OneSignalWeb.loginUser(user.id);
      final tags = <String, String>{};
      if (appState.activeCommunityId != null) {
        tags['community_id'] = appState.activeCommunityId!;
      }
      if (appState.activeRole != null) {
        tags['role'] = appState.activeRole!.role.name;
      }
      if (tags.isNotEmpty) {
        print('OneSignal: setting tags $tags');
        OneSignalWeb.setTags(tags);
      }
      // Request push permission if not already granted
      if (!OneSignalWeb.permissionGranted) {
        print('OneSignal: requesting notification permission');
        OneSignalWeb.requestPermission();
      }
    } catch (e) {
      print('OneSignal registration error: $e');
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
      pageTitle = 'Community Expenses';
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
                width: _sidebarOpen ? 260 : 0,
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
                          ? Column(
                              children: [
                                if (isAdmin &&
                                    !currentPath.contains('/settings'))
                                  _PlanExpiryBanner(
                                    community: appState.activeCommunity,
                                    slug: widget.communitySlug,
                                  ),
                                Expanded(child: widget.child),
                              ],
                            )
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

        // Mobile layout with drawer + bottom nav
        final slug = widget.communitySlug;
        final sidebarColor = _getSidebarColor(appState);

        // Determine which bottom nav tab is active based on current route
        int? activeBottomTab;
        if (currentPath.contains('/announcements')) {
          activeBottomTab = 0;
        } else if (currentPath.contains('/billing')) {
          activeBottomTab = 1;
        } else if (currentPath.contains('/households')) {
          activeBottomTab = 2; // mapped to center FAB
        } else if (currentPath.contains('/security-pass')) {
          activeBottomTab = 3;
        } else if (currentPath.contains('/notifications')) {
          activeBottomTab = 4;
        }

        return Scaffold(
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(70),
            child: AppBar(
              backgroundColor: sidebarColor,
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
                // Notification bell
                if (isDesktop) ...[
                  Padding(
                    padding: const EdgeInsets.only(right: 2),
                    child: IconButton(
                      icon: Badge(
                        isLabelVisible: _totalNotifications > 0,
                        label: Text('$_totalNotifications',
                            style: const TextStyle(
                                fontSize: 9, fontWeight: FontWeight.bold)),
                        backgroundColor: Colors.red.shade400,
                        child: const Icon(Icons.notifications_outlined),
                      ),
                      onPressed: () => context.go('/$slug/notifications'),
                    ),
                  )
                ],
                _buildUserDropdown(context, user, appState),
              ],
            ),
          ),
          drawer: _buildDrawer(context, user, appState, isStaff, isAdmin,
              isGuard, isMaintenance, isResident, isPro, currentPath),
          body: Stack(
            children: [
              _isCommunityLoaded
                  ? Column(
                      children: [
                        if (isAdmin && !currentPath.contains('/settings'))
                          _PlanExpiryBanner(
                            community: appState.activeCommunity,
                            slug: widget.communitySlug,
                          ),
                        Expanded(child: widget.child),
                      ],
                    )
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
            ],
          ),
          bottomNavigationBar: _buildMobileBottomNav(
              context, appState, slug, activeBottomTab, sidebarColor),
          floatingActionButton: _buildMobileCenterFab(
              context, appState, slug, currentPath, sidebarColor),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerDocked,
        );
      },
    );
  }

  Widget _buildMobileBottomNav(
    BuildContext context,
    AppState appState,
    String slug,
    int? activeTab,
    Color primary,
  ) {
    Widget navIcon(IconData icon, IconData selectedIcon, String label,
        int tabIndex, int badge, String route) {
      final isActive = activeTab == tabIndex;
      return InkWell(
        onTap: () => context.go('/$slug/$route'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Badge(
                isLabelVisible: badge > 0,
                label: Text('$badge',
                    style: const TextStyle(
                        fontSize: 9, fontWeight: FontWeight.bold)),
                backgroundColor: Colors.red.shade400,
                child: Icon(
                  isActive ? selectedIcon : icon,
                  size: 20,
                  color: isActive ? Colors.white : Colors.white70,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  color: isActive ? Colors.white : Colors.white70,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      );
    }

    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      elevation: 8,
      color: primary,
      surfaceTintColor: Colors.transparent,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Expanded(
              child: navIcon(Icons.campaign_outlined, Icons.campaign, 'News', 0,
                  _newAnnouncements, 'announcements')),
          Expanded(
              child: navIcon(
                  Icons.family_restroom_outlined,
                  Icons.family_restroom,
                  appState.isResident ? 'My Household' : 'Households',
                  1,
                  0,
                  'households')),
          const SizedBox(width: 48), // space for FAB
          Expanded(
              child: navIcon(Icons.qr_code_2_outlined, Icons.qr_code_2,
                  'Security', 3, 0, 'security-pass')),
          Expanded(
              child: navIcon(Icons.notifications_outlined, Icons.notifications,
                  'Notifications', 4, _totalNotifications, 'notifications')),
        ],
      ),
    );
  }

  Widget _buildMobileCenterFab(
    BuildContext context,
    AppState appState,
    String slug,
    String currentPath,
    Color primary,
  ) {
    final isBillingActive = currentPath.contains('/billing');

    return SizedBox(
      width: 64,
      height: 64,
      child: FloatingActionButton(
        elevation: isBillingActive ? 2 : 6,
        backgroundColor: primary,
        shape: const CircleBorder(),
        onPressed: () => context.go('/$slug/billing'),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isBillingActive ? Icons.payment : Icons.payment_outlined,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(height: 2),
            const Text(
              'Billing',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserDropdown(
      BuildContext context, dynamic user, AppState appState) {
    final email = user?.email ?? '';
    final fullName =
        _profileName ?? user?.userMetadata?['full_name'] as String?;
    final displayName =
        (fullName != null && fullName.isNotEmpty) ? fullName : email;
    final roleBadge = appState.activeRole != null
        ? _formatRole(appState.activeRole!.role)
        : null;
    final communityName = appState.activeCommunity?.name ?? '';
    final initials = displayName.isNotEmpty
        ? displayName
            .trim()
            .split(' ')
            .map((w) => w.isNotEmpty ? w[0] : '')
            .take(2)
            .join()
            .toUpperCase()
        : '?';

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
          OneSignalWeb.logoutUser();
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
                displayName,
                style: TextStyle(
                  color: Colors.grey.shade800,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (fullName != null && fullName.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  email,
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 12,
                  ),
                ),
              ],
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
        if (appState.userCommunities.length > 1)
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
              radius: 18,
              backgroundColor: Colors.white.withOpacity(0.15),
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.none,
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
    ).then((_) => _refreshProfileName(appState));
  }

  Future<void> _refreshProfileName(AppState appState) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final communityId = appState.activeCommunityId;
    if (userId == null || communityId == null) return;
    try {
      final row = await Supabase.instance.client
          .from('profiles')
          .select('full_name')
          .eq('user_id', userId)
          .eq('community_id', communityId)
          .maybeSingle();
      if (row != null && mounted) {
        setState(() => _profileName = row['full_name'] as String?);
      }
    } catch (_) {}
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
    final fullName =
        _profileName ?? user?.userMetadata?['full_name'] as String?;
    final displayName =
        (fullName != null && fullName.isNotEmpty) ? fullName : email;
    final roleBadge = appState.activeRole != null && hasUnit
        ? _formatRole(appState.activeRole!.role)
        : _isCommunityLoaded
            ? 'User (contact Admin to assign unit)'
            : '';
    final sidebarColor = _getSidebarColor(appState);
    final sidebarDark = Color.lerp(sidebarColor, Colors.black, 0.15)!;
    final initials = displayName.isNotEmpty
        ? displayName
            .trim()
            .split(' ')
            .map((w) => w.isNotEmpty ? w[0] : '')
            .take(2)
            .join()
            .toUpperCase()
        : '?';

    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.topLeft,
        maxWidth: 260,
        child: Container(
          width: 260,
          margin: const EdgeInsets.fromLTRB(0, 0, 1, 0),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [sidebarColor, sidebarDark],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.30),
                blurRadius: 24,
                offset: const Offset(3, 0),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // Logo with subtle shadow
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: sidebarColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: appState.activeCommunity?.logoUrl != null
                    ? Image.network(
                        appState.activeCommunity!.logoUrl!,
                        fit: BoxFit.contain,
                        height: 60,
                        errorBuilder: (_, __, ___) => Image.asset(
                          'assets/images/hoapp-logo.png',
                          fit: BoxFit.contain,
                          height: 60,
                        ),
                      )
                    : Image.asset(
                        'assets/images/hoapp-logo.png',
                        fit: BoxFit.contain,
                        height: 60,
                      ),
              ),
              // User header
              Container(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                        color: Colors.white.withOpacity(0.12), width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.5),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.white.withOpacity(0.15),
                        child: Text(
                          initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.none,
                              letterSpacing: 0.1,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (roleBadge != null) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                roleBadge,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w500,
                                  decoration: TextDecoration.none,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        children: [
                          _buildSidebarItem(
                              context,
                              'Announcements',
                              Icons.campaign_outlined,
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
                              (hasUnit || isStaff)) ...[
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
                              child: Divider(
                                  color: Colors.white.withOpacity(0.15),
                                  height: 1),
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
                              child: Divider(
                                  color: Colors.white.withOpacity(0.15),
                                  height: 1),
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

              // Sign-out at bottom
              Container(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withOpacity(0.12),
                      width: 1,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      hoverColor: Colors.red.withOpacity(0.12),
                      splashColor: Colors.red.withOpacity(0.15),
                      onTap: () async {
                        OneSignalWeb.logoutUser();
                        await context.read<AuthRepository>().signOut();
                        if (context.mounted) context.go('/login');
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            Icon(Icons.logout_rounded,
                                size: 18, color: Colors.white.withOpacity(0.6)),
                            const SizedBox(width: 12),
                            Text(
                              'Sign Out',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
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
      padding: const EdgeInsets.only(bottom: 3),
      child: Material(
        color: isActive ? Colors.white.withOpacity(0.14) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          hoverColor: Colors.white.withOpacity(0.08),
          splashColor: Colors.white.withOpacity(0.12),
          onTap: () => context.go('/${widget.communitySlug}$pathSuffix'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: isActive
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border(
                      left: BorderSide(
                        color: Colors.white.withOpacity(0.85),
                        width: 3,
                      ),
                    ),
                  )
                : null,
            child: Row(
              children: [
                Icon(icon,
                    size: 20, color: isActive ? Colors.white : Colors.white54),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.white70,
                      fontSize: 13.5,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
                if (badge > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
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
    final primary = _getSidebarColor(appState);
    final communityName = appState.activeCommunity?.name ?? '';
    final email = user?.email ?? '';
    final roleLabel = appState.activeRole != null
        ? _formatRole(appState.activeRole!.role)
        : '';

    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          // ── Green gradient header (matches native mobile) ──
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 20,
              bottom: 20,
              left: 20,
              right: 20,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  primary,
                  primary.withValues(alpha: 0.85),
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.6),
                            width: 2),
                      ),
                      child: CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.white,
                        child: ClipOval(
                          child: appState.activeCommunity!.logoUrl != null
                              ? Image.network(
                                  appState.activeCommunity!.logoUrl!,
                                  fit: BoxFit.contain,
                                  height: 60,
                                  errorBuilder: (_, __, ___) => Image.asset(
                                    'assets/images/hoapp-logo.png',
                                    fit: BoxFit.contain,
                                    height: 60,
                                  ),
                                )
                              : Image.asset(
                                  'assets/images/hoapp-icon.png',
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.contain,
                                ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (roleLabel.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          roleLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  communityName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // ── Navigation items ──
          if (!_isCommunityLoaded)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                children: [
                  _buildDrawerItem(
                      context,
                      'Announcements',
                      Icons.campaign_outlined,
                      Icons.campaign,
                      '/${widget.communitySlug}/announcements',
                      currentPath,
                      primary,
                      badge: _newAnnouncements),
                  if (isResident && hasUnit)
                    _buildDrawerItem(
                        context,
                        'My Household',
                        Icons.family_restroom_outlined,
                        Icons.family_restroom,
                        '/${widget.communitySlug}/households',
                        currentPath,
                        primary),
                  _buildDrawerItem(
                      context,
                      'Billing & Payments',
                      Icons.payment_outlined,
                      Icons.payment,
                      '/${widget.communitySlug}/billing',
                      currentPath,
                      primary,
                      badge: _pendingPayments),
                  _buildDrawerItem(
                      context,
                      'Tickets',
                      Icons.support_outlined,
                      Icons.support,
                      '/${widget.communitySlug}/tickets',
                      currentPath,
                      primary,
                      badge: _openTickets),
                  _buildDrawerItem(
                      context,
                      'Violations',
                      Icons.report_outlined,
                      Icons.report,
                      '/${widget.communitySlug}/violations',
                      currentPath,
                      primary,
                      badge: _pendingViolations),
                  _buildDrawerItem(
                      context,
                      'Amenities',
                      Icons.pool_outlined,
                      Icons.pool,
                      '/${widget.communitySlug}/amenities',
                      currentPath,
                      primary,
                      badge: _pendingBookings),
                  if (isPro && (hasUnit || isStaff)) ...[
                    if (!isGuard && !isMaintenance)
                      _buildDrawerItem(
                          context,
                          'Pool Access',
                          Icons.accessibility_outlined,
                          Icons.accessibility,
                          '/${widget.communitySlug}/pool-access',
                          currentPath,
                          primary),
                    if (!isResident)
                      _buildDrawerItem(
                          context,
                          'Registered Swimmers',
                          Icons.pool_outlined,
                          Icons.pool,
                          '/${widget.communitySlug}/registered-swimmers',
                          currentPath,
                          primary),
                  ],
                  if (isPro && (hasUnit || isStaff))
                    _buildDrawerItem(
                        context,
                        'Security Pass',
                        Icons.badge_outlined,
                        Icons.badge,
                        '/${widget.communitySlug}/security-pass',
                        currentPath,
                        primary),
                  if ((isGuard || isMaintenance) && isPro)
                    _buildDrawerItem(
                        context,
                        'QR Pass Scanner',
                        Icons.qr_code_scanner_outlined,
                        Icons.qr_code_scanner,
                        '/${widget.communitySlug}/qr-scanner',
                        currentPath,
                        primary),
                  if (!isGuard && !isMaintenance && (hasUnit || isStaff)) ...[
                    _buildDrawerItem(
                        context,
                        'Community Expenses',
                        Icons.account_balance_wallet_outlined,
                        Icons.account_balance_wallet,
                        '/${widget.communitySlug}/expenses',
                        currentPath,
                        primary),
                    _buildDrawerItem(
                        context,
                        'Financial Reports',
                        Icons.analytics_outlined,
                        Icons.analytics,
                        '/${widget.communitySlug}/financial-reports',
                        currentPath,
                        primary),
                  ],
                  if (isStaff) ...[
                    _buildSectionDivider('STAFF'),
                    _buildDrawerItem(
                        context,
                        'Households',
                        Icons.family_restroom_outlined,
                        Icons.family_restroom,
                        '/${widget.communitySlug}/households',
                        currentPath,
                        primary),
                  ],
                  if (isAdmin) ...[
                    _buildSectionDivider('ADMIN'),
                    _buildDrawerItem(
                        context,
                        'Manage Users',
                        Icons.people_outlined,
                        Icons.people,
                        '/${widget.communitySlug}/manage-users',
                        currentPath,
                        primary),
                    _buildDrawerItem(
                        context,
                        'Settings',
                        Icons.settings_outlined,
                        Icons.settings,
                        '/${widget.communitySlug}/settings',
                        currentPath,
                        primary),
                  ],
                  _buildDrawerItem(
                      context,
                      'Feedback',
                      Icons.feedback_outlined,
                      Icons.feedback,
                      '/${widget.communitySlug}/feedback',
                      currentPath,
                      primary,
                      badge: _openFeedback),
                ],
              ),
            ),

          // ── Sign Out ──
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: ListTile(
                leading: Icon(Icons.logout_rounded,
                    color: Colors.red.shade400, size: 22),
                title: Text('Sign Out',
                    style: TextStyle(
                        color: Colors.red.shade400,
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                onTap: () async {
                  Navigator.of(context).pop();
                  OneSignalWeb.logoutUser();
                  await context.read<AuthRepository>().signOut();
                  if (context.mounted) context.go('/login');
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(BuildContext context, String title, IconData icon,
      IconData selectedIcon, String route, String currentPath, Color primary,
      {int badge = 0}) {
    final routeSegment = route.split('/').last;
    final pathSegments = currentPath.split('/');
    final isActive = pathSegments.contains(routeSegment);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isActive ? primary.withValues(alpha: 0.1) : Colors.transparent,
      ),
      child: ListTile(
        dense: true,
        leading: Icon(
          isActive ? selectedIcon : icon,
          color: isActive ? primary : Colors.grey.shade600,
          size: 22,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            color: isActive ? primary : Colors.grey.shade800,
            fontSize: 14,
          ),
        ),
        trailing: badge > 0
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.red.shade400,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge > 99 ? '99+' : '$badge',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              )
            : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: () {
          Navigator.of(context).pop();
          context.go(route);
        },
      ),
    );
  }

  Widget _buildSectionDivider(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 12, bottom: 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade400,
          letterSpacing: 1.2,
        ),
      ),
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

// ─── Plan Expiry Banner ──────────────────────────────────────────────────────

class _PlanExpiryBanner extends StatelessWidget {
  final Community? community;
  final String slug;

  const _PlanExpiryBanner({required this.community, required this.slug});

  @override
  Widget build(BuildContext context) {
    if (community == null) return const SizedBox.shrink();
    final c = community!;

    // Only show for paid plans that are expiring soon or expired
    if (c.plan == 'starter') return const SizedBox.shrink();
    if (!c.isPlanExpiringSoon && !c.isPlanExpired)
      return const SizedBox.shrink();

    final isExpired = c.isPlanExpired;
    final daysLeft = (c.daysUntilExpiry ?? 0) + 1;

    final bgColor = isExpired ? Colors.red.shade50 : Colors.orange.shade50;
    final fgColor = isExpired ? Colors.red.shade800 : Colors.orange.shade900;
    final icon = isExpired ? Icons.error_outline : Icons.warning_amber_rounded;
    final message = isExpired
        ? 'Your ${c.plan == 'professional' ? 'Professional' : 'Enterprise'} plan has expired. Renew now to keep premium features.'
        : 'Your plan expires in $daysLeft day${daysLeft == 1 ? '' : 's'}. Renew to avoid losing premium features.';

    return Material(
      color: bgColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(icon, color: fgColor, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 13,
                  color: fgColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 12),
            TextButton(
              onPressed: () => context.go('/$slug/settings'),
              style: TextButton.styleFrom(
                foregroundColor: fgColor,
                backgroundColor: fgColor.withOpacity(0.1),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Renew',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}
