import 'dart:convert';
import 'package:core_domain/core_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/notification_service.dart';
import '../supabase_client.dart';

class BillingRepository {
  final SupabaseClient _client = SupabaseClientManager.instance;

  // ============ INVOICES ============

  /// Get invoices for current user's household(s)
  Future<List<Invoice>> getMyInvoices(String communityId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    // Get all units the user belongs to
    final householdRows = await _client
        .from('household_members')
        .select('unit_id')
        .eq('user_id', userId);

    final unitIds = (householdRows as List)
        .map((row) => row['unit_id'] as String)
        .toSet()
        .toList();

    if (unitIds.isEmpty) return [];

    // Get invoices for all user's units
    final response = await _client
        .from('invoices')
        .select()
        .eq('community_id', communityId)
        .inFilter('unit_id', unitIds)
        .order('due_date', ascending: false);

    return (response as List).map((item) => Invoice.fromJson(item)).toList();
  }

  /// Get invoices for a unit (residents see their unit's invoices)
  /// Supports search and pagination
  Future<List<Invoice>> getInvoices(
    String communityId, {
    String? searchQuery,
    int? limit,
    int? offset,
  }) async {
    var query =
        _client.from('invoices').select().eq('community_id', communityId);

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

    return (response as List).map((item) => Invoice.fromJson(item)).toList();
  }

  /// Get total count of invoices for pagination
  Future<int> getInvoicesCount(
    String communityId, {
    String? searchQuery,
  }) async {
    var query =
        _client.from('invoices').select('id').eq('community_id', communityId);

    if (searchQuery != null && searchQuery.isNotEmpty) {
      query = query.ilike('category', '%$searchQuery%');
    }

    final response = await query;
    return (response as List).length;
  }

  /// Get single invoice
  Future<Invoice?> getInvoice(String id) async {
    final response =
        await _client.from('invoices').select().eq('id', id).maybeSingle();

    if (response == null) return null;
    return Invoice.fromJson(response);
  }

  /// Get line items for an invoice
  Future<List<InvoiceLineItem>> getLineItems(String invoiceId) async {
    final response = await _client
        .from('invoice_line_items')
        .select()
        .eq('invoice_id', invoiceId)
        .order('sort_order', ascending: true);

    return (response as List)
        .map((item) => InvoiceLineItem.fromJson(item))
        .toList();
  }

  /// Create invoice (staff only)
  Future<String> createInvoice({
    required String communityId,
    required String unitId,
    required InvoiceCategory category,
    required double amount,
    required DateTime dueDate,
    String? sourceId,
    String? description,
    DateTime? periodStart,
    DateTime? periodEnd,
    Map<String, dynamic>? metadata,
    List<Map<String, dynamic>>? lineItems,
  }) async {
    final response = await _client
        .from('invoices')
        .insert({
          'community_id': communityId,
          'unit_id': unitId,
          'category': category.name,
          'amount': amount,
          'currency': 'PHP',
          'due_date': dueDate.toIso8601String(),
          'status': 'unpaid',
          'created_by': _client.auth.currentUser?.id,
          if (sourceId != null) 'source_id': sourceId,
          if (description != null) 'description': description,
          if (periodStart != null)
            'period_start': periodStart.toIso8601String().split('T').first,
          if (periodEnd != null)
            'period_end': periodEnd.toIso8601String().split('T').first,
          if (metadata != null) 'metadata': metadata,
        })
        .select()
        .single();

    final invoiceId = response['id'] as String;

    // Insert line items if provided
    if (lineItems != null && lineItems.isNotEmpty) {
      final items = lineItems
          .asMap()
          .entries
          .map((e) => {
                'invoice_id': invoiceId,
                'label': e.value['label'],
                'amount': e.value['amount'],
                'sort_order': e.key,
                if (e.value['metadata'] != null)
                  'metadata': e.value['metadata'],
                if (e.value['category'] != null)
                  'category': e.value['category'],
                if (e.value['description'] != null)
                  'description': e.value['description'],
                if (e.value['period_start'] != null)
                  'period_start': e.value['period_start'],
                if (e.value['period_end'] != null)
                  'period_end': e.value['period_end'],
              })
          .toList();
      await _client.from('invoice_line_items').insert(items);
    }

    // Fire-and-forget: send invoice email notification to primary household member
    _sendInvoiceEmail(
      invoiceId: invoiceId,
      communityId: communityId,
      unitId: unitId,
      amount: amount,
      dueDate: dueDate,
      description: description,
    );

    return invoiceId;
  }

  /// Send invoice email notification (fire-and-forget, never throws).
  void _sendInvoiceEmail({
    required String invoiceId,
    required String communityId,
    required String unitId,
    required double amount,
    required DateTime dueDate,
    String? description,
  }) {
    Future(() async {
      try {
        final jwt = _client.auth.currentSession?.accessToken;
        await _client.functions.invoke(
          'invoice_email',
          headers: {
            if (jwt != null) 'x-user-token': jwt,
          },
          body: {
            'invoice_id': invoiceId,
            'community_id': communityId,
            'unit_id': unitId,
            'amount': amount,
            'due_date': dueDate.toIso8601String().split('T').first,
            if (description != null) 'description': description,
            if (jwt != null) '_jwt': jwt,
          },
        );
      } catch (e) {
        // Email is non-critical; silently ignore failures
        print('Invoice email notification failed (non-critical): $e');
      }
    });
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

    return (response as List).map((item) => Payment.fromJson(item)).toList();
  }

  /// Get all payments for a community
  /// Supports search and pagination
  Future<List<Payment>> getPayments(
    String communityId, {
    String? searchQuery,
    int? limit,
    int? offset,
  }) async {
    var query =
        _client.from('payments').select().eq('community_id', communityId);

    // Add search filter if provided (search by method or status)
    if (searchQuery != null && searchQuery.isNotEmpty) {
      query =
          query.or('method.ilike.%$searchQuery%,status.ilike.%$searchQuery%');
    }

    // Build the final query with ordering and pagination
    var finalQuery = query.order('posted_at', ascending: false);

    if (limit != null && offset != null) {
      finalQuery = finalQuery.limit(limit).range(offset, offset + limit - 1);
    } else if (limit != null) {
      finalQuery = finalQuery.limit(limit);
    }

    final response = await finalQuery;

    return (response as List).map((item) => Payment.fromJson(item)).toList();
  }

  /// Get total count of payments for pagination
  Future<int> getPaymentsCount(
    String communityId, {
    String? searchQuery,
  }) async {
    var query =
        _client.from('payments').select('id').eq('community_id', communityId);

    if (searchQuery != null && searchQuery.isNotEmpty) {
      query =
          query.or('method.ilike.%$searchQuery%,status.ilike.%$searchQuery%');
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

    final response = await _client
        .from('payments')
        .insert({
          'community_id': communityId,
          'invoice_id': invoiceId,
          'user_id': userId,
          'method': 'gcash_manual',
          'amount': amount,
          'currency': 'PHP',
          'status': 'submitted',
          'proof_url': proofUrl,
        })
        .select()
        .single();

    // Fire-and-forget: notify community admin(s) of submitted payment
    _sendPaymentSubmittedEmail(
      communityId: communityId,
      invoiceId: invoiceId,
      amount: amount,
    );

    // Push notification to community staff
    NotificationService().send(
      communityId: communityId,
      heading: 'Payment Submitted',
      content:
          'A resident submitted a payment of \u20B1${amount.toStringAsFixed(2)} for verification.',
      data: {'type': 'payment', 'invoice_id': invoiceId},
    );

    return response['id'] as String;
  }

  /// Send payment-submitted email notification to community admin(s).
  void _sendPaymentSubmittedEmail({
    required String communityId,
    required String invoiceId,
    required double amount,
  }) {
    Future(() async {
      try {
        final jwt = _client.auth.currentSession?.accessToken;
        await _client.functions.invoke(
          'payment_submitted_email',
          headers: {
            if (jwt != null) 'x-user-token': jwt,
          },
          body: {
            'community_id': communityId,
            'invoice_id': invoiceId,
            'amount': amount,
            if (jwt != null) '_jwt': jwt,
          },
        );
      } catch (e) {
        // Email is non-critical; silently ignore failures
        print('Payment submitted email notification failed (non-critical): $e');
      }
    });
  }

  /// Verify payment via Edge Function (staff only)
  Future<void> verifyPayment({
    required String paymentId,
    required bool verified,
    String? receiptUrl,
    String? rejectionReason,
    double? amount,
  }) async {
    final jwt = _client.auth.currentSession?.accessToken;
    final response = await _client.functions.invoke(
      'verify_payment',
      headers: {
        if (jwt != null) 'x-user-token': jwt,
      },
      body: {
        'payment_id': paymentId,
        'verified': verified,
        if (receiptUrl != null) 'receipt_url': receiptUrl,
        if (rejectionReason != null) 'rejection_reason': rejectionReason,
        if (amount != null) 'amount': amount,
        if (jwt != null) '_jwt': jwt,
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

  /// Scan an invoice image using AI and extract structured data.
  /// [imageBytes] - raw image bytes (JPEG/PNG)
  /// Returns a map with: description, category, amount, line_items, due_date, period_start, period_end, notes
  Future<Map<String, dynamic>> scanInvoiceImage(List<int> imageBytes) async {
    final jwt = _client.auth.currentSession?.accessToken;
    final base64Image = base64Encode(imageBytes);

    final response = await _client.functions.invoke(
      'scan_invoice',
      headers: {
        if (jwt != null) 'x-user-token': jwt,
      },
      body: {
        'image_base64': base64Image,
        if (jwt != null) '_jwt': jwt,
      },
    );

    final data = response.data as Map<String, dynamic>;
    if (data['ok'] != true) {
      throw Exception(data['error'] ?? 'Failed to scan invoice');
    }

    return data['data'] as Map<String, dynamic>;
  }
}
