// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'household_member.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HouseholdMember _$HouseholdMemberFromJson(Map<String, dynamic> json) =>
    HouseholdMember(
      id: json['id'] as String,
      communityId: json['community_id'] as String,
      unitId: json['unit_id'] as String,
      userId: json['user_id'] as String?,
      memberName: json['member_name'] as String?,
      memberRole: $enumDecode(_$MemberRoleEnumMap, json['member_role']),
      relationship: json['relationship'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      userName: json['user_name'] as String?,
      userEmail: json['user_email'] as String?,
    );

Map<String, dynamic> _$HouseholdMemberToJson(HouseholdMember instance) =>
    <String, dynamic>{
      'id': instance.id,
      'community_id': instance.communityId,
      'unit_id': instance.unitId,
      'user_id': instance.userId,
      'member_name': instance.memberName,
      'member_role': _$MemberRoleEnumMap[instance.memberRole]!,
      'relationship': instance.relationship,
      'created_at': instance.createdAt.toIso8601String(),
      'user_name': instance.userName,
      'user_email': instance.userEmail,
    };

const _$MemberRoleEnumMap = {
  MemberRole.primary: 'primary',
  MemberRole.member: 'member',
  MemberRole.child: 'child',
  MemberRole.tenant: 'tenant',
  MemberRole.other: 'other',
};
