import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_strategy/url_strategy.dart';
import 'package:core_data/core_data.dart';
import 'theme/theme.dart';
import 'core/responsive.dart';
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

  // Pre-load last active community slug for router redirect
  final prefs = await SharedPreferences.getInstance();
  final lastSlug = prefs.getString('active_community_slug');

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
        Provider(create: (_) => ExpenseRepository()),
        Provider(create: (_) => PoolAccessRepository()),
        Provider(create: (_) => HouseholdRepository()),
      ],
      child: HOAppWebPortal(lastCommunitySlug: lastSlug),
    ),
  );
}

class HOAppWebPortal extends StatelessWidget {
  const HOAppWebPortal({super.key, this.lastCommunitySlug});

  final String? lastCommunitySlug;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'HOApp - Homeowners Management',
      theme: HOAppTheme.lightTheme,
      darkTheme: HOAppTheme.darkTheme,
      themeMode: ThemeMode.light,
      routerConfig: createRouter(lastCommunitySlug: lastCommunitySlug),
      builder: AppResponsive.builder,
      debugShowCheckedModeBanner: false,
    );
  }
}
