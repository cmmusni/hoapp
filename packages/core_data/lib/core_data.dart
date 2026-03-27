library core_data;

// Re-export Supabase auth types needed by consumers
export 'package:supabase_flutter/supabase_flutter.dart'
    show AuthState, AuthChangeEvent, RealtimeChannel;

// Core infrastructure
export 'src/supabase_client.dart';
export 'src/state/app_state.dart';
export 'src/config.dart';

// Repositories
export 'src/repositories/auth_repository.dart';
export 'src/repositories/community_repository.dart';
export 'src/repositories/announcement_repository.dart';
export 'src/repositories/violation_repository.dart';
export 'src/repositories/ticket_repository.dart';
export 'src/repositories/amenity_repository.dart';
export 'src/repositories/billing_repository.dart';
export 'src/repositories/expense_repository.dart';
export 'src/repositories/income_repository.dart';
export 'src/repositories/pool_access_repository.dart';
export 'src/repositories/household_repository.dart';
export 'src/repositories/security_pass_repository.dart';

// Services
export 'src/services/storage_service.dart';
export 'src/services/realtime_service.dart';
