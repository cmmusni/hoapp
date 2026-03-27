enum RecurringFrequency {
  monthly,
  quarterly,
  yearly,
}

class RecurringBilling {
  final String id;
  final String communityId;
  final String? unitId;
  final String category;
  final String? description;
  final double amount;
  final String currency;
  final RecurringFrequency frequency;
  final int dayOfMonth;
  final int dueDayOffset;
  final bool isActive;
  final bool applyToAll;
  final List<Map<String, dynamic>>? lineItems;
  final DateTime nextRunDate;
  final DateTime? lastRunDate;
  final String? notes;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Attached at query time for display
  final String? unitNumber;

  RecurringBilling({
    required this.id,
    required this.communityId,
    this.unitId,
    required this.category,
    this.description,
    required this.amount,
    required this.currency,
    required this.frequency,
    required this.dayOfMonth,
    required this.dueDayOffset,
    required this.isActive,
    required this.applyToAll,
    this.lineItems,
    required this.nextRunDate,
    this.lastRunDate,
    this.notes,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.unitNumber,
  });

  factory RecurringBilling.fromJson(Map<String, dynamic> json) {
    return RecurringBilling(
      id: json['id'] as String,
      communityId: json['community_id'] as String,
      unitId: json['unit_id'] as String?,
      category: json['category'] as String,
      description: json['description'] as String?,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'PHP',
      frequency: RecurringFrequency.values.firstWhere(
        (e) => e.name == json['frequency'],
        orElse: () => RecurringFrequency.monthly,
      ),
      dayOfMonth: json['day_of_month'] as int? ?? 1,
      dueDayOffset: json['due_day_offset'] as int? ?? 15,
      isActive: json['is_active'] as bool? ?? true,
      applyToAll: json['apply_to_all'] as bool? ?? false,
      lineItems: json['line_items'] != null
          ? List<Map<String, dynamic>>.from(json['line_items'] as List)
          : null,
      nextRunDate: DateTime.parse(json['next_run_date'] as String),
      lastRunDate: json['last_run_date'] != null
          ? DateTime.parse(json['last_run_date'] as String)
          : null,
      notes: json['notes'] as String?,
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      unitNumber: json['units'] != null
          ? (json['units'] as Map<String, dynamic>)['unit_no'] as String?
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'community_id': communityId,
        'unit_id': unitId,
        'category': category,
        'description': description,
        'amount': amount,
        'currency': currency,
        'frequency': frequency.name,
        'day_of_month': dayOfMonth,
        'due_day_offset': dueDayOffset,
        'is_active': isActive,
        'apply_to_all': applyToAll,
        'line_items': lineItems,
        'next_run_date': nextRunDate.toIso8601String().split('T').first,
        'last_run_date': lastRunDate?.toIso8601String().split('T').first,
        'notes': notes,
        'created_by': createdBy,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  String get frequencyLabel {
    switch (frequency) {
      case RecurringFrequency.monthly:
        return 'Monthly';
      case RecurringFrequency.quarterly:
        return 'Quarterly';
      case RecurringFrequency.yearly:
        return 'Yearly';
    }
  }

  String get categoryLabel {
    switch (category) {
      case 'dues':
        return 'Monthly Dues';
      case 'water':
        return 'Water';
      case 'amenity':
        return 'Amenity';
      case 'insurance':
        return 'Insurance';
      case 'other':
        return 'Other';
      default:
        return category;
    }
  }

  bool get isDue =>
      isActive &&
      DateTime.now().isAfter(nextRunDate.subtract(const Duration(days: 1)));
}
