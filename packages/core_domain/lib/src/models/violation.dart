import 'package:json_annotation/json_annotation.dart';

part 'violation.g.dart';

enum ViolationStatus {
  @JsonValue('new')
  newStatus,
  @JsonValue('under_review')
  underReview,
  @JsonValue('resolved')
  resolved,
}

@JsonSerializable()
class Violation {
  final String id;
  
  @JsonKey(name: 'community_id')
  final String communityId;
  
  final String title;
  final String body;
  final ViolationStatus status;
  
  @JsonKey(name: 'reporter_user_id')
  final String? reporterUserId;
  
  final List<dynamic>? attachments;
  
  @JsonKey(name: 'staff_notes')
  final String? staffNotes;
  
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  Violation({
    required this.id,
    required this.communityId,
    required this.title,
    required this.body,
    required this.status,
    this.reporterUserId,
    this.attachments,
    this.staffNotes,
    required this.createdAt,
  });

  factory Violation.fromJson(Map<String, dynamic> json) =>
      _$ViolationFromJson(json);

  Map<String, dynamic> toJson() => _$ViolationToJson(this);
}
