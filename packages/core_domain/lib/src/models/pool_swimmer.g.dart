// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pool_swimmer.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PoolSwimmer _$PoolSwimmerFromJson(Map<String, dynamic> json) => PoolSwimmer(
      id: json['id'] as String,
      registrationId: json['registration_id'] as String,
      fullName: json['full_name'] as String,
      birthdate: json['birthdate'] == null
          ? null
          : DateTime.parse(json['birthdate'] as String),
      sortOrder: (json['sort_order'] as num).toInt(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$PoolSwimmerToJson(PoolSwimmer instance) =>
    <String, dynamic>{
      'id': instance.id,
      'registration_id': instance.registrationId,
      'full_name': instance.fullName,
      'birthdate': instance.birthdate?.toIso8601String(),
      'sort_order': instance.sortOrder,
      'created_at': instance.createdAt.toIso8601String(),
    };
