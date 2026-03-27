enum ExpenseCategory {
  maintenance,
  utilities,
  supplies,
  services,
  repairs,
  salaries,
  insurance,
  taxes,
  other,
}

class Expense {
  final String id;
  final String communityId;
  final String createdBy;
  final ExpenseCategory category;
  final String description;
  final double amount;
  final String currency;
  final DateTime expenseDate;
  final String? vendor;
  final String? receiptUrl;
  final String? notes;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  Expense({
    required this.id,
    required this.communityId,
    required this.createdBy,
    required this.category,
    required this.description,
    required this.amount,
    required this.currency,
    required this.expenseDate,
    this.vendor,
    this.receiptUrl,
    this.notes,
    this.metadata,
    required this.createdAt,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] as String,
      communityId: json['community_id'] as String,
      createdBy: json['created_by'] as String,
      category: ExpenseCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => ExpenseCategory.other,
      ),
      description: json['description'] as String,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'PHP',
      expenseDate: DateTime.parse(json['expense_date'] as String),
      vendor: json['vendor'] as String?,
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
        'expense_date': expenseDate.toIso8601String().split('T').first,
        'vendor': vendor,
        'receipt_url': receiptUrl,
        'notes': notes,
        'metadata': metadata,
        'created_at': createdAt.toIso8601String(),
      };
}
