import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:core_data/core_data.dart';
import 'package:core_domain/core_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HouseholdScreen extends StatefulWidget {
  const HouseholdScreen({super.key});

  @override
  State<HouseholdScreen> createState() => _HouseholdScreenState();
}

class _HouseholdScreenState extends State<HouseholdScreen> {
  Future<List<HouseholdMember>>? _membersFuture;
  Unit? _unit;

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
      // Query household_members with joined unit data directly
      final response = await Supabase.instance.client
          .from('household_members')
          .select('*, units(*)')
          .eq('user_id', userId)
          .eq('community_id', appState.activeCommunityId!);

      final rows = response as List;
      if (rows.isNotEmpty && mounted) {
        final first = Map<String, dynamic>.from(rows.first);
        final unitId = first['unit_id'] as String;

        // Extract the joined unit data
        final unitData = first['units'];
        if (unitData != null && unitData is Map) {
          _unit = Unit.fromJson(Map<String, dynamic>.from(unitData));
        } else {
          _unit = Unit(
            id: unitId,
            communityId: appState.activeCommunityId!,
            unitNo: 'Unknown',
            createdAt: DateTime.now(),
          );
        }

        setState(() {
          _membersFuture = repo.getHouseholdMembers(unitId);
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
      body: _unit == null
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
                      Row(
                        children: [
                          const Icon(Icons.home,
                              color: Colors.white70, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Unit ${_unit!.unitNo}',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_unit!.unitType != null)
                        Text(
                          _unit!.unitType!,
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
                                  member.displayName
                                      .substring(0, 1)
                                      .toUpperCase(),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(
                                member.displayName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(_getRoleLabel(member.memberRole)),
                                  if (member.relationship != null)
                                    Text(
                                      member.relationship!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                ],
                              ),
                              trailing: Chip(
                                label: Text(
                                  _getRoleLabel(member.memberRole),
                                  style: const TextStyle(fontSize: 11),
                                ),
                                backgroundColor:
                                    _getRoleColor(member.memberRole)
                                        .withOpacity(0.2),
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
      case HouseholdRole.primary:
        return 'Primary';
      case HouseholdRole.member:
        return 'Member';
      case HouseholdRole.child:
        return 'Child';
      case HouseholdRole.tenant:
        return 'Tenant';
      case HouseholdRole.other:
        return 'Other';
    }
  }

  Color _getRoleColor(HouseholdRole role) {
    switch (role) {
      case HouseholdRole.primary:
        return Colors.purple;
      case HouseholdRole.member:
        return Colors.blue;
      case HouseholdRole.child:
        return Colors.orange;
      case HouseholdRole.tenant:
        return Color.fromRGBO(39, 99, 67, 1);
      case HouseholdRole.other:
        return Colors.grey;
    }
  }
}
