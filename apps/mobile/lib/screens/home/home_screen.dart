import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:core_data/core_data.dart';
import 'package:core_domain/core_domain.dart';
import 'package:core_ui/core_ui.dart' as shared;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../household/household_screen.dart';
import '../pool_access/pool_access_screen.dart';
import '../billing/billing_screen.dart';
import '../amenities/amenities_screen.dart';
import '../expenses/expense_income_chart_screen.dart';
import '../registered_swimmers/registered_swimmers_screen.dart';
import '../qr_scanner/qr_scanner_screen.dart';
import 'tabs/announcements_tab.dart';
import 'tabs/violations_tab.dart';
import 'tabs/tickets_tab.dart';

/// Navigation item for the drawer menu.
class _NavItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget Function() pageBuilder;
  final bool staffOnly;
  final bool adminOnly;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.pageBuilder,
    this.staffOnly = false,
    this.adminOnly = false,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  int _pendingPayments = 0;
  int _openTickets = 0;
  int _pendingViolations = 0;
  int _openFeedback = 0;
  int _pendingBookings = 0;
  int _unpaidInvoices = 0;

  @override
  void initState() {
    super.initState();
    _loadBadgeCounts();
  }

  List<_NavItem> _buildNavItems() {
    return [
      _NavItem(
        label: 'Announcements',
        icon: Icons.announcement_outlined,
        selectedIcon: Icons.announcement,
        pageBuilder: () => const AnnouncementsTab(),
      ),
      if (context.read<AppState>().isResident) ...[
        _NavItem(
          label: 'My Household',
          icon: Icons.family_restroom_outlined,
          selectedIcon: Icons.family_restroom,
          pageBuilder: () => const HouseholdScreen(),
        ),
      ],
      _NavItem(
        label: 'Billing & Payments',
        icon: Icons.payment_outlined,
        selectedIcon: Icons.payment,
        pageBuilder: () => const BillingScreen(),
      ),
      _NavItem(
        label: 'Tickets',
        icon: Icons.support_outlined,
        selectedIcon: Icons.support,
        pageBuilder: () => const TicketsTab(),
      ),
      _NavItem(
        label: 'Violations',
        icon: Icons.report_outlined,
        selectedIcon: Icons.report,
        pageBuilder: () => const ViolationsTab(),
      ),
      _NavItem(
        label: 'Amenities',
        icon: Icons.pool_outlined,
        selectedIcon: Icons.pool,
        pageBuilder: () => const AmenitiesScreen(),
      ),
      _NavItem(
        label: 'Pool Access',
        icon: Icons.accessibility_outlined,
        selectedIcon: Icons.accessibility,
        pageBuilder: () => const PoolAccessScreen(),
      ),
      _NavItem(
        label: 'Registered Swimmers',
        icon: Icons.pool_outlined,
        selectedIcon: Icons.pool,
        pageBuilder: () => const RegisteredSwimmersScreen(),
      ),
      _NavItem(
        label: 'Security Pass',
        icon: Icons.qr_code_2_outlined,
        selectedIcon: Icons.qr_code_2,
        pageBuilder: () => const shared.SecurityPassScreen(),
      ),
      _NavItem(
        label: 'QR Scanner',
        icon: Icons.qr_code_scanner_outlined,
        selectedIcon: Icons.qr_code_scanner,
        pageBuilder: () => const QrScannerScreen(),
        staffOnly: true,
      ),
      _NavItem(
        label: 'Community Expenses',
        icon: Icons.account_balance_wallet_outlined,
        selectedIcon: Icons.account_balance_wallet,
        pageBuilder: () => const shared.ExpensesScreen(),
      ),
      _NavItem(
        label: 'Financial Reports',
        icon: Icons.bar_chart_outlined,
        selectedIcon: Icons.bar_chart,
        pageBuilder: () => const ExpenseIncomeChartScreen(),
      ),
      // Admin-only items
      _NavItem(
        label: 'Households',
        icon: Icons.family_restroom_outlined,
        selectedIcon: Icons.family_restroom,
        pageBuilder: () => const HouseholdScreen(),
        staffOnly: true,
      ),
      _NavItem(
        label: 'Manage Users',
        icon: Icons.people_outline,
        selectedIcon: Icons.people,
        pageBuilder: () => const shared.ManageUsersScreen(),
        adminOnly: true,
      ),
      _NavItem(
        label: 'Settings',
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings,
        pageBuilder: () => const shared.SettingsScreen(),
        adminOnly: true,
      ),
      _NavItem(
        label: 'Notifications',
        icon: Icons.notifications_outlined,
        selectedIcon: Icons.notifications,
        pageBuilder: () =>
            shared.NotificationsScreen(onNavigate: _navigateToSection),
      ),
      _NavItem(
        label: 'Feedback',
        icon: Icons.feedback_outlined,
        selectedIcon: Icons.feedback,
        pageBuilder: () => const shared.FeedbackScreen(),
      ),
    ];
  }

  List<_NavItem> _getVisibleItems(AppState appState) {
    final isStaff = appState.isStaff;
    final isAdmin = appState.isAdmin;

    return _buildNavItems().where((item) {
      if (item.label == 'Notifications') return false; // handled by AppBar bell
      if (item.adminOnly && !isAdmin) return false;
      if (item.staffOnly && !isStaff) return false;
      return true;
    }).toList();
  }

  Future<void> _loadBadgeCounts() async {
    try {
      final appState = context.read<AppState>();
      final communityId = appState.activeCommunityId;
      if (communityId == null) return;

      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;

      // Unpaid invoices for the current user's units (all roles)
      int invoiceCount = 0;
      if (userId != null) {
        final householdRows = await client
            .from('household_members')
            .select('unit_id')
            .eq('user_id', userId);
        final unitIds = (householdRows as List)
            .map((e) => e['unit_id'] as String)
            .toSet()
            .toList();
        if (unitIds.isNotEmpty) {
          final invoiceResult = await client
              .from('invoices')
              .select('id')
              .eq('community_id', communityId)
              .eq('status', 'unpaid')
              .inFilter('unit_id', unitIds)
              .count(CountOption.exact);
          invoiceCount = invoiceResult.count;
        }
      }
      if (mounted) {
        setState(() => _unpaidInvoices = invoiceCount);
      }

      if (!appState.isStaff) return;
      final results = await Future.wait([
        client
            .from('payments')
            .select('id')
            .eq('community_id', communityId)
            .eq('status', 'submitted'),
        client
            .from('tickets')
            .select('id')
            .eq('community_id', communityId)
            .eq('status', 'open'),
        client
            .from('violations')
            .select('id')
            .eq('community_id', communityId)
            .neq('status', 'resolved'),
        client
            .from('feedback')
            .select('id')
            .eq('community_id', communityId)
            .eq('status', 'open'),
        client
            .from('amenity_bookings')
            .select('id')
            .eq('community_id', communityId)
            .eq('status', 'pending'),
      ]);

      if (mounted) {
        setState(() {
          _pendingPayments = (results[0] as List).length;
          _openTickets = (results[1] as List).length;
          _pendingViolations = (results[2] as List).length;
          _openFeedback = (results[3] as List).length;
          _pendingBookings = (results[4] as List).length;
        });
      }
    } catch (_) {}
  }

  /// Labels of the bottom nav items — used to map indices to the drawer items.
  static const _bottomNavLabels = [
    'Announcements',
    'My Household',
    'Billing & Payments', // placeholder — center FAB handles this
    'Security Pass',
    'Notifications',
  ];

  /// Resolve the currently displayed nav item.
  /// If _selectedIndex matches a bottom-nav label, use that; otherwise use
  /// the drawer-selected item stored in _drawerItemIndex.
  int? _drawerItemIndex;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final visibleItems = _getVisibleItems(appState);
    final primary = Theme.of(context).colorScheme.primary;

    // Clamp selected index
    if (_selectedIndex >= visibleItems.length) {
      _selectedIndex = 0;
    }

    // Determine which bottom nav tab is active (null if showing a drawer page)
    int? activeBottomTab;
    if (_drawerItemIndex == null) {
      final label = visibleItems[_selectedIndex].label;
      final idx = _bottomNavLabels.indexOf(label);
      activeBottomTab = idx >= 0 ? idx : null;
    }

    final currentItem = visibleItems[_selectedIndex];
    final totalBadge =
        _pendingPayments +
        _openTickets +
        _pendingViolations +
        _openFeedback +
        _pendingBookings +
        _unpaidInvoices;

    return Scaffold(
      appBar: AppBar(
        title: Text(currentItem.label),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Badge(
              isLabelVisible: totalBadge > 0,
              label: Text(
                '$totalBadge',
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: Colors.red.shade400,
              child: IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => shared.NotificationsScreen(
                        onNavigate: (section) {
                          Navigator.of(context).pop();
                          _navigateToSection(section);
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      drawer: _buildDrawer(context, appState, visibleItems),
      body: currentItem.pageBuilder(),
      bottomNavigationBar: _buildBottomNavBar(
        context,
        appState,
        visibleItems,
        activeBottomTab,
        primary,
      ),
      floatingActionButton: _buildCenterFab(
        context,
        appState,
        visibleItems,
        primary,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildBottomNavBar(
    BuildContext context,
    AppState appState,
    List<_NavItem> visibleItems,
    int? activeTab,
    Color primary,
  ) {
    Widget navIcon(
      IconData icon,
      IconData selectedIcon,
      String label,
      int tabIndex,
      int badge,
    ) {
      final isActive = activeTab == tabIndex;
      return InkWell(
        onTap: () => _selectBottomTab(tabIndex, visibleItems),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Badge(
                isLabelVisible: badge > 0,
                label: Text(
                  '$badge',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
            child: navIcon(
              Icons.campaign_outlined,
              Icons.campaign,
              'News',
              0,
              0,
            ),
          ),
          Expanded(
            child: navIcon(
              Icons.family_restroom_outlined,
              Icons.family_restroom,
              appState.isResident ? 'My Household' : 'Households',
              1,
              0,
            ),
          ),
          const SizedBox(width: 48), // space for FAB
          Expanded(
            child: navIcon(
              Icons.qr_code_2_outlined,
              Icons.qr_code_2,
              'Security',
              3,
              0,
            ),
          ),
          Expanded(
            child: navIcon(
              Icons.notifications_outlined,
              Icons.notifications,
              'Notifications',
              4,
              0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterFab(
    BuildContext context,
    AppState appState,
    List<_NavItem> visibleItems,
    Color primary,
  ) {
    final isBillingActive =
        visibleItems[_selectedIndex].label == 'Billing & Payments';

    return SizedBox(
      width: 64,
      height: 64,
      child: FloatingActionButton(
        elevation: isBillingActive ? 2 : 6,
        backgroundColor: primary,
        shape: const CircleBorder(),
        onPressed: () {
          final idx = visibleItems.indexWhere(
            (item) => item.label == 'Billing & Payments',
          );
          if (idx >= 0) {
            setState(() {
              _selectedIndex = idx;
              _drawerItemIndex = null;
            });
          }
        },
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
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Jumps to the drawer page matching [section]. Used by NotificationsScreen
  /// taps so a tap on a notification opens the relevant feature page.
  void _navigateToSection(String section) {
    final appState = context.read<AppState>();
    final visibleItems = _getVisibleItems(appState);
    final idx = visibleItems.indexWhere((item) => item.label == section);
    if (idx >= 0) {
      setState(() {
        _selectedIndex = idx;
        _drawerItemIndex = null;
      });
    }
  }

  void _selectBottomTab(int tabIndex, List<_NavItem> visibleItems) {
    final label = _bottomNavLabels[tabIndex];
    // Notifications is not in the drawer list — push it as a route instead.
    if (label == 'Notifications') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => shared.NotificationsScreen(
            onNavigate: (section) {
              Navigator.of(context).pop();
              _navigateToSection(section);
            },
          ),
        ),
      );
      return;
    }
    final idx = visibleItems.indexWhere((item) => item.label == label);
    if (idx >= 0) {
      setState(() {
        _selectedIndex = idx;
        _drawerItemIndex = null;
      });
    }
  }

  Widget _buildDrawer(
    BuildContext context,
    AppState appState,
    List<_NavItem> visibleItems,
  ) {
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';
    final roleLabel = _getRoleLabel(appState);
    final communityName = appState.activeCommunity?.name ?? 'HOApp';
    final primary = Theme.of(context).colorScheme.primary;

    return Drawer(
      child: Column(
        children: [
          // Profile header
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
                colors: [primary, primary.withValues(alpha: 0.85)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar + Notifications
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.6),
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.white,
                        child: appState.activeCommunity?.logoUrl != null
                            ? ClipOval(
                                child: Image.network(
                                  appState.activeCommunity!.logoUrl!,
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => Text(
                                    communityName.isNotEmpty
                                        ? communityName[0].toUpperCase()
                                        : 'H',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              )
                            : CircleAvatar(
                                radius: 28,
                                backgroundColor: Colors.white,
                                child: ClipOval(
                                  child: Image.asset(
                                    'assets/images/hoapp-icon.png',
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
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
          // Navigation items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              itemCount: visibleItems.length,
              itemBuilder: (context, index) {
                final item = visibleItems[index];
                final isSelected = index == _selectedIndex;

                // Section dividers
                Widget? divider;
                if (item.staffOnly &&
                    index > 0 &&
                    !visibleItems[index - 1].staffOnly &&
                    !visibleItems[index - 1].adminOnly) {
                  divider = _buildSectionLabel('STAFF');
                } else if (item.adminOnly &&
                    index > 0 &&
                    !visibleItems[index - 1].adminOnly) {
                  divider = _buildSectionLabel('ADMIN');
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (divider != null) divider,
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: isSelected
                            ? primary.withValues(alpha: 0.1)
                            : Colors.transparent,
                      ),
                      child: ListTile(
                        dense: true,
                        leading: Icon(
                          isSelected ? item.selectedIcon : item.icon,
                          color: isSelected ? primary : Colors.grey.shade600,
                          size: 22,
                        ),
                        title: Text(
                          item.label,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: isSelected ? primary : Colors.grey.shade800,
                            fontSize: 14,
                          ),
                        ),
                        trailing: null,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        onTap: () {
                          setState(() {
                            _selectedIndex = index;
                            _drawerItemIndex = null;
                          });
                          Navigator.of(context).pop();
                          _loadBadgeCounts();
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          // Sign out
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: ListTile(
                leading: Icon(
                  Icons.logout_rounded,
                  color: Colors.red.shade400,
                  size: 22,
                ),
                title: Text(
                  'Sign Out',
                  style: TextStyle(
                    color: Colors.red.shade400,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Sign Out?'),
                      content: const Text('Are you sure you want to sign out?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red.shade400,
                          ),
                          child: const Text('Sign Out'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true && context.mounted) {
                    await context.read<AuthRepository>().signOut();
                    if (context.mounted) {
                      Navigator.of(context).pushReplacementNamed('/login');
                    }
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.grey.shade300)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Expanded(child: Divider(color: Colors.grey.shade300)),
        ],
      ),
    );
  }

  String _getRoleLabel(AppState appState) {
    final role = appState.activeRole;
    if (role == null) return 'Member';
    if (role.isAdmin) return 'Admin';
    if (role.isStaff) return 'Staff';
    if (role.role == Role.guard) return 'Security Guard';
    if (role.role == Role.maintenance) return 'Maintenance';
    return 'Resident';
  }
}
