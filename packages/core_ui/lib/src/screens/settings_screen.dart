import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:core_data/core_data.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/eyedropper.dart' as eyedropper;

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
                      const Divider(height: 24),
                      Row(children: [
                        const Text('Community Logo:'),
                        const Spacer(),
                        if (isAdmin)
                          TextButton.icon(
                            onPressed: () => _uploadLogo(context, community),
                            icon: const Icon(Icons.upload, size: 18),
                            label: Text(community.logoUrl != null
                                ? 'Change'
                                : 'Upload'),
                          ),
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
                      ] else
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('No logo uploaded',
                              style: TextStyle(color: Colors.grey)),
                        ),
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

  // Preset color swatches for quick selection
  static const List<Color> _presetColors = [
    Color(0xff215E3F), // Forest green (default)
    Color(0xff1565C0), // Blue
    Color(0xff6A1B9A), // Purple
    Color(0xffC62828), // Red
    Color(0xffE65100), // Deep orange
    Color(0xff2E7D32), // Green
    Color(0xff00838F), // Teal
    Color(0xff4527A0), // Deep purple
    Color(0xff283593), // Indigo
    Color(0xff558B2F), // Light green
    Color(0xff795548), // Brown
    Color(0xff37474F), // Blue grey
    Color(0xffF57F17), // Amber
    Color(0xffAD1457), // Pink
    Color(0xff00695C), // Dark teal
    Color(0xff1B5E20), // Dark green
  ];

  void _showBrandingDialog(BuildContext context, Community community) {
    Color pickerColor =
        Color(int.parse(community.primaryColor.replaceFirst('#', '0xff')));
    final hexController = TextEditingController(
      text: community.primaryColor.replaceFirst('#', '').toUpperCase(),
    );
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          void updateFromHex(String hex) {
            hex = hex.replaceFirst('#', '').toUpperCase();
            if (hex.length == 6 && RegExp(r'^[0-9A-F]{6}$').hasMatch(hex)) {
              setDialogState(() {
                pickerColor = Color(int.parse('0xff$hex'));
              });
            }
          }

          void updateFromPicker(Color c) {
            setDialogState(() {
              pickerColor = c;
              hexController.text =
                  c.toARGB32().toRadixString(16).substring(2).toUpperCase();
            });
          }

          final theme = Theme.of(ctx);

          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            titlePadding: EdgeInsets.zero,
            title: Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              decoration: BoxDecoration(
                color: pickerColor.withValues(alpha: 0.08),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: pickerColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.palette_rounded,
                        color: pickerColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Text('Edit Branding',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Live preview
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: pickerColor,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: pickerColor.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.visibility_rounded,
                              color: Colors.white, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Live Preview',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Text(
                            '#${hexController.text}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontFamily: 'monospace',
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Hex input + eyedropper
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: pickerColor,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: Colors.grey.shade300, width: 1.5),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: hexController,
                            decoration: InputDecoration(
                              prefixText: '#',
                              labelText: 'Hex Color',
                              hintText: '2E7D32',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: pickerColor, width: 1.5),
                              ),
                              counterText: '',
                            ),
                            maxLength: 6,
                            onChanged: updateFromHex,
                          ),
                        ),
                        if (eyedropper.isEyeDropperAvailable) ...[
                          const SizedBox(width: 8),
                          Tooltip(
                            message: 'Pick color from screen',
                            child: Material(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () async {
                                  final color =
                                      await eyedropper.pickColorFromScreen();
                                  if (color != null) {
                                    updateFromPicker(color);
                                  }
                                },
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  alignment: Alignment.center,
                                  child: Icon(Icons.colorize_rounded,
                                      color: Colors.grey.shade700, size: 22),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Preset colors
                    Text('Quick Select',
                        style: theme.textTheme.titleSmall?.copyWith(
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _presetColors.map((color) {
                        final isSelected =
                            pickerColor.toARGB32() == color.toARGB32();
                        return GestureDetector(
                          onTap: () => updateFromPicker(color),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.transparent,
                                width: 2.5,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: color.withValues(alpha: 0.5),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      )
                                    ]
                                  : null,
                            ),
                            child: isSelected
                                ? const Icon(Icons.check_rounded,
                                    color: Colors.white, size: 18)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Color picker
                    Text('Custom Color',
                        style: theme.textTheme.titleSmall?.copyWith(
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ColorPicker(
                        pickerColor: pickerColor,
                        onColorChanged: updateFromPicker,
                        enableAlpha: false,
                        pickerAreaHeightPercent: 0.5,
                        displayThumbColor: true,
                        paletteType: PaletteType.hsvWithHue,
                        labelTypes: const [],
                        pickerAreaBorderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actionsPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.of(ctx).pop(),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: saving
                    ? null
                    : () async {
                        setDialogState(() => saving = true);
                        try {
                          final repo = context.read<CommunityRepository>();
                          final appState = context.read<AppState>();
                          final hex =
                              '#${pickerColor.toARGB32().toRadixString(16).substring(2)}';
                          final existing =
                              appState.activeCommunity?.settings ?? {};
                          final brand =
                              (existing['brand'] as Map<String, dynamic>?) ??
                                  {};
                          final updatedSettings = {
                            ...existing,
                            'brand': {...brand, 'primary': hex},
                          };
                          await repo.updateCommunitySettings(
                            communityId: appState.activeCommunityId!,
                            settings: updatedSettings,
                          );
                          if (mounted) {
                            final refreshed = await repo.getCommunityById(
                              appState.activeCommunityId!,
                            );
                            if (refreshed != null) {
                              appState.setActiveCommunityData(refreshed);
                            }
                            Navigator.of(ctx).pop();
                            _loadCommunity();
                          }
                        } catch (e) {
                          setDialogState(() => saving = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')));
                          }
                        }
                      },
                icon: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_rounded),
                label: Text(saving ? 'Saving...' : 'Save'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: pickerColor,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _uploadLogo(BuildContext context, Community community) async {
    try {
      final storageService = StorageService(Supabase.instance.client);
      final file = await storageService.pickImage();
      if (file == null) return;

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Uploading logo...')));

      final url = await storageService.uploadImage(
        bucket: 'community-logos',
        file: file,
        folder: community.id,
      );

      if (!mounted) return;
      final repo = context.read<CommunityRepository>();
      final appState = context.read<AppState>();
      final existing = appState.activeCommunity?.settings ?? {};
      final updatedSettings = {
        ...existing,
        'logo_url': url,
      };
      await repo.updateCommunitySettings(
        communityId: community.id,
        settings: updatedSettings,
      );

      final refreshed = await repo.getCommunityById(community.id);
      if (refreshed != null && mounted) {
        appState.setActiveCommunityData(refreshed);
        _loadCommunity();
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Logo uploaded successfully')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    }
  }

  Future<void> _handleSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: EdgeInsets.zero,
        title: Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.logout_rounded,
                    color: Colors.red.shade700, size: 22),
              ),
              const SizedBox(width: 12),
              Text('Sign Out',
                  style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600, color: Colors.red.shade700)),
            ],
          ),
        ),
        content: const Text(
          'Are you sure you want to sign out? You will need to log in again to access your community.',
          style: TextStyle(fontSize: 15, height: 1.4),
        ),
        actionsPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Sign Out'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          ),
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
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final primary = theme.colorScheme.primary;
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titlePadding: EdgeInsets.zero,
          title: Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.add_home_work_rounded,
                      color: primary, size: 22),
                ),
                const SizedBox(width: 12),
                Text('Add Unit Type',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
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
                    borderSide: BorderSide(color: primary, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 14),
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
                    borderSide: BorderSide(color: primary, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
          actionsPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 8),
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
              icon: Icon(Icons.add_circle_outline, color: primary),
              label: const Text('Create'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ],
        );
      },
    );
  }

  void _showEditDialog(UnitType unitType) {
    final nameCtrl = TextEditingController(text: unitType.name);
    final descCtrl = TextEditingController(text: unitType.description ?? '');
    showDialog(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final primary = theme.colorScheme.primary;
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titlePadding: EdgeInsets.zero,
          title: Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.edit_rounded, color: primary, size: 22),
                ),
                const SizedBox(width: 12),
                Text('Edit Unit Type',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
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
                    borderSide: BorderSide(color: primary, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 14),
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
                    borderSide: BorderSide(color: primary, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
          actionsPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 8),
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
              icon: const Icon(Icons.save_rounded, size: 18),
              label: const Text('Save'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ],
        );
      },
    );
  }
}
