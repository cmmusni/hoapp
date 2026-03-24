import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:core_data/core_data.dart';

/// Handles the Supabase email verification callback.
/// When the user clicks the email confirmation link, Supabase redirects to
/// `/?code=...`. The SDK exchanges the code for a session automatically.
/// This page waits for the session, accepts pending invites, and navigates.
class AuthCallbackPage extends StatefulWidget {
  const AuthCallbackPage({super.key});

  @override
  State<AuthCallbackPage> createState() => _AuthCallbackPageState();
}

class _AuthCallbackPageState extends State<AuthCallbackPage> {
  StreamSubscription<AuthState>? _authSub;
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    _listenForSession();
  }

  void _listenForSession() {
    final authRepo = context.read<AuthRepository>();

    // Check if already signed in (SDK may have already exchanged the code)
    if (authRepo.currentUser != null) {
      _onAuthenticated();
      return;
    }

    // Otherwise wait for session to appear
    _authSub = authRepo.authStateChanges.listen((authState) {
      if (authState.event == AuthChangeEvent.signedIn ||
          authState.event == AuthChangeEvent.tokenRefreshed) {
        _onAuthenticated();
      }
    });

    // Timeout fallback — if no session after 10s, go to login
    Future.delayed(const Duration(seconds: 10), () {
      if (!_handled && mounted) {
        context.go('/login');
      }
    });
  }

  Future<void> _onAuthenticated() async {
    if (_handled) return;
    _handled = true;
    _authSub?.cancel();

    if (!mounted) return;

    final communityRepo = context.read<CommunityRepository>();
    final authRepo = context.read<AuthRepository>();

    // Read invite context from user_metadata (stored during signup)
    final userMeta = authRepo.currentUser?.userMetadata;
    final inviteToken = userMeta?['invite_token'] as String?;
    final communitySlug = userMeta?['community_slug'] as String?;

    debugPrint(
        'Auth callback: user=${authRepo.currentUser?.email}, inviteToken=$inviteToken, communitySlug=$communitySlug');

    // Accept invite: prefer explicit token, fall back to pending invites by email
    try {
      if (inviteToken != null) {
        debugPrint('Auth callback: calling acceptInvite with token');
        final result = await communityRepo.acceptInvite(inviteToken);
        debugPrint('Auth callback: acceptInvite result=$result');
      } else {
        debugPrint('Auth callback: calling acceptPendingInvites');
        final result = await communityRepo.acceptPendingInvites();
        debugPrint('Auth callback: acceptPendingInvites result=$result');
      }
    } catch (e) {
      debugPrint('Auth callback: invite acceptance failed: $e');
    }

    if (!mounted) return;

    // Navigate to community from metadata if available
    if (communitySlug != null && communitySlug.isNotEmpty) {
      context.go('/$communitySlug/announcements');
      return;
    }

    // Otherwise look up user's communities
    try {
      final communities = await communityRepo.getUserCommunities();
      if (communities.isNotEmpty) {
        final slug = communities.first.slug;
        if (slug.isNotEmpty) {
          context.go('/$slug/announcements');
          return;
        }
      }
    } catch (e) {
      debugPrint('Auth callback: error loading communities: $e');
    }

    if (mounted) {
      context.go('/create-community');
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              'Verifying your account...',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}
