import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:core_data/core_data.dart';
import 'package:core_domain/core_domain.dart';
import '../household/household_screen.dart';
import '../pool_access/pool_access_screen.dart';
import '../billing/billing_screen.dart';
import '../tickets/ticket_chat_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const _AnnouncementsTab(),
    const _ViolationsTab(),
    const _TicketsTab(),
    const _AmenitiesTab(),
    const _ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: Text(appState.activeCommunity?.name ?? 'HOApp'),
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.announcement_outlined),
            selectedIcon: Icon(Icons.announcement),
            label: 'Announcements',
          ),
          NavigationDestination(
            icon: Icon(Icons.report_outlined),
            selectedIcon: Icon(Icons.report),
            label: 'Violations',
          ),
          NavigationDestination(
            icon: Icon(Icons.support_outlined),
            selectedIcon: Icon(Icons.support),
            label: 'Tickets',
          ),
          NavigationDestination(
            icon: Icon(Icons.pool_outlined),
            selectedIcon: Icon(Icons.pool),
            label: 'Amenities',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _AnnouncementsTab extends StatefulWidget {
  const _AnnouncementsTab();

  @override
  State<_AnnouncementsTab> createState() => _AnnouncementsTabState();
}

class _AnnouncementsTabState extends State<_AnnouncementsTab> {
  List<dynamic> _announcements = [];
  bool _isLoading = true;
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _loadAnnouncements();
    _subscribeToAnnouncements();
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadAnnouncements() async {
    final appState = context.read<AppState>();
    if (appState.activeCommunityId == null) return;

    try {
      final repo = context.read<AnnouncementRepository>();
      final announcements = await repo.getAnnouncements(appState.activeCommunityId!);
      
      if (mounted) {
        setState(() {
          _announcements = announcements;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load announcements: ${e.toString()}')),
        );
      }
    }
  }

  void _subscribeToAnnouncements() {
    final appState = context.read<AppState>();
    if (appState.activeCommunityId == null) return;

    final repo = context.read<AnnouncementRepository>();
    _realtimeChannel = repo.subscribeToAnnouncements(
      appState.activeCommunityId!,
      (newAnnouncement) {
        if (mounted) {
          setState(() {
            _announcements.insert(0, newAnnouncement);
          });
          
          // Show a subtle notification
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('New announcement: ${newAnnouncement.title}'),
              duration: const Duration(seconds: 2),
              backgroundColor: Colors.blue,
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_announcements.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.announcement_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No announcements yet'),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => _loadAnnouncements(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _announcements.length,
        itemBuilder: (context, index) {
          final announcement = _announcements[index];
          return _AnnouncementCard(
            announcement: announcement,
                onTap: () => _showAnnouncementDetails(announcement),
              );
            },
          ),
        );
      },
    );
  }

  void _showAnnouncementDetails(dynamic announcement) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(24),
                children: [
                  if (announcement.isPinned)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.push_pin, size: 16, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'PINNED',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    announcement.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatDate(announcement.publishAt ?? announcement.createdAt),
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    announcement.body,
                    style: const TextStyle(fontSize: 16, height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final localDate = date.toLocal();
    final now = DateTime.now();
    final diff = now.difference(localDate);

    if (diff.inMinutes <= 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    
    return '${localDate.month}/${localDate.day}/${localDate.year}';
  }
}

class _AnnouncementCard extends StatelessWidget {
  final dynamic announcement;
  final VoidCallback onTap;

  const _AnnouncementCard({
    required this.announcement,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (announcement.isPinned)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Icon(
                    Icons.push_pin,
                    size: 16,
                    color: Colors.orange[700],
                  ),
                ),
              Text(
                announcement.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                announcement.body,
                style: TextStyle(color: Colors.grey[700]),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                _formatDate(announcement.publishAt ?? announcement.createdAt),
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final localDate = date.toLocal();
    final now = DateTime.now();
    final diff = now.difference(localDate);

    if (diff.inMinutes <= 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    
    return '${localDate.month}/${localDate.day}/${localDate.year}';
  }
}

class _ViolationsTab extends StatefulWidget {
  const _ViolationsTab();

  @override
  State<_ViolationsTab> createState() => _ViolationsTabState();
}

class _ViolationsTabState extends State<_ViolationsTab> {
  Future<List<dynamic>>? _violationsFuture;

  @override
  void initState() {
    super.initState();
    _loadViolations();
  }

  void _loadViolations() {
    final appState = context.read<AppState>();
    if (appState.activeCommunityId != null) {
      final repo = context.read<ViolationRepository>();
      setState(() {
        _violationsFuture = repo.getViolations(appState.activeCommunityId!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<dynamic>>(
        future: _violationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadViolations,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final violations = snapshot.data ?? [];

          if (violations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_outline, size: 64, color: Color.fromRGBO(39, 99, 67, 1)),
                  const SizedBox(height: 16),
                  const Text('No active violations'),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _showReportDialog(),
                    icon: const Icon(Icons.report),
                    label: const Text('Report a Violation'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _loadViolations(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: violations.length,
              itemBuilder: (context, index) {
                final violation = violations[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getStatusColor(violation.status),
                      child: Icon(
                        _getStatusIcon(violation.status),
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    title: Text(violation.title),
                    subtitle: Text(
                      _formatDate(violation.createdAt),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    trailing: Chip(
                      label: Text(
                        _getStatusLabel(violation.status),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      backgroundColor: _getStatusColor(violation.status).withOpacity(0.2),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showReportDialog(),
        icon: const Icon(Icons.report),
        label: const Text('Report'),
      ),
    );
  }

  void _showReportDialog() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _ReportViolationScreen(onReported: _loadViolations),
        fullscreenDialog: true,
      ),
    );
  }

  String _formatDate(DateTime date) {
    final localDate = date.toLocal();
    return '${localDate.month}/${localDate.day}/${localDate.year}';
  }

  Color _getStatusColor(dynamic status) {
    final statusStr = status.toString();
    if (statusStr.contains('new')) return Colors.orange;
    if (statusStr.contains('under')) return Colors.blue;
    if (statusStr.contains('resolved')) return Color.fromRGBO(39, 99, 67, 1);
    return Colors.grey;
  }

  IconData _getStatusIcon(dynamic status) {
    final statusStr = status.toString();
    if (statusStr.contains('new')) return Icons.fiber_new;
    if (statusStr.contains('under')) return Icons.pending;
    if (statusStr.contains('resolved')) return Icons.check_circle;
    return Icons.report;
  }

  String _getStatusLabel(dynamic status) {
    final statusStr = status.toString();
    if (statusStr.contains('new')) return 'NEW';
    if (statusStr.contains('under')) return 'UNDER REVIEW';
    if (statusStr.contains('resolved')) return 'RESOLVED';
    return 'UNKNOWN';
  }
}

class _ReportViolationScreen extends StatefulWidget {
  final VoidCallback onReported;

  const _ReportViolationScreen({required this.onReported});

  @override
  State<_ReportViolationScreen> createState() => _ReportViolationScreenState();
}

class _ReportViolationScreenState extends State<_ReportViolationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Violation'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber),
              ),
              child: Row(
                children: [
                  Icon(Icons.privacy_tip, color: Colors.amber[700]),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Your identity will remain anonymous to other residents',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'Brief description',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a title';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _bodyController,
              decoration: const InputDecoration(
                labelText: 'Details',
                hintText: 'Provide detailed information',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 6,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please provide details';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _handleSubmit,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit Report'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final appState = context.read<AppState>();
      final repo = context.read<ViolationRepository>();

      await repo.createViolation(
        communityId: appState.activeCommunityId!,
        title: _titleController.text.trim(),
        body: _bodyController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Violation reported successfully')),
        );
        widget.onReported();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

class _TicketsTab extends StatefulWidget {
  const _TicketsTab();

  @override
  State<_TicketsTab> createState() => _TicketsTabState();
}

class _TicketsTabState extends State<_TicketsTab> {
  Future<List<dynamic>>? _ticketsFuture;

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  void _loadTickets() {
    final appState = context.read<AppState>();
    if (appState.activeCommunityId != null) {
      final repo = context.read<TicketRepository>();
      setState(() {
        _ticketsFuture = repo.getMyTickets(appState.activeCommunityId!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<dynamic>>(
        future: _ticketsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadTickets,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final tickets = snapshot.data ?? [];

          if (tickets.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.support_agent, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No support tickets'),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Create ticket feature coming soon')),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Create Ticket'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _loadTickets(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: tickets.length,
              itemBuilder: (context, index) {
                final ticket = tickets[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => TicketChatScreen(ticket: ticket),
                        ),
                      );
                    },
                    leading: CircleAvatar(
                      backgroundColor: _getStatusColor(ticket.status),
                      child: Icon(
                        _getStatusIcon(ticket.status),
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    title: Text(ticket.subject),
                    subtitle: Text(
                      _formatDate(ticket.createdAt),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    trailing: Chip(
                      label: Text(
                        _getStatusLabel(ticket.status),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      backgroundColor: _getStatusColor(ticket.status).withOpacity(0.2),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Create ticket feature coming soon')),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('New Ticket'),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final localDate = date.toLocal();
    return '${localDate.month}/${localDate.day}/${localDate.year}';
  }

  Color _getStatusColor(dynamic status) {
    final statusStr = status.toString();
    if (statusStr.contains('open')) return Colors.orange;
    if (statusStr.contains('assigned')) return Colors.blue;
    if (statusStr.contains('resolved')) return Color.fromRGBO(39, 99, 67, 1);
    if (statusStr.contains('closed')) return Colors.grey;
    return Colors.grey;
  }

  IconData _getStatusIcon(dynamic status) {
    final statusStr = status.toString();
    if (statusStr.contains('open')) return Icons.fiber_new;
    if (statusStr.contains('assigned')) return Icons.pending;
    if (statusStr.contains('resolved')) return Icons.check_circle;
    if (statusStr.contains('closed')) return Icons.archive;
    return Icons.support;
  }

  String _getStatusLabel(dynamic status) {
    final statusStr = status.toString();
    if (statusStr.contains('open')) return 'OPEN';
    if (statusStr.contains('assigned')) return 'ASSIGNED';
    if (statusStr.contains('resolved')) return 'RESOLVED';
    if (statusStr.contains('closed')) return 'CLOSED';
    return 'UNKNOWN';
  }
}

class _AmenitiesTab extends StatefulWidget {
  const _AmenitiesTab();

  @override
  State<_AmenitiesTab> createState() => _AmenitiesTabState();
}

class _AmenitiesTabState extends State<_AmenitiesTab> {
  Future<List<dynamic>>? _amenitiesFuture;

  @override
  void initState() {
    super.initState();
    _loadAmenities();
  }

  void _loadAmenities() {
    final appState = context.read<AppState>();
    if (appState.activeCommunityId != null) {
      final repo = context.read<AmenityRepository>();
      setState(() {
        _amenitiesFuture = repo.getAmenities(appState.activeCommunityId!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _amenitiesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadAmenities,
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final amenities = snapshot.data ?? [];

        if (amenities.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.pool_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No amenities available'),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => _loadAmenities(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: amenities.length,
            itemBuilder: (context, index) {
              final amenity = amenities[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Icon(_getAmenityIcon(amenity.amenityType)),
                  ),
                  title: Text(amenity.name),
                  subtitle: amenity.description != null
                      ? Text(
                          amenity.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        )
                      : null,
                  trailing: amenity.requiresBooking
                      ? ElevatedButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Booking feature coming soon')),
                            );
                          },
                          child: const Text('Book'),
                        )
                      : null,
                ),
              );
            },
          ),
        );
      },
    );
  }

  IconData _getAmenityIcon(dynamic type) {
    final typeStr = type.toString().toLowerCase();
    if (typeStr.contains('pool')) return Icons.pool;
    if (typeStr.contains('gym')) return Icons.fitness_center;
    if (typeStr.contains('hall')) return Icons.event;
    if (typeStr.contains('court')) return Icons.sports_tennis;
    return Icons.place;
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        ListTile(
          leading: const Icon(Icons.family_restroom),
          title: const Text('My Household'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const HouseholdScreen(),
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.accessibility),
          title: const Text('Pool Access'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const PoolAccessScreen(),
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.payment),
          title: const Text('Billing & Payments'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const BillingScreen(),
              ),
            );
          },
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Logout'),
          onTap: () async {
            await context.read<AuthRepository>().signOut();
            if (context.mounted) {
              Navigator.of(context).pushReplacementNamed('/login');
            }
          },
        ),
      ],
    );
  }
}
