enum IncomeCategory {
  dues,
  water,
  amenity,
  insurance,
  rental,
  fee,
  donation,
  other,
}

class ManualIncome {
  final String id;
  final String communityId;
  final String createdBy;
  final IncomeCategory category;
  final String description;
  final double amount;
  final String currency;
  final DateTime incomeDate;
  final String? source;
  final String? receiptUrl;
  final String? notes;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  ManualIncome({
    required this.id,
    required this.communityId,
    required this.createdBy,
    required this.category,
    required this.description,
    required this.amount,
    required this.currency,
    required this.incomeDate,
    this.source,
    this.receiptUrl,
    this.notes,
    this.metadata,
    required this.createdAt,
  });

  factory ManualIncome.fromJson(Map<String, dynamic> json) {
    return ManualIncome(
      id: json['id'] as String,
      communityId: json['community_id'] as String,
      createdBy: json['created_by'] as String,
      category: IncomeCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => IncomeCategory.other,
      ),
      description: json['description'] as String,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'PHP',
      incomeDate: DateTime.parse(json['income_date'] as String),
      source: json['source'] as String?,
      receiptUrl: json['receipt_url'] as String?,
      notes: json['notes'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'community_id': communityId,
        'created_by': createdBy,
        'category': category.name,
        'description': description,
        'amount': amount,
        'currency': currency,
        'income_date': incomeDate.toIso8601String().split('T').first,
        'source': source,
        'receipt_url': receiptUrl,
        'notes': notes,
        'metadata': metadata,
        'created_at': createdAt.toIso8601String(),
      };
}
