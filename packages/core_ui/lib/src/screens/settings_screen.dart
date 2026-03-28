import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:core_data/core_data.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

/// Shared settings screen — adaptive for web and mobile.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<Community?>? _communityFuture;

  @override
  void initState() {
    super.initState();
    _loadCommunity();
  }

  void _loadCommunity() {
    final appState = context.read<AppState>();
    final repo = context.read<CommunityRepository>();
    if (appState.activeCommunityId != null) {
      setState(() {
        _communityFuture = repo.getCommunityById(appState.activeCommunityId!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isAdmin = appState.isAdmin;

    return Scaffold(
      body: FutureBuilder<Community?>(
        future: _communityFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final community = snapshot.data;
          if (community == null) {
            return const Center(child: Text('Community not found'));
          }

          return RefreshIndicator(
            onRefresh: () async => _loadCommunity(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Community info
                Text('Community Information',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(children: [
                      _InfoRow(label: 'Name', value: community.name),
                      const Divider(),
                      _InfoRow(label: 'Slug', value: community.slug),
                      if (community.address != null) ...[
                        const Divider(),
                        _InfoRow(label: 'Address', value: community.address!),
                      ],
                    ]),
                  ),
                ),
                const SizedBox(height: 24),

                // Branding
                Row(children: [
                  Text('Branding',
                      style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  if (isAdmin)
                    TextButton.icon(
                      onPressed: () => _showBrandingDialog(context, community),
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Edit'),
                    ),
                ]),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(children: [
                      Row(children: [
                        const Text('Primary Color:'),
                        const SizedBox(width: 12),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Color(int.parse(community.primaryColor
                                .replaceFirst('#', '0xff'))),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(community.primaryColor),
                      ]),
                      if (community.logoUrl != null) ...[
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            community.logoUrl!,
                            height: 60,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.broken_image),
                          ),
                        ),
                      ],
                    ]),
                  ),
                ),
                const SizedBox(height: 24),

                // Unit Types (admin only)
                if (isAdmin) ...[
                  _UnitTypesSection(communityId: community.id),
                  const SizedBox(height: 24),
                ],

                // Sign out
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _handleSignOut(context),
                    icon: const Icon(Icons.logout, color: Colors.red),
                    label: const Text('Sign Out'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showBrandingDialog(BuildContext context, Community community) {
    Color pickerColor =
        Color(int.parse(community.primaryColor.replaceFirst('#', '0xff')));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Branding'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Primary Color'),
              const SizedBox(height: 8),
              ColorPicker(
                pickerColor: pickerColor,
                onColorChanged: (c) => pickerColor = c,
                enableAlpha: false,
                pickerAreaHeightPercent: 0.6,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              try {
                final repo = context.read<CommunityRepository>();
                final appState = context.read<AppState>();
                final hex =
                    '#${pickerColor.toARGB32().toRadixString(16).substring(2)}';
                await repo.updateCommunitySettings(
                  communityId: appState.activeCommunityId!,
                  settings: {'primary_color': hex},
                );
                if (mounted) {
                  Navigator.of(ctx).pop();
                  _loadCommunity();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out?'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Sign Out')),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      final authRepo = context.read<AuthRepository>();
      await authRepo.signOut();
      if (context.mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }
}

// ─── Support Widgets ─────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        SizedBox(
          width: 80,
          child: Text(label,
              style: TextStyle(
                  color: Colors.grey[600], fontWeight: FontWeight.w500)),
        ),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 15))),
      ]),
    );
  }
}

// ─── Unit Types Section ──────────────────────────────────────────────────────

class _UnitTypesSection extends StatefulWidget {
  final String communityId;
  const _UnitTypesSection({required this.communityId});

  @override
  State<_UnitTypesSection> createState() => _UnitTypesSectionState();
}

class _UnitTypesSectionState extends State<_UnitTypesSection> {
  Future<List<UnitType>>? _unitTypesFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final repo = context.read<HouseholdRepository>();
    setState(() {
      _unitTypesFuture = repo.getUnitTypes(widget.communityId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text('Unit Types', style: Theme.of(context).textTheme.titleLarge),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => _showAddDialog(),
          ),
        ]),
        const SizedBox(height: 8),
        FutureBuilder<List<UnitType>>(
          future: _unitTypesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LinearProgressIndicator();
            }
            final types = snapshot.data ?? [];
            if (types.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('No unit types defined',
                      style: TextStyle(color: Colors.grey[500])),
                ),
              );
            }
            return Column(
              children: types
                  .map((t) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(t.name),
                          subtitle: t.description != null
                              ? Text(t.description!)
                              : null,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20),
                                onPressed: () => _showEditDialog(t),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete,
                                    size: 20, color: Colors.red),
                                onPressed: () async {
                                  final repo =
                                      context.read<HouseholdRepository>();
                                  await repo.deleteUnitType(t.id);
                                  _load();
                                },
                              ),
                            ],
                          ),
                        ),
                      ))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  void _showAddDialog() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add Unit Type'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                  labelText: 'Name',
                  prefixIcon: const Icon(Icons.label_outlined, size: 20),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xff215e3f), width: 1.5),
                  )),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              decoration: InputDecoration(
                  labelText: 'Description (optional)',
                  prefixIcon: const Icon(Icons.description_outlined, size: 20),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xff215e3f), width: 1.5),
                  )),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          ElevatedButton.icon(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              try {
                final repo = context.read<HouseholdRepository>();
                await repo.createUnitType(
                  communityId: widget.communityId,
                  name: nameCtrl.text.trim(),
                  description: descCtrl.text.trim().isEmpty
                      ? null
                      : descCtrl.text.trim(),
                );
                if (mounted) {
                  Navigator.of(ctx).pop();
                  _load();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Create'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff215e3f),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(UnitType unitType) {
    final nameCtrl = TextEditingController(text: unitType.name);
    final descCtrl = TextEditingController(text: unitType.description ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Unit Type'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                  labelText: 'Name',
                  prefixIcon: const Icon(Icons.label_outlined, size: 20),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xff215e3f), width: 1.5),
                  )),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              decoration: InputDecoration(
                  labelText: 'Description (optional)',
                  prefixIcon: const Icon(Icons.description_outlined, size: 20),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xff215e3f), width: 1.5),
                  )),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          ElevatedButton.icon(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              try {
                final repo = context.read<HouseholdRepository>();
                await repo.updateUnitType(
                  id: unitType.id,
                  name: nameCtrl.text.trim(),
                  description: descCtrl.text.trim().isEmpty
                      ? null
                      : descCtrl.text.trim(),
                );
                if (mounted) {
                  Navigator.of(ctx).pop();
                  _load();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            icon: const Icon(Icons.save_rounded),
            label: const Text('Save'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff215e3f),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}
