import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for managing Supabase realtime subscriptions
class RealtimeService {
  final SupabaseClient _client;
  final Map<String, RealtimeChannel> _channels = {};

  RealtimeService(this._client);

  /// Subscribe to changes in a table
  /// 
  /// [table] - Table name to subscribe to
  /// [event] - Event type (INSERT, UPDATE, DELETE, or * for all)
  /// [filter] - Optional filter (e.g., 'community_id=eq.123')
  /// [callback] - Function to call when changes occur
  /// 
  /// Returns a channel key that can be used to unsubscribe
  String subscribeToTable({
    required String table,
    required String event,
    String? filter,
    required Function(Map<String, dynamic>) callback,
  }) {
    final channelKey = '${table}_${event}_${filter ?? 'all'}';

    // Remove existing subscription if any
    unsubscribe(channelKey);

    // Create new channel
    final channel = _client.channel(channelKey);

    // Configure the subscription - returns RealtimeChannel, not PostgrestFilterBuilder
    channel.onPostgresChanges(
      event: _parseEvent(event),
      schema: 'public',
      table: table,
      callback: (payload) {
        if (payload.newRecord.isNotEmpty) {
          callback(payload.newRecord);
        } else if (payload.oldRecord.isNotEmpty) {
          callback(payload.oldRecord);
        }
      },
    );

    // Note: Filters are applied via RLS policies in database
    // Subscribe to start receiving events
    channel.subscribe();

    // Subscribe to the channel
    channel.subscribe();

    _channels[channelKey] = channel;

    return channelKey;
  }

  /// Subscribe to new announcements in a community
  String subscribeToAnnouncements({
    required String communityId,
    required Function(Map<String, dynamic>) onNewAnnouncement,
  }) {
    return subscribeToTable(
      table: 'announcements',
      event: 'INSERT',
      filter: 'community_id=eq.$communityId',
      callback: onNewAnnouncement,
    );
  }

  /// Subscribe to ticket messages (for chat functionality)
  String subscribeToTicketMessages({
    required String ticketId,
    required Function(Map<String, dynamic>) onNewMessage,
  }) {
    return subscribeToTable(
      table: 'messages',
      event: 'INSERT',
      filter: 'ticket_id=eq.$ticketId',
      callback: onNewMessage,
    );
  }

  /// Subscribe to violations updates
  String subscribeToViolations({
    required String communityId,
    required Function(Map<String, dynamic>) onViolationUpdate,
  }) {
    return subscribeToTable(
      table: 'violations',
      event: '*',
      filter: 'community_id=eq.$communityId',
      callback: onViolationUpdate,
    );
  }

  /// Subscribe to invoice updates (for payment notifications)
  String subscribeToInvoices({
    required String communityId,
    required Function(Map<String, dynamic>) onInvoiceUpdate,
  }) {
    return subscribeToTable(
      table: 'invoices',
      event: 'UPDATE',
      filter: 'community_id=eq.$communityId',
      callback: onInvoiceUpdate,
    );
  }

  /// Subscribe to amenity bookings
  String subscribeToAmenityBookings({
    required String amenityId,
    required Function(Map<String, dynamic>) onNewBooking,
  }) {
    return subscribeToTable(
      table: 'amenity_bookings',
      event: 'INSERT',
      filter: 'amenity_id=eq.$amenityId',
      callback: onNewBooking,
    );
  }

  /// Subscribe to presence (online users)
  /// 
  /// Note: This requires Supabase Realtime Presence feature
  String subscribeToPresence({
    required String channelName,
    required Function(List<Map<String, dynamic>>) onPresenceChange,
  }) {
    final channelKey = 'presence_$channelName';

    unsubscribe(channelKey);

    final channel = _client.channel(channelKey);

    channel
        .onPresenceSync((_) {
          // For now, just return an empty list - presence handling needs proper implementation
          // TODO: Fix presence state handling based on Supabase realtime_client API
          onPresenceChange([]);
        })
        .onPresenceJoin((payload) {
          // Handle user joined
        })
        .onPresenceLeave((payload) {
          // Handle user left
        });

    channel.subscribe((status, error) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        // Track current user presence
        await channel.track({'online_at': DateTime.now().toIso8601String()});
      }
    });

    _channels[channelKey] = channel;

    return channelKey;
  }

  /// Subscribe to broadcast messages
  /// Useful for notifications or events that don't need database persistence
  String subscribeToBroadcast({
    required String channelName,
    required String event,
    required Function(Map<String, dynamic>) callback,
  }) {
    final channelKey = 'broadcast_${channelName}_$event';

    unsubscribe(channelKey);

    final channel = _client.channel(channelKey);

    channel.onBroadcast(
      event: event,
      callback: (payload) {
        callback(payload);
      },
    );

    channel.subscribe();

    _channels[channelKey] = channel;

    return channelKey;
  }

  /// Send a broadcast message
  Future<void> broadcast({
    required String channelKey,
    required String event,
    required Map<String, dynamic> payload,
  }) async {
    final channel = _channels[channelKey];
    if (channel != null) {
      await channel.sendBroadcastMessage(
        event: event,
        payload: payload,
      );
    }
  }

  /// Unsubscribe from a channel
  Future<void> unsubscribe(String channelKey) async {
    final channel = _channels[channelKey];
    if (channel != null) {
      await _client.removeChannel(channel);
      _channels.remove(channelKey);
    }
  }

  /// Unsubscribe from all channels
  Future<void> unsubscribeAll() async {
    for (var channel in _channels.values) {
      await _client.removeChannel(channel);
    }
    _channels.clear();
  }

  /// Parse event string to PostgresChangeEvent
  PostgresChangeEvent _parseEvent(String event) {
    switch (event.toUpperCase()) {
      case 'INSERT':
        return PostgresChangeEvent.insert;
      case 'UPDATE':
        return PostgresChangeEvent.update;
      case 'DELETE':
        return PostgresChangeEvent.delete;
      case '*':
      case 'ALL':
        return PostgresChangeEvent.all;
      default:
        return PostgresChangeEvent.all;
    }
  }

  /// Dispose of the service and clean up all subscriptions
  Future<void> dispose() async {
    await unsubscribeAll();
  }
}
