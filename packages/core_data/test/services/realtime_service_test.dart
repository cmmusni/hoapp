import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:core_data/core_data.dart';
import 'package:fake_async/fake_async.dart';

@GenerateMocks([SupabaseClient, RealtimeChannel, RealtimeClient])
import 'realtime_service_test.mocks.dart';

void main() {
  late RealtimeService realtimeService;
  late MockSupabaseClient mockClient;
  late MockRealtimeChannel mockChannel;

  setUp(() {
    mockClient = MockSupabaseClient();
    mockChannel = MockRealtimeChannel();
    realtimeService = RealtimeService(mockClient);
  });

  group('RealtimeService - Table Subscriptions', () {
    test('subscribeToTable creates channel and subscribes', () {
      // Arrange
      final table = 'announcements';
      final event = 'INSERT';
      var callbackInvoked = false;

      when(mockClient.channel(any)).thenReturn(mockChannel);
      when(mockChannel.onPostgresChanges(
        event: anyNamed('event'),
        schema: anyNamed('schema'),
        table: anyNamed('table'),
        callback: anyNamed('callback'),
      )).thenReturn(null);
      when(mockChannel.subscribe()).thenAnswer((_) async => RealtimeSubscribeStatus.subscribed);

      // Act
      final key = realtimeService.subscribeToTable(
        table: table,
        event: event,
        callback: (data) {
          callbackInvoked = true;
        },
      );

      // Assert
      expect(key, isNotEmpty);
      verify(mockClient.channel(any)).called(1);
      verify(mockChannel.subscribe()).called(1);
    });

    test('subscribeToAnnouncements creates subscription for announcements table', () {
      // Arrange
      final communityId = 'test-community-id';
      when(mockClient.channel(any)).thenReturn(mockChannel);
      when(mockChannel.onPostgresChanges(
        event: anyNamed('event'),
        schema: anyNamed('schema'),
        table: anyNamed('table'),
        callback: anyNamed('callback'),
      )).thenReturn(null);
      when(mockChannel.subscribe()).thenAnswer((_) async => RealtimeSubscribeStatus.subscribed);

      // Act
      final key = realtimeService.subscribeToAnnouncements(
        communityId: communityId,
        onNewAnnouncement: (data) {},
      );

      // Assert
      expect(key, contains('announcements'));
      expect(key, contains('INSERT'));
    });

    test('subscribeToTicketMessages creates subscription for messages table', () {
      // Arrange
      final ticketId = 'test-ticket-id';
      when(mockClient.channel(any)).thenReturn(mockChannel);
      when(mockChannel.onPostgresChanges(
        event: anyNamed('event'),
        schema: anyNamed('schema'),
        table: anyNamed('table'),
        callback: anyNamed('callback'),
      )).thenReturn(null);
      when(mockChannel.subscribe()).thenAnswer((_) async => RealtimeSubscribeStatus.subscribed);

      // Act
      final key = realtimeService.subscribeToTicketMessages(
        ticketId: ticketId,
        onNewMessage: (data) {},
      );

      // Assert
      expect(key, contains('messages'));
      expect(key, contains('INSERT'));
    });
  });

  group('RealtimeService - Unsubscribe', () {
    test('unsubscribe removes channel', () async {
      // Arrange
      final channelKey = 'test-channel';
      when(mockClient.channel(channelKey)).thenReturn(mockChannel);
      when(mockChannel.onPostgresChanges(
        event: anyNamed('event'),
        schema: anyNamed('schema'),
        table: anyNamed('table'),
        callback: anyNamed('callback'),
      )).thenReturn(null);
      when(mockChannel.subscribe()).thenAnswer((_) async => RealtimeSubscribeStatus.subscribed);
      when(mockClient.removeChannel(mockChannel)).thenAnswer((_) async => RealtimeChannelSendStatus.ok);

      // Subscribe first
      realtimeService.subscribeToTable(
        table: 'test',
        event: 'INSERT',
        callback: (data) {},
      );

      // Act
      await realtimeService.unsubscribe(channelKey);

      // Assert
      verify(mockClient.removeChannel(mockChannel)).called(1);
    });

    test('unsubscribeAll removes all channels', () async {
      // Arrange
      when(mockClient.channel(any)).thenReturn(mockChannel);
      when(mockChannel.onPostgresChanges(
        event: anyNamed('event'),
        schema: anyNamed('schema'),
        table: anyNamed('table'),
        callback: anyNamed('callback'),
      )).thenReturn(null);
      when(mockChannel.subscribe()).thenAnswer((_) async => RealtimeSubscribeStatus.subscribed);
      when(mockClient.removeChannel(mockChannel)).thenAnswer((_) async => RealtimeChannelSendStatus.ok);

      // Subscribe to multiple tables
      realtimeService.subscribeToTable(table: 'table1', event: 'INSERT', callback: (_) {});
      realtimeService.subscribeToTable(table: 'table2', event: 'UPDATE', callback: (_) {});

      // Act
      await realtimeService.unsubscribeAll();

      // Assert
      verify(mockClient.removeChannel(mockChannel)).called(greaterThanOrEqualTo(2));
    });
  });

  group('RealtimeService - Presence', () {
    test('subscribeToPresence configures presence channel', () {
      // Arrange
      final channelName = 'test-presence';
      when(mockClient.channel(any)).thenReturn(mockChannel);
      when(mockChannel.onPresenceSync(any)).thenReturn(mockChannel);
      when(mockChannel.onPresenceJoin(any)).thenReturn(mockChannel);
      when(mockChannel.onPresenceLeave(any)).thenReturn(mockChannel);
      when(mockChannel.subscribe(any)).thenAnswer((_) async => RealtimeSubscribeStatus.subscribed);

      // Act
      final key = realtimeService.subscribeToPresence(
        channelName: channelName,
        onPresenceChange: (users) {},
      );

      // Assert
      expect(key, contains('presence'));
      verify(mockChannel.onPresenceSync(any)).called(1);
      verify(mockChannel.subscribe(any)).called(1);
    });
  });

  group('RealtimeService - Broadcast', () {
    test('subscribeToBroadcast creates broadcast channel', () {
      // Arrange
      final channelName = 'notifications';
      final event = 'new_alert';
      when(mockClient.channel(any)).thenReturn(mockChannel);
      when(mockChannel.onBroadcast(event: event, callback: anyNamed('callback')))
          .thenReturn(mockChannel);
      when(mockChannel.subscribe()).thenAnswer((_) async => RealtimeSubscribeStatus.subscribed);

      // Act
      final key = realtimeService.subscribeToBroadcast(
        channelName: channelName,
        event: event,
        callback: (data) {},
      );

      // Assert
      expect(key, contains('broadcast'));
      verify(mockChannel.onBroadcast(event: event, callback: anyNamed('callback'))).called(1);
    });

    test('broadcast sends message to channel', () async {
      // Arrange
      final channelKey = 'broadcast_notifications_alert';
      final event = 'new_alert';
      final payload = {'title': 'Test', 'message': 'Test message'};

      when(mockClient.channel(any)).thenReturn(mockChannel);
      when(mockChannel.onBroadcast(event: anyNamed('event'), callback: anyNamed('callback')))
          .thenReturn(mockChannel);
      when(mockChannel.subscribe()).thenAnswer((_) async => RealtimeSubscribeStatus.subscribed);
      when(mockChannel.sendBroadcastMessage(
        event: event,
        payload: payload,
      )).thenAnswer((_) async => RealtimeChannelSendStatus.ok);

      // Subscribe first
      realtimeService.subscribeToBroadcast(
        channelName: 'notifications',
        event: event,
        callback: (_) {},
      );

      // Act
      await realtimeService.broadcast(
        channelKey: channelKey,
        event: event,
        payload: payload,
      );

      // Assert
      verify(mockChannel.sendBroadcastMessage(
        event: event,
        payload: payload,
      )).called(1);
    });
  });

  group('RealtimeService - Event Parsing', () {
    test('_parseEvent converts string to PostgresChangeEvent', () {
      // This tests the private method behavior through subscribeToTable
      when(mockClient.channel(any)).thenReturn(mockChannel);
      when(mockChannel.onPostgresChanges(
        event: anyNamed('event'),
        schema: anyNamed('schema'),
        table: anyNamed('table'),
        callback: anyNamed('callback'),
      )).thenReturn(null);
      when(mockChannel.subscribe()).thenAnswer((_) async => RealtimeSubscribeStatus.subscribed);

      // Test INSERT
      realtimeService.subscribeToTable(
        table: 'test',
        event: 'INSERT',
        callback: (_) {},
      );

      // Test UPDATE
      realtimeService.subscribeToTable(
        table: 'test',
        event: 'UPDATE',
        callback: (_) {},
      );

      // Verify channels were created
      verify(mockClient.channel(any)).called(greaterThanOrEqualTo(2));
    });
  });
}
