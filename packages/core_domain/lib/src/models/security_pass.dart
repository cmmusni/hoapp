import 'package:json_annotation/json_annotation.dart';

part 'security_pass.g.dart';

enum PassStatus {
  @JsonValue('draft')
  draft,
  @JsonValue('submitted')
  submitted,
  @JsonValue('pending_review')
  pendingReview,
  @JsonValue('approved')
  approved,
  @JsonValue('active')
  active,
  @JsonValue('used')
  used,
  @JsonValue('expired')
  expired,
  @JsonValue('revoked')
  revoked,
  @JsonValue('rejected')
  rejected,
}

@JsonSerializable()
class PassType {
  final String id;

  @JsonKey(name: 'community_id')
  final String communityId;

  final String name;
  final String slug;
  final String? description;

  @JsonKey(name: 'approval_required')
  final bool approvalRequired;

  @JsonKey(name: 'max_validity_hours')
  final int maxValidityHours;

  @JsonKey(name: 'multi_use')
  final bool multiUse;

  @JsonKey(name: 'max_uses')
  final int maxUses;

  @JsonKey(name: 'vehicle_required')
  final bool vehicleRequired;

  @JsonKey(name: 'attachment_required')
  final bool attachmentRequired;

  @JsonKey(name: 'lead_time_hours')
  final int leadTimeHours;

  @JsonKey(name: 'grace_period_hours')
  final int gracePeriodHours;

  final bool active;

  @JsonKey(name: 'sort_order')
  final int sortOrder;

  PassType({
    required this.id,
    required this.communityId,
    required this.name,
    required this.slug,
    this.description,
    this.approvalRequired = true,
    this.maxValidityHours = 24,
    this.multiUse = false,
    this.maxUses = 1,
    this.vehicleRequired = false,
    this.attachmentRequired = false,
    this.leadTimeHours = 0,
    this.gracePeriodHours = 2,
    this.active = true,
    this.sortOrder = 0,
  });

  factory PassType.fromJson(Map<String, dynamic> json) =>
      _$PassTypeFromJson(json);
  Map<String, dynamic> toJson() => _$PassTypeToJson(this);
}

@JsonSerializable()
class SecurityPass {
  final String id;

  @JsonKey(name: 'community_id')
  final String communityId;

  @JsonKey(name: 'pass_type_id')
  final String passTypeId;

  @JsonKey(name: 'requested_by')
  final String requestedBy;

  final PassStatus status;

  @JsonKey(name: 'visitor_name')
  final String? visitorName;

  @JsonKey(name: 'visitor_phone')
  final String? visitorPhone;

  @JsonKey(name: 'visitor_email')
  final String? visitorEmail;

  final String? purpose;

  @JsonKey(name: 'company_name')
  final String? companyName;

  @JsonKey(name: 'plate_number')
  final String? plateNumber;

  @JsonKey(name: 'vehicle_description')
  final String? vehicleDescription;

  @JsonKey(name: 'items_description')
  final String? itemsDescription;

  @JsonKey(name: 'valid_from')
  final DateTime validFrom;

  @JsonKey(name: 'valid_until')
  final DateTime validUntil;

  @JsonKey(name: 'max_uses')
  final int maxUses;

  @JsonKey(name: 'use_count')
  final int useCount;

  @JsonKey(name: 'qr_token')
  final String? qrToken;

  @JsonKey(name: 'qr_generated_at')
  final DateTime? qrGeneratedAt;

  @JsonKey(name: 'reviewed_by')
  final String? reviewedBy;

  @JsonKey(name: 'reviewed_at')
  final DateTime? reviewedAt;

  @JsonKey(name: 'rejection_reason')
  final String? rejectionReason;

  final List<String>? attachments;

  final String? notes;

  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  // Joined fields (nullable — only present when joined)
  @JsonKey(name: 'pass_types')
  final PassType? passType;

  @JsonKey(name: 'requester_name')
  final String? requesterName;

  @JsonKey(name: 'unit_no')
  final String? unitNo;

  SecurityPass({
    required this.id,
    required this.communityId,
    required this.passTypeId,
    required this.requestedBy,
    this.status = PassStatus.submitted,
    this.visitorName,
    this.visitorPhone,
    this.visitorEmail,
    this.purpose,
    this.companyName,
    this.plateNumber,
    this.vehicleDescription,
    this.itemsDescription,
    required this.validFrom,
    required this.validUntil,
    this.maxUses = 1,
    this.useCount = 0,
    this.qrToken,
    this.qrGeneratedAt,
    this.reviewedBy,
    this.reviewedAt,
    this.rejectionReason,
    this.attachments,
    this.notes,
    required this.createdAt,
    this.updatedAt,
    this.passType,
    this.requesterName,
    this.unitNo,
  });

  factory SecurityPass.fromJson(Map<String, dynamic> json) =>
      _$SecurityPassFromJson(json);
  Map<String, dynamic> toJson() => _$SecurityPassToJson(this);

  bool get isExpired => DateTime.now().isAfter(validUntil);
  bool get isActive =>
      status == PassStatus.active || status == PassStatus.approved;
  bool get isUsedUp => maxUses > 0 && useCount >= maxUses;
}

@JsonSerializable()
class PassScanLog {
  final String id;

  @JsonKey(name: 'pass_id')
  final String passId;

  @JsonKey(name: 'community_id')
  final String communityId;

  @JsonKey(name: 'scanned_by')
  final String scannedBy;

  @JsonKey(name: 'scan_type')
  final String scanType;

  @JsonKey(name: 'scan_result')
  final String scanResult;

  final String? notes;

  @JsonKey(name: 'scanned_at')
  final DateTime scannedAt;

  PassScanLog({
    required this.id,
    required this.passId,
    required this.communityId,
    required this.scannedBy,
    required this.scanType,
    required this.scanResult,
    this.notes,
    required this.scannedAt,
  });

  factory PassScanLog.fromJson(Map<String, dynamic> json) =>
      _$PassScanLogFromJson(json);
  Map<String, dynamic> toJson() => _$PassScanLogToJson(this);
}
