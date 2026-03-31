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

  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  Community({
    required this.id,
    required this.name,
    required this.slug,
    this.address,
    this.settings,
    this.plan = 'starter',
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

  /// OR template configuration from community settings.
  /// Falls back to default detailed style if not configured.
  ORTemplateConfig get orTemplate {
    final raw = settings?['or_template'];
    if (raw is Map<String, dynamic>) {
      return ORTemplateConfig.fromJson(raw);
    }
    return ORTemplateConfig.defaultConfig;
  }
}
