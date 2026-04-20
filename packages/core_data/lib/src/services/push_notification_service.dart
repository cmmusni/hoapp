import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_client.dart';

/// Manages FCM push notification token lifecycle.
///
/// Registers/unregisters device tokens in the `notification_tokens` table.
/// Call [registerToken] after Firebase Messaging gives you an FCM token,
/// and [unregisterToken] on logout or token invalidation.
class PushNotificationService {
  final SupabaseClient _client = SupabaseClientManager.instance;

  /// Determines the current platform string for storage.
  String get _platform {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'unknown';
  }

  /// Stores an FCM token for the currently authenticated user.
  ///
  /// Uses upsert so re-registering the same token is idempotent.
  Future<void> registerToken(String token) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _client.from('notification_tokens').upsert({
        'user_id': userId,
        'token': token,
        'platform': _platform,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id,token');
      debugPrint('PushNotificationService: token registered for $userId');
    } catch (e) {
      debugPrint('PushNotificationService.registerToken error: $e');
    }
  }

  /// Removes a specific FCM token (e.g., on logout or token refresh).
  Future<void> unregisterToken(String token) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _client
          .from('notification_tokens')
          .delete()
          .eq('user_id', userId)
          .eq('token', token);
      debugPrint('PushNotificationService: token unregistered');
    } catch (e) {
      debugPrint('PushNotificationService.unregisterToken error: $e');
    }
  }

  /// Removes all tokens for the current user (e.g., on full logout).
  Future<void> unregisterAllTokens() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _client.from('notification_tokens').delete().eq('user_id', userId);
      debugPrint('PushNotificationService: all tokens unregistered');
    } catch (e) {
      debugPrint('PushNotificationService.unregisterAllTokens error: $e');
    }
  }
}
