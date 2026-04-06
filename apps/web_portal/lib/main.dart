import 'dart:convert';
import 'dart:html' as html;
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_strategy/url_strategy.dart';
import 'package:core_data/core_data.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme/theme.dart';
import 'core/responsive.dart';
import 'router.dart';

/// Generate a simple browser fingerprint from stable properties.
String _browserFingerprint() {
  final nav = html.window.navigator;
  final screen = html.window.screen;
  final raw = [
    nav.userAgent,
    nav.language,
    '${screen?.width}x${screen?.height}',
    '${screen?.colorDepth}',
    DateTime.now().timeZoneOffset.inMinutes.toString(),
    nav.platform ?? '',
  ].join('|');
  return sha256.convert(utf8.encode(raw)).toString();
}

String _detectPlatform() {
  final ua = html.window.navigator.userAgent.toLowerCase();
  if (ua.contains('iphone') || ua.contains('ipad')) return 'iOS';
  if (ua.contains('android')) return 'Android';
  if (ua.contains('macintosh') || ua.contains('mac os')) return 'macOS';
  if (ua.contains('windows')) return 'Windows';
  if (ua.contains('linux')) return 'Linux';
  return 'Other';
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Remove # from URLs
  setPathUrlStrategy();

  // Initialize Supabase
  await SupabaseClientManager.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  // Notify platform admin of site access (fire-and-forget, emails only on new device)
  Supabase.instance.client.functions.invoke('notify_access', body: {
    'fingerprint': _browserFingerprint(),
    'platform': _detectPlatform(),
  }).ignore();

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
      title: community != null ? '${community.name} — HOApp' : 'HOApp',
      theme: HOAppTheme.buildLight(primaryColor: brandColor),
      darkTheme: HOAppTheme.darkTheme,
      themeMode: ThemeMode.light,
      routerConfig: _router,
      builder: AppResponsive.builder,
      debugShowCheckedModeBanner: false,
    );
  }
}
