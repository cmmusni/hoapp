// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'community.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Community _$CommunityFromJson(Map<String, dynamic> json) => Community(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      address: json['address'] as String?,
      settings: json['settings'] as Map<String, dynamic>?,
      plan: json['plan'] as String? ?? 'starter',
      planExpiresAt: json['plan_expires_at'] == null
          ? null
          : DateTime.parse(json['plan_expires_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$CommunityToJson(Community instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'slug': instance.slug,
      'address': instance.address,
      'settings': instance.settings,
      'plan': instance.plan,
      'plan_expires_at': instance.planExpiresAt?.toIso8601String(),
      'created_at': instance.createdAt.toIso8601String(),
    };
