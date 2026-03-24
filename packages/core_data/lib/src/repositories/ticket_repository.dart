import 'package:flutter/foundation.dart';
import 'package:core_domain/core_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

    return (response as List)
        .map((item) => Ticket.fromJson(item))
        .toList();
  }

  /// Get tickets for a community (user sees their own + staff sees all)
  /// Supports search and pagination
  Future<List<Ticket>> getTickets(
    String communityId, {
    String? searchQuery,
    int? limit,
    int? offset,
  }) async {
    var query = _client
        .from('tickets')
        .select()
        .eq('community_id', communityId);

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

    return (response as List)
        .map((item) => Ticket.fromJson(item))
        .toList();
  }

  /// Get total count of tickets for pagination
  Future<int> getTicketsCount(
    String communityId, {
    String? searchQuery,
  }) async {
    var query = _client
        .from('tickets')
        .select('id')
        .eq('community_id', communityId);

    if (searchQuery != null && searchQuery.isNotEmpty) {
      query = query.ilike('type', '%$searchQuery%');
    }

    final response = await query;
    return (response as List).length;
  }

  /// Get single ticket with validation
  Future<Ticket?> getTicket(String id) async {
    final response = await _client
        .from('tickets')
        .select()
        .eq('id', id)
        .maybeSingle();

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

    final response = await _client.from('tickets').insert({
      'community_id': communityId,
      'type': type.name,
      'status': 'open',
      'created_by': userId,
      if (unitId != null) 'unit_id': unitId,
    }).select().single();

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

    return (response as List)
        .map((item) => Message.fromJson(item))
        .toList();
  }

  /// Send a message to a ticket
  Future<String> sendMessage({
    required String ticketId,
    required String body,
    List<String>? attachmentUrls,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    final response = await _client.from('messages').insert({
      'ticket_id': ticketId,
      'sender_user_id': userId,
      'body': body,
      'attachments': attachmentUrls ?? [],
    }).select().single();

    return response['id'] as String;
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
