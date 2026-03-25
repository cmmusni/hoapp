// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'announcement.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Announcement _$AnnouncementFromJson(Map<String, dynamic> json) => Announcement(
      id: json['id'] as String,
      communityId: json['community_id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      pinned: json['pinned'] as bool,
      publishAt: DateTime.parse(json['publish_at'] as String),
      createdBy: json['created_by'] as String,
      imageUrl: json['image_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$AnnouncementToJson(Announcement instance) =>
    <String, dynamic>{
      'id': instance.id,
      'community_id': instance.communityId,
      'title': instance.title,
      'body': instance.body,
      'pinned': instance.pinned,
      'publish_at': instance.publishAt.toIso8601String(),
      'created_by': instance.createdBy,
      'image_url': instance.imageUrl,
      'created_at': instance.createdAt.toIso8601String(),
    };
