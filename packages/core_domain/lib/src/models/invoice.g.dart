// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'invoice.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Invoice _$InvoiceFromJson(Map<String, dynamic> json) => Invoice(
      id: json['id'] as String,
      communityId: json['community_id'] as String,
      unitId: json['unit_id'] as String,
      category: $enumDecode(_$InvoiceCategoryEnumMap, json['category']),
      sourceId: json['source_id'] as String?,
      currency: json['currency'] as String,
      amount: (json['amount'] as num).toDouble(),
      dueDate: DateTime.parse(json['due_date'] as String),
      status: $enumDecode(_$InvoiceStatusEnumMap, json['status']),
      metadata: json['metadata'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$InvoiceToJson(Invoice instance) => <String, dynamic>{
      'id': instance.id,
      'community_id': instance.communityId,
      'unit_id': instance.unitId,
      'category': _$InvoiceCategoryEnumMap[instance.category]!,
      'source_id': instance.sourceId,
      'currency': instance.currency,
      'amount': instance.amount,
      'due_date': instance.dueDate.toIso8601String(),
      'status': _$InvoiceStatusEnumMap[instance.status]!,
      'metadata': instance.metadata,
      'created_at': instance.createdAt.toIso8601String(),
    };

const _$InvoiceCategoryEnumMap = {
  InvoiceCategory.dues: 'dues',
  InvoiceCategory.amenity: 'amenity',
  InvoiceCategory.other: 'other',
};

const _$InvoiceStatusEnumMap = {
  InvoiceStatus.unpaid: 'unpaid',
  InvoiceStatus.paid: 'paid',
  InvoiceStatus.void_: 'void',
  InvoiceStatus.refunded: 'refunded',
};
