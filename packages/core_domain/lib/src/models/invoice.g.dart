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
      description: json['description'] as String?,
      periodStart: json['period_start'] == null
          ? null
          : DateTime.parse(json['period_start'] as String),
      periodEnd: json['period_end'] == null
          ? null
          : DateTime.parse(json['period_end'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      createdBy: json['created_by'] as String?,
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
      'description': instance.description,
      'period_start': instance.periodStart?.toIso8601String(),
      'period_end': instance.periodEnd?.toIso8601String(),
      'created_at': instance.createdAt.toIso8601String(),
      'created_by': instance.createdBy,
    };

const _$InvoiceCategoryEnumMap = {
  InvoiceCategory.dues: 'dues',
  InvoiceCategory.water: 'water',
  InvoiceCategory.amenity: 'amenity',
  InvoiceCategory.insurance: 'insurance',
  InvoiceCategory.other: 'other',
};

const _$InvoiceStatusEnumMap = {
  InvoiceStatus.unpaid: 'unpaid',
  InvoiceStatus.paid: 'paid',
  InvoiceStatus.void_: 'void',
  InvoiceStatus.refunded: 'refunded',
};
