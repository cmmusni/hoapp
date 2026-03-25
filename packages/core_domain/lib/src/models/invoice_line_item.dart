class InvoiceLineItem {
  final String id;
  final String invoiceId;
  final String label;
  final double amount;
  final Map<String, dynamic>? metadata;
  final int sortOrder;
  final DateTime createdAt;

  InvoiceLineItem({
    required this.id,
    required this.invoiceId,
    required this.label,
    required this.amount,
    this.metadata,
    this.sortOrder = 0,
    required this.createdAt,
  });

  factory InvoiceLineItem.fromJson(Map<String, dynamic> json) {
    return InvoiceLineItem(
      id: json['id'] as String,
      invoiceId: json['invoice_id'] as String,
      label: json['label'] as String,
      amount: (json['amount'] as num).toDouble(),
      metadata: json['metadata'] as Map<String, dynamic>?,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'invoice_id': invoiceId,
        'label': label,
        'amount': amount,
        'metadata': metadata,
        'sort_order': sortOrder,
        'created_at': createdAt.toIso8601String(),
      };
}
