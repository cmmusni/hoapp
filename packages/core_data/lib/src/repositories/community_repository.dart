import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:core_domain/core_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_client.dart';
import '../config.dart';

class CommunityRepository {
  final SupabaseClient _client = SupabaseClientManager.instance;

  Future<Community?> getCommunityBySlug(String slug) async {
    final response = await _client
        .from('communities')
        .select()
        .eq('slug', slug)
        .maybeSingle();

    if (response == null) return null;
    return Community.fromJson(response);
  }

  Future<Community?> getCommunityById(String id) async {
    final response =
        await _client.from('communities').select().eq('id', id).maybeSingle();

    if (response == null) return null;
    return Community.fromJson(response);
  }

  Future<List<Community>> getUserCommunities() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final response = await _client
          .from('profiles')
          .select('community_id, communities(*)')
          .eq('user_id', userId);

      print('DEBUG: getUserCommunities response: $response');

      return (response as List).where((item) {
        final community = item['communities'];
        if (community == null) {
          print('DEBUG: Skipping null community');
          return false;
        }
        // Check if required fields exist
        if (community['id'] == null || community['slug'] == null) {
          print(
              'DEBUG: Skipping community with null required fields: $community');
          return false;
        }
        return true;
      }).map((item) {
        try {
          return Community.fromJson(
              item['communities'] as Map<String, dynamic>);
        } catch (e) {
          print('DEBUG: Error parsing community: $e');
          print('DEBUG: Community data: ${item['communities']}');
          rethrow;
        }
      }).toList();
    } catch (e) {
      print('DEBUG: getUserCommunities error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createCommunity({
    required String name,
    required String slug,
  }) async {
    // Get current session
    final session = _client.auth.currentSession;
    final user = _client.auth.currentUser;

    print('DEBUG: Creating community...');
    print('DEBUG: Session exists: ${session != null}');
    print('DEBUG: User exists: ${user != null}');
    print('DEBUG: User ID: ${user?.id}');

    if (session == null || user == null) {
      throw Exception(
          'User must be logged in to create a community. Please refresh the page and try again.');
    }

    print('DEBUG: Access token: ${session.accessToken.substring(0, 20)}...');

    try {
      // Let the Supabase SDK handle authentication automatically
      final response = await _client.functions.invoke(
        'create_community',
        body: {'name': name, 'slug': slug},
      );

      print('DEBUG: Response status: ${response.status}');
      print('DEBUG: Response data: ${response.data}');

      if (response.status != 200) {
        final errorData = response.data is Map
            ? response.data
            : {'error': response.data.toString()};
        throw Exception(
            'Failed to create community: ${errorData['error'] ?? 'Unknown error'}');
      }

      return response.data as Map<String, dynamic>;
    } catch (e) {
      print('DEBUG: Error creating community: $e');
      rethrow;
    }
  }

  Future<List<UserRole>> getUserRoles(String userId) async {
    final response =
        await _client.from('user_roles').select().eq('user_id', userId);

    return (response as List).map((item) => UserRole.fromJson(item)).toList();
  }

  /// Get all user roles for a community (admin only)
  Future<List<UserRole>> getCommunityUserRoles(String communityId) async {
    final response = await _client
        .from('user_roles')
        .select()
        .eq('community_id', communityId)
        .order('created_at', ascending: false);

    return (response as List).map((item) => UserRole.fromJson(item)).toList();
  }

  /// Delete/revoke a user role (admin only)
  Future<void> deleteUserRole(int roleId) async {
    await _client.from('user_roles').delete().eq('id', roleId);
  }

  /// Fully delete a user (auth + profile + roles) via edge function
  Future<Map<String, dynamic>> deleteUser({
    required String targetUserId,
    required String communityId,
  }) async {
    await _client.auth.refreshSession();
    final session = _client.auth.currentSession;
    if (session == null) {
      throw Exception('No active session. Please sign in again.');
    }

    const functionsUrl = '${AppConfig.supabaseUrl}/functions/v1/delete_user';

    final response = await http.post(
      Uri.parse(functionsUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${session.accessToken}',
        'apikey': AppConfig.supabaseAnonKey,
      },
      body: jsonEncode({
        'target_user_id': targetUserId,
        'community_id': communityId,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete user: ${response.body}');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Update a user role (admin only)
  Future<void> updateUserRole({
    required int roleId,
    required Role role,
  }) async {
    await _client
        .from('user_roles')
        .update({'role': role.name}).eq('id', roleId);
  }

  Future<Map<String, dynamic>> createInvite({
    required String communityId,
    required String email,
    required String role,
    String? unitId,
    String? newUnitNo,
    String? inviteKind,
  }) async {
    // Refresh session to ensure we have a valid token
    await _client.auth.refreshSession();
    final session = _client.auth.currentSession;

    if (session == null) {
      throw Exception('No active session. Please sign in again.');
    }

    print(
        'DEBUG: Making HTTP request with token: ${session.accessToken.substring(0, 20)}...');
    print('DEBUG: Session user: ${session.user.id}');

    try {
      // Use direct HTTP POST to work around Supabase Flutter SDK issue
      const functionsUrl =
          '${AppConfig.supabaseUrl}/functions/v1/create_invite?v=2'; // Cache buster

      final response = await http.post(
        Uri.parse(functionsUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.accessToken}',
          'apikey': AppConfig.supabaseAnonKey,
        },
        body: jsonEncode({
          'community_id': communityId,
          'email': email,
          'role': role,
          '_jwt': session
              .accessToken, // Pass JWT in body since headers are stripped
          if (unitId != null) 'unit_id': unitId,
          if (newUnitNo != null) 'new_unit_no': newUnitNo,
          if (inviteKind != null) 'invite_kind': inviteKind,
        }),
      );

      print('DEBUG: HTTP Response status: ${response.statusCode}');
      print('DEBUG: HTTP Response body: ${response.body}');

      if (response.statusCode != 200) {
        throw Exception('Edge Function error: ${response.body}');
      }

      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      print('DEBUG: Error calling create_invite: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> acceptInvite(String token) async {
    // Refresh session to ensure we have a valid token
    try {
      await _client.auth.refreshSession();
    } catch (e) {
      print('DEBUG acceptInvite: refreshSession failed: $e');
    }
    final session = _client.auth.currentSession;

    if (session == null) {
      throw Exception('No active session. Please sign in again.');
    }

    // Use direct HTTP POST to work around Supabase Flutter SDK issue
    const functionsUrl = '${AppConfig.supabaseUrl}/functions/v1/accept_invite';

    final response = await http.post(
      Uri.parse(functionsUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${session.accessToken}',
        'apikey': AppConfig.supabaseAnonKey,
      },
      body: jsonEncode({
        'token': token,
        '_jwt': session.accessToken, // Pass JWT in body as fallback
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Edge Function error: ${response.body}');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> acceptPendingInvites() async {
    // Refresh session to ensure we have a valid token
    await _client.auth.refreshSession();
    final session = _client.auth.currentSession;

    if (session == null) {
      throw Exception('No active session. Please sign in again.');
    }

    const functionsUrl = '${AppConfig.supabaseUrl}/functions/v1/accept_invite';

    final response = await http.post(
      Uri.parse(functionsUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${session.accessToken}',
        'apikey': AppConfig.supabaseAnonKey,
      },
      body: jsonEncode({
        '_jwt': session.accessToken,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Edge Function error: ${response.body}');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
