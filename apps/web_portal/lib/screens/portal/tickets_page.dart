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
                    ? _TicketDetail(
                        ticket: _selectedTicket!,
                        onStatusChanged: () {
                          final appState = context.read<AppState>();
                          final repo = context.read<TicketRepository>();
                          setState(() {
                            _selectedTicket = null;
                            if (appState.activeCommunityId != null) {
                              _ticketsFuture =
                                  repo.getTickets(appState.activeCommunityId!);
                            }
                          });
                        },
                      )
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
            onStatusChanged: () {
              final appState = context.read<AppState>();
              final repo = context.read<TicketRepository>();
              setState(() {
                _selectedTicket = null;
                if (appState.activeCommunityId != null) {
                  _ticketsFuture = repo.getTickets(appState.activeCommunityId!);
                }
              });
            },
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('New Ticket'),
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
  final VoidCallback? onStatusChanged;

  const _TicketDetail({
    required this.ticket,
    this.onBack,
    this.onStatusChanged,
  });

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
    final appState = context.watch<AppState>();
    final isStaff = appState.isStaff;

    return Scaffold(
      appBar: AppBar(
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              )
            : null,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'TKT-${widget.ticket.id.hashCode.abs() % 10000}',
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              widget.ticket.type.name.toUpperCase(),
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          if (widget.ticket.status == TicketStatus.open)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: OutlinedButton.icon(
                onPressed: () => _closeTicket(context),
                icon: const Icon(Icons.check_circle, size: 18),
                label: const Text('Close Ticket'),
                style: OutlinedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 255, 255, 255),
                  side: const BorderSide(color: Color(0xFF2E5C3F)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ),
          if (isStaff)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ElevatedButton.icon(
                onPressed: () => _deleteTicket(context),
                icon: const Icon(Icons.delete, size: 16, color: Colors.white),
                label: const Text('Delete Ticket'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[500],
                  foregroundColor: Colors.white,
                ),
              ),
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
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Color(0xff215e3f), width: 1.5),
                        ),
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
        widget.onStatusChanged?.call();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _deleteTicket(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
            SizedBox(width: 12),
            Text('Delete Ticket',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        content: const Text(
            'Are you sure you want to delete this ticket? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final repo = context.read<TicketRepository>();
        await repo.deleteTicket(widget.ticket.id);

        if (context.mounted) {
          context.read<AppState>().requestBadgeRefresh();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ticket deleted')),
          );
          widget.onStatusChanged?.call();
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
      titlePadding: EdgeInsets.zero,
      title: Container(
        decoration: const BoxDecoration(
          color: Color(0xff215e3f),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
        child: Row(
          children: [
            const Icon(Icons.confirmation_number_outlined,
                color: Colors.white, size: 24),
            const SizedBox(width: 12),
            const Text('Create New Ticket',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                )),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white70),
              onPressed: () => Navigator.of(context).pop(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'What do you need help with?',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            _buildTicketTypeOption(
              type: TicketType.billing,
              icon: Icons.payment_outlined,
              label: 'Billing Question',
              description: 'Payment issues, invoices, or fees',
            ),
            const SizedBox(height: 8),
            _buildTicketTypeOption(
              type: TicketType.repair,
              icon: Icons.build_outlined,
              label: 'Repair Request',
              description: 'Maintenance or facility repairs',
            ),
            const SizedBox(height: 8),
            _buildTicketTypeOption(
              type: TicketType.general,
              icon: Icons.help_outline,
              label: 'General Inquiry',
              description: 'Questions, feedback, or other concerns',
            ),
          ],
        ),
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _handleCreate,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.confirmation_num_outlined),
            label: const Text('Create Ticket',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff215e3f),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTicketTypeOption({
    required TicketType type,
    required IconData icon,
    required String label,
    required String description,
  }) {
    final isSelected = _selectedType == type;
    final primaryColor = const Color(0xff215e3f);

    return InkWell(
      onTap: () => setState(() => _selectedType = type),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected ? primaryColor.withOpacity(0.05) : Colors.white,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected
                    ? primaryColor.withOpacity(0.1)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 20,
                color: isSelected ? primaryColor : Colors.grey[500],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: isSelected ? primaryColor : Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: primaryColor, size: 22),
          ],
        ),
      ),
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
