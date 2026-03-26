// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pool_access.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PoolAccessRegistration _$PoolAccessRegistrationFromJson(
        Map<String, dynamic> json) =>
    PoolAccessRegistration(
      id: json['id'] as String,
      communityId: json['community_id'] as String,
      userId: json['user_id'] as String,
      unitId: json['unit_id'] as String?,
      occupantType: $enumDecode(_$OccupantTypeEnumMap, json['occupant_type']),
      fullName: json['full_name'] as String,
      phone: json['phone'] as String,
      email: json['email'] as String,
      birthdate: json['birthdate'] == null
          ? null
          : DateTime.parse(json['birthdate'] as String),
      emergencyContactName: json['emergency_contact_name'] as String,
      emergencyContactPhone: json['emergency_contact_phone'] as String,
      idDocUrl: json['id_doc_url'] as String?,
      signatureUrl: json['signature_url'] as String?,
      acknowledgements: json['acknowledgements'] as Map<String, dynamic>?,
      rulesVersion: json['rules_version'] as String,
      approved: json['approved'] as bool,
      approvedBy: json['approved_by'] as String?,
      approvedAt: json['approved_at'] == null
          ? null
          : DateTime.parse(json['approved_at'] as String),
      maxPax: (json['max_pax'] as num?)?.toInt() ?? 5,
      lastEditedAt: DateTime.parse(json['last_edited_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$PoolAccessRegistrationToJson(
        PoolAccessRegistration instance) =>
    <String, dynamic>{
      'id': instance.id,
      'community_id': instance.communityId,
      'user_id': instance.userId,
      'unit_id': instance.unitId,
      'occupant_type': _$OccupantTypeEnumMap[instance.occupantType]!,
      'full_name': instance.fullName,
      'phone': instance.phone,
      'email': instance.email,
      'birthdate': instance.birthdate?.toIso8601String(),
      'emergency_contact_name': instance.emergencyContactName,
      'emergency_contact_phone': instance.emergencyContactPhone,
      'id_doc_url': instance.idDocUrl,
      'signature_url': instance.signatureUrl,
      'acknowledgements': instance.acknowledgements,
      'rules_version': instance.rulesVersion,
      'approved': instance.approved,
      'approved_by': instance.approvedBy,
      'approved_at': instance.approvedAt?.toIso8601String(),
      'max_pax': instance.maxPax,
      'last_edited_at': instance.lastEditedAt.toIso8601String(),
      'created_at': instance.createdAt.toIso8601String(),
    };

const _$OccupantTypeEnumMap = {
  OccupantType.resident: 'resident',
  OccupantType.tenant: 'tenant',
};
