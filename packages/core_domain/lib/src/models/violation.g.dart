// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'violation.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Violation _$ViolationFromJson(Map<String, dynamic> json) => Violation(
      id: json['id'] as String,
      communityId: json['community_id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      status: $enumDecode(_$ViolationStatusEnumMap, json['status']),
      reporterUserId: json['reporter_user_id'] as String?,
      attachments: json['attachments'] as List<dynamic>?,
      staffNotes: json['staff_notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$ViolationToJson(Violation instance) => <String, dynamic>{
      'id': instance.id,
      'community_id': instance.communityId,
      'title': instance.title,
      'body': instance.body,
      'status': _$ViolationStatusEnumMap[instance.status]!,
      'reporter_user_id': instance.reporterUserId,
      'attachments': instance.attachments,
      'staff_notes': instance.staffNotes,
      'created_at': instance.createdAt.toIso8601String(),
    };

const _$ViolationStatusEnumMap = {
  ViolationStatus.newStatus: 'new',
  ViolationStatus.underReview: 'under_review',
  ViolationStatus.resolved: 'resolved',
};
