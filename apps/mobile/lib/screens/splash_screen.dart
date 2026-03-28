import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:core_data/core_data.dart';
import 'package:core_ui/core_ui.dart';
import '../services/role_loader.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    final authRepo = context.read<AuthRepository>();
    final user = authRepo.currentUser;

    if (user == null) {
      Navigator.of(context).pushReplacementNamed('/login');
      return;
    }

    // User is authenticated, check communities
    final communityRepo = context.read<CommunityRepository>();
    final appState = context.read<AppState>();

    try {
      // Try to load last active community
      await appState.loadLastActiveCommunity();

      if (appState.activeCommunityId != null) {
        // Validate it still exists and user has access
        final community = await communityRepo.getCommunityById(
          appState.activeCommunityId!,
        );

        if (community != null) {
          appState.setActiveCommunityData(community);
          await RoleLoader.loadRoles(context);
          Navigator.of(context).pushReplacementNamed('/home');
          return;
        }
      }

      // Load user communities
      final communities = await communityRepo.getUserCommunities();

      if (communities.isEmpty) {
        // Show "Join Your Community" screen
        _showJoinCommunityDialog();
      } else if (communities.length == 1) {
        // Auto-select single community
        final community = communities.first;
        await appState.setActiveCommunity(community.id, community.slug);
        appState.setActiveCommunityData(community);
        await RoleLoader.loadRoles(context);
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        // Show community picker
        _showCommunityPicker(communities);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading communities: $e')),
      );
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  void _showJoinCommunityDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Join Your Community'),
        content: const Text(
          'You are not part of any community yet. Please contact your HOA administrator for an invite link.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushReplacementNamed('/login');
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _showCommunityPicker(List communities) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Select Community'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: communities.length,
            itemBuilder: (context, index) {
              final community = communities[index];
              return ListTile(
                title: Text(community.name),
                subtitle: Text(community.slug),
                onTap: () async {
                  final appState = context.read<AppState>();
                  await appState.setActiveCommunity(
                    community.id,
                    community.slug,
                  );
                  appState.setActiveCommunityData(community);
                  await RoleLoader.loadRoles(context);
                  Navigator.of(context).pop();
                  Navigator.of(context).pushReplacementNamed('/home');
                },
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/hoapp-icon.png',
              height: 100,
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(color: Color(0xff215e3f)),
          ],
        ),
      ),
    );
  }
}
