import 'package:core_domain/core_domain.dart';
import '../supabase_client.dart';

class SecurityPassRepository {
  final _client = SupabaseClientManager.instance;

  // ── Pass Types ──────────────────────────────────────────────

  Future<List<PassType>> getPassTypes(String communityId) async {
    final rows = await _client
        .from('pass_types')
        .select()
        .eq('community_id', communityId)
        .eq('active', true)
        .order('sort_order');
    return rows.map<PassType>((r) => PassType.fromJson(r)).toList();
  }

  // ── Passes ──────────────────────────────────────────────────

  Future<List<SecurityPass>> getPasses(
    String communityId, {
    String? status,
    String? requestedBy,
  }) async {
    var query = _client
        .from('security_passes')
        .select('*, pass_types(*)')
        .eq('community_id', communityId);

    if (status != null) {
      query = query.eq('status', status);
    }
    if (requestedBy != null) {
      query = query.eq('requested_by', requestedBy);
    }

    final rows = await query.order('created_at', ascending: false);
    return rows.map<SecurityPass>((r) => SecurityPass.fromJson(r)).toList();
  }

  Future<SecurityPass?> getPassByQrToken(String qrToken) async {
    final row = await _client
        .from('security_passes')
        .select('*, pass_types(*)')
        .eq('qr_token', qrToken)
        .maybeSingle();
    if (row == null) return null;
    return SecurityPass.fromJson(row);
  }

  Future<void> createPass({
    required String communityId,
    required String passTypeId,
    required String visitorName,
    String? visitorPhone,
    String? visitorEmail,
    String? purpose,
    String? companyName,
    String? plateNumber,
    String? vehicleDescription,
    String? itemsDescription,
    required DateTime validFrom,
    required DateTime validUntil,
    int maxUses = 1,
    String? notes,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    await _client.from('security_passes').insert({
      'community_id': communityId,
      'pass_type_id': passTypeId,
      'requested_by': userId,
      'status': 'submitted',
      'visitor_name': visitorName,
      'visitor_phone': visitorPhone,
      'visitor_email': visitorEmail,
      'purpose': purpose,
      'company_name': companyName,
      'plate_number': plateNumber,
      'vehicle_description': vehicleDescription,
      'items_description': itemsDescription,
      'valid_from': validFrom.toIso8601String(),
      'valid_until': validUntil.toIso8601String(),
      'max_uses': maxUses,
      'notes': notes,
    });
  }

  /// Approve or reject a pass (calls Edge Function)
  Future<Map<String, dynamic>> reviewPass({
    required String passId,
    required String action, // 'approve' or 'reject'
    String? rejectionReason,
  }) async {
    final jwt = _client.auth.currentSession?.accessToken;
    final response = await _client.functions.invoke(
      'review_pass',
      body: {
        'pass_id': passId,
        'action': action,
        'rejection_reason': rejectionReason,
        if (jwt != null) '_jwt': jwt,
      },
    );

    final result = response.data as Map<String, dynamic>;
    if (result['ok'] != true) {
      throw Exception(result['error'] ?? 'Failed to review pass');
    }
    return result;
  }

  /// Validate a QR token (calls Edge Function)
  Future<Map<String, dynamic>> validateQr({
    required String qrToken,
    required String communityId,
    String scanType = 'entry',
  }) async {
    final jwt = _client.auth.currentSession?.accessToken;
    final response = await _client.functions.invoke(
      'validate_pass',
      body: {
        'qr_token': qrToken,
        'community_id': communityId,
        'scan_type': scanType,
        if (jwt != null) '_jwt': jwt,
      },
    );

    return response.data as Map<String, dynamic>;
  }

  /// Revoke own pass
  Future<void> revokePass(String passId) async {
    await _client.from('security_passes').update({
      'status': 'revoked',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', passId);
  }

  /// Delete a pass (staff only)
  Future<void> deletePass(String passId) async {
    await _client.from('security_passes').delete().eq('id', passId);
  }

  // ── Scan Logs ────────────────────────────────────────────────

  Future<List<PassScanLog>> getScanLogs(String communityId,
      {String? passId}) async {
    var query =
        _client.from('pass_scan_logs').select().eq('community_id', communityId);

    if (passId != null) {
      query = query.eq('pass_id', passId);
    }

    final rows = await query.order('scanned_at', ascending: false);
    return rows.map<PassScanLog>((r) => PassScanLog.fromJson(r)).toList();
  }
}
