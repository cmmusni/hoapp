import 'package:flutter/foundation.dart';
import 'package:core_domain/core_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_client.dart';

class AnnouncementRepository {
  final SupabaseClient _client = SupabaseClientManager.instance;

  Future<List<Announcement>> getAnnouncements(
    String communityId, {
    String? searchQuery,
    int? limit,
    int? offset,
  }) async {
    var query = _client
        .from('announcements')
        .select()
        .eq('community_id', communityId);

    // Apply search filter
    if (searchQuery != null && searchQuery.isNotEmpty) {
      query = query.or('title.ilike.%$searchQuery%,body.ilike.%$searchQuery%');
    }

    // Build the final query with ordering and pagination
    var finalQuery = query
        .order('pinned', ascending: false)
        .order('publish_at', ascending: false);

    if (limit != null && offset != null) {
      finalQuery = finalQuery.limit(limit).range(offset, offset + limit - 1);
    } else if (limit != null) {
      finalQuery = finalQuery.limit(limit);
    }

    final response = await finalQuery;

    return (response as List)
        .map((item) => Announcement.fromJson(item))
        .toList();
  }

  Future<int> getAnnouncementsCount(
    String communityId, {
    String? searchQuery,
  }) async {
    var query = _client
        .from('announcements')
        .select('id')
        .eq('community_id', communityId);

    if (searchQuery != null && searchQuery.isNotEmpty) {
      query = query.or('title.ilike.%$searchQuery%,body.ilike.%$searchQuery%');
    }

    final response = await query;
    return (response as List).length;
  }

  Future<void> createAnnouncement({
    required String communityId,
    required String title,
    required String body,
    bool pinned = false,
    DateTime? publishAt,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    await _client.from('announcements').insert({
      'community_id': communityId,
      'title': title,
      'body': body,
      'pinned': pinned,
      'publish_at': (publishAt ?? DateTime.now().toUtc()).toIso8601String(),
      'created_by': userId,
    });
  }

  Future<void> updateAnnouncement(
    String id,
    Map<String, dynamic> updates,
  ) async {
    await _client.from('announcements').update(updates).eq('id', id);
  }

  Future<void> deleteAnnouncement(String id) async {
    await _client.from('announcements').delete().eq('id', id);
  }

  /// Subscribe to realtime announcements for a community
  RealtimeChannel subscribeToAnnouncements(
    String communityId,
    void Function(Announcement announcement) onNewAnnouncement,
  ) {
    return _client
        .channel('announcements_$communityId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'announcements',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'community_id',
            value: communityId,
          ),
          callback: (payload) {
            try {
              final announcement = Announcement.fromJson(payload.newRecord);
              onNewAnnouncement(announcement);
            } catch (e) {
              debugPrint('Error parsing realtime announcement: $e');
            }
          },
        )
        .subscribe();
  }
}
