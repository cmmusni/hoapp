import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:core_data/core_data.dart';
import 'package:core_domain/core_domain.dart';
import '../../tickets/ticket_chat_screen.dart';

class TicketsTab extends StatefulWidget {
  const TicketsTab({super.key});

  @override
  State<TicketsTab> createState() => _TicketsTabState();
}

class _TicketsTabState extends State<TicketsTab> {
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
      final isStaff = appState.isStaff;
      setState(() {
        _ticketsFuture = isStaff
            ? repo.getTickets(appState.activeCommunityId!)
            : repo.getMyTickets(appState.activeCommunityId!);
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
                    onPressed: () => _showCreateTicketSheet(context),
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
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              TicketChatScreen(ticket: ticket),
                        ),
                      );
                      _loadTickets();
                    },
                    leading: CircleAvatar(
                      backgroundColor: _getStatusColor(ticket.status),
                      child: Icon(
                        _getStatusIcon(ticket.status),
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    title: Text('${ticket.type.name.toUpperCase()} Ticket'),
                    subtitle: Text(
                      _formatDate(ticket.createdAt),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    trailing: Chip(
                      label: Text(
                        _getStatusLabel(ticket.status),
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      backgroundColor:
                          _getStatusColor(ticket.status).withOpacity(0.2),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateTicketSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('New Ticket'),
      ),
    );
  }

  void _showCreateTicketSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: _CreateTicketSheet(onCreated: _loadTickets),
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
    if (statusStr.contains('resolved')) return const Color(0xff215e3f);
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

class _CreateTicketSheet extends StatefulWidget {
  final VoidCallback onCreated;
  const _CreateTicketSheet({required this.onCreated});

  @override
  State<_CreateTicketSheet> createState() => _CreateTicketSheetState();
}

class _CreateTicketSheetState extends State<_CreateTicketSheet> {
  final _subjectController = TextEditingController();
  final _bodyController = TextEditingController();
  TicketType _type = TicketType.general;
  bool _isLoading = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('New Support Ticket',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            DropdownButtonFormField<TicketType>(
              value: _type,
              decoration: const InputDecoration(
                labelText: 'Type',
                border: OutlineInputBorder(),
              ),
              items: TicketType.values
                  .map((t) => DropdownMenuItem(
                        value: t,
                        child:
                            Text(t.name[0].toUpperCase() + t.name.substring(1)),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _type = v);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bodyController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleCreate,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Submit Ticket'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleCreate() async {
    if (_bodyController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a description')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final appState = context.read<AppState>();
      final repo = context.read<TicketRepository>();
      await repo.createTicket(
        communityId: appState.activeCommunityId!,
        type: _type,
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
