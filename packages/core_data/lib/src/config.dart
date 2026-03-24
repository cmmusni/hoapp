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
}
