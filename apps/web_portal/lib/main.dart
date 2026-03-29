import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
        Provider(create: (_) => RecurringBillingRepository()),
        Provider(create: (_) => ExpenseRepository()),
        Provider(create: (_) => IncomeRepository()),
        Provider(create: (_) => PoolAccessRepository()),
        Provider(create: (_) => HouseholdRepository()),
      ],
      child: HOAppWebPortal(lastCommunitySlug: lastSlug),
    ),
  );
}

class HOAppWebPortal extends StatefulWidget {
  const HOAppWebPortal({super.key, this.lastCommunitySlug});

  final String? lastCommunitySlug;

  @override
  State<HOAppWebPortal> createState() => _HOAppWebPortalState();
}

class _HOAppWebPortalState extends State<HOAppWebPortal> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = createRouter(lastCommunitySlug: widget.lastCommunitySlug);
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final community = appState.activeCommunity;
    Color? brandColor;
    if (community != null) {
      final hex = community.primaryColor;
      brandColor = Color(int.parse(hex.replaceFirst('#', '0xff')));
    }

    return MaterialApp.router(
      title: 'HOApp',
      theme: HOAppTheme.buildLight(primaryColor: brandColor),
      darkTheme: HOAppTheme.darkTheme,
      themeMode: ThemeMode.light,
      routerConfig: _router,
      builder: AppResponsive.builder,
      debugShowCheckedModeBanner: false,
    );
  }
}
