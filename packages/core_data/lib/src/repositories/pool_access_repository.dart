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
        .select('*, units(unit_no)')
        .eq('community_id', communityId)
        .order('created_at', ascending: false);

    return (response as List).map((item) {
      final map = Map<String, dynamic>.from(item);
      final unitData = map.remove('units') as Map<String, dynamic>?;
      if (unitData != null) {
        map['unit_no'] = unitData['unit_no'];
      }
      return PoolAccessRegistration.fromJson(map);
    }).toList();
  }

  /// Create or update registration
  Future<String> upsertRegistration({
    String? id,
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
    int maxPax = 5,
    Map<String, dynamic>? acknowledgements,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    final data = {
      if (id != null) 'id': id,
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
      'max_pax': maxPax,
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

  // ============ SWIMMERS ============

  /// Get all registered swimmers for a community (with registrant info)
  Future<List<Map<String, dynamic>>> getAllSwimmers(String communityId) async {
    final response = await _client
        .from('pool_registered_swimmers')
        .select(
            'id, full_name, birthdate, created_at, registration_id, pool_access_registrations!inner(id, community_id, full_name, unit_id, approved)')
        .eq('pool_access_registrations.community_id', communityId)
        .order('full_name');

    return List<Map<String, dynamic>>.from(response);
  }

  /// Get swimmers for a registration
  Future<List<PoolSwimmer>> getSwimmers(String registrationId) async {
    final response = await _client
        .from('pool_registered_swimmers')
        .select()
        .eq('registration_id', registrationId)
        .order('sort_order');

    return (response as List)
        .map((item) => PoolSwimmer.fromJson(item))
        .toList();
  }

  /// Save swimmers for a registration (delete existing + insert new batch)
  Future<void> saveSwimmers({
    required String registrationId,
    required List<Map<String, dynamic>> swimmers,
  }) async {
    // Delete existing swimmers
    await _client
        .from('pool_registered_swimmers')
        .delete()
        .eq('registration_id', registrationId);

    // Insert new swimmers
    if (swimmers.isNotEmpty) {
      final rows = swimmers
          .asMap()
          .entries
          .map((entry) => {
                'registration_id': registrationId,
                'full_name': entry.value['full_name'],
                if (entry.value['birthdate'] != null)
                  'birthdate': entry.value['birthdate'],
                'sort_order': entry.key,
              })
          .toList();

      await _client.from('pool_registered_swimmers').insert(rows);
    }
  }
}
