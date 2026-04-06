import 'dart:convert';
import 'dart:math';
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

    // Collect unique requester IDs to batch-fetch profile names & units
    final requesterIds = rows
        .map((r) => r['requested_by'] as String?)
        .whereType<String>()
        .toSet()
        .toList();

    // Fetch profiles for requester names
    Map<String, String> nameMap = {};
    if (requesterIds.isNotEmpty) {
      final profiles = await _client
          .from('profiles')
          .select('user_id, full_name')
          .eq('community_id', communityId)
          .inFilter('user_id', requesterIds);
      for (final p in profiles) {
        final uid = p['user_id'] as String?;
        final name = p['full_name'] as String?;
        if (uid != null && name != null) nameMap[uid] = name;
      }
    }

    // Fetch household_members + units for requester unit numbers
    Map<String, String> unitMap = {};
    if (requesterIds.isNotEmpty) {
      final members = await _client
          .from('household_members')
          .select('user_id, units(unit_no)')
          .eq('community_id', communityId)
          .inFilter('user_id', requesterIds);
      for (final m in members) {
        final uid = m['user_id'] as String?;
        final unitData = m['units'];
        if (uid != null && unitData is Map && unitData['unit_no'] != null) {
          unitMap[uid] = unitData['unit_no'] as String;
        }
      }
    }

    // Merge requester info into pass rows
    return rows.map<SecurityPass>((r) {
      final uid = r['requested_by'] as String?;
      r['requester_name'] = uid != null ? nameMap[uid] : null;
      r['unit_no'] = uid != null ? unitMap[uid] : null;
      return SecurityPass.fromJson(r);
    }).toList();
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

  Future<Map<String, dynamic>?> createPass({
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

    // Auto-approve: generate QR token and set status to active/approved
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    final qrToken = base64Url.encode(bytes).replaceAll('=', '');
    final now = DateTime.now().toUtc().toIso8601String();
    final isNowValid = validFrom.isBefore(DateTime.now()) ||
        validFrom.isAtSameMomentAs(DateTime.now());
    final status = isNowValid ? 'active' : 'approved';

    final rows = await _client.from('security_passes').insert({
      'community_id': communityId,
      'pass_type_id': passTypeId,
      'requested_by': userId,
      'status': status,
      'visitor_name': visitorName,
      'visitor_phone': visitorPhone,
      'visitor_email': visitorEmail,
      'purpose': purpose,
      'company_name': companyName,
      'plate_number': plateNumber,
      'vehicle_description': vehicleDescription,
      'items_description': itemsDescription,
      'valid_from': validFrom.toUtc().toIso8601String(),
      'valid_until': validUntil.toUtc().toIso8601String(),
      'max_uses': maxUses,
      'notes': notes,
      'qr_token': qrToken,
      'qr_generated_at': now,
      'reviewed_by': userId,
      'reviewed_at': now,
    }).select('id, qr_token');

    if (rows.isNotEmpty) return rows.first;
    return null;
  }

  /// Send QR code email to visitor (calls Edge Function)
  Future<void> sendPassEmail({
    required String passId,
    required String communityId,
  }) async {
    final jwt = _client.auth.currentSession?.accessToken;
    await _client.functions.invoke(
      'send_pass_email',
      headers: {
        if (jwt != null) 'x-user-token': jwt,
      },
      body: {
        'pass_id': passId,
        'community_id': communityId,
        if (jwt != null) '_jwt': jwt,
      },
    );
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
