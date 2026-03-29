import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:core_data/core_data.dart';
import 'package:core_domain/core_domain.dart';

class SelectCommunityPage extends StatefulWidget {
  const SelectCommunityPage({super.key});

  @override
  State<SelectCommunityPage> createState() => _SelectCommunityPageState();
}

class _SelectCommunityPageState extends State<SelectCommunityPage> {
  List<Community> _communities = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCommunities();
  }

  Future<void> _loadCommunities() async {
    final appState = context.read<AppState>();
    final repo = context.read<CommunityRepository>();

    try {
      List<Community> communities;
      // Platform admins see all communities
      if (appState.isPlatformAdmin) {
        communities = await repo.getAllCommunities();
      } else if (appState.userCommunities.isNotEmpty) {
        communities = appState.userCommunities;
      } else {
        communities = await repo.getUserCommunities();
        appState.setUserCommunities(communities);
      }
      if (mounted) {
        setState(() {
          _communities = communities;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final activeCommunityId = appState.activeCommunityId;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.apartment_rounded,
                    size: 48, color: Colors.blueGrey),
                const SizedBox(height: 16),
                Text(
                  'Select Community',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose which community you want to manage',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                ),
                const SizedBox(height: 32),
                if (_loading)
                  const CircularProgressIndicator()
                else if (_communities.isEmpty)
                  Column(
                    children: [
                      const Text('No communities found.'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => context.go('/create-community'),
                        child: const Text('Create Community'),
                      ),
                    ],
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _communities.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final community = _communities[index];
                        final isActive = community.id == activeCommunityId;

                        return _CommunityCard(
                          community: community,
                          isActive: isActive,
                          onTap: () {
                            context.go('/${community.slug}/announcements');
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CommunityCard extends StatelessWidget {
  final Community community;
  final bool isActive;
  final VoidCallback onTap;

  const _CommunityCard({
    required this.community,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final brandColor = _parseColor(community.primaryColor);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: isActive ? 3 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive ? brandColor : Colors.grey.shade200,
              width: isActive ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              // Logo or icon
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: community.logoUrl != null
                    ? Image.network(
                        community.logoUrl!,
                        width: 48,
                        height: 48,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: brandColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.apartment,
                              color: brandColor, size: 28),
                        ),
                      )
                    : Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: brandColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child:
                            Icon(Icons.apartment, color: brandColor, size: 28),
                      ),
              ),
              const SizedBox(width: 16),
              // Community info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      community.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isActive ? brandColor : Colors.grey.shade900,
                      ),
                    ),
                    if (community.address != null &&
                        community.address!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          community.address!,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              // Active indicator
              if (isActive)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: brandColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Current',
                    style: TextStyle(
                      color: brandColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                Icon(Icons.arrow_forward_ios,
                    size: 16, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  Color _parseColor(String hex) {
    try {
      final cleaned = hex.replaceFirst('#', '');
      return Color(int.parse('FF$cleaned', radix: 16));
    } catch (_) {
      return const Color(0xFF215E3F);
    }
  }
}
