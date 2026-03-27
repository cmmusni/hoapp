import 'package:core_domain/core_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_client.dart';

class RecurringBillingRepository {
  final SupabaseClient _client = SupabaseClientManager.instance;

  /// Get all recurring billings for a community
  Future<List<RecurringBilling>> getRecurringBillings(
      String communityId) async {
    final response = await _client
        .from('recurring_billings')
        .select('*, units(unit_no)')
        .eq('community_id', communityId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((item) => RecurringBilling.fromJson(item))
        .toList();
  }

  /// Create a recurring billing template
  Future<String> createRecurringBilling({
    required String communityId,
    String? unitId,
    required String category,
    String? description,
    required double amount,
    required RecurringFrequency frequency,
    required int dayOfMonth,
    int dueDayOffset = 15,
    bool applyToAll = false,
    List<Map<String, dynamic>>? lineItems,
    required DateTime nextRunDate,
    String? notes,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    final response = await _client
        .from('recurring_billings')
        .insert({
          'community_id': communityId,
          'unit_id': applyToAll ? null : unitId,
          'category': category,
          'description': description,
          'amount': amount,
          'currency': 'PHP',
          'frequency': frequency.name,
          'day_of_month': dayOfMonth,
          'due_day_offset': dueDayOffset,
          'is_active': true,
          'apply_to_all': applyToAll,
          'line_items': lineItems,
          'next_run_date': nextRunDate.toIso8601String().split('T').first,
          'notes': notes,
          'created_by': userId,
        })
        .select()
        .single();

    return response['id'] as String;
  }

  /// Toggle active status
  Future<void> toggleActive(String id, bool isActive) async {
    await _client
        .from('recurring_billings')
        .update({'is_active': isActive}).eq('id', id);
  }

  /// Delete a recurring billing
  Future<void> deleteRecurringBilling(String id) async {
    await _client.from('recurring_billings').delete().eq('id', id);
  }

  /// Get all due recurring billings (next_run_date <= today and active)
  Future<List<RecurringBilling>> getDueRecurringBillings(
      String communityId) async {
    final today = DateTime.now().toIso8601String().split('T').first;
    final response = await _client
        .from('recurring_billings')
        .select('*, units(unit_no)')
        .eq('community_id', communityId)
        .eq('is_active', true)
        .lte('next_run_date', today)
        .order('next_run_date', ascending: true);

    return (response as List)
        .map((item) => RecurringBilling.fromJson(item))
        .toList();
  }

  /// Generate invoices for all due recurring billings in a community.
  /// Returns the number of invoices created.
  Future<int> generateDueInvoices(String communityId) async {
    final dueItems = await getDueRecurringBillings(communityId);
    if (dueItems.isEmpty) return 0;

    int count = 0;

    for (final billing in dueItems) {
      final targetUnits = <String>[];

      if (billing.applyToAll) {
        // Get all units in the community
        final units = await _client
            .from('units')
            .select('id')
            .eq('community_id', communityId);
        for (final u in (units as List)) {
          targetUnits.add(u['id'] as String);
        }
      } else if (billing.unitId != null) {
        targetUnits.add(billing.unitId!);
      }

      for (final unitId in targetUnits) {
        // Create the invoice
        final invoiceResponse = await _client
            .from('invoices')
            .insert({
              'community_id': communityId,
              'unit_id': unitId,
              'category': billing.category,
              'amount': billing.amount,
              'currency': billing.currency,
              'due_date': billing.nextRunDate
                  .add(Duration(days: billing.dueDayOffset))
                  .toIso8601String(),
              'status': 'unpaid',
              if (billing.description != null)
                'description': billing.description,
              'period_start':
                  billing.nextRunDate.toIso8601String().split('T').first,
              'period_end': _calculatePeriodEnd(billing)
                  .toIso8601String()
                  .split('T')
                  .first,
              'metadata': {
                if (billing.notes != null) 'notes': billing.notes,
                'recurring_billing_id': billing.id,
              },
            })
            .select()
            .single();

        final invoiceId = invoiceResponse['id'] as String;

        // Insert line items if defined
        if (billing.lineItems != null && billing.lineItems!.isNotEmpty) {
          final items = billing.lineItems!
              .asMap()
              .entries
              .map((e) => {
                    'invoice_id': invoiceId,
                    'label': e.value['label'],
                    'amount': e.value['amount'],
                    'sort_order': e.key,
                  })
              .toList();
          await _client.from('invoice_line_items').insert(items);
        }

        count++;
      }

      // Advance next_run_date
      final nextDate = _advanceDate(
          billing.nextRunDate, billing.frequency, billing.dayOfMonth);
      await _client.from('recurring_billings').update({
        'next_run_date': nextDate.toIso8601String().split('T').first,
        'last_run_date': billing.nextRunDate.toIso8601String().split('T').first,
      }).eq('id', billing.id);
    }

    return count;
  }

  DateTime _calculatePeriodEnd(RecurringBilling billing) {
    switch (billing.frequency) {
      case RecurringFrequency.monthly:
        final next = DateTime(billing.nextRunDate.year,
            billing.nextRunDate.month + 1, billing.dayOfMonth);
        return next.subtract(const Duration(days: 1));
      case RecurringFrequency.quarterly:
        final next = DateTime(billing.nextRunDate.year,
            billing.nextRunDate.month + 3, billing.dayOfMonth);
        return next.subtract(const Duration(days: 1));
      case RecurringFrequency.yearly:
        final next = DateTime(billing.nextRunDate.year + 1,
            billing.nextRunDate.month, billing.dayOfMonth);
        return next.subtract(const Duration(days: 1));
    }
  }

  DateTime _advanceDate(
      DateTime current, RecurringFrequency frequency, int dayOfMonth) {
    switch (frequency) {
      case RecurringFrequency.monthly:
        return DateTime(current.year, current.month + 1, dayOfMonth);
      case RecurringFrequency.quarterly:
        return DateTime(current.year, current.month + 3, dayOfMonth);
      case RecurringFrequency.yearly:
        return DateTime(current.year + 1, current.month, dayOfMonth);
    }
  }
}
