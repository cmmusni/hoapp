import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:core_data/core_data.dart';

/// Manages Firebase Cloud Messaging for the web portal.
///
/// Requests browser notification permission, registers the FCM token,
/// and listens for token refresh events.
class WebPushService {
  static final WebPushService _instance = WebPushService._();
  factory WebPushService() => _instance;
  WebPushService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final PushNotificationService _pushService = PushNotificationService();
  String? _currentToken;

  /// Initialize web push notifications. Call after Firebase.initializeApp().
  Future<void> initialize() async {
    try {
      // Request permission — browser will show a prompt
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('WebPush: User denied notification permission');
        return;
      }

      debugPrint('WebPush: Permission status: ${settings.authorizationStatus}');

      // Get FCM token for web (requires VAPID key)
      // The VAPID key is set in the firebase-messaging-sw.js or passed here
      final token = await _messaging.getToken(
        vapidKey: const String.fromEnvironment(
          'FIREBASE_VAPID_KEY',
          defaultValue: '',
        ),
      );

      if (token != null) {
        _currentToken = token;
        await _pushService.registerToken(token);
        debugPrint('WebPush: Token registered: ${token.substring(0, 20)}...');
      }

      // Listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) async {
        if (_currentToken != null) {
          await _pushService.unregisterToken(_currentToken!);
        }
        _currentToken = newToken;
        await _pushService.registerToken(newToken);
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('WebPush foreground: ${message.notification?.title}');
        // Web browser will show the notification via the service worker
      });
    } catch (e) {
      debugPrint('WebPush initialization error: $e');
    }
  }

  /// Unregister token on logout.
  Future<void> unregister() async {
    if (_currentToken != null) {
      await _pushService.unregisterToken(_currentToken!);
      _currentToken = null;
    }
  }
}
