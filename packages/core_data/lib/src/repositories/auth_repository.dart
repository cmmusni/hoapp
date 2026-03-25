import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_client.dart';

class AuthRepository {
  final SupabaseClient _client = SupabaseClientManager.instance;

  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Returns the current origin (e.g. https://hoapp.net) for email redirects.
  String? get _redirectUrl {
    if (!kIsWeb) return null;
    final uri = Uri.base;
    return '${uri.scheme}://${uri.host}${uri.hasPort && uri.port != 443 && uri.port != 80 ? ':${uri.port}' : ''}/auth/callback';
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? metadata,
  }) async {
    return await _client.auth.signUp(
      email: email,
      password: password,
      data: metadata,
      emailRedirectTo: _redirectUrl,
    );
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(
      email,
      redirectTo: _redirectUrl,
    );
  }
}
