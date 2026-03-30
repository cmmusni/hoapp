import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:core_data/core_data.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Handles the Supabase email verification callback.
/// When the user clicks the email confirmation link, Supabase redirects to
/// `/auth/callback?token=...&type=signup`. This page exchanges the token
/// for a session, accepts pending invites, and navigates.
class AuthCallbackPage extends StatefulWidget {
  const AuthCallbackPage({super.key});

  @override
  State<AuthCallbackPage> createState() => _AuthCallbackPageState();
}

class _AuthCallbackPageState extends State<AuthCallbackPage> {
  StreamSubscription<AuthState>? _authSub;
  bool _handled = false;
  String _status = 'Verifying your account...';

  @override
  void initState() {
    super.initState();
    // Set up auth listener IMMEDIATELY before any delays
    // This ensures we catch the auth state change when SDK exchanges the PKCE code
    final authRepo = context.read<AuthRepository>();
    _authSub = authRepo.authStateChanges.listen((authState) {
      debugPrint('Auth callback: auth state changed: ${authState.event}');
      if (authState.event == AuthChangeEvent.signedIn ||
          authState.event == AuthChangeEvent.tokenRefreshed ||
          authState.event == AuthChangeEvent.initialSession) {
        _onAuthenticated();
      }
    });

    // Delay to ensure router context is available for URI reading
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _handleCallback();
      }
    });
  }

  Future<void> _handleCallback() async {
    try {
      // Get current URI from GoRouter
      final uri = GoRouterState.of(context).uri;
      debugPrint('Auth callback: URI=$uri');
      debugPrint('Auth callback: Query params=${uri.queryParameters}');

      // Check for PKCE code (email verification) or tokens (other flows)
      final code = uri.queryParameters['code'];
      final accessToken = uri.queryParameters['access_token'];
      final refreshToken = uri.queryParameters['refresh_token'];
      final type = uri.queryParameters['type'];

      debugPrint(
          'Auth callback: code=${code != null ? "present" : "null"}, access_token=${accessToken != null ? "present" : "null"}, type=$type');

      setState(() {
        _status = 'Processing verification...';
      });

      // Check immediately if session already exists (SDK might have already exchanged)
      final currentSession = Supabase.instance.client.auth.currentSession;

      if (currentSession != null) {
        debugPrint('Auth callback: session already established!');
        _onAuthenticated();
        return;
      }

      // If we have a code (PKCE flow), the SDK should auto-process it
      // Wait for the exchange to complete
      if (code != null) {
        debugPrint('Auth callback: Waiting for SDK to exchange PKCE code...');
        setState(() {
          _status = 'Completing sign in...';
        });

        // Check periodically for session (max 10 seconds)
        for (int i = 0; i < 20; i++) {
          await Future.delayed(const Duration(milliseconds: 500));

          final session = Supabase.instance.client.auth.currentSession;
          if (session != null) {
            debugPrint(
                'Auth callback: Session established after ${(i + 1) * 500}ms');
            _onAuthenticated();
            return;
          }

          if (!mounted || _handled) return;
        }

        debugPrint('Auth callback: Session not established after polling');
      } else if (accessToken != null || refreshToken != null) {
        // Direct token flow
        debugPrint('Auth callback: Waiting for SDK to process tokens...');
        await Future.delayed(const Duration(milliseconds: 1500));

        final session = Supabase.instance.client.auth.currentSession;
        if (session != null) {
          _onAuthenticated();
          return;
        }
      }

      // If we get here and still no session, rely on auth state listener
      setState(() {
        _status = 'Completing sign in...';
      });

      // Final timeout
      Future.delayed(const Duration(seconds: 5), () {
        if (!_handled && mounted) {
          debugPrint('Auth callback: Final timeout after waiting');
          setState(() {
            _status = 'Verification timed out. Redirecting...';
          });
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              context.go('/login');
            }
          });
        }
      });
    } catch (e) {
      debugPrint('Auth callback: error processing URL: $e');
      setState(() {
        _status = 'Error: ${e.toString()}';
      });

      // Still try to wait for session as fallback
      Future.delayed(const Duration(seconds: 2), () {
        if (!_handled && mounted) {
          final session = Supabase.instance.client.auth.currentSession;
          if (session != null) {
            _onAuthenticated();
          } else {
            context.go('/login');
          }
        }
      });
    }
  }

  Future<void> _onAuthenticated() async {
    if (_handled) return;
    _handled = true;
    _authSub?.cancel();

    if (!mounted) return;

    setState(() {
      _status = 'Setting up your account...';
    });

    final communityRepo = context.read<CommunityRepository>();
    final authRepo = context.read<AuthRepository>();

    // Read invite context from user_metadata (stored during signup)
    final userMeta = authRepo.currentUser?.userMetadata;
    final inviteToken = userMeta?['invite_token'] as String?;
    final communitySlug = userMeta?['community_slug'] as String?;

    debugPrint(
        'Auth callback: user=${authRepo.currentUser?.email}, inviteToken=$inviteToken, communitySlug=$communitySlug');

    // Only accept invite if there's an explicit invite token
    // Don't auto-accept pending invites for regular signups
    if (inviteToken != null) {
      try {
        debugPrint('Auth callback: calling acceptInvite with token');
        final result = await communityRepo.acceptInvite(inviteToken);
        debugPrint('Auth callback: acceptInvite result=$result');
      } catch (e) {
        debugPrint('Auth callback: invite acceptance failed: $e');
      }
    }

    if (!mounted) return;

    setState(() {
      _status = 'Redirecting...';
    });

    // Navigate to community from metadata if available (invite flow)
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

    // No communities found - redirect to create community page
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
              _status,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Text(
              'Please wait...',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
