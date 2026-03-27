import 'package:core_domain/core_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_client.dart';

class ExpenseRepository {
  final SupabaseClient _client = SupabaseClientManager.instance;

  /// Get all expenses for a community (staff only via RLS)
  Future<List<Expense>> getExpenses(
    String communityId, {
    String? searchQuery,
    ExpenseCategory? category,
    int? limit,
    int? offset,
  }) async {
    var query =
        _client.from('expenses').select().eq('community_id', communityId);

    if (category != null) {
      query = query.eq('category', category.name);
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      query = query
          .or('description.ilike.%$searchQuery%,vendor.ilike.%$searchQuery%');
    }

    var finalQuery = query.order('expense_date', ascending: false);

    if (limit != null && offset != null) {
      finalQuery = finalQuery.limit(limit).range(offset, offset + limit - 1);
    } else if (limit != null) {
      finalQuery = finalQuery.limit(limit);
    }

    final response = await finalQuery;

    return (response as List).map((item) => Expense.fromJson(item)).toList();
  }

  /// Get total count of expenses
  Future<int> getExpensesCount(
    String communityId, {
    String? searchQuery,
    ExpenseCategory? category,
  }) async {
    var query =
        _client.from('expenses').select('id').eq('community_id', communityId);

    if (category != null) {
      query = query.eq('category', category.name);
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      query = query
          .or('description.ilike.%$searchQuery%,vendor.ilike.%$searchQuery%');
    }

    final response = await query;
    return (response as List).length;
  }

  /// Create an expense (staff only)
  Future<String> createExpense({
    required String communityId,
    required ExpenseCategory category,
    required String description,
    required double amount,
    required DateTime expenseDate,
    String? vendor,
    String? receiptUrl,
    String? notes,
    Map<String, dynamic>? metadata,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    final response = await _client
        .from('expenses')
        .insert({
          'community_id': communityId,
          'created_by': userId,
          'category': category.name,
          'description': description,
          'amount': amount,
          'currency': 'PHP',
          'expense_date': expenseDate.toIso8601String().split('T').first,
          if (vendor != null) 'vendor': vendor,
          if (receiptUrl != null) 'receipt_url': receiptUrl,
          if (notes != null) 'notes': notes,
          if (metadata != null) 'metadata': metadata,
        })
        .select()
        .single();

    return response['id'] as String;
  }

  /// Update an expense (staff only)
  Future<void> updateExpense({
    required String id,
    ExpenseCategory? category,
    String? description,
    double? amount,
    DateTime? expenseDate,
    String? vendor,
    String? receiptUrl,
    String? notes,
  }) async {
    final updates = <String, dynamic>{};
    if (category != null) updates['category'] = category.name;
    if (description != null) updates['description'] = description;
    if (amount != null) updates['amount'] = amount;
    if (expenseDate != null) {
      updates['expense_date'] = expenseDate.toIso8601String().split('T').first;
    }
    if (vendor != null) updates['vendor'] = vendor;
    if (receiptUrl != null) updates['receipt_url'] = receiptUrl;
    if (notes != null) updates['notes'] = notes;

    if (updates.isNotEmpty) {
      await _client.from('expenses').update(updates).eq('id', id);
    }
  }

  /// Delete an expense (staff only)
  Future<void> deleteExpense(String id) async {
    await _client.from('expenses').delete().eq('id', id);
  }
}
