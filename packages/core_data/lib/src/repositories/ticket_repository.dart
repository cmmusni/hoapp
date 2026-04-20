import 'package:flutter/foundation.dart';
import 'package:core_domain/core_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/notification_service.dart';
import '../supabase_client.dart';

class TicketRepository {
  final SupabaseClient _client = SupabaseClientManager.instance;

  /// Get user's own tickets
  Future<List<Ticket>> getMyTickets(String communityId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _client
        .from('tickets')
        .select()
        .eq('community_id', communityId)
        .eq('created_by', userId)
        .order('created_at', ascending: false);

    return (response as List).map((item) => Ticket.fromJson(item)).toList();
  }

  /// Get tickets for a community (user sees their own + staff sees all)
  /// Supports search and pagination
  Future<List<Ticket>> getTickets(
    String communityId, {
    String? searchQuery,
    int? limit,
    int? offset,
  }) async {
    var query =
        _client.from('tickets').select().eq('community_id', communityId);

    // Add search filter if provided (search by ticket type)
    if (searchQuery != null && searchQuery.isNotEmpty) {
      query = query.ilike('type', '%$searchQuery%');
    }

    // Build the final query with ordering and pagination
    var finalQuery = query.order('created_at', ascending: false);

    if (limit != null && offset != null) {
      finalQuery = finalQuery.limit(limit).range(offset, offset + limit - 1);
    } else if (limit != null) {
      finalQuery = finalQuery.limit(limit);
    }

    final response = await finalQuery;

    return (response as List).map((item) => Ticket.fromJson(item)).toList();
  }

  /// Get total count of tickets for pagination
  Future<int> getTicketsCount(
    String communityId, {
    String? searchQuery,
  }) async {
    var query =
        _client.from('tickets').select('id').eq('community_id', communityId);

    if (searchQuery != null && searchQuery.isNotEmpty) {
      query = query.ilike('type', '%$searchQuery%');
    }

    final response = await query;
    return (response as List).length;
  }

  /// Get single ticket with validation
  Future<Ticket?> getTicket(String id) async {
    final response =
        await _client.from('tickets').select().eq('id', id).maybeSingle();

    if (response == null) return null;
    return Ticket.fromJson(response);
  }

  /// Create a new ticket
  Future<String> createTicket({
    required String communityId,
    required TicketType type,
    String? unitId,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    final response = await _client
        .from('tickets')
        .insert({
          'community_id': communityId,
          'type': type.name,
          'status': 'open',
          'created_by': userId,
          if (unitId != null) 'unit_id': unitId,
        })
        .select()
        .single();

    // Push notification to community staff.
    NotificationService().send(
      communityId: communityId,
      heading: 'New ${type.name} ticket',
      content: 'A resident opened a new ${type.name} ticket.',
      targetRoles: const ['community_admin', 'hoa_officer'],
      data: {'type': 'ticket', 'ticket_id': response['id']},
    );

    return response['id'] as String;
  }

  /// Update ticket status
  Future<void> updateTicketStatus(String id, TicketStatus status) async {
    await _client.from('tickets').update({
      'status': status.name,
    }).eq('id', id);
  }

  /// Get messages for a ticket
  Future<List<Message>> getMessages(String ticketId) async {
    final response = await _client
        .from('messages')
        .select()
        .eq('ticket_id', ticketId)
        .order('created_at', ascending: true);

    return (response as List).map((item) => Message.fromJson(item)).toList();
  }

  /// Send a message to a ticket
  Future<String> sendMessage({
    required String ticketId,
    required String body,
    List<String>? attachmentUrls,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    final response = await _client
        .from('messages')
        .insert({
          'ticket_id': ticketId,
          'sender_user_id': userId,
          'body': body,
          'attachments': attachmentUrls ?? [],
        })
        .select()
        .single();

    // Push notification to the other party (resident <-> staff).
    _notifyTicketReply(ticketId: ticketId, senderId: userId, body: body);

    return response['id'] as String;
  }

  /// Fire-and-forget notification for ticket replies. Sends to the ticket
  /// owner if a staff member replied, otherwise broadcasts to staff.
  void _notifyTicketReply({
    required String ticketId,
    required String senderId,
    required String body,
  }) {
    Future(() async {
      try {
        final ticket = await _client
            .from('tickets')
            .select('community_id, created_by, type')
            .eq('id', ticketId)
            .maybeSingle();
        if (ticket == null) return;

        final communityId = ticket['community_id'] as String;
        final createdBy = ticket['created_by'] as String?;
        final type = ticket['type'] as String? ?? 'ticket';
        final preview = body.length > 80 ? '${body.substring(0, 80)}…' : body;

        if (createdBy != null && senderId == createdBy) {
          // Resident replied — notify staff.
          NotificationService().send(
            communityId: communityId,
            heading: 'New reply on $type ticket',
            content: preview,
            targetRoles: const ['community_admin', 'hoa_officer'],
            data: {'type': 'ticket', 'ticket_id': ticketId},
          );
        } else if (createdBy != null) {
          // Staff replied — notify the ticket owner.
          NotificationService().send(
            communityId: communityId,
            heading: 'Reply on your $type ticket',
            content: preview,
            targetUserIds: [createdBy],
            data: {'type': 'ticket', 'ticket_id': ticketId},
          );
        }
      } catch (e) {
        debugPrint('Ticket reply notification failed: $e');
      }
    });
  }

  /// Subscribe to realtime messages for a ticket
  RealtimeChannel subscribeToMessages(
    String ticketId,
    void Function(Message message) onMessage,
  ) {
    return _client
        .channel('ticket_messages_$ticketId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'ticket_id',
            value: ticketId,
          ),
          callback: (payload) {
            try {
              final message = Message.fromJson(payload.newRecord);
              onMessage(message);
            } catch (e) {
              debugPrint('Error parsing realtime message: $e');
            }
          },
        )
        .subscribe();
  }

  /// Delete ticket (staff only)
  Future<void> deleteTicket(String id) async {
    await _client.from('tickets').delete().eq('id', id);
  }
}
