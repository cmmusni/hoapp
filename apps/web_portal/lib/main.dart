import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_strategy/url_strategy.dart';
import 'package:core_data/core_data.dart';
import 'package:core_ui/core_ui.dart';
import 'router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Remove # from URLs
  setPathUrlStrategy();

  // Initialize Supabase
  await SupabaseClientManager.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
        Provider(create: (_) => AuthRepository()),
        Provider(create: (_) => CommunityRepository()),
        Provider(create: (_) => AnnouncementRepository()),
        Provider(create: (_) => ViolationRepository()),
        Provider(create: (_) => TicketRepository()),
        Provider(create: (_) => AmenityRepository()),
        Provider(create: (_) => BillingRepository()),
        Provider(create: (_) => PoolAccessRepository()),
        Provider(create: (_) => HouseholdRepository()),
      ],
      child: const HOAppWebPortal(),
    ),
  );
}

class HOAppWebPortal extends StatelessWidget {
  const HOAppWebPortal({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'HOApp - Homeowners Management',
      theme: AppTheme.defaultTheme,
      routerConfig: createRouter(),
      debugShowCheckedModeBanner: false,
    );
  }
}
