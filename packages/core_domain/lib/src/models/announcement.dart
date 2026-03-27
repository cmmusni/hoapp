import 'package:json_annotation/json_annotation.dart';

part 'announcement.g.dart';

@JsonSerializable()
class Announcement {
  final String id;

  @JsonKey(name: 'community_id')
  final String communityId;

  final String title;
  final String body;
  final bool pinned;

  @JsonKey(name: 'publish_at')
  final DateTime publishAt;

  @JsonKey(name: 'created_by')
  final String createdBy;

  @JsonKey(name: 'image_url')
  final String? imageUrl;

  @JsonKey(name: 'attachment_url')
  final String? attachmentUrl;

  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  Announcement({
    required this.id,
    required this.communityId,
    required this.title,
    required this.body,
    required this.pinned,
    required this.publishAt,
    required this.createdBy,
    this.imageUrl,
    this.attachmentUrl,
    required this.createdAt,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) =>
      _$AnnouncementFromJson(json);

  Map<String, dynamic> toJson() => _$AnnouncementToJson(this);
}
