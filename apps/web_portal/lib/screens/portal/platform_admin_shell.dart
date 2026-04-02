import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:core_data/core_data.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'beta_requests_page.dart';
import 'plan_pricing_page.dart';

/// Platform admin shell — outside the community portal context.
/// Accessible only to users with the app_admin platform role.
class PlatformAdminShell extends StatefulWidget {
  const PlatformAdminShell({super.key});

  @override
  State<PlatformAdminShell> createState() => _PlatformAdminShellState();
}

class _PlatformAdminShellState extends State<PlatformAdminShell> {
  bool _loading = true;
  bool _isAllowed = false;
  int _pendingBetaRequests = 0;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    final repo = context.read<CommunityRepository>();
    final allowed = await repo.isPlatformAdmin();
    if (mounted) {
      setState(() {
        _isAllowed = allowed;
        _loading = false;
      });
      if (allowed) _loadBadgeCount();
    }
  }

  Future<void> _loadBadgeCount() async {
    try {
      final sb = Supabase.instance.client;
      final res = await sb
          .from('beta_access_requests')
          .select('id')
          .eq('status', 'pending')
          .count(CountOption.exact);
      if (mounted) {
        setState(() {
          _pendingBetaRequests = res.count ?? 0;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isAllowed) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          title: const Text('Access Denied'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'Platform Admin Access Required',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'You do not have permission to access this area.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go('/'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Back to Home'),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 800;

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            title: Row(
              children: [
                Image.asset(
                  'assets/images/hoapp-logo-white.png',
                  height: 28,
                  errorBuilder: (_, __, ___) => const SizedBox(height: 28),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Platform Admin',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
                ),
              ],
            ),
            actions: [
              TextButton.icon(
                onPressed: () => context.go('/'),
                icon:
                    const Icon(Icons.arrow_back, size: 18, color: Colors.white),
                label: const Text('Back to Portal',
                    style: TextStyle(color: Colors.white)),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: isWide
              ? Row(
                  children: [
                    _buildSidebar(context),
                    const VerticalDivider(width: 1),
                    Expanded(
                        child: _selectedTab == 0
                            ? const BetaRequestsPage()
                            : const PlanPricingPage()),
                  ],
                )
              : _selectedTab == 0
                  ? const BetaRequestsPage()
                  : const PlanPricingPage(),
          drawer: isWide ? null : _buildDrawer(context),
        );
      },
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Container(
      width: 240,
      color: const Color(0xFF1A3C2A),
      child: Column(
        children: [
          const SizedBox(height: 16),
          _sidebarItem(
            context,
            icon: Icons.science_outlined,
            label: 'Beta Requests',
            selected: _selectedTab == 0,
            badge: _pendingBetaRequests,
            onTap: () => setState(() => _selectedTab = 0),
          ),
          _sidebarItem(
            context,
            icon: Icons.payments_outlined,
            label: 'Plan Pricing',
            selected: _selectedTab == 1,
            onTap: () => setState(() => _selectedTab = 1),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Platform-wide management',
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: ListView(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.admin_panel_settings, color: Colors.white, size: 32),
                SizedBox(height: 8),
                Text('Platform Admin',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text('Manage platform-wide features',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
          ListTile(
            leading: Icon(Icons.science_outlined,
                color: Theme.of(context).colorScheme.primary),
            title: const Text('Beta Requests',
                style: TextStyle(fontWeight: FontWeight.w600)),
            trailing: _pendingBetaRequests > 0
                ? Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _pendingBetaRequests > 99
                          ? '99+'
                          : '$_pendingBetaRequests',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                : null,
            tileColor: _selectedTab == 0
                ? Theme.of(context).colorScheme.primary.withOpacity(0.08)
                : null,
            onTap: () {
              Navigator.pop(context);
              setState(() => _selectedTab = 0);
            },
          ),
          ListTile(
            leading: Icon(Icons.payments_outlined,
                color: Theme.of(context).colorScheme.primary),
            title: const Text('Plan Pricing',
                style: TextStyle(fontWeight: FontWeight.w600)),
            tileColor: _selectedTab == 1
                ? Theme.of(context).colorScheme.primary.withOpacity(0.08)
                : null,
            onTap: () {
              Navigator.pop(context);
              setState(() => _selectedTab = 1);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.arrow_back, color: Colors.grey),
            title: const Text('Back to Portal'),
            onTap: () => context.go('/'),
          ),
        ],
      ),
    );
  }

  Widget _sidebarItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    bool selected = false,
    int badge = 0,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: selected ? Colors.white.withOpacity(0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        dense: true,
        onTap: onTap,
        leading: Icon(icon,
            color: selected ? Colors.white : Colors.white.withOpacity(0.6),
            size: 20),
        title: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white.withOpacity(0.7),
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 14,
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
      ),
    );
  }
}
