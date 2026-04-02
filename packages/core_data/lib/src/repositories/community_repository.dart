import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:core_domain/core_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_client.dart';
import '../config.dart';

class CommunityRepository {
  final SupabaseClient _client = SupabaseClientManager.instance;

  /// Check if the current user is a platform admin (app_admin)
  Future<bool> isPlatformAdmin() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;

    final row = await _client
        .from('platform_roles')
        .select('role')
        .eq('user_id', userId)
        .eq('role', 'app_admin')
        .maybeSingle();

    return row != null;
  }

  /// Fetch all communities (platform admin only)
  Future<List<Community>> getAllCommunities() async {
    try {
      final response = await _client.from('communities').select().order('name');

      return (response as List)
          .map((item) {
            try {
              return Community.fromJson(item as Map<String, dynamic>);
            } catch (e) {
              return null;
            }
          })
          .whereType<Community>()
          .toList();
    } catch (e) {
      return [];
    }
  }

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

      return (response as List)
          .where((item) {
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
          })
          .map((item) {
            try {
              return Community.fromJson(
                  item['communities'] as Map<String, dynamic>);
            } catch (e) {
              print('DEBUG: Error parsing community: $e');
              print('DEBUG: Community data: ${item['communities']}');
              return null;
            }
          })
          .whereType<Community>()
          .toList();
    } catch (e) {
      print('DEBUG: getUserCommunities error: $e');
      return [];
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
    const roleToDb = {
      Role.communityAdmin: 'community_admin',
      Role.hoaOfficer: 'hoa_officer',
      Role.guard: 'guard',
      Role.resident: 'resident',
      Role.maintenance: 'maintenance',
    };
    await _client
        .from('user_roles')
        .update({'role': roleToDb[role]!}).eq('id', roleId);
  }

  Future<Map<String, dynamic>> createInvite({
    required String communityId,
    required String email,
    required String role,
    String? unitId,
    String? newUnitNo,
    String? inviteKind,
    String? householdMemberId,
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
          if (householdMemberId != null)
            'household_member_id': householdMemberId,
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

  // ─── Beta Access Requests ─────────────────────────────────

  /// Fetch all beta access requests (admin only)
  Future<List<Map<String, dynamic>>> getBetaAccessRequests() async {
    final response = await _client
        .from('beta_access_requests')
        .select()
        .order('created_at', ascending: false);

    return (response as List).cast<Map<String, dynamic>>();
  }

  /// Provision a community for a beta requester
  Future<Map<String, dynamic>> provisionCommunity({
    required String requestId,
    required String communityName,
    required String communitySlug,
    required String password,
  }) async {
    final session = _client.auth.currentSession;
    if (session == null) throw Exception('Not authenticated');

    const functionsUrl =
        '${AppConfig.supabaseUrl}/functions/v1/provision_community';

    final response = await http.post(
      Uri.parse(functionsUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${session.accessToken}',
        'apikey': AppConfig.supabaseAnonKey,
      },
      body: jsonEncode({
        'request_id': requestId,
        'community_name': communityName,
        'community_slug': communitySlug,
        'password': password,
      }),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'Failed to provision community');
    }

    return data;
  }

  /// Reject a beta access request
  Future<void> rejectBetaRequest(String requestId) async {
    await _client.from('beta_access_requests').update({
      'status': 'rejected',
      'processed_by': _client.auth.currentUser?.id,
      'processed_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', requestId);
  }

  // ============ FEEDBACK ============

  /// Submit feedback from any user
  Future<void> submitFeedback({
    required String communityId,
    required String category,
    required String subject,
    required String description,
    String? imageUrl,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final row = <String, dynamic>{
      'community_id': communityId,
      'user_id': user.id,
      'user_email': user.email ?? '',
      'category': category,
      'subject': subject,
      'description': description,
    };
    if (imageUrl != null) row['image_url'] = imageUrl;

    await _client.from('feedback').insert(row);
  }

  /// Get feedback for a community (staff sees all, residents see own)
  Future<List<Map<String, dynamic>>> getFeedback(String communityId) async {
    final data = await _client
        .from('feedback')
        .select()
        .eq('community_id', communityId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  /// Update feedback status and/or admin notes (staff only)
  Future<void> updateFeedback({
    required String feedbackId,
    String? status,
    String? adminNotes,
  }) async {
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (status != null) updates['status'] = status;
    if (adminNotes != null) updates['admin_notes'] = adminNotes;

    await _client.from('feedback').update(updates).eq('id', feedbackId);
  }

  /// Delete feedback (staff only)
  Future<void> deleteFeedback(String feedbackId) async {
    await _client.from('feedback').delete().eq('id', feedbackId);
  }

  /// Update community settings (e.g. logo_url, brand colors)
  Future<void> updateCommunitySettings({
    required String communityId,
    required Map<String, dynamic> settings,
  }) async {
    await _client
        .from('communities')
        .update({'settings': settings}).eq('id', communityId);
  }

  /// Update community plan (starter, professional, enterprise)
  Future<void> updateCommunityPlan({
    required String communityId,
    required String plan,
    DateTime? planExpiresAt,
  }) async {
    final updates = <String, dynamic>{'plan': plan};
    if (plan == 'starter') {
      updates['plan_expires_at'] = null;
    } else if (planExpiresAt != null) {
      updates['plan_expires_at'] = planExpiresAt.toIso8601String();
    }
    await _client.from('communities').update(updates).eq('id', communityId);
  }
}
