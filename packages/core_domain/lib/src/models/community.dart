import 'package:json_annotation/json_annotation.dart';
import 'or_template_config.dart';

part 'community.g.dart';

@JsonSerializable()
class Community {
  final String id;
  final String name;
  final String slug;
  final String? address;
  final Map<String, dynamic>? settings;
  final String plan; // 'starter', 'professional', 'enterprise'

  @JsonKey(name: 'plan_expires_at')
  final DateTime? planExpiresAt;

  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  Community({
    required this.id,
    required this.name,
    required this.slug,
    this.address,
    this.settings,
    this.plan = 'starter',
    this.planExpiresAt,
    required this.createdAt,
  });

  factory Community.fromJson(Map<String, dynamic> json) =>
      _$CommunityFromJson(json);

  Map<String, dynamic> toJson() => _$CommunityToJson(this);

  String? get logoUrl => settings?['logo_url'] as String?;

  String get primaryColor =>
      settings?['brand']?['primary'] as String? ?? '#215E3F';

  String get surfaceColor =>
      settings?['brand']?['surface'] as String? ?? '#ECEFF1';

  bool get isProfessional => plan == 'professional' || plan == 'enterprise';
  bool get isEnterprise => plan == 'enterprise';

  /// Whether the plan is expiring within 7 days.
  bool get isPlanExpiringSoon =>
      planExpiresAt != null &&
      planExpiresAt!.difference(DateTime.now()).inDays <= 7 &&
      planExpiresAt!.isAfter(DateTime.now());

  /// Whether the plan has expired (but may still be in grace period).
  bool get isPlanExpired =>
      planExpiresAt != null && planExpiresAt!.isBefore(DateTime.now());

  /// Days remaining until plan expires (negative if expired).
  int? get daysUntilExpiry => planExpiresAt?.difference(DateTime.now()).inDays;

  /// OR template configuration from community settings.
  /// Falls back to default detailed style if not configured.
  ORTemplateConfig get orTemplate {
    final raw = settings?['or_template'];
    if (raw is Map<String, dynamic>) {
      return ORTemplateConfig.fromJson(raw);
    }
    return ORTemplateConfig.defaultConfig;
  }

  /// User IDs of community admins who should receive payment submission
  /// email notifications. Empty list means all admins will be notified.
  List<String> get paymentNotificationAdminIds {
    final raw = settings?['payment_notification_admin_ids'];
    if (raw is List) {
      return raw.cast<String>();
    }
    return [];
  }
}
