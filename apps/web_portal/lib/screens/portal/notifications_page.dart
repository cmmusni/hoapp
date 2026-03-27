import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:core_data/core_data.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationItem {
  final String id;
  final String type; // 'payment', 'ticket', 'violation', 'feedback', 'booking'
  final String title;
  final String subtitle;
  final String status;
  final DateTime createdAt;
  final String route;
  final IconData icon;
  final Color color;

  _NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.createdAt,
    required this.route,
    required this.icon,
    required this.color,
  });
}

class _NotificationsPageState extends State<NotificationsPage> {
  static const _brand = Color(0xff215e3f);

  List<_NotificationItem> _items = [];
  bool _loading = true;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final appState = context.read<AppState>();
      final communityId = appState.activeCommunityId;
      if (communityId == null) return;

      final slug = appState.activeCommunity?.slug ?? '';
      final client = Supabase.instance.client;
      final items = <_NotificationItem>[];

      final results = await Future.wait([
        client
            .from('payments')
            .select('id, amount, status, created_at, invoice_id, invoices!inner(invoice_number)')
            .eq('community_id', communityId)
            .eq('status', 'submitted')
            .order('created_at', ascending: false)
            .limit(50),
        client
            .from('tickets')
            .select('id, subject, status, created_at')
            .eq('community_id', communityId)
            .eq('status', 'open')
            .order('created_at', ascending: false)
            .limit(50),
        client
            .from('violations')
            .select('id, title, status, created_at')
            .eq('community_id', communityId)
            .neq('status', 'resolved')
            .order('created_at', ascending: false)
            .limit(50),
        client
            .from('feedback')
            .select('id, title, status, created_at')
            .eq('community_id', communityId)
            .eq('status', 'open')
            .order('created_at', ascending: false)
            .limit(50),
        client
            .from('amenity_bookings')
            .select('id, status, created_at, amenities!inner(name)')
            .eq('community_id', communityId)
            .eq('status', 'pending')
            .order('created_at', ascending: false)
            .limit(50),
      ]);

      // Payments
      for (final row in results[0] as List) {
        final invoiceNum = row['invoices']?['invoice_number'] ?? '';
        items.add(_NotificationItem(
          id: row['id'].toString(),
          type: 'payment',
          title: 'Payment Submitted',
          subtitle: 'Invoice $invoiceNum — ₱${row['amount']}',
          status: row['status'] ?? '',
          createdAt: DateTime.tryParse(row['created_at'] ?? '') ?? DateTime.now(),
          route: '/$slug/billing',
          icon: Icons.payment,
          color: Colors.orange,
        ));
      }

      // Tickets
      for (final row in results[1] as List) {
        items.add(_NotificationItem(
          id: row['id'].toString(),
          type: 'ticket',
          title: 'Open Ticket',
          subtitle: row['subject'] ?? 'No subject',
          status: row['status'] ?? '',
          createdAt: DateTime.tryParse(row['created_at'] ?? '') ?? DateTime.now(),
          route: '/$slug/tickets',
          icon: Icons.support,
          color: Colors.blue,
        ));
      }

      // Violations
      for (final row in results[2] as List) {
        items.add(_NotificationItem(
          id: row['id'].toString(),
          type: 'violation',
          title: 'Violation',
          subtitle: row['title'] ?? 'No title',
          status: row['status'] ?? '',
          createdAt: DateTime.tryParse(row['created_at'] ?? '') ?? DateTime.now(),
          route: '/$slug/violations',
          icon: Icons.report,
          color: Colors.red,
        ));
      }

      // Feedback
      for (final row in results[3] as List) {
        items.add(_NotificationItem(
          id: row['id'].toString(),
          type: 'feedback',
          title: 'Open Feedback',
          subtitle: row['title'] ?? 'No title',
          status: row['status'] ?? '',
          createdAt: DateTime.tryParse(row['created_at'] ?? '') ?? DateTime.now(),
          route: '/$slug/feedback',
          icon: Icons.feedback,
          color: Colors.purple,
        ));
      }

      // Bookings
      for (final row in results[4] as List) {
        final amenityName = row['amenities']?['name'] ?? 'Amenity';
        items.add(_NotificationItem(
          id: row['id'].toString(),
          type: 'booking',
          title: 'Pending Booking',
          subtitle: amenityName,
          status: row['status'] ?? '',
          createdAt: DateTime.tryParse(row['created_at'] ?? '') ?? DateTime.now(),
          route: '/$slug/amenities',
          icon: Icons.pool,
          color: Colors.teal,
        ));
      }

      // Sort by most recent first
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading notifications: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<_NotificationItem> get _filtered {
    if (_filter == 'all') return _items;
    return _items.where((i) => i.type == _filter).toList();
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'payment':
        return 'Payments';
      case 'ticket':
        return 'Tickets';
      case 'violation':
        return 'Violations';
      case 'feedback':
        return 'Feedback';
      case 'booking':
        return 'Bookings';
      default:
        return type;
    }
  }

  String _timeAgo(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d, y').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final types = ['all', 'payment', 'ticket', 'violation', 'feedback', 'booking'];
    final filtered = _filtered;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.notifications, size: 28, color: _brand),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Notifications',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
                onPressed: _load,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Action items requiring your attention',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
          const SizedBox(height: 16),

          // Filter chips
          Wrap(
            spacing: 8,
            children: types.map((t) {
              final isActive = _filter == t;
              final count = t == 'all'
                  ? _items.length
                  : _items.where((i) => i.type == t).length;
              return FilterChip(
                label: Text(
                  '${t == 'all' ? 'All' : _typeLabel(t)} ($count)',
                  style: TextStyle(
                    color: isActive ? Colors.white : Colors.grey.shade700,
                    fontSize: 13,
                  ),
                ),
                selected: isActive,
                selectedColor: _brand,
                backgroundColor: Colors.grey.shade100,
                checkmarkColor: Colors.white,
                onSelected: (_) => setState(() => _filter = t),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Content
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.notifications_none,
                                size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text(
                              'No notifications',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'All caught up!',
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          return _buildNotificationTile(item);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationTile(_NotificationItem item) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () => context.go(item.route),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: item.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.icon, size: 20, color: item.color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _timeAgo(item.createdAt),
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: item.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      item.status,
                      style: TextStyle(
                        color: item.color,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
