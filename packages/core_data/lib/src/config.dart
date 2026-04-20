/// Configuration constants for the application
class AppConfig {
  // Supabase configuration - loaded from environment or defaults
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://rdkpxdgxepybuswyirrs.supabase.co',
  );

  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJka3B4ZGd4ZXB5YnVzd3lpcnJzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQxNjE5NTIsImV4cCI6MjA4OTczNzk1Mn0.gU3MpxmJ2idouYZ80BbWMVsWiHmYUgR6Wc2oaUp-3pA',
  );

  // Flavor / white-label configuration
  static const defaultCommunityId = String.fromEnvironment(
    'DEFAULT_COMMUNITY_ID',
  );

  static const appName = String.fromEnvironment(
    'APP_NAME',
    defaultValue: 'HOApp',
  );

  /// Build flavor identifier (e.g. "standard", "elevehomes").
  /// Set via `--dart-define=FLAVOR=elevehomes` at build time.
  static const flavor = String.fromEnvironment(
    'FLAVOR',
    defaultValue: 'standard',
  );

  /// Whether a specific community is hardcoded for this build
  static bool get isCommunityBuild => defaultCommunityId.isNotEmpty;

  /// Whether this is the Eleve Homes branded build.
  static bool get isElevehomes => flavor == 'elevehomes';

  /// Whether this is any white-label / branded build (not the standard HOApp).
  static bool get isBrandedBuild => isCommunityBuild || isElevehomes;
}
