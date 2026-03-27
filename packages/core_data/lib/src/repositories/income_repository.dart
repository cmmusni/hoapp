import 'package:core_domain/core_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_client.dart';

class IncomeRepository {
  final SupabaseClient _client = SupabaseClientManager.instance;

  // ============ INVOICE-BASED INCOME (verified payments) ============

  /// Get all verified payments as income for a community
  Future<List<Payment>> getVerifiedPayments(
    String communityId, {
    int? limit,
    int? offset,
  }) async {
    var query = _client
        .from('payments')
        .select()
        .eq('community_id', communityId)
        .eq('status', 'verified');

    var finalQuery = query.order('verified_at', ascending: false);

    if (limit != null && offset != null) {
      finalQuery = finalQuery.limit(limit).range(offset, offset + limit - 1);
    } else if (limit != null) {
      finalQuery = finalQuery.limit(limit);
    }

    final response = await finalQuery;
    return (response as List).map((item) => Payment.fromJson(item)).toList();
  }

  /// Get total verified payment income for a community
  Future<double> getTotalVerifiedIncome(String communityId) async {
    final response = await _client
        .from('payments')
        .select('amount')
        .eq('community_id', communityId)
        .eq('status', 'verified');

    double total = 0;
    for (final row in response as List) {
      total += (row['amount'] as num).toDouble();
    }
    return total;
  }

  // ============ MANUAL INCOME ============

  /// Get all manual income entries for a community
  Future<List<ManualIncome>> getManualIncome(
    String communityId, {
    String? searchQuery,
    IncomeCategory? category,
    int? limit,
    int? offset,
  }) async {
    var query =
        _client.from('manual_income').select().eq('community_id', communityId);

    if (category != null) {
      query = query.eq('category', category.name);
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      query = query
          .or('description.ilike.%$searchQuery%,source.ilike.%$searchQuery%');
    }

    var finalQuery = query.order('income_date', ascending: false);

    if (limit != null && offset != null) {
      finalQuery = finalQuery.limit(limit).range(offset, offset + limit - 1);
    } else if (limit != null) {
      finalQuery = finalQuery.limit(limit);
    }

    final response = await finalQuery;
    return (response as List)
        .map((item) => ManualIncome.fromJson(item))
        .toList();
  }

  /// Get total manual income for a community
  Future<double> getTotalManualIncome(String communityId) async {
    final response = await _client
        .from('manual_income')
        .select('amount')
        .eq('community_id', communityId);

    double total = 0;
    for (final row in response as List) {
      total += (row['amount'] as num).toDouble();
    }
    return total;
  }

  /// Create a manual income entry (staff only)
  Future<String> createManualIncome({
    required String communityId,
    required IncomeCategory category,
    required String description,
    required double amount,
    required DateTime incomeDate,
    String? source,
    String? receiptUrl,
    String? notes,
    Map<String, dynamic>? metadata,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    final response = await _client
        .from('manual_income')
        .insert({
          'community_id': communityId,
          'created_by': userId,
          'category': category.name,
          'description': description,
          'amount': amount,
          'currency': 'PHP',
          'income_date': incomeDate.toIso8601String().split('T').first,
          if (source != null) 'source': source,
          if (receiptUrl != null) 'receipt_url': receiptUrl,
          if (notes != null) 'notes': notes,
          if (metadata != null) 'metadata': metadata,
        })
        .select()
        .single();

    return response['id'] as String;
  }

  /// Delete a manual income entry (staff only)
  Future<void> deleteManualIncome(String id) async {
    await _client.from('manual_income').delete().eq('id', id);
  }
}
