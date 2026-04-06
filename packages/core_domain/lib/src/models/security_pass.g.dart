// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'security_pass.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PassType _$PassTypeFromJson(Map<String, dynamic> json) => PassType(
      id: json['id'] as String,
      communityId: json['community_id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      description: json['description'] as String?,
      approvalRequired: json['approval_required'] as bool? ?? true,
      maxValidityHours: (json['max_validity_hours'] as num?)?.toInt() ?? 24,
      multiUse: json['multi_use'] as bool? ?? false,
      maxUses: (json['max_uses'] as num?)?.toInt() ?? 1,
      vehicleRequired: json['vehicle_required'] as bool? ?? false,
      attachmentRequired: json['attachment_required'] as bool? ?? false,
      leadTimeHours: (json['lead_time_hours'] as num?)?.toInt() ?? 0,
      gracePeriodHours: (json['grace_period_hours'] as num?)?.toInt() ?? 2,
      active: json['active'] as bool? ?? true,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$PassTypeToJson(PassType instance) => <String, dynamic>{
      'id': instance.id,
      'community_id': instance.communityId,
      'name': instance.name,
      'slug': instance.slug,
      'description': instance.description,
      'approval_required': instance.approvalRequired,
      'max_validity_hours': instance.maxValidityHours,
      'multi_use': instance.multiUse,
      'max_uses': instance.maxUses,
      'vehicle_required': instance.vehicleRequired,
      'attachment_required': instance.attachmentRequired,
      'lead_time_hours': instance.leadTimeHours,
      'grace_period_hours': instance.gracePeriodHours,
      'active': instance.active,
      'sort_order': instance.sortOrder,
    };

SecurityPass _$SecurityPassFromJson(Map<String, dynamic> json) => SecurityPass(
      id: json['id'] as String,
      communityId: json['community_id'] as String,
      passTypeId: json['pass_type_id'] as String,
      requestedBy: json['requested_by'] as String,
      status: $enumDecodeNullable(_$PassStatusEnumMap, json['status']) ??
          PassStatus.submitted,
      visitorName: json['visitor_name'] as String?,
      visitorPhone: json['visitor_phone'] as String?,
      visitorEmail: json['visitor_email'] as String?,
      purpose: json['purpose'] as String?,
      companyName: json['company_name'] as String?,
      plateNumber: json['plate_number'] as String?,
      vehicleDescription: json['vehicle_description'] as String?,
      itemsDescription: json['items_description'] as String?,
      validFrom: DateTime.parse(json['valid_from'] as String),
      validUntil: DateTime.parse(json['valid_until'] as String),
      maxUses: (json['max_uses'] as num?)?.toInt() ?? 1,
      useCount: (json['use_count'] as num?)?.toInt() ?? 0,
      qrToken: json['qr_token'] as String?,
      qrGeneratedAt: json['qr_generated_at'] == null
          ? null
          : DateTime.parse(json['qr_generated_at'] as String),
      reviewedBy: json['reviewed_by'] as String?,
      reviewedAt: json['reviewed_at'] == null
          ? null
          : DateTime.parse(json['reviewed_at'] as String),
      rejectionReason: json['rejection_reason'] as String?,
      attachments: (json['attachments'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
      passType: json['pass_types'] == null
          ? null
          : PassType.fromJson(json['pass_types'] as Map<String, dynamic>),
      requesterName: json['requester_name'] as String?,
      unitNo: json['unit_no'] as String?,
    );

Map<String, dynamic> _$SecurityPassToJson(SecurityPass instance) =>
    <String, dynamic>{
      'id': instance.id,
      'community_id': instance.communityId,
      'pass_type_id': instance.passTypeId,
      'requested_by': instance.requestedBy,
      'status': _$PassStatusEnumMap[instance.status]!,
      'visitor_name': instance.visitorName,
      'visitor_phone': instance.visitorPhone,
      'visitor_email': instance.visitorEmail,
      'purpose': instance.purpose,
      'company_name': instance.companyName,
      'plate_number': instance.plateNumber,
      'vehicle_description': instance.vehicleDescription,
      'items_description': instance.itemsDescription,
      'valid_from': instance.validFrom.toIso8601String(),
      'valid_until': instance.validUntil.toIso8601String(),
      'max_uses': instance.maxUses,
      'use_count': instance.useCount,
      'qr_token': instance.qrToken,
      'qr_generated_at': instance.qrGeneratedAt?.toIso8601String(),
      'reviewed_by': instance.reviewedBy,
      'reviewed_at': instance.reviewedAt?.toIso8601String(),
      'rejection_reason': instance.rejectionReason,
      'attachments': instance.attachments,
      'notes': instance.notes,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
      'pass_types': instance.passType,
      'requester_name': instance.requesterName,
      'unit_no': instance.unitNo,
    };

const _$PassStatusEnumMap = {
  PassStatus.draft: 'draft',
  PassStatus.submitted: 'submitted',
  PassStatus.pendingReview: 'pending_review',
  PassStatus.approved: 'approved',
  PassStatus.active: 'active',
  PassStatus.used: 'used',
  PassStatus.expired: 'expired',
  PassStatus.revoked: 'revoked',
  PassStatus.rejected: 'rejected',
};

PassScanLog _$PassScanLogFromJson(Map<String, dynamic> json) => PassScanLog(
      id: json['id'] as String,
      passId: json['pass_id'] as String,
      communityId: json['community_id'] as String,
      scannedBy: json['scanned_by'] as String,
      scanType: json['scan_type'] as String,
      scanResult: json['scan_result'] as String,
      notes: json['notes'] as String?,
      scannedAt: DateTime.parse(json['scanned_at'] as String),
    );

Map<String, dynamic> _$PassScanLogToJson(PassScanLog instance) =>
    <String, dynamic>{
      'id': instance.id,
      'pass_id': instance.passId,
      'community_id': instance.communityId,
      'scanned_by': instance.scannedBy,
      'scan_type': instance.scanType,
      'scan_result': instance.scanResult,
      'notes': instance.notes,
      'scanned_at': instance.scannedAt.toIso8601String(),
    };
