// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Payment _$PaymentFromJson(Map<String, dynamic> json) => Payment(
      id: json['id'] as String,
      communityId: json['community_id'] as String,
      invoiceId: json['invoice_id'] as String,
      userId: json['user_id'] as String,
      method: json['method'] as String,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String,
      status: $enumDecode(_$PaymentStatusEnumMap, json['status']),
      proofUrl: json['proof_url'] as String?,
      receiptUrl: json['receipt_url'] as String?,
      verifiedBy: json['verified_by'] as String?,
      verifiedAt: json['verified_at'] == null
          ? null
          : DateTime.parse(json['verified_at'] as String),
      rejectionReason: json['rejection_reason'] as String?,
      postedAt: DateTime.parse(json['posted_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$PaymentToJson(Payment instance) => <String, dynamic>{
      'id': instance.id,
      'community_id': instance.communityId,
      'invoice_id': instance.invoiceId,
      'user_id': instance.userId,
      'method': instance.method,
      'amount': instance.amount,
      'currency': instance.currency,
      'status': _$PaymentStatusEnumMap[instance.status]!,
      'proof_url': instance.proofUrl,
      'receipt_url': instance.receiptUrl,
      'verified_by': instance.verifiedBy,
      'verified_at': instance.verifiedAt?.toIso8601String(),
      'rejection_reason': instance.rejectionReason,
      'posted_at': instance.postedAt.toIso8601String(),
      'created_at': instance.createdAt.toIso8601String(),
    };

const _$PaymentStatusEnumMap = {
  PaymentStatus.submitted: 'submitted',
  PaymentStatus.verified: 'verified',
  PaymentStatus.rejected: 'rejected',
};
