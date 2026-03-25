import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:core_data/core_data.dart';
import 'package:core_ui/core_ui.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'services/deep_link_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
      child: const HOAppMobile(),
    ),
  );
}

class HOAppMobile extends StatefulWidget {
  const HOAppMobile({super.key});

  @override
  State<HOAppMobile> createState() => _HOAppMobileState();
}

class _HOAppMobileState extends State<HOAppMobile> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  String? _pendingInviteToken;

  @override
  void initState() {
    super.initState();
    _initializeDeepLinks();
  }

  Future<void> _initializeDeepLinks() async {
    final deepLinkService = DeepLinkService();

    // Handle invite token from deep link
    deepLinkService.onInviteReceived = (token) {
      debugPrint('Invite received: $token');
      _pendingInviteToken = token;

      // Navigate to login with invite token
      _navigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/login',
        (route) => false,
        arguments: {'inviteToken': token},
      );
    };

    await deepLinkService.initialize();
  }

  @override
  void dispose() {
    DeepLinkService().dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HOApp',
      theme: AppTheme.defaultTheme,
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      home: const SplashScreen(),
      onGenerateRoute: (settings) {
        if (settings.name == '/login') {
          final args = settings.arguments as Map<String, dynamic>?;
          return MaterialPageRoute(
            builder: (context) => LoginScreen(
              inviteToken: args?['inviteToken'],
            ),
          );
        } else if (settings.name == '/home') {
          return MaterialPageRoute(
            builder: (context) => const HomeScreen(),
          );
        } else if (settings.name == '/splash') {
          return MaterialPageRoute(
            builder: (context) => const SplashScreen(),
          );
        }
        return null;
      },
    );
  }
}
