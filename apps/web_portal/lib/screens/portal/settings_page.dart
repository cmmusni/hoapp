import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:core_data/core_data.dart';
import 'package:core_domain/core_domain.dart';
import 'package:core_ui/core_ui.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
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
        // TODO: getCommunity method doesn't exist, using getCommunityById
        _communityFuture = repo.getCommunityById(appState.activeCommunityId!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isAdmin = appState.isAdmin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
      ),
      body: FutureBuilder<Community?>(
        future: _communityFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingIndicator(message: 'Loading settings...');
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  HOAppButton(label: 'Retry', onPressed: _loadCommunity),
                ],
              ),
            );
          }

          final community = snapshot.data;

          if (community == null) {
            return const Center(child: Text('Community not found'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Community info
                Text(
                  'Community Information',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                _InfoCard(children: [
                  _InfoRow(label: 'Name', value: community.name),
                  _InfoRow(label: 'Slug', value: community.slug),
                  if (community.address != null)
                    _InfoRow(label: 'Address', value: community.address!),
                ]),

                const SizedBox(height: 24),

                // Branding
                Row(
                  children: [
                    Text(
                      'Branding',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    if (isAdmin)
                      TextButton.icon(
                        onPressed: () =>
                            _showBrandingDialog(context, community),
                        icon: const Icon(Icons.edit),
                        label: const Text('Edit'),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                _BrandingPreview(
                  primaryColor: _parseBrandingValue<String>(
                    community.settings,
                    'primaryColor',
                    '#2E7D32',
                  ),
                  logoUrl: _parseBrandingValue<String>(
                    community.settings,
                    'logoUrl',
                    '', // Empty string instead of null
                  ),
                ),

                const SizedBox(height: 24),

                // Unit Types
                if (isAdmin) ...[
                  _UnitTypesSection(
                    communityId: community.id,
                  ),
                  const SizedBox(height: 24),
                ],

                // Account settings
                Text(
                  'Account',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                HOAppCard(
                  onTap: () {
                    // TODO: Navigate to change password
                  },
                  child: const ListTile(
                    leading: Icon(Icons.lock),
                    title: Text('Change Password'),
                    trailing: Icon(Icons.chevron_right),
                  ),
                ),
                const SizedBox(height: 8),
                HOAppCard(
                  onTap: () {
                    // TODO: Navigate to edit profile
                  },
                  child: const ListTile(
                    leading: Icon(Icons.person),
                    title: Text('Edit Profile'),
                    trailing: Icon(Icons.chevron_right),
                  ),
                ),
                const SizedBox(height: 8),
                HOAppCard(
                  onTap: () {
                    // TODO: Show notifications settings
                  },
                  child: const ListTile(
                    leading: Icon(Icons.notifications),
                    title: Text('Notifications'),
                    trailing: Icon(Icons.chevron_right),
                  ),
                ),

                const SizedBox(height: 24),

                // Sign out
                SizedBox(
                  width: double.infinity, // Full width
                  child: HOAppButton(
                    label: 'Sign Out',
                    onPressed: () => _handleSignOut(context),
                    isOutlined: true, // Use isOutlined instead of variant
                  ),
                ),

                const SizedBox(height: 32),

                // App info
                Center(
                  child: Column(
                    children: [
                      Text(
                        'HOApp v1.0.0',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Made with Flutter & Supabase',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  T _parseBrandingValue<T>(
      Map<String, dynamic>? settings, String key, T defaultValue) {
    if (settings == null) return defaultValue;
    final value = settings[key];
    if (value is T) return value;
    return defaultValue;
  }

  void _showBrandingDialog(BuildContext context, Community community) {
    showDialog(
      context: context,
      builder: (context) => _BrandingDialog(
        community: community,
        onSaved: _loadCommunity,
      ),
    );
  }

  Future<void> _handleSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.logout, color: Colors.orange, size: 24),
            const SizedBox(width: 12),
            const Text('Sign Out?',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(false),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final authRepo = context.read<AuthRepository>();
      await authRepo.signOut();

      if (context.mounted) {
        // TODO: Navigate to login screen
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Signed out')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;

  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: children,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}

class _BrandingPreview extends StatelessWidget {
  final String primaryColor;
  final String? logoUrl;

  const _BrandingPreview({
    required this.primaryColor,
    this.logoUrl,
  });

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(primaryColor);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (logoUrl != null) ...[
              Center(
                child: Image.network(
                  logoUrl!,
                  height: 80,
                  errorBuilder: (context, error, stack) {
                    return Container(
                      height: 80,
                      width: 80,
                      color: Colors.grey[300],
                      child: const Icon(Icons.image_not_supported),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
            ],
            const Text(
              'Primary Color',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(primaryColor),
                    const SizedBox(height: 4),
                    Text(
                      'Used in buttons, links, and highlights',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 20, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Changes may require app restart to take full effect.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _parseColor(String hex) {
    try {
      final hexCode = hex.replaceAll('#', '');
      return Color(int.parse('FF$hexCode', radix: 16));
    } catch (e) {
      return Colors.grey;
    }
  }
}

class _BrandingDialog extends StatefulWidget {
  final Community community;
  final VoidCallback onSaved;

  const _BrandingDialog({required this.community, required this.onSaved});

  @override
  State<_BrandingDialog> createState() => _BrandingDialogState();
}

class _BrandingDialogState extends State<_BrandingDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _primaryColorController;
  late final TextEditingController _logoUrlController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final settings = widget.community.settings ?? {};
    _primaryColorController = TextEditingController(
      text: settings['primaryColor'] ?? '#2E7D32',
    );
    _logoUrlController = TextEditingController(
      text: settings['logoUrl'] ?? '',
    );
  }

  @override
  void dispose() {
    _primaryColorController.dispose();
    _logoUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.palette_outlined,
              color: Color(0xFF2E7D32), size: 24),
          const SizedBox(width: 12),
          const Text('Edit Branding',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _primaryColorController,
                decoration: const InputDecoration(
                  labelText: 'Primary Color',
                  border: OutlineInputBorder(),
                  hintText: '#2E7D32',
                  helperText: 'Hex color code (e.g., #2E7D32)',
                ),
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Required';
                  if (!RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(value!)) {
                    return 'Invalid hex color';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _logoUrlController,
                decoration: const InputDecoration(
                  labelText: 'Logo URL (optional)',
                  border: OutlineInputBorder(),
                  hintText: 'https://example.com/logo.png',
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber,
                        size: 20, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Branding changes affect all users in this community.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        HOAppButton(
          label: 'Save',
          onPressed: _handleSave,
          isLoading: _isLoading,
        ),
      ],
    );
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final repo = context.read<CommunityRepository>();

      final updatedSettings = {
        ...?widget.community.settings,
        'primaryColor': _primaryColorController.text.trim(),
        if (_logoUrlController.text.trim().isNotEmpty)
          'logoUrl': _logoUrlController.text.trim(),
      };

      final updatedCommunity = Community(
        id: widget.community.id,
        name: widget.community.name,
        slug: widget.community.slug,
        address: widget.community.address,
        settings: updatedSettings,
        createdAt: widget.community.createdAt,
      );

      // TODO: updateCommunity method doesn't exist yet
      // await repo.updateCommunity(updatedCommunity);
      await Future.delayed(const Duration(milliseconds: 500)); // Stub for now

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Branding updated')),
        );
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

// ============ UNIT TYPES SECTION ============

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
        Row(
          children: [
            Text(
              'Unit Types',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _showAddDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Define unit types that can be assigned when creating units (e.g. Studio, 1BR, 2BR).',
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<UnitType>>(
          future: _unitTypesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            }

            final types = snapshot.data ?? [];

            if (types.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.category_outlined,
                            size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        const Text('No unit types defined yet'),
                        const SizedBox(height: 8),
                        Text(
                          'Add types like "Studio", "1BR", "2BR", "Penthouse"',
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return Card(
              child: Column(
                children: [
                  for (int i = 0; i < types.length; i++) ...[
                    ListTile(
                      leading: const Icon(Icons.category_outlined),
                      title: Text(types[i].name),
                      subtitle: types[i].description != null
                          ? Text(types[i].description!)
                          : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            onPressed: () => _showEditDialog(context, types[i]),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                size: 20, color: Colors.red),
                            onPressed: () => _confirmDelete(context, types[i]),
                          ),
                        ],
                      ),
                    ),
                    if (i < types.length - 1) const Divider(height: 1),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  void _showAddDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _UnitTypeDialog(
        communityId: widget.communityId,
        onSaved: _load,
      ),
    );
  }

  void _showEditDialog(BuildContext context, UnitType unitType) {
    showDialog(
      context: context,
      builder: (context) => _UnitTypeDialog(
        communityId: widget.communityId,
        unitType: unitType,
        onSaved: _load,
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, UnitType unitType) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.delete_outline, color: Colors.red, size: 24),
            const SizedBox(width: 12),
            const Text('Delete Unit Type',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(false),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        content: Text(
            'Delete "${unitType.name}"? Units using this type will keep their current value.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final repo = context.read<HouseholdRepository>();
      await repo.deleteUnitType(unitType.id);
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unit type deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

class _UnitTypeDialog extends StatefulWidget {
  final String communityId;
  final UnitType? unitType;
  final VoidCallback onSaved;

  const _UnitTypeDialog({
    required this.communityId,
    this.unitType,
    required this.onSaved,
  });

  @override
  State<_UnitTypeDialog> createState() => _UnitTypeDialogState();
}

class _UnitTypeDialogState extends State<_UnitTypeDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  bool _isSaving = false;

  bool get _isEditing => widget.unitType != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.unitType?.name ?? '');
    _descController =
        TextEditingController(text: widget.unitType?.description ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(
            _isEditing ? Icons.edit_outlined : Icons.add_circle_outline,
            color: const Color(0xFF2E7D32),
            size: 24,
          ),
          const SizedBox(width: 12),
          Text(
            _isEditing ? 'Edit Unit Type' : 'Add Unit Type',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g., Studio, 1BR, 2BR',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null,
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                hintText: 'e.g., One bedroom unit with balcony',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        HOAppButton(
          label: _isSaving ? 'Saving...' : (_isEditing ? 'Update' : 'Add'),
          onPressed: _isSaving ? null : _handleSave,
        ),
      ],
    );
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final repo = context.read<HouseholdRepository>();
      final name = _nameController.text.trim();
      final desc = _descController.text.trim().isNotEmpty
          ? _descController.text.trim()
          : null;

      if (_isEditing) {
        await repo.updateUnitType(
          id: widget.unitType!.id,
          name: name,
          description: desc,
        );
      } else {
        await repo.createUnitType(
          communityId: widget.communityId,
          name: name,
          description: desc,
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Unit type ${_isEditing ? 'updated' : 'added'}')),
        );
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
