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

const _brand = Color(0xff215e3f);

/// Navigation item for the drawer menu.
class _NavItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget Function() pageBuilder;
  final bool staffOnly;
  final bool adminOnly;
  final bool guardOnly;
  final bool maintenanceOnly;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.pageBuilder,
    this.staffOnly = false,
    this.adminOnly = false,
    this.guardOnly = false,
    this.maintenanceOnly = false,
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
        guardOnly: true,
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
        staffOnly: true,
      ),
      _NavItem(
        label: 'Settings',
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings,
        pageBuilder: () => const shared.SettingsScreen(),
        adminOnly: true,
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
    final isGuard = appState.isGuard;
    final isMaintenance = appState.isMaintenance;

    return _buildNavItems().where((item) {
      if (item.adminOnly && !isAdmin) return false;
      if (item.staffOnly && !isStaff) return false;
      if (item.guardOnly && !isGuard) return false;
      if (item.maintenanceOnly && !isMaintenance) return false;
      return true;
    }).toList();
  }

  Future<void> _loadBadgeCounts() async {
    try {
      final appState = context.read<AppState>();
      final communityId = appState.activeCommunityId;
      if (communityId == null || !appState.isStaff) return;

      final client = Supabase.instance.client;
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

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final visibleItems = _getVisibleItems(appState);

    // Clamp selected index
    if (_selectedIndex >= visibleItems.length) {
      _selectedIndex = 0;
    }

    final currentItem = visibleItems[_selectedIndex];
    final totalBadge = _pendingPayments +
        _openTickets +
        _pendingViolations +
        _openFeedback +
        _pendingBookings;

    return Scaffold(
      appBar: AppBar(
        title: Text(currentItem.label),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: totalBadge > 0
                  ? Badge(
                      label: Text('$totalBadge'),
                      child: const Icon(Icons.notifications_outlined),
                    )
                  : const Icon(Icons.notifications_outlined),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      appBar: AppBar(
                        title: const Text('Notifications'),
                        backgroundColor: _brand,
                        foregroundColor: Colors.white,
                      ),
                      body: shared.NotificationsScreen(
                        onNavigate: (section) {
                          Navigator.of(context).pop();
                          _navigateToSection(section);
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      drawer: _buildDrawer(context, appState, visibleItems),
      body: currentItem.pageBuilder(),
    );
  }

  Widget _buildDrawer(
      BuildContext context, AppState appState, List<_NavItem> visibleItems) {
    return Drawer(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.only(top: 48, bottom: 16),
            child: Center(
              child: appState.activeCommunity?.logoUrl != null
                  ? Image.network(
                      appState.activeCommunity!.logoUrl!,
                      height: 140,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Image.asset(
                        'assets/images/hoapp-logo-with-bg.png',
                        height: 140,
                        fit: BoxFit.contain,
                      ),
                    )
                  : Image.asset(
                      'assets/images/hoapp-logo-with-bg.png',
                      height: 140,
                      fit: BoxFit.contain,
                    ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Supabase.instance.client.auth.currentUser?.email ?? '',
                    style: const TextStyle(fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _brand.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getRoleLabel(appState),
                      style: TextStyle(
                        color: _brand,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    appState.activeCommunity?.name ?? 'HOApp',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: visibleItems.length,
              itemBuilder: (context, index) {
                final item = visibleItems[index];
                final isSelected = index == _selectedIndex;
                final badge = _getBadgeForItem(item.label);

                // Add section dividers
                Widget? divider;
                if (item.staffOnly &&
                    index > 0 &&
                    !visibleItems[index - 1].staffOnly &&
                    !visibleItems[index - 1].adminOnly) {
                  divider = const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(
                      children: [
                        Expanded(child: Divider()),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text('STAFF',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w600)),
                        ),
                        Expanded(child: Divider()),
                      ],
                    ),
                  );
                } else if (item.adminOnly &&
                    index > 0 &&
                    !visibleItems[index - 1].adminOnly) {
                  divider = const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(
                      children: [
                        Expanded(child: Divider()),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text('ADMIN',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w600)),
                        ),
                        Expanded(child: Divider()),
                      ],
                    ),
                  );
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (divider != null) divider,
                    ListTile(
                      leading: Icon(
                        isSelected ? item.selectedIcon : item.icon,
                        color: isSelected ? _brand : null,
                      ),
                      title: Text(
                        item.label,
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: isSelected ? _brand : null,
                        ),
                      ),
                      trailing: badge > 0
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$badge',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12),
                              ),
                            )
                          : null,
                      selected: isSelected,
                      selectedTileColor: _brand.withOpacity(0.08),
                      onTap: () {
                        setState(() => _selectedIndex = index);
                        Navigator.of(context).pop(); // close drawer
                        _loadBadgeCounts(); // refresh counts on nav
                      },
                    ),
                  ],
                );
              },
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Sign Out', style: TextStyle(color: Colors.red)),
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
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
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

  int _getBadgeForItem(String label) {
    switch (label) {
      case 'Billing':
        return _pendingPayments;
      case 'Tickets':
        return _openTickets;
      case 'Violations':
        return _pendingViolations;
      case 'Feedback':
        return _openFeedback;
      case 'Amenities':
        return _pendingBookings;
      default:
        return 0;
    }
  }

  void _navigateToSection(String section) {
    final appState = context.read<AppState>();
    final visibleItems = _getVisibleItems(appState);
    final index = visibleItems.indexWhere((item) => item.label == section);
    if (index >= 0) {
      setState(() => _selectedIndex = index);
    }
  }
}
