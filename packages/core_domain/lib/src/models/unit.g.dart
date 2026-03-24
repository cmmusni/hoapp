// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'unit.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Unit _$UnitFromJson(Map<String, dynamic> json) => Unit(
      id: json['id'] as String,
      communityId: json['community_id'] as String,
      buildingId: json['building_id'] as String?,
      unitNo: json['unit_no'] as String,
      unitType: json['unit_type'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$UnitToJson(Unit instance) => <String, dynamic>{
      'id': instance.id,
      'community_id': instance.communityId,
      'building_id': instance.buildingId,
      'unit_no': instance.unitNo,
      'unit_type': instance.unitType,
      'created_at': instance.createdAt.toIso8601String(),
    };
