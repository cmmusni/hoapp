import 'package:core_domain/core_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_client.dart';

class BillingRepository {
  final SupabaseClient _client = SupabaseClientManager.instance;

  // ============ INVOICES ============

  /// Get invoices for current user's household
  Future<List<Invoice>> getMyInvoices(String communityId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    // Get user's household unit
    final householdResponse = await _client
        .from('household_members')
        .select('unit_id')
        .eq('user_id', userId)
        .maybeSingle();

    if (householdResponse == null) return [];
    
    final unitId = householdResponse['unit_id'] as String;

    // Get invoices for that unit
    final response = await _client
        .from('invoices')
        .select()
        .eq('community_id', communityId)
        .eq('unit_id', unitId)
        .order('due_date', ascending: false);

    return (response as List)
        .map((item) => Invoice.fromJson(item))
        .toList();
  }

  /// Get invoices for a unit (residents see their unit's invoices)
  /// Supports search and pagination
  Future<List<Invoice>> getInvoices(
    String communityId, {
    String? searchQuery,
    int? limit,
    int? offset,
  }) async {
    var query = _client
        .from('invoices')
        .select()
        .eq('community_id', communityId);

    // Add search filter if provided (search by category)
    if (searchQuery != null && searchQuery.isNotEmpty) {
      query = query.ilike('category', '%$searchQuery%');
    }

    // Build the final query with ordering and pagination
    var finalQuery = query.order('due_date', ascending: false);

    if (limit != null && offset != null) {
      finalQuery = finalQuery.limit(limit).range(offset, offset + limit - 1);
    } else if (limit != null) {
      finalQuery = finalQuery.limit(limit);
    }

    final response = await finalQuery;

    return (response as List)
        .map((item) => Invoice.fromJson(item))
        .toList();
  }

  /// Get total count of invoices for pagination
  Future<int> getInvoicesCount(
    String communityId, {
    String? searchQuery,
  }) async {
    var query = _client
        .from('invoices')
        .select('id')
        .eq('community_id', communityId);

    if (searchQuery != null && searchQuery.isNotEmpty) {
      query = query.ilike('category', '%$searchQuery%');
    }

    final response = await query;
    return (response as List).length;
  }

  /// Get single invoice
  Future<Invoice?> getInvoice(String id) async {
    final response = await _client
        .from('invoices')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return Invoice.fromJson(response);
  }

  /// Create invoice (staff only)
  Future<String> createInvoice({
    required String communityId,
    required String unitId,
    required InvoiceCategory category,
    required double amount,
    required DateTime dueDate,
    String? sourceId,
    Map<String, dynamic>? metadata,
  }) async {
    final response = await _client.from('invoices').insert({
      'community_id': communityId,
      'unit_id': unitId,
      'category': category.name,
      'amount': amount,
      'currency': 'PHP',
      'due_date': dueDate.toIso8601String(),
      'status': 'unpaid',
      if (sourceId != null) 'source_id': sourceId,
      if (metadata != null) 'metadata': metadata,
    }).select().single();

    return response['id'] as String;
  }

  /// Update invoice status (staff only)
  Future<void> updateInvoiceStatus(String id, InvoiceStatus status) async {
    await _client.from('invoices').update({
      'status': status.name == 'void_' ? 'void' : status.name,
    }).eq('id', id);
  }

  // ============ PAYMENTS ============

  /// Get payments for an invoice
  Future<List<Payment>> getPaymentsForInvoice(String invoiceId) async {
    final response = await _client
        .from('payments')
        .select()
        .eq('invoice_id', invoiceId)
        .order('posted_at', ascending: false);

    return (response as List)
        .map((item) => Payment.fromJson(item))
        .toList();
  }

  /// Get all payments for a community
  /// Supports search and pagination
  Future<List<Payment>> getPayments(
    String communityId, {
    String? searchQuery,
    int? limit,
    int? offset,
  }) async {
    var query = _client
        .from('payments')
        .select()
        .eq('community_id', communityId);

    // Add search filter if provided (search by method or status)
    if (searchQuery != null && searchQuery.isNotEmpty) {
      query = query.or('method.ilike.%$searchQuery%,status.ilike.%$searchQuery%');
    }

    // Build the final query with ordering and pagination
    var finalQuery = query.order('posted_at', ascending: false);

    if (limit != null && offset != null) {
      finalQuery = finalQuery.limit(limit).range(offset, offset + limit - 1);
    } else if (limit != null) {
      finalQuery = finalQuery.limit(limit);
    }

    final response = await finalQuery;

    return (response as List)
        .map((item) => Payment.fromJson(item))
        .toList();
  }

  /// Get total count of payments for pagination
  Future<int> getPaymentsCount(
    String communityId, {
    String? searchQuery,
  }) async {
    var query = _client
        .from('payments')
        .select('id')
        .eq('community_id', communityId);

    if (searchQuery != null && searchQuery.isNotEmpty) {
      query = query.or('method.ilike.%$searchQuery%,status.ilike.%$searchQuery%');
    }

    final response = await query;
    return (response as List).length;
  }

  /// Submit payment proof (resident)
  Future<String> submitPayment({
    required String invoiceId,
    required String communityId,
    required double amount,
    required String proofUrl,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    final response = await _client.from('payments').insert({
      'community_id': communityId,
      'invoice_id': invoiceId,
      'user_id': userId,
      'method': 'gcash_manual',
      'amount': amount,
      'currency': 'PHP',
      'status': 'submitted',
      'proof_url': proofUrl,
    }).select().single();

    return response['id'] as String;
  }

  /// Verify payment via Edge Function (staff only)
  Future<void> verifyPayment({
    required String paymentId,
    required bool verified,
    String? receiptUrl,
    String? rejectionReason,
    double? amount,
  }) async {
    final response = await _client.functions.invoke(
      'verify_payment',
      body: {
        'payment_id': paymentId,
        'verified': verified,
        if (receiptUrl != null) 'receipt_url': receiptUrl,
        if (rejectionReason != null) 'rejection_reason': rejectionReason,
        if (amount != null) 'amount': amount,
      },
    );

    final data = response.data as Map<String, dynamic>;
    if (data['ok'] != true) {
      throw Exception(data['error'] ?? 'Verification failed');
    }
  }

  /// Delete invoice (staff only)
  Future<void> deleteInvoice(String id) async {
    await _client.from('invoices').delete().eq('id', id);
  }
}
