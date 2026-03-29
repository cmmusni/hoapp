import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:core_data/core_data.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

const _brand = Color(0xff215e3f);

/// Shared notifications screen — works on both web and mobile.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
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
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (communityId == null || userId == null) return;

      final client = Supabase.instance.client;
      final results = await Future.wait([
        client
            .from('announcements')
            .select('id, title, created_at')
            .eq('community_id', communityId)
            .order('created_at', ascending: false)
            .limit(20),
        client
            .from('violations')
            .select('id, title, status, created_at')
            .eq('community_id', communityId)
            .eq('reporter_user_id', userId)
            .order('created_at', ascending: false)
            .limit(10),
        client
            .from('tickets')
            .select('id, type, status, created_at')
            .eq('community_id', communityId)
            .eq('created_by', userId)
            .order('created_at', ascending: false)
            .limit(10),
        client
            .from('payments')
            .select('id, amount, status, created_at')
            .eq('community_id', communityId)
            .eq('user_id', userId)
            .order('created_at', ascending: false)
            .limit(10),
        client
            .from('amenity_bookings')
            .select('id, status, created_at')
            .eq('community_id', communityId)
            .eq('user_id', userId)
            .order('created_at', ascending: false)
            .limit(10),
        client
            .from('feedback')
            .select('id, subject, status, created_at')
            .eq('community_id', communityId)
            .eq('user_id', userId)
            .order('created_at', ascending: false)
            .limit(10),
      ]);

      final items = <_NotificationItem>[];

      for (final a in results[0] as List) {
        items.add(_NotificationItem(
          id: a['id'],
          type: 'announcement',
          title: a['title'] ?? 'Announcement',
          subtitle: 'New community announcement',
          createdAt: DateTime.parse(a['created_at']),
          icon: Icons.campaign,
          color: Colors.blue,
        ));
      }
      for (final v in results[1] as List) {
        items.add(_NotificationItem(
          id: v['id'],
          type: 'violation',
          title: 'Violation: ${v['title'] ?? 'N/A'}',
          subtitle: 'Status: ${v['status']}',
          createdAt: DateTime.parse(v['created_at']),
          icon: Icons.report,
          color: Colors.red,
        ));
      }
      for (final t in results[2] as List) {
        items.add(_NotificationItem(
          id: t['id'],
          type: 'ticket',
          title: 'Ticket: ${t['type']}',
          subtitle: 'Status: ${t['status']}',
          createdAt: DateTime.parse(t['created_at']),
          icon: Icons.support,
          color: Colors.orange,
        ));
      }
      for (final p in results[3] as List) {
        items.add(_NotificationItem(
          id: p['id'],
          type: 'payment',
          title: 'Payment: ₱${p['amount']}',
          subtitle: 'Status: ${p['status']}',
          createdAt: DateTime.parse(p['created_at']),
          icon: Icons.payment,
          color: _brand,
        ));
      }
      for (final b in results[4] as List) {
        items.add(_NotificationItem(
          id: b['id'],
          type: 'booking',
          title: 'Booking',
          subtitle: 'Status: ${b['status']}',
          createdAt: DateTime.parse(b['created_at']),
          icon: Icons.event,
          color: Colors.purple,
        ));
      }
      for (final f in results[5] as List) {
        items.add(_NotificationItem(
          id: f['id'],
          type: 'feedback',
          title: f['subject'] ?? 'Feedback',
          subtitle: 'Status: ${f['status']}',
          createdAt: DateTime.parse(f['created_at']),
          icon: Icons.feedback,
          color: Colors.teal,
        ));
      }

      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<_NotificationItem> get _filtered {
    if (_filter == 'all') return _items;
    return _items.where((i) => i.type == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              _chip('All', 'all'),
              _chip('Announcements', 'announcement'),
              _chip('Violations', 'violation'),
              _chip('Tickets', 'ticket'),
              _chip('Payments', 'payment'),
              _chip('Bookings', 'booking'),
              _chip('Feedback', 'feedback'),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _filtered.isEmpty
                        ? ListView(children: [
                            const SizedBox(height: 120),
                            const Center(
                                child: Text('No notifications',
                                    style: TextStyle(color: Colors.grey))),
                          ])
                        : ListView.builder(
                            itemCount: _filtered.length,
                            itemBuilder: (_, i) =>
                                _NotificationTile(item: _filtered[i]),
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, String value) {
    final isSelected = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: _brand.withValues(alpha: 0.15),
        checkmarkColor: _brand,
        onSelected: (_) => setState(() => _filter = value),
      ),
    );
  }
}

class _NotificationItem {
  final String id;
  final String type;
  final String title;
  final String subtitle;
  final DateTime createdAt;
  final IconData icon;
  final Color color;

  _NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.createdAt,
    required this.icon,
    required this.color,
  });
}

class _NotificationTile extends StatelessWidget {
  final _NotificationItem item;
  const _NotificationTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: item.color.withValues(alpha: 0.1),
        child: Icon(item.icon, color: item.color, size: 20),
      ),
      title: Text(item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(item.subtitle,
          style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      trailing: Text(
        _timeAgo(item.createdAt),
        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(dt);
  }
}
