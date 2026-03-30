// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'unit_type.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UnitType _$UnitTypeFromJson(Map<String, dynamic> json) => UnitType(
      id: json['id'] as String,
      communityId: json['community_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      maxPax: (json['max_pax'] as num?)?.toInt() ?? 5,
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$UnitTypeToJson(UnitType instance) => <String, dynamic>{
      'id': instance.id,
      'community_id': instance.communityId,
      'name': instance.name,
      'description': instance.description,
      'max_pax': instance.maxPax,
      'created_at': instance.createdAt.toIso8601String(),
    };
