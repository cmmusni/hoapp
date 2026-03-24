// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'amenity.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Amenity _$AmenityFromJson(Map<String, dynamic> json) => Amenity(
      id: json['id'] as String,
      communityId: json['community_id'] as String,
      name: json['name'] as String,
      rules: json['rules'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$AmenityToJson(Amenity instance) => <String, dynamic>{
      'id': instance.id,
      'community_id': instance.communityId,
      'name': instance.name,
      'rules': instance.rules,
      'created_at': instance.createdAt.toIso8601String(),
    };
