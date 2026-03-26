// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_role.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserRole _$UserRoleFromJson(Map<String, dynamic> json) => UserRole(
      id: (json['id'] as num).toInt(),
      userId: json['user_id'] as String,
      communityId: json['community_id'] as String,
      role: $enumDecode(_$RoleEnumMap, json['role']),
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$UserRoleToJson(UserRole instance) => <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'community_id': instance.communityId,
      'role': _$RoleEnumMap[instance.role]!,
      'created_at': instance.createdAt.toIso8601String(),
    };

const _$RoleEnumMap = {
  Role.communityAdmin: 'community_admin',
  Role.hoaOfficer: 'hoa_officer',
  Role.guard: 'guard',
  Role.resident: 'resident',
  Role.maintenance: 'maintenance',
};
