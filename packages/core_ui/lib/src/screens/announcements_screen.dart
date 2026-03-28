import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:core_data/core_data.dart';
import 'package:core_domain/core_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../adaptive/adaptive_layout.dart';

const _brand = Color(0xff215e3f);

/// Shared announcements screen that works on both web and mobile.
class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  Future<List<Announcement>>? _announcementsFuture;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _loadAnnouncements();
    _markAnnouncementsRead();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _markAnnouncementsRead() async {
    final appState = context.read<AppState>();
    final communityId = appState.activeCommunityId;
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (communityId == null || userId == null) return;

    try {
      await client.from('announcement_reads').upsert({
        'user_id': userId,
        'community_id': communityId,
        'last_read_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,community_id');
    } catch (_) {}
  }

  void _subscribeRealtime() {
    final appState = context.read<AppState>();
    final communityId = appState.activeCommunityId;
    if (communityId == null) return;

    _channel = Supabase.instance.client
        .channel('announcements_$communityId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'announcements',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'community_id',
            value: communityId,
          ),
          callback: (_) => _loadAnnouncements(),
        )
        .subscribe();
  }

  void _loadAnnouncements() {
    final appState = context.read<AppState>();
    final repo = context.read<AnnouncementRepository>();
    if (appState.activeCommunityId != null) {
      setState(() {
        _announcementsFuture =
            repo.getAnnouncements(appState.activeCommunityId!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isStaff = appState.isStaff;

    return FutureBuilder<List<Announcement>>(
      future: _announcementsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final announcements = snapshot.data ?? [];

        return Scaffold(
          body: RefreshIndicator(
            onRefresh: () async => _loadAnnouncements(),
            child: announcements.isEmpty
                ? ListView(children: [
                    const SizedBox(height: 120),
                    Center(
                      child: Column(children: [
                        Icon(Icons.campaign_outlined,
                            size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        const Text('No announcements yet',
                            style: TextStyle(fontSize: 18)),
                      ]),
                    ),
                  ])
                : AdaptiveBuilder(
                    mobile: (_) => _MobileList(announcements: announcements),
                    desktop: (_) => _DesktopGrid(announcements: announcements),
                  ),
          ),
          floatingActionButton: isStaff
              ? FloatingActionButton.extended(
                  onPressed: () => _showCreateSheet(context),
                  icon: const Icon(Icons.add),
                  label: const Text('New Announcement'),
                  backgroundColor: _brand,
                  foregroundColor: Colors.white,
                )
              : null,
        );
      },
    );
  }

  void _showCreateSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _CreateAnnouncementSheet(onCreated: _loadAnnouncements),
      ),
    );
  }
}

class _MobileList extends StatelessWidget {
  final List<Announcement> announcements;
  const _MobileList({required this.announcements});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: announcements.length,
      itemBuilder: (context, index) =>
          _AnnouncementCard(announcement: announcements[index]),
    );
  }
}

class _DesktopGrid extends StatelessWidget {
  final List<Announcement> announcements;
  const _DesktopGrid({required this.announcements});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 500,
        childAspectRatio: 1.6,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
      ),
      itemCount: announcements.length,
      itemBuilder: (context, index) =>
          _AnnouncementCard(announcement: announcements[index]),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  final Announcement announcement;
  const _AnnouncementCard({required this.announcement});

  @override
  Widget build(BuildContext context) {
    final isPinned = announcement.pinned;
    final dateStr = DateFormat('MMM d, yyyy').format(announcement.createdAt);

    return Card(
      elevation: isPinned ? 3 : 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showDetails(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (isPinned)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Icon(Icons.push_pin,
                          size: 16, color: Colors.orange.shade700),
                    ),
                  Expanded(
                    child: Text(
                      announcement.title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Text(
                  announcement.body,
                  style: TextStyle(color: Colors.grey.shade600, height: 1.4),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 8),
              Text(dateStr,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    final dateStr = DateFormat('MMMM d, yyyy').format(announcement.createdAt);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(announcement.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(dateStr,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
              const SizedBox(height: 16),
              Text(announcement.body, style: const TextStyle(height: 1.6)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _CreateAnnouncementSheet extends StatefulWidget {
  final VoidCallback onCreated;
  const _CreateAnnouncementSheet({required this.onCreated});

  @override
  State<_CreateAnnouncementSheet> createState() =>
      _CreateAnnouncementSheetState();
}

class _CreateAnnouncementSheetState extends State<_CreateAnnouncementSheet> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  bool _pinned = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('New Announcement',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                  labelText: 'Title',
                  prefixIcon: const Icon(Icons.title, size: 20),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _brand, width: 1.5),
                  )),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bodyCtrl,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: 'Body',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _brand, width: 1.5),
                ),
                alignLabelWithHint: true,
              ),
            ),
            SwitchListTile(
              title: const Text('Pin announcement'),
              value: _pinned,
              onChanged: (v) => setState(() => _pinned = v),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _handleCreate,
                icon: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.campaign_outlined),
                label: const Text('Post Announcement',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: _brand,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleCreate() async {
    if (_titleCtrl.text.trim().isEmpty || _bodyCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and body are required')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final appState = context.read<AppState>();
      final repo = context.read<AnnouncementRepository>();
      await repo.createAnnouncement(
        communityId: appState.activeCommunityId!,
        title: _titleCtrl.text.trim(),
        body: _bodyCtrl.text.trim(),
        pinned: _pinned,
      );
      if (mounted) {
        Navigator.of(context).pop();
        widget.onCreated();
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
