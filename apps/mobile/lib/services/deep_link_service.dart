import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

/// Service to handle deep links for invite acceptance
class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  
  // Callback to handle the invite token
  void Function(String token)? onInviteReceived;

  /// Initialize deep link listening
  Future<void> initialize() async {
    // Handle initial link when app is cold-started
    try {
      final initialUri = await _appLinks.getInitialAppLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }
    } catch (e) {
      debugPrint('Error getting initial link: $e');
    }

    // Handle links when app is already running
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    }, onError: (err) {
      debugPrint('Error listening to deep links: $err');
    });
  }

  /// Parse and handle deep link
  void _handleDeepLink(Uri uri) {
    debugPrint('Deep link received: $uri');
    
    // Format: hoapp://invite?token=abc123
    // or hoapp://login?invite=abc123
    if (uri.host == 'invite' || uri.path == '/invite') {
      final token = uri.queryParameters['token'] ?? uri.queryParameters['invite'];
      if (token != null && token.isNotEmpty) {
        onInviteReceived?.call(token);
      }
    } else if (uri.host == 'login' || uri.path == '/login') {
      final token = uri.queryParameters['invite'];
      if (token != null && token.isNotEmpty) {
        onInviteReceived?.call(token);
      }
    }
  }

  /// Clean up
  void dispose() {
    _linkSubscription?.cancel();
  }
}
