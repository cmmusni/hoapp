import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:core_data/core_data.dart';
import '../firebase_options.dart';

/// Handles background messages when app is terminated/background.
/// Must be a top-level function.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('FCM background message: ${message.messageId}');
}

/// Initializes Firebase Cloud Messaging for the mobile app.
///
/// - Requests notification permission
/// - Registers the FCM token with the backend
/// - Listens for token refresh
/// - Configures foreground notification display
class FirebaseMessagingService {
  static final FirebaseMessagingService _instance =
      FirebaseMessagingService._();
  factory FirebaseMessagingService() => _instance;
  FirebaseMessagingService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final PushNotificationService _pushService = PushNotificationService();
  String? _currentToken;

  /// Initialize Firebase Messaging. Call after Firebase.initializeApp().
  Future<void> initialize() async {
    // Register background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request permission (iOS will show a prompt; Android 13+ needs runtime permission)
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('FCM: User denied notification permission');
      return;
    }

    debugPrint('FCM: Permission status: ${settings.authorizationStatus}');

    // Get and register the FCM token
    await _registerToken();

    // Listen for token refresh (e.g. app reinstall, user clears data)
    _messaging.onTokenRefresh.listen((newToken) async {
      debugPrint('FCM: Token refreshed');
      if (_currentToken != null) {
        await _pushService.unregisterToken(_currentToken!);
      }
      _currentToken = newToken;
      await _pushService.registerToken(newToken);
    });

    // Configure foreground message handling
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification taps when app is in background (not terminated)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Check if app was opened from a terminated state via notification
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    // Show notifications in foreground on iOS
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> _registerToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        _currentToken = token;
        await _pushService.registerToken(token);
        debugPrint('FCM: Token registered: ${token.substring(0, 20)}...');
      }
    } catch (e) {
      debugPrint('FCM: Error getting token: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('FCM foreground message: ${message.notification?.title}');
    // Foreground notifications are shown automatically on Android via
    // the notification channel. On iOS, setForegroundNotificationPresentationOptions
    // handles display. No manual handling needed.
  }

  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('FCM: Notification tapped: ${message.data}');
    // Navigation logic can be added here based on message.data
    // e.g., navigate to a specific screen based on notification type
  }

  /// Unregister current token (call on logout).
  Future<void> unregister() async {
    if (_currentToken != null) {
      await _pushService.unregisterToken(_currentToken!);
      _currentToken = null;
    }
  }
}
