import 'package:core_domain/core_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_client.dart';

class ViolationRepository {
  final SupabaseClient _client = SupabaseClientManager.instance;

  /// Get all violations for a community (residents see public view without reporter)
  /// Supports search and pagination
  Future<List<Violation>> getViolations(
    String communityId, {
    String? searchQuery,
    int? limit,
    int? offset,
  }) async {
    var query = _client
        .from('violations')
        .select()
        .eq('community_id', communityId);

    // Add search filter if provided
    if (searchQuery != null && searchQuery.isNotEmpty) {
      query = query.or('title.ilike.%$searchQuery%,body.ilike.%$searchQuery%');
    }

    // Build the final query with ordering and pagination
    var finalQuery = query.order('created_at', ascending: false);

    if (limit != null && offset != null) {
      finalQuery = finalQuery.limit(limit).range(offset, offset + limit - 1);
    } else if (limit != null) {
      finalQuery = finalQuery.limit(limit);
    }

    final response = await finalQuery;

    return (response as List)
        .map((item) => Violation.fromJson(item))
        .toList();
  }

  /// Get total count of violations for pagination
  Future<int> getViolationsCount(
    String communityId, {
    String? searchQuery,
  }) async {
    var query = _client
        .from('violations')
        .select('id')
        .eq('community_id', communityId);

    if (searchQuery != null && searchQuery.isNotEmpty) {
      query = query.or('title.ilike.%$searchQuery%,body.ilike.%$searchQuery%');
    }

    final response = await query;
    return (response as List).length;
  }

  /// Get single violation (staff can see reporter_user_id)
  Future<Violation?> getViolation(String id) async {
    final response = await _client
        .from('violations')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return Violation.fromJson(response);
  }

  /// Submit anonymous violation (resident)
  Future<String> createViolation({
    required String communityId,
    required String title,
    required String body,
    List<String>? attachmentUrls,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    final response = await _client.from('violations').insert({
      'community_id': communityId,
      'title': title,
      'body': body,
      'reporter_user_id': userId,
      'attachments': attachmentUrls ?? [],
      'status': 'new',
    }).select().single();

    return response['id'] as String;
  }

  /// Update violation status and staff notes (staff only)
  Future<void> updateViolation({
    required String id,
    ViolationStatus? status,
    String? staffNotes,
  }) async {
    final updates = <String, dynamic>{};
    
    if (status != null) {
      updates['status'] = status.name == 'newStatus' ? 'new' : status.name;
    }
    if (staffNotes != null) {
      updates['staff_notes'] = staffNotes;
    }

    if (updates.isEmpty) return;

    await _client.from('violations').update(updates).eq('id', id);
  }

  /// Delete violation (staff only)
  Future<void> deleteViolation(String id) async {
    await _client.from('violations').delete().eq('id', id);
  }

  /// Get violations by status
  Future<List<Violation>> getViolationsByStatus(
    String communityId,
    ViolationStatus status,
  ) async {
    final statusStr = status.name == 'newStatus' ? 'new' : status.name;
    
    final response = await _client
        .from('violations')
        .select()
        .eq('community_id', communityId)
        .eq('status', statusStr)
        .order('created_at', ascending: false);

    return (response as List)
        .map((item) => Violation.fromJson(item))
        .toList();
  }
}
