import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_client.dart';

/// Sends push notifications via the `send_notification` Supabase Edge Function.
class NotificationService {
  final SupabaseClient _client = SupabaseClientManager.instance;

  /// Send a push notification to all members of [communityId], or to specific
  /// users if [targetUserIds] is provided. When [targetRoles] is set (and
  /// [targetUserIds] is not), the broadcast is filtered to only members
  /// matching one of the given role names (e.g. `['community_admin',
  /// 'community_staff']`).
  ///
  /// Returns silently on failure so callers aren't blocked by notification
  /// errors — the primary action (create violation, etc.) has already succeeded.
  Future<void> send({
    required String communityId,
    required String heading,
    required String content,
    String? url,
    List<String>? targetUserIds,
    List<String>? targetRoles,
    Map<String, dynamic>? data,
  }) async {
    try {
      final body = <String, dynamic>{
        'community_id': communityId,
        'heading': heading,
        'content': content,
      };
      if (url != null) body['url'] = url;
      if (targetUserIds != null) body['target_user_ids'] = targetUserIds;
      if (targetRoles != null) body['target_roles'] = targetRoles;
      if (data != null) body['data'] = data;

      print('NotificationService: sending to $communityId — "$heading"');
      final response = await _client.functions.invoke(
        'send_notification',
        body: body,
      );
      print(
          'NotificationService: response status ${response.status}, data: ${response.data}');
    } catch (e) {
      // Don't throw — notification failure shouldn't break the primary action.
      print('NotificationService.send error: $e');
    }
  }
}
