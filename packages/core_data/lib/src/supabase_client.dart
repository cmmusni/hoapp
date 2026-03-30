import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class SupabaseClientManager {
  static SupabaseClient? _instance;

  static Future<void> initialize({
    required String url,
    required String anonKey,
  }) async {
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
      authOptions: FlutterAuthClientOptions(
        authFlowType: kIsWeb ? AuthFlowType.pkce : AuthFlowType.implicit,
      ),
    );
    _instance = Supabase.instance.client;
  }

  static SupabaseClient get instance {
    if (_instance == null) {
      throw Exception(
        'SupabaseClient not initialized. Call initialize() first.',
      );
    }
    return _instance!;
  }
}
