import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:core_data/core_data.dart';
import 'package:core_domain/core_domain.dart';

class HouseholdScreen extends StatefulWidget {
  const HouseholdScreen({super.key});

  @override
  State<HouseholdScreen> createState() => _HouseholdScreenState();
}

class _HouseholdScreenState extends State<HouseholdScreen> {
  Future<List<HouseholdMember>>? _membersFuture;
  Household? _household;

  @override
  void initState() {
    super.initState();
    _loadHousehold();
  }

  Future<void> _loadHousehold() async {
    final appState = context.read<AppState>();
    final userId = context.read<AuthRepository>().currentUser?.id;

    if (appState.activeCommunityId == null || userId == null) return;

    final repo = context.read<HouseholdRepository>();

    try {
      // Get user's household
      final households = await repo.getHouseholds(appState.activeCommunityId!);
      final myHousehold = households
          .where((h) => h.members?.any((m) => m.userId == userId) ?? false)
          .firstOrNull;

      if (myHousehold != null && mounted) {
        setState(() {
          _household = myHousehold;
          _membersFuture = repo.getHouseholdMembers(myHousehold.id);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading household: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Household'),
      ),
      body: _household == null
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.home_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No household found'),
                  SizedBox(height: 8),
                  Text(
                    'Contact your community admin to be added to a unit',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Household info header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.primary.withOpacity(0.7),
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _household!.unitNumber,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_household!.address != null)
                        Text(
                          _household!.address!,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white70,
                          ),
                        ),
                    ],
                  ),
                ),

                // Members list
                Expanded(
                  child: FutureBuilder<List<HouseholdMember>>(
                    future: _membersFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline,
                                  size: 64, color: Colors.red),
                              const SizedBox(height: 16),
                              Text('Error: ${snapshot.error}'),
                            ],
                          ),
                        );
                      }

                      final members = snapshot.data ?? [];

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: members.length,
                        itemBuilder: (context, index) {
                          final member = members[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: CircleAvatar(
                                child: Text(
                                  member.name.substring(0, 1).toUpperCase(),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(
                                member.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(_getRoleLabel(member.role)),
                                  if (member.email != null)
                                    Text(
                                      member.email!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  if (member.phone != null)
                                    Text(
                                      member.phone!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                ],
                              ),
                              trailing: Chip(
                                label: Text(
                                  _getRoleLabel(member.role),
                                  style: const TextStyle(fontSize: 11),
                                ),
                                backgroundColor:
                                    _getRoleColor(member.role).withOpacity(0.2),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  String _getRoleLabel(HouseholdRole role) {
    switch (role) {
      case HouseholdRole.owner:
        return 'Owner';
      case HouseholdRole.tenant:
        return 'Tenant';
      case HouseholdRole.occupant:
        return 'Occupant';
      case HouseholdRole.dependent:
        return 'Dependent';
    }
  }

  Color _getRoleColor(HouseholdRole role) {
    switch (role) {
      case HouseholdRole.owner:
        return Colors.purple;
      case HouseholdRole.tenant:
        return Colors.blue;
      case HouseholdRole.occupant:
        return Color.fromRGBO(39, 99, 67, 1);
      case HouseholdRole.dependent:
        return Colors.orange;
    }
  }
}
