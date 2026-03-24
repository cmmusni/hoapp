import 'package:core_domain/core_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_client.dart';

class PoolAccessRepository {
  final SupabaseClient _client = SupabaseClientManager.instance;

  /// Get user's pool access registration
  Future<PoolAccessRegistration?> getMyRegistration(String communityId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    final response = await _client
        .from('pool_access_registrations')
        .select()
        .eq('community_id', communityId)
        .eq('user_id', userId)
        .maybeSingle();

    if (response == null) return null;
    return PoolAccessRegistration.fromJson(response);
  }

  /// Get all registrations for a community (staff only)
  Future<List<PoolAccessRegistration>> getRegistrations(
    String communityId,
  ) async {
    final response = await _client
        .from('pool_access_registrations')
        .select()
        .eq('community_id', communityId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((item) => PoolAccessRegistration.fromJson(item))
        .toList();
  }

  /// Create or update registration
  Future<String> upsertRegistration({
    required String communityId,
    String? unitId,
    required OccupantType occupantType,
    required String fullName,
    required String phone,
    required String email,
    DateTime? birthdate,
    required String emergencyContactName,
    required String emergencyContactPhone,
    String? idDocUrl,
    Map<String, dynamic>? acknowledgements,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    final data = {
      'community_id': communityId,
      'user_id': userId,
      if (unitId != null) 'unit_id': unitId,
      'occupant_type': occupantType.name,
      'full_name': fullName,
      'phone': phone,
      'email': email,
      if (birthdate != null) 'birthdate': birthdate.toIso8601String(),
      'emergency_contact_name': emergencyContactName,
      'emergency_contact_phone': emergencyContactPhone,
      if (idDocUrl != null) 'id_doc_url': idDocUrl,
      'acknowledgements': acknowledgements ?? {},
      'rules_version': 'v1',
      'approved': false,
    };

    final response = await _client
        .from('pool_access_registrations')
        .upsert(data)
        .select()
        .single();

    return response['id'] as String;
  }

  /// Approve registration (staff only)
  Future<void> approveRegistration(String id) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    await _client.from('pool_access_registrations').update({
      'approved': true,
      'approved_by': userId,
      'approved_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  /// Upload signed document (staff only)
  Future<void> uploadSignedDocument(String id, String signatureUrl) async {
    await _client.from('pool_access_registrations').update({
      'signature_url': signatureUrl,
    }).eq('id', id);
  }

  /// Delete registration (admin only)
  Future<void> deleteRegistration(String id) async {
    await _client.from('pool_access_registrations').delete().eq('id', id);
  }

  /// Check if user can edit (3-month rule)
  Future<bool> canEdit(String communityId) async {
    final registration = await getMyRegistration(communityId);
    if (registration == null) return true; // Can create new
    return registration.canEdit;
  }
}
