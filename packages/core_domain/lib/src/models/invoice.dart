import 'package:json_annotation/json_annotation.dart';

part 'invoice.g.dart';

enum InvoiceCategory {
  @JsonValue('dues')
  dues,
  @JsonValue('water')
  water,
  @JsonValue('amenity')
  amenity,
  @JsonValue('insurance')
  insurance,
  @JsonValue('other')
  other,
}

enum InvoiceStatus {
  @JsonValue('unpaid')
  unpaid,
  @JsonValue('paid')
  paid,
  @JsonValue('void')
  void_,
  @JsonValue('refunded')
  refunded,
}

@JsonSerializable()
class Invoice {
  final String id;

  @JsonKey(name: 'community_id')
  final String communityId;

  @JsonKey(name: 'unit_id')
  final String unitId;

  final InvoiceCategory category;

  @JsonKey(name: 'source_id')
  final String? sourceId;

  final String currency;
  final double amount;

  @JsonKey(name: 'due_date')
  final DateTime dueDate;

  final InvoiceStatus status;
  final Map<String, dynamic>? metadata;

  final String? description;

  @JsonKey(name: 'period_start')
  final DateTime? periodStart;

  @JsonKey(name: 'period_end')
  final DateTime? periodEnd;

  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  @JsonKey(name: 'created_by')
  final String? createdBy;

  Invoice({
    required this.id,
    required this.communityId,
    required this.unitId,
    required this.category,
    this.sourceId,
    required this.currency,
    required this.amount,
    required this.dueDate,
    required this.status,
    this.metadata,
    this.description,
    this.periodStart,
    this.periodEnd,
    required this.createdAt,
    this.createdBy,
  });

  factory Invoice.fromJson(Map<String, dynamic> json) =>
      _$InvoiceFromJson(json);

  Map<String, dynamic> toJson() => _$InvoiceToJson(this);

  bool get isOverdue =>
      status == InvoiceStatus.unpaid && DateTime.now().isAfter(dueDate);

  // Additional getters for UI compatibility
  DateTime? get paidAt => metadata?['paid_at'] != null
      ? DateTime.tryParse(metadata!['paid_at'] as String)
      : null;
  String get type => category.name;
  String? get unitNumber => metadata?['unit_number'] as String?;
  String? get notes => metadata?['notes'] as String?;
}
