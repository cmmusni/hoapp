import 'package:json_annotation/json_annotation.dart';

part 'payment.g.dart';

enum PaymentStatus {
  @JsonValue('submitted')
  submitted,
  @JsonValue('verified')
  verified,
  @JsonValue('rejected')
  rejected,
}

@JsonSerializable()
class Payment {
  final String id;
  
  @JsonKey(name: 'community_id')
  final String communityId;
  
  @JsonKey(name: 'invoice_id')
  final String invoiceId;
  
  @JsonKey(name: 'user_id')
  final String userId;
  
  final String method;
  final double amount;
  final String currency;
  final PaymentStatus status;
  
  @JsonKey(name: 'proof_url')
  final String? proofUrl;
  
  @JsonKey(name: 'receipt_url')
  final String? receiptUrl;
  
  @JsonKey(name: 'verified_by')
  final String? verifiedBy;
  
  @JsonKey(name: 'verified_at')
  final DateTime? verifiedAt;
  
  @JsonKey(name: 'rejection_reason')
  final String? rejectionReason;
  
  @JsonKey(name: 'posted_at')
  final DateTime postedAt;
  
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  Payment({
    required this.id,
    required this.communityId,
    required this.invoiceId,
    required this.userId,
    required this.method,
    required this.amount,
    required this.currency,
    required this.status,
    this.proofUrl,
    this.receiptUrl,
    this.verifiedBy,
    this.verifiedAt,
    this.rejectionReason,
    required this.postedAt,
    required this.createdAt,
  });

  factory Payment.fromJson(Map<String, dynamic> json) =>
      _$PaymentFromJson(json);

  Map<String, dynamic> toJson() => _$PaymentToJson(this);
  
  // Getter for UI compatibility
  String? get referenceNumber => null; // Not in current schema
}
