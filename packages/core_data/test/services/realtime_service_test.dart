import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:core_data/core_data.dart';

@GenerateMocks([SupabaseClient, RealtimeChannel, RealtimeClient])
import 'realtime_service_test.mocks.dart';

void _stubChannel(
    MockSupabaseClient mockClient, MockRealtimeChannel mockChannel) {
  when(mockClient.channel(any)).thenReturn(mockChannel);
  when(mockChannel.onPostgresChanges(
    event: anyNamed('event'),
    schema: anyNamed('schema'),
    table: anyNamed('table'),
    callback: anyNamed('callback'),
  )).thenReturn(mockChannel);
  when(mockChannel.subscribe(any)).thenReturn(mockChannel);
  when(mockChannel.subscribe()).thenReturn(mockChannel);
  when(mockClient.removeChannel(mockChannel)).thenAnswer((_) async => 'ok');
}

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
      _stubChannel(mockClient, mockChannel);

      final key = realtimeService.subscribeToTable(
        table: 'announcements',
        event: 'INSERT',
        callback: (data) {},
      );

      expect(key, isNotEmpty);
      verify(mockClient.channel(any)).called(1);
      // subscribe() is called twice in the production code (known duplication)
      verify(mockChannel.subscribe()).called(2);
    });

    test(
        'subscribeToAnnouncements creates subscription for announcements table',
        () {
      _stubChannel(mockClient, mockChannel);

      final key = realtimeService.subscribeToAnnouncements(
        communityId: 'test-community-id',
        onNewAnnouncement: (data) {},
      );

      expect(key, contains('announcements'));
      expect(key, contains('INSERT'));
    });

    test('subscribeToTicketMessages creates subscription for messages table',
        () {
      _stubChannel(mockClient, mockChannel);

      final key = realtimeService.subscribeToTicketMessages(
        ticketId: 'test-ticket-id',
        onNewMessage: (data) {},
      );

      expect(key, contains('messages'));
      expect(key, contains('INSERT'));
    });
  });

  group('RealtimeService - Unsubscribe', () {
    test('unsubscribe removes channel', () async {
      _stubChannel(mockClient, mockChannel);

      // Subscribe first so a channel exists
      realtimeService.subscribeToTable(
        table: 'test',
        event: 'INSERT',
        callback: (data) {},
      );

      // Act - unsubscribe using the key that was generated
      await realtimeService.unsubscribe('test_INSERT_all');

      // Assert
      verify(mockClient.removeChannel(mockChannel)).called(1);
    });

    test('unsubscribeAll removes all channels', () async {
      _stubChannel(mockClient, mockChannel);

      // Subscribe to multiple tables
      realtimeService.subscribeToTable(
          table: 'table1', event: 'INSERT', callback: (_) {});
      realtimeService.subscribeToTable(
          table: 'table2', event: 'UPDATE', callback: (_) {});

      // Act
      await realtimeService.unsubscribeAll();

      // Assert
      verify(mockClient.removeChannel(mockChannel))
          .called(greaterThanOrEqualTo(2));
    });
  });

  group('RealtimeService - Presence', () {
    test('subscribeToPresence configures presence channel', () {
      when(mockClient.channel(any)).thenReturn(mockChannel);
      when(mockChannel.onPresenceSync(any)).thenReturn(mockChannel);
      when(mockChannel.onPresenceJoin(any)).thenReturn(mockChannel);
      when(mockChannel.onPresenceLeave(any)).thenReturn(mockChannel);
      when(mockChannel.subscribe(any)).thenReturn(mockChannel);
      when(mockClient.removeChannel(mockChannel)).thenAnswer((_) async => 'ok');

      final key = realtimeService.subscribeToPresence(
        channelName: 'test-presence',
        onPresenceChange: (users) {},
      );

      expect(key, contains('presence'));
      verify(mockChannel.onPresenceSync(any)).called(1);
      verify(mockChannel.subscribe(any)).called(1);
    });
  });

  group('RealtimeService - Broadcast', () {
    test('subscribeToBroadcast creates broadcast channel', () {
      when(mockClient.channel(any)).thenReturn(mockChannel);
      when(mockChannel.onBroadcast(
              event: anyNamed('event'), callback: anyNamed('callback')))
          .thenReturn(mockChannel);
      when(mockChannel.subscribe()).thenReturn(mockChannel);
      when(mockClient.removeChannel(mockChannel)).thenAnswer((_) async => 'ok');

      final key = realtimeService.subscribeToBroadcast(
        channelName: 'notifications',
        event: 'new_alert',
        callback: (data) {},
      );

      expect(key, contains('broadcast'));
      verify(mockChannel.onBroadcast(
              event: 'new_alert', callback: anyNamed('callback')))
          .called(1);
    });
  });

  group('RealtimeService - Event Parsing', () {
    test('subscribeToTable handles different event types', () {
      _stubChannel(mockClient, mockChannel);

      // Test INSERT
      realtimeService.subscribeToTable(
          table: 'test', event: 'INSERT', callback: (_) {});

      // Test UPDATE
      realtimeService.subscribeToTable(
          table: 'test', event: 'UPDATE', callback: (_) {});

      // Verify channels were created
      verify(mockClient.channel(any)).called(greaterThanOrEqualTo(2));
    });
  });
}
