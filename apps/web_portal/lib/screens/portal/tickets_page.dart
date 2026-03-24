import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:core_data/core_data.dart';
import 'package:core_domain/core_domain.dart';
import 'package:core_ui/core_ui.dart';

class TicketsPage extends StatefulWidget {
  const TicketsPage({super.key});

  @override
  State<TicketsPage> createState() => _TicketsPageState();
}

class _TicketsPageState extends State<TicketsPage> {
  Future<List<Ticket>>? _ticketsFuture;
  Ticket? _selectedTicket;

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  void _loadTickets() {
    final appState = context.read<AppState>();
    final repo = context.read<TicketRepository>();

    if (appState.activeCommunityId != null) {
      setState(() {
        _ticketsFuture = repo.getTickets(appState.activeCommunityId!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 800;

        if (isWide) {
          return Row(
            children: [
              SizedBox(
                width: 350,
                child: _TicketList(
                  ticketsFuture: _ticketsFuture,
                  selectedTicket: _selectedTicket,
                  onTicketSelected: (ticket) {
                    setState(() => _selectedTicket = ticket);
                  },
                  onRefresh: _loadTickets,
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: _selectedTicket != null
                    ? _TicketDetail(ticket: _selectedTicket!)
                    : const Center(
                        child: Text('Select a ticket to view conversation'),
                      ),
              ),
            ],
          );
        }

        // Mobile/narrow layout
        if (_selectedTicket != null) {
          return _TicketDetail(
            ticket: _selectedTicket!,
            onBack: () => setState(() => _selectedTicket = null),
          );
        }

        return _TicketList(
          ticketsFuture: _ticketsFuture,
          selectedTicket: _selectedTicket,
          onTicketSelected: (ticket) {
            setState(() => _selectedTicket = ticket);
          },
          onRefresh: _loadTickets,
        );
      },
    );
  }
}

class _TicketList extends StatelessWidget {
  final Future<List<Ticket>>? ticketsFuture;
  final Ticket? selectedTicket;
  final Function(Ticket) onTicketSelected;
  final VoidCallback onRefresh;

  const _TicketList({
    required this.ticketsFuture,
    required this.selectedTicket,
    required this.onTicketSelected,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tickets'),
        elevation: 0,
      ),
      body: FutureBuilder<List<Ticket>>(
        future: ticketsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingIndicator(message: 'Loading tickets...');
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final tickets = snapshot.data ?? [];

          if (tickets.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.support_outlined,
                      size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text('No tickets yet'),
                  const SizedBox(height: 8),
                  const Text('Create your first ticket'),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: tickets.length,
            itemBuilder: (context, index) {
              final ticket = tickets[index];
              final isSelected = selectedTicket?.id == ticket.id;

              return ListTile(
                selected: isSelected,
                leading: CircleAvatar(
                  child: Icon(_getTypeIcon(ticket.type)),
                ),
                title: Text(_getTypeLabel(ticket.type)),
                subtitle: Text(
                  _formatDate(ticket.createdAt),
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: _StatusBadge(status: ticket.status),
                onTap: () => onTicketSelected(ticket),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  IconData _getTypeIcon(TicketType type) {
    switch (type) {
      case TicketType.billing:
        return Icons.payment;
      case TicketType.repair:
        return Icons.build;
      case TicketType.general:
        return Icons.help;
    }
  }

  String _getTypeLabel(TicketType type) {
    switch (type) {
      case TicketType.billing:
        return 'Billing Question';
      case TicketType.repair:
        return 'Repair Request';
      case TicketType.general:
        return 'General Inquiry';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  void _showCreateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _CreateTicketDialog(onCreate: onRefresh),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final TicketStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = status == TicketStatus.open
        ? Color.fromRGBO(39, 99, 67, 1)
        : Colors.grey;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.name.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

class _TicketDetail extends StatefulWidget {
  final Ticket ticket;
  final VoidCallback? onBack;

  const _TicketDetail({required this.ticket, this.onBack});

  @override
  State<_TicketDetail> createState() => _TicketDetailState();
}

class _TicketDetailState extends State<_TicketDetail> {
  final _messageController = TextEditingController();
  Future<List<Message>>? _messagesFuture;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void didUpdateWidget(_TicketDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ticket.id != widget.ticket.id) {
      _loadMessages();
    }
  }

  void _loadMessages() {
    final repo = context.read<TicketRepository>();
    setState(() {
      _messagesFuture = repo.getMessages(widget.ticket.id);
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.read<AuthRepository>().currentUser?.id ?? '';

    return Scaffold(
      appBar: AppBar(
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              )
            : null,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ticket #${widget.ticket.id.substring(0, 8)}',
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              widget.ticket.type.name,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          if (widget.ticket.status == TicketStatus.open)
            TextButton.icon(
              onPressed: () => _closeTicket(context),
              icon: const Icon(Icons.check_circle),
              label: const Text('Close'),
            ),
        ],
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: FutureBuilder<List<Message>>(
              future: _messagesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingIndicator();
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return const Center(
                    child:
                        Text('No messages yet\nStart the conversation below'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderUserId == currentUserId;

                    return Align(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        constraints: const BoxConstraints(maxWidth: 500),
                        decoration: BoxDecoration(
                          color: isMe
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Theme.of(context).colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(message.body),
                            const SizedBox(height: 4),
                            Text(
                              _formatTime(message.createdAt),
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Message input
          if (widget.ticket.status == TicketStatus.open)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: null,
                      enabled: !_isSending,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _isSending ? null : _sendMessage,
                    icon: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${time.month}/${time.day} ${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    setState(() => _isSending = true);

    try {
      final repo = context.read<TicketRepository>();
      await repo.sendMessage(
        ticketId: widget.ticket.id,
        body: _messageController.text.trim(),
      );

      _messageController.clear();
      _loadMessages();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _closeTicket(BuildContext context) async {
    try {
      final repo = context.read<TicketRepository>();
      await repo.updateTicketStatus(widget.ticket.id, TicketStatus.closed);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ticket closed')),
        );
        // Reload ticket list would happen here
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}

class _CreateTicketDialog extends StatefulWidget {
  final VoidCallback onCreate;

  const _CreateTicketDialog({required this.onCreate});

  @override
  State<_CreateTicketDialog> createState() => _CreateTicketDialogState();
}

class _CreateTicketDialogState extends State<_CreateTicketDialog> {
  TicketType _selectedType = TicketType.general;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.confirmation_number_outlined,
              color: Color(0xFF2E7D32), size: 24),
          const SizedBox(width: 12),
          const Text('Create New Ticket',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('What do you need help with?'),
          const SizedBox(height: 16),
          RadioListTile<TicketType>(
            value: TicketType.billing,
            groupValue: _selectedType,
            onChanged: (value) => setState(() => _selectedType = value!),
            title: const Text('Billing Question'),
          ),
          RadioListTile<TicketType>(
            value: TicketType.repair,
            groupValue: _selectedType,
            onChanged: (value) => setState(() => _selectedType = value!),
            title: const Text('Repair Request'),
          ),
          RadioListTile<TicketType>(
            value: TicketType.general,
            groupValue: _selectedType,
            onChanged: (value) => setState(() => _selectedType = value!),
            title: const Text('General Inquiry'),
          ),
        ],
      ),
      actions: [
        HOAppButton(
          label: 'Create',
          onPressed: _handleCreate,
          isLoading: _isLoading,
        ),
      ],
    );
  }

  Future<void> _handleCreate() async {
    setState(() => _isLoading = true);

    try {
      final appState = context.read<AppState>();
      final repo = context.read<TicketRepository>();

      await repo.createTicket(
        communityId: appState.activeCommunityId!,
        type: _selectedType,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ticket created')),
        );
        widget.onCreate();
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
