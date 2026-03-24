import 'package:json_annotation/json_annotation.dart';

part 'pool_access.g.dart';

enum OccupantType {
  @JsonValue('resident')
  resident,
  @JsonValue('tenant')
  tenant,
}

@JsonSerializable()
class PoolAccessRegistration {
  final String id;
  
  @JsonKey(name: 'community_id')
  final String communityId;
  
  @JsonKey(name: 'user_id')
  final String userId;
  
  @JsonKey(name: 'unit_id')
  final String? unitId;
  
  @JsonKey(name: 'occupant_type')
  final OccupantType occupantType;
  
  @JsonKey(name: 'full_name')
  final String fullName;
  
  final String phone;
  final String email;
  final DateTime? birthdate;
  
  @JsonKey(name: 'emergency_contact_name')
  final String emergencyContactName;
  
  @JsonKey(name: 'emergency_contact_phone')
  final String emergencyContactPhone;
  
  @JsonKey(name: 'id_doc_url')
  final String? idDocUrl;
  
  @JsonKey(name: 'signature_url')
  final String? signatureUrl;
  
  final Map<String, dynamic>? acknowledgements;
  
  @JsonKey(name: 'rules_version')
  final String rulesVersion;
  
  final bool approved;
  
  @JsonKey(name: 'approved_by')
  final String? approvedBy;
  
  @JsonKey(name: 'approved_at')
  final DateTime? approvedAt;
  
  @JsonKey(name: 'last_edited_at')
  final DateTime lastEditedAt;
  
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  PoolAccessRegistration({
    required this.id,
    required this.communityId,
    required this.userId,
    this.unitId,
    required this.occupantType,
    required this.fullName,
    required this.phone,
    required this.email,
    this.birthdate,
    required this.emergencyContactName,
    required this.emergencyContactPhone,
    this.idDocUrl,
    this.signatureUrl,
    this.acknowledgements,
    required this.rulesVersion,
    required this.approved,
    this.approvedBy,
    this.approvedAt,
    required this.lastEditedAt,
    required this.createdAt,
  });

  factory PoolAccessRegistration.fromJson(Map<String, dynamic> json) =>
      _$PoolAccessRegistrationFromJson(json);

  Map<String, dynamic> toJson() => _$PoolAccessRegistrationToJson(this);
  
  // Aliases for UI compatibility
  String get phoneNumber => phone;
  String? get emergencyContactRelationship => null; // Not in current schema
  String? get signedDocumentUrl => signatureUrl;
  
  // Edit lock functionality (3-month rule)
  DateTime get nextEditableDate =>
      lastEditedAt.add(const Duration(days: 90));

  bool get canEdit => DateTime.now().isAfter(nextEditableDate);
}
